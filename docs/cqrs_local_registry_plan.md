# CQRS Local Registry Migration Plan

## Executive Summary

This document analyzes the feasibility and implications of switching our Commanded application from `:global` to `:local` registry and removing the CQRS leader election system.

**TL;DR**: Your assumption about `:local` registry is correct for aggregates, but there's a critical issue with event handlers, projectors, and process managers that must be addressed. **Recommended approach: Hybrid architecture** that uses `:local` registry for command processing while keeping leader election for event subscriptions.

## Current Architecture

### Overview

```
WaltUi.Application
  ├─ CQRSLeader (manages leadership via :global registry)
  └─ CQRSSupervisor (dynamically starts children when node becomes leader)
      ├─ CQRS (Commanded application - aggregates with :global registry)
      ├─ Projectors.Supervisor (12 projectors)
      ├─ Handlers.Supervisor (8 event handlers)
      └─ ProcessManagers.Supervisor (5 process managers)
```

### How It Works

1. Multiple nodes in cluster (via libcluster)
2. **CQRSLeader** uses `:global.register_name/2` to elect one leader
3. Only the leader node runs CQRS processes
4. **CQRS application** configured with `registry: :global`
5. Aggregate processes (LeadAggregate, EnrichmentAggregate, MeetingAggregate) can only exist on one node cluster-wide

### Why It Was Built

From `apps/walt_ui/lib/walt_ui/cqrs_leader.ex:6-7`:
> "This prevents global registry conflicts during rolling deployments while maintaining exactly-once event processing guarantees."

**Problem being solved**: With `:global` registry, new nodes joining during rolling deployments cause registry conflicts and potential split-brain scenarios. Leader election ensures only ONE node handles all CQRS operations.

### Configuration

**config/config.exs:26-31**:
```elixir
config :cqrs, CQRS,
  registry: :global,
  event_store: [
    adapter: Commanded.EventStore.Adapters.EventStore,
    event_store: CQRS.EventStore
  ]
```

## Understanding Registry Options

### :global Registry (Current)

**How it works**:
- Uses Erlang's `:global` module for process registration
- Ensures an aggregate with specific ID exists on only ONE node in cluster
- Provides distributed coordination across all nodes
- If two nodes try to handle commands for same aggregate, `:global` ensures only one process exists

**Pros**:
- Strong guarantee of single aggregate instance cluster-wide
- Prevents concurrent command processing for same aggregate across nodes

**Cons**:
- Causes conflicts during rolling deployments
- Single node handles ALL command processing (bottleneck)
- Requires distributed Erlang coordination overhead

### :local Registry

**How it works**:
- Processes registered locally on each node using local process registry
- Multiple nodes CAN have different aggregate instances with the SAME ID
- Requires Phoenix.PubSub for event distribution (✅ already configured)
- Each node processes commands independently
- Event store provides source of truth and consistency through event ordering

**Pros**:
- All nodes can process commands (distributed load)
- No registry conflicts during rolling deployments
- Better throughput, no single bottleneck
- Simpler cluster coordination

**Cons**:
- Multiple aggregate instances for same ID across nodes
- Requires event store's optimistic concurrency control
- Event handlers/projectors/process managers run on ALL nodes (⚠️ duplication issue)

### How Consistency Works with :local

**Event Store Optimistic Locking**:
1. Node A loads aggregate state from event store
2. Node B loads same aggregate state
3. Both process commands and generate events
4. Node A appends events to stream (succeeds)
5. Node B tries to append events with same expected version (FAILS - conflict detected)
6. Node B retries: reloads state, re-executes command, appends events (succeeds)

This is **safe** when:
- Commands don't require strong consistency
- Business logic can tolerate occasional retries
- Idempotent command handlers

## Your Assumption Analysis

### ✅ CORRECT: For Aggregate Command Processing

You stated: "We don't dispatch commands with strong consistency, I think this should be fine."

**Analysis**: You're absolutely right about aggregates. Looking at `apps/cqrs/lib/cqrs.ex`:
- `create_contact/2`: Uses `returning: :aggregate_state` (no strong consistency required)
- `update_contact/3`: Same pattern
- `delete_contact/2`: Dispatches without consistency guarantees
- Most operations are eventual consistency

The event store's optimistic locking is sufficient for:
- **Leads.LeadAggregate**: Contact CRUD operations
- **Enrichments.EnrichmentAggregate**: Data enrichment workflows
- **Meetings.MeetingAggregate**: Calendar event management

### ⚠️ CRITICAL ISSUE: Event Handlers, Projectors, and Process Managers

**The problem you haven't considered**: With `:local` registry, ALL Commanded components run on ALL nodes, not just aggregates.

#### Event Handlers (8 handlers)

Located in `apps/walt_ui/lib/walt_ui/handlers/`:
- `Search` - Updates TypeSense search index
- `ProviderEnrichmentRequestedHandler` - Triggers Oban enrichment jobs
- `EnrichmentCompositionRequestedHandler` - Triggers composition jobs
- `EmailSyncOnContactUpdate` - Syncs emails for updated contacts
- `EmailSyncOnLeadCreated` - Syncs emails for new contacts
- `CalendarSyncOnLeadCreated` - Syncs calendar events
- `CalendarSyncOnContactUpdate` - Syncs calendar events
- `GeocodeOnAddressChange` - Geocodes addresses

**What happens with :local registry**:
- Each node subscribes to event store independently
- Each handler receives ALL events
- Result: **N nodes = N executions of each side effect**

**Example**: 3-node cluster, contact created:
- Node 1 SearchHandler indexes contact in TypeSense
- Node 2 SearchHandler indexes same contact in TypeSense (duplicate!)
- Node 3 SearchHandler indexes same contact in TypeSense (duplicate!)

Same for: emails sent N times, N Oban jobs enqueued, N geocoding API calls, etc.

#### Process Managers (5 managers)

Located in `apps/walt_ui/lib/walt_ui/process_managers/`:
- `CalendarMeetingsManager` - Coordinates calendar meeting workflows
- `ContactEnrichmentManager` - Orchestrates enrichment process
- `EnrichmentOrchestrationManager` - Manages provider enrichment
- `EnrichmentResetManager` - Handles enrichment resets
- `UnificationManager` - Coordinates contact unification

**What happens with :local registry**:
- Each node creates separate PM instances for same workflow
- Each receives same events
- Each dispatches commands
- Result: **Duplicate command execution, workflow chaos**

**Example**: Contact enrichment workflow on 3-node cluster:
- Node 1 PM dispatches `RequestProviderEnrichment` command
- Node 2 PM dispatches same command (duplicate enrichment!)
- Node 3 PM dispatches same command (triple enrichment!)

#### Projectors (12 projectors)

Located in `apps/walt_ui/lib/walt_ui/projectors/`:
- Contact, ContactCreation, ContactInteraction, ContactShowcase
- Endato, Enrichment, Faraday, Gravatar, Jitter
- PossibleAddress, PttScore, Trestle

**What happens with :local registry**:
- Each node runs projector instances
- Each tries to update same database rows
- **Might** be safer due to:
  - Database constraints prevent duplicates
  - Upserts based on aggregate ID are idempotent
  - Commanded.Projections.Ecto tracks progress per subscription

**Status**: Needs verification, but likely causes unnecessary contention and load.

## Architectural Options

### Option 1: Hybrid Architecture (RECOMMENDED)

**Strategy**: Use `:local` registry for aggregates, keep leader election for event subscriptions.

#### Architecture

```
WaltUi.Application
  ├─ CQRS (Commanded app with :local registry) ← ALL NODES
  ├─ EventSubscriptionLeader (renamed from CQRSLeader)
  └─ EventSubscriptionSupervisor (renamed from CQRSSupervisor)
      ├─ Projectors.Supervisor  ← LEADER ONLY
      ├─ Handlers.Supervisor    ← LEADER ONLY
      └─ ProcessManagers.Supervisor ← LEADER ONLY
```

#### Changes Required

**1. Config change** (`config/config.exs:27`):
```elixir
config :cqrs, CQRS,
  registry: :local,  # Changed from :global
  event_store: [
    adapter: Commanded.EventStore.Adapters.EventStore,
    event_store: CQRS.EventStore
  ]
```

**2. Supervision tree** (`apps/walt_ui/lib/walt_ui/application.ex:13-33`):
```elixir
children = [
  goth(),
  {Cluster.Supervisor, [Application.get_env(:libcluster, :topologies),
                        [name: WaltUi.ClusterSupervisor]]},
  WaltUiWeb.Telemetry,
  {Phoenix.PubSub, name: WaltUi.PubSub},

  # CQRS Application - NOW RUNS ON ALL NODES
  CQRS,

  # Event subscription leadership - ONLY for handlers/projectors/PMs
  event_subscription_leader(),
  WaltUi.EventSubscriptionSupervisor,

  {Task.Supervisor, name: WaltUi.TaskSupervisor},
  # ... rest of children
]
```

**3. Rename modules** for clarity:
- `CQRSLeader` → `EventSubscriptionLeader`
- `CQRSSupervisor` → `EventSubscriptionSupervisor`

**4. Update config check**:
```elixir
defp event_subscription_leader do
  if Application.get_env(:walt_ui, :event_subscription_leader_enabled, true) do
    WaltUi.EventSubscriptionLeader
  end
end
```

#### Benefits

✅ **All nodes process commands** - Distributed aggregate instances, better throughput
✅ **No handler duplication** - Side effects execute once
✅ **No PM duplication** - Workflows execute correctly
✅ **Minimal risk** - Small, focused changes
✅ **Easy rollback** - Can revert to `:global` if issues arise
✅ **Solves rolling deployment issues** - `:local` registry doesn't conflict
✅ **Clear separation** - Commands distributed, events single-node

#### Drawbacks

⚠️ Still have single point of bottleneck for event processing
⚠️ Still need leader election (reduced scope, but still present)

#### Migration Path

1. Deploy with `:local` registry but keep full leader election (safe rollback point)
2. Test command processing across multiple nodes
3. Rename modules for clarity
4. Move CQRS to main application supervisor
5. Monitor for issues
6. Consider Option 2 in future if event processing becomes bottleneck

---

### Option 2: Complete Removal (Higher Risk)

**Strategy**: Fully distribute all components, remove leader election entirely.

#### Architecture

```
WaltUi.Application
  ├─ CQRS (with :local registry)
  ├─ Projectors.Supervisor
  ├─ Handlers.Supervisor
  └─ ProcessManagers.Supervisor
```

All components run on all nodes.

#### Changes Required

**1. Config change**: Same as Option 1

**2. Supervision tree**: Move all 4 children directly to `WaltUi.Application`

**3. Make ALL handlers idempotent**:
- Create `event_handler_progress` table tracking `(handler_name, event_id)`
- Wrap each handler in deduplication logic:
  ```elixir
  def handle(event, %{event_id: event_id}) do
    case EventHandlerProgress.mark_processed(__MODULE__, event_id) do
      {:ok, :processed} ->
        # Execute handler logic
        :ok
      {:error, :already_processed} ->
        :ok  # Skip, another node handled it
    end
  end
  ```
- 8 handlers need this treatment

**4. Make ALL process managers handle concurrent instances**:
- Much more complex than handlers
- Each PM needs logic to coordinate with other node instances
- Likely requires distributed locks or similar
- 5 process managers need modification

**5. Extensive testing**:
- Race condition testing
- Failure scenario testing
- Verify deduplication works under load

#### Benefits

✅ **Fully distributed** - No single point of failure
✅ **Maximum throughput** - All nodes do everything
✅ **No leader election** - Simpler operational model

#### Drawbacks

❌ **High implementation effort** - 8 handlers + 5 PMs need changes
❌ **High risk** - Subtle bugs possible if deduplication fails
❌ **Complex testing** - Need to verify distributed behavior
❌ **Database overhead** - Deduplication checks on every event
❌ **Potential for race conditions** - Multiple nodes competing

#### When to Consider

- Event processing becomes actual bottleneck (measure first!)
- Team has bandwidth for thorough implementation and testing
- After Option 1 is stable and you understand pain points

---

## Commanded Documentation References

### Multi-Node Deployment with :local

From Commanded deployment guide:

**Local registry configuration**:
```elixir
# config/config.exs
config :my_app, MyApp.Application,
  registry: :local,
  pubsub: [
    phoenix_pubsub: [
      adapter: Phoenix.PubSub.PG2,
      pool_size: 1
    ]
  ]
```

**Key points**:
- `:local` registry supported for multi-node deployments
- Requires Phoenix.PubSub for event distribution (✅ you have this)
- Event store provides consistency through optimistic concurrency
- Each node can process commands independently

### Event Store Optimistic Concurrency

When multiple nodes append events to same stream:
- Event store tracks expected version
- First write succeeds
- Subsequent writes with stale version fail with `{:error, :wrong_expected_version}`
- Commanded retries: reloads aggregate, re-executes command, retries append
- Eventually succeeds

This is the **consistency guarantee** that makes `:local` registry safe for aggregates.

## Recommendation

**Start with Option 1 (Hybrid Architecture)** because:

1. **Addresses your goal**: Removes `:global` registry conflicts, distributes command processing
2. **Low risk**: Minimal code changes, easy to test and rollback
3. **Maintains safety**: Prevents handler/PM duplication without requiring code changes
4. **Performance gain**: All nodes can handle commands (your bottleneck)
5. **Future-proof**: Can evolve to Option 2 later if needed
6. **Proven pattern**: Separating command dispatch from event subscriptions is common in CQRS systems

The handler duplication issue is real and would cause immediate production problems:
- Duplicate emails to customers
- Duplicate Oban jobs (wasted enrichment API calls, wasted $$)
- Duplicate search index updates
- Process manager workflow corruption

Don't risk it without proper idempotency implementation.

## Implementation Checklist (Option 1)

- [ ] Update `config/config.exs:27` to `registry: :local`
- [ ] Move `CQRS` from `CQRSSupervisor` to `WaltUi.Application` children
- [ ] Rename `CQRSLeader` to `EventSubscriptionLeader`
- [ ] Rename `CQRSSupervisor` to `EventSubscriptionSupervisor`
- [ ] Update all references in both modules
- [ ] Update config check in `WaltUi.Application`
- [ ] Update test configuration (`config/test.exs:81`) to use new naming
- [ ] Test command dispatch works on all nodes
- [ ] Test handlers only run on leader node
- [ ] Verify no duplicate side effects
- [ ] Test rolling deployment scenario
- [ ] Update documentation

## Testing Strategy

1. **Local testing**: Start 2-node cluster locally, verify command distribution
2. **Staging deployment**: Deploy to staging, monitor for issues
3. **Verify single event processing**: Check logs to ensure handlers execute once per event
4. **Load testing**: Ensure performance improvement is real
5. **Rolling deployment test**: Deploy new version while cluster is running
6. **Monitor metrics**: Command throughput, event handler lag, error rates

## Rollback Plan

If issues arise:

1. Change `registry: :local` back to `registry: :global`
2. Move `CQRS` back into `EventSubscriptionSupervisor`
3. Rename modules back to original names (or keep new names)
4. Deploy with updated config

The changes are minimal and reversible.

## Questions for Consideration

1. **What's the actual command throughput bottleneck?**
   - Is it truly the single-node CQRS processing?
   - Or is it event store pool size (recently increased to 75)?
   - Measure before and after to verify improvement

2. **Do you have monitoring for handler execution?**
   - Can you detect if handlers run multiple times?
   - AppSignal metrics to track this?

3. **Is event processing a bottleneck?**
   - If not, keeping it single-node is fine
   - If yes, Option 2 becomes more attractive

4. **What's your cluster size?**
   - 2 nodes: Option 1 is perfect
   - 10+ nodes: Might eventually want Option 2 for event processing

## Conclusion

Your instinct to switch to `:local` registry is sound for **aggregate command processing**. The `:global` registry is unnecessary overhead given your eventual consistency model, and it causes deployment friction.

However, **don't remove the leader election entirely** without addressing event handlers and process managers. The hybrid approach (Option 1) gives you the benefits you're seeking while avoiding the duplication trap.

Start with Option 1, measure the results, and consider Option 2 as a future enhancement if event processing becomes a bottleneck.

---

**Document Author**: Claude
**Date**: 2025-10-06
**Status**: Analysis Complete, Awaiting Implementation Decision
