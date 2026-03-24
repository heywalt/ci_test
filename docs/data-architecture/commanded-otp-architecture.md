# Commanded OTP Process Architecture

This document describes the OTP process architecture of the
[Commanded](https://hexdocs.pm/commanded/) library -- specifically, how
processes are structured, supervised, and communicate during the pipeline
from command dispatch through event persistence.

---

## Supervision Tree

When the `CQRS` application starts, Commanded builds this process tree:

```
CQRS Application Supervisor (:one_for_one)
├── EventStore (PostgreSQL adapter)
├── PubSub Adapter (broadcasts ack messages between nodes)
├── Registry (Elixir Registry, :unique keys)
├── Task.Supervisor (TaskDispatcher)
├── Commanded.Aggregates.Supervisor (DynamicSupervisor)
│   └── Aggregate instances (GenServer, :temporary restart)
│       ├── LeadAggregate "uuid-123"
│       ├── EnrichmentAggregate "uuid-456"
│       └── ... (one process per active aggregate instance)
├── Subscriptions.Registry (GenServer owning ETS table)
└── Subscriptions (GenServer coordinating strong consistency)
```

### Design Decisions

- **Aggregates use `:temporary` restart.** They are never auto-restarted. If
  one crashes, the next command targeting that UUID spawns a fresh process
  that rebuilds state from the event store. The event store is the source of
  truth, not the process.

- **DynamicSupervisor for aggregates.** Aggregates are started on-demand, not
  at boot time. Only aggregates that are actively handling commands exist as
  processes.

- **Registry with `:unique` keys.** Each aggregate identity
  (`{app, module, uuid}`) maps to exactly one process. This is how the system
  locates an aggregate that is already running.

---

## Process Roles

| Process | OTP Behaviour | Registration | Lifetime |
|:--------|:-------------|:-------------|:---------|
| Application Supervisor | Supervisor | Named | Application lifetime |
| Aggregates Supervisor | DynamicSupervisor | Named | Application lifetime |
| Aggregate instance | GenServer (`:temporary`) | Registry `:unique` | Until lifespan timeout or `:stop` |
| Task Dispatcher | Task.Supervisor | Named | Application lifetime |
| Dispatch Task | Task (via `async_nolink`) | None | Single command |
| Subscriptions | GenServer | Named | Application lifetime |
| Subscriptions Registry | GenServer (owns ETS) | Named | Application lifetime |
| Event Handler | GenServer | Registry `:unique` | Application lifetime (supervised) |
| Process Manager | GenServer | Registry `:unique` | Application lifetime (supervised) |

---

## The Full Pipeline

Here is exactly what happens, process by process, when code calls
`CQRS.dispatch(command)`.

### Step 1: Router (calling process)

The router is a compiled macro. It runs in the calling process (e.g., a
Phoenix controller or an Oban worker). It builds a `Dispatcher.Payload`
struct containing:

- The command struct and a generated command UUID
- Correlation and causation IDs
- The handler module, aggregate module, and identity field
- The middleware list, consistency requirement, timeout, and return strategy

No processes are spawned or messaged yet.

### Step 2: Dispatcher and Middleware (calling process)

Still running in the calling process. The Dispatcher converts the Payload
into a `Pipeline` struct, then runs the `:before_dispatch` middleware chain
sequentially:

1. **`ExtractAggregateIdentity`** -- reads the identity field from the
   command (e.g., `command.id`) and sets `pipeline.aggregate_uuid`.

2. **`CommandValidation`** (Amby's custom middleware) -- calls
   `Certifiable.certify(command)`. If validation fails, the pipeline is
   halted and an error is returned immediately. No aggregate process is
   touched.

3. **`ConsistencyGuarantee`** (setup phase) -- prepares for the
   after-dispatch consistency wait if needed.

If any middleware halts the pipeline, dispatch stops here and the error
is returned to the caller.

### Step 3: Open Aggregate (cross-process boundary)

The Dispatcher calls `Aggregates.Supervisor.open_aggregate/3`:

```elixir
Aggregates.Supervisor.open_aggregate(application, LeadAggregate, "uuid-123")
```

This does a **Registry lookup**:

- **Process found** -- returns the existing PID. No new process is started.
- **Process not found** -- calls `DynamicSupervisor.start_child/2` to start
  a new Aggregate GenServer.

When a new aggregate process starts, it goes through initialization:

```
init/1
  └─▶ handle_continue(:populate_aggregate_state)
        │  Load latest snapshot from EventStore (if any)
        │  Stream all events after the snapshot version
        │  Apply each event via apply/2 to rebuild state
        └─▶ handle_continue(:subscribe_to_events)
              Subscribe to own event stream for external updates
```

After initialization, the aggregate's in-memory state matches the full
event history in the event store.

### Step 4: Execute Command (Task -> GenServer.call)

The Dispatcher does **not** call the aggregate directly. Instead, it spawns
a short-lived Task through the Task.Supervisor:

```elixir
task = Task.Supervisor.async_nolink(TaskDispatcher, fn ->
  GenServer.call(aggregate_pid, {:execute_command, context}, timeout)
end)

result = Task.yield(task, timeout) || Task.shutdown(task)
```

The Task exists for **timeout isolation**: if the aggregate takes too long,
`Task.yield` returns `nil` and `Task.shutdown` kills the Task process
without crashing the caller or the aggregate.

Inside the Task, `GenServer.call` sends a **synchronous message** to the
aggregate process and blocks waiting for the reply.

### Step 5: Inside the Aggregate Process (handle_call)

The aggregate's `handle_call({:execute_command, context}, from, state)`
runs the command through the domain logic:

**5a. Execute the handler function:**

```elixir
LeadAggregate.execute(current_state, command)
```

This returns event struct(s), an `Aggregate.Multi`, `nil`/`:ok` (no-op),
or an error tuple.

**5b. Apply events to aggregate state:**

For each event produced, the aggregate calls:

```elixir
new_state = LeadAggregate.apply(state, event)
```

The aggregate's in-memory state is now updated, but events are not yet
persisted.

**5c. Persist events (synchronous, blocking):**

```elixir
EventStore.append_to_stream(app, stream_uuid, expected_version, event_data)
```

This is a **synchronous call to PostgreSQL**. The aggregate process blocks
until the events are durably written. Returns `:ok` or
`{:error, :wrong_expected_version}`.

If the version is wrong (another process appended events to the same stream
between state load and now), the aggregate rebuilds its state from the event
store and retries the command.

**5d. Calculate lifespan timeout:**

```elixir
Lifespan.after_event(last_event)
```

Returns `:infinity`, a millisecond timeout, `:hibernate`, or `:stop`.
This value becomes the GenServer timeout for the reply.

**5e. Schedule snapshot (async, to self):**

```elixir
send(self(), {:take_snapshot, lifespan_timeout})
```

Snapshots are taken asynchronously after the reply is sent, so they do not
add latency to the command.

**5f. Reply:**

The aggregate replies to the GenServer.call with:

```elixir
{:ok, aggregate_version, events, aggregate_state}
```

The GenServer timeout is set to the lifespan value. If no new messages
arrive before the timeout, `handle_info(:timeout, state)` stops the
process, freeing memory.

### Step 6: After Dispatch (calling process)

Back in the calling process, the Task has completed and returned the result.
The Dispatcher runs the `:after_dispatch` middleware chain.

If `consistency: :strong`, the `ConsistencyGuarantee` middleware calls:

```elixir
Subscriptions.wait_for(app, stream_uuid, version, opts)
```

This sends a synchronous `GenServer.call` to the Subscriptions process,
which blocks the caller until **all** `:strong` consistency handlers have
acknowledged processing the events at this version. Default timeout is
5 seconds.

### Step 7: Return to Caller

The result is formatted according to the `:returning` option:

- `:aggregate_state` -- returns the evolved aggregate struct
- `:aggregate_version` -- returns the version number
- `:events` -- returns the list of persisted events
- `:execution_result` -- returns a full `ExecutionResult` struct
- `false` (default) -- returns `:ok`

---

## Event Publishing After Persistence

After step 5c, the EventStore publishes persisted events to all subscribers.
This happens inside the EventStore adapter, triggered by the
`append_to_stream` call:

```
EventStore persists events to PostgreSQL
  │
  │  Notifies all subscribers of this stream
  │
  ├──▶ Transient Subscribers
  │     └─ The aggregate itself
  │        Receives {:events, events} via handle_info
  │        Already applied these events, so they are
  │        skipped (version check: event_already_seen?)
  │
  └──▶ Persistent Subscribers
        │
        ├─ Projectors (e.g., Contact Projector)
        │    Receives {:events, events}
        │    Writes to projection tables (PostgreSQL)
        │    Calls EventStore.ack_event/3
        │
        ├─ Event Handlers (e.g., SearchHandler)
        │    Receives {:events, events}
        │    Performs side effects (enqueue Oban job, update TypeSense)
        │    Calls EventStore.ack_event/3
        │
        └─ Process Managers (e.g., UnificationManager)
             Receives {:events, events}
             interested?/1 → routing decision
             handle/2 → returns new command(s)
             apply/2 → updates process manager state
             Dispatches new commands → pipeline starts again at Step 1
```

### Strong Consistency Acknowledgment Flow

When an event handler with `consistency: :strong` finishes processing:

```
Handler calls EventStore.ack_event/3
  │
  └─▶ PubSub.broadcast({:ack_event, handler_name, stream_uuid, version})
        │
        └─▶ Subscriptions GenServer receives broadcast
              │  Updates ETS table: {{handler_name, stream_uuid}, version}
              │  Checks: have ALL :strong handlers acked this stream+version?
              │
              ├─ Not yet → wait for more acks
              └─ Yes → send({:ok, stream_uuid, version}) to waiting caller
                       └─▶ Unblocks Step 6 above
```

---

## Message Flow Diagram

```
  Caller           Task         Aggregate        EventStore       Subscriptions
    │                │              │                │                  │
    │  dispatch()    │              │                │                  │
    ├─── middleware ─┤              │                │                  │
    │                │              │                │                  │
    │  open_aggregate (Registry lookup / DynamicSupervisor.start_child)│
    │                │              │                │                  │
    │  async_nolink  │              │                │                  │
    ├───────────────▶│              │                │                  │
    │                │  call        │                │                  │
    │                │  {:execute}  │                │                  │
    │                ├─────────────▶│                │                  │
    │                │              │                │                  │
    │                │              │  execute/2     │                  │
    │                │              │  apply/2       │                  │
    │                │              │                │                  │
    │                │              │  append_to_    │                  │
    │                │              │  stream (sync) │                  │
    │                │              ├───────────────▶│                  │
    │                │              │           :ok  │                  │
    │                │              │◀───────────────┤                  │
    │                │              │                │                  │
    │                │     reply    │                │  publish to      │
    │                │  {:ok, ver,  │                │  subscribers     │
    │                │   events,    │                ├─────────────────▶│
    │                │   state}     │                │  {:events, [...]}│
    │                │◀─────────────┤                │                  │
    │                │              │                │                  │
    │   yield(task)  │              │                │                  │
    │◀───────────────┤              │                │                  │
    │                              (lifespan         │                  │
    │   if :strong:                 timeout          │                  │
    │   wait_for()                  ticking)         │                  │
    ├──────────────────────────────────────────────────────────────────▶│
    │                                                                  │
    │                                                (handlers ack     │
    │                                                 via PubSub)      │
    │                                                                  │
    │   {:ok, stream, version}                                         │
    │◀─────────────────────────────────────────────────────────────────┤
    │                                                                  │
    │  format result                                                   │
    │  return to caller                                                │
    ▼                                                                  │
```

---

## Synchronous vs Asynchronous Boundaries

Understanding which calls block and which do not is critical for reasoning
about latency, timeouts, and failure modes.

### Synchronous (blocking)

| Call | From | To | Blocks Until |
|:-----|:-----|:---|:-------------|
| `GenServer.call({:execute_command, ctx})` | Task | Aggregate | Command executed + events persisted |
| `EventStore.append_to_stream/4` | Aggregate | PostgreSQL | Events written to disk |
| `Task.yield(task, timeout)` | Caller | Task | Task completes or timeout |
| `Subscriptions.wait_for/4` | Caller | Subscriptions | All `:strong` handlers ack |

### Asynchronous (non-blocking)

| Message | From | To | Purpose |
|:--------|:-----|:---|:--------|
| `send(self(), {:take_snapshot, ...})` | Aggregate | Aggregate (self) | Snapshot after reply sent |
| `{:events, events}` | EventStore | Subscribers | Notify handlers of new events |
| `PubSub.broadcast({:ack_event, ...})` | Handler | Subscriptions | Signal event processed |
| `send(pid, {:ok, stream, version})` | Subscriptions | Waiting caller | Unblock strong consistency wait |

---

## Aggregate Lifecycle

An aggregate process goes through these states:

```
                         ┌───────────────────┐
                         │   Not Running     │
                         │  (no process)     │
                         └────────┬──────────┘
                                  │
                    open_aggregate (first command)
                                  │
                         ┌────────▼──────────┐
                         │   Initializing    │
                         │  Load snapshot    │
                         │  Replay events    │
                         │  Subscribe        │
                         └────────┬──────────┘
                                  │
                         ┌────────▼──────────┐
                ┌───────▶│     Idle          │◀──────────┐
                │        │  Waiting for      │           │
                │        │  commands         │           │
                │        └────────┬──────────┘           │
                │                 │                      │
                │     {:execute_command, ctx}            │
                │                 │                      │
                │        ┌────────▼──────────┐           │
                │        │   Executing       │           │
                │        │  execute/2        │           │
                │        │  apply/2          │           │
                │        │  append_to_stream │           │
                │        └────────┬──────────┘           │
                │                 │                      │
                │            reply sent                  │
                │                 │                      │
                │     Lifespan.after_event/1             │
                │        │              │                │
                │   :infinity      timeout (ms)     :stop
                │        │              │                │
                │        └──────┐       │          ┌─────▼─────┐
                │               │       │          │  Stopped  │
                └───────────────┘  ┌────▼────┐     │  Process  │
                                   │ Timeout │     │  exits    │
                                   │ ticking │     └───────────┘
                                   └────┬────┘
                                        │
                                 handle_info(:timeout)
                                        │
                                  ┌─────▼─────┐
                                  │  Stopped  │
                                  │  Process  │
                                  │  exits    │
                                  └───────────┘
```

When the process exits (timeout or `:stop`), its Registry entry is
automatically cleaned up. The next command for this UUID will start a fresh
process via DynamicSupervisor and rebuild state from the event store.

---

## Concurrency and Consistency Guarantees

### Within a Single Aggregate

Commands for the same aggregate UUID are **serialized**. The aggregate is a
single GenServer process, and GenServer processes messages sequentially from
their mailbox. Two commands for the same contact cannot execute concurrently.
This is the fundamental consistency boundary.

### Across Aggregates

Commands for different aggregate UUIDs execute in **parallel**. Each
aggregate is a separate process. A command for contact A does not block a
command for contact B.

### Optimistic Concurrency

When the aggregate calls `append_to_stream`, it passes the expected stream
version. If another process appended events to the same stream between the
aggregate's state load and the append call, the EventStore returns
`{:error, :wrong_expected_version}`. The aggregate then rebuilds its state
from the event store and retries the command. This handles the rare case
where the aggregate process received external events via its stream
subscription during command execution.

### Strong vs Eventual Consistency

- **`:strong` handlers** -- the command dispatch blocks until these handlers
  have processed and acknowledged the events. The caller is guaranteed that
  read models are up to date when the response is returned.

- **`:eventual` handlers** -- the command dispatch returns immediately after
  events are persisted. These handlers process events asynchronously and may
  lag behind.

In Amby, most projectors use `:strong` consistency. This means when the API
returns a response after creating a contact, the `projection_contacts` table
is guaranteed to have the new record. Event handlers like search indexing and
email sync use `:eventual` consistency because they can tolerate lag.

---

## Failure Modes

### Aggregate Process Crashes

The aggregate uses `:temporary` restart strategy, so it is **not restarted**.
The in-flight command fails and the error propagates to the caller. The next
command for this UUID starts a fresh process that rebuilds from events. No
data is lost because events are already persisted in PostgreSQL.

### EventStore Write Failure

If `append_to_stream` fails (e.g., database connection error), the aggregate
returns an error to the calling Task, which propagates to the caller. The
aggregate's in-memory state has already been updated by `apply/2`, but since
the events were not persisted, the next command will rebuild from the event
store and the in-memory state will be corrected.

### Task Timeout

If the aggregate takes longer than the configured timeout, `Task.yield`
returns `nil` and `Task.shutdown` kills the Task. The caller receives a
timeout error. The aggregate process itself **continues running** -- it will
finish the command and persist events, but the caller has already moved on.
This is a deliberate design choice: it is better to persist events than to
lose them, even if the caller has timed out.

### Strong Consistency Timeout

If a `:strong` handler does not acknowledge events within 5 seconds (default),
`Subscriptions.wait_for` returns `{:error, :timeout}`. The events **are**
persisted -- the handler is just slow or stuck. The caller receives the
timeout error, but the system state is consistent. The handler will
eventually process the events.

### Handler Crash

Event handlers and process managers are supervised separately from
aggregates. If a handler crashes, its supervisor restarts it. The handler
re-subscribes to the event store from its last acknowledged position and
resumes processing. Events in the event store are never lost.
