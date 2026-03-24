# Amby CQRS Architecture

This document describes the event-sourced architecture of the `apps/cqrs/`
application. It catalogs every command, event, aggregate, process manager,
event handler, and projector, and traces the flows that connect them.

The system is built on the [Commanded](https://hexdocs.pm/commanded/) library,
which implements CQRS (Command Query Responsibility Segregation) and Event
Sourcing for Elixir.

---

## How Commanded Works

In a Commanded application, data flows through a pipeline:

1. **Command** -- a request to change state (e.g., "create this contact").
   Commands are plain structs dispatched through a router.

2. **Router** -- maps each command struct to its target aggregate and identity
   field. A middleware pipeline runs before dispatch (validation, etc.).

3. **Aggregate** -- the domain object that decides whether a command is valid
   and, if so, produces one or more events. The aggregate's `execute/2`
   function receives the current state and the command, and returns events.
   Its `apply/2` function folds each event into the aggregate state.

4. **Event** -- an immutable fact that something happened (e.g., "contact was
   created"). Events are persisted to the event store (PostgreSQL) and are
   the source of truth.

5. **Event Handler** -- a subscriber that reacts to events by performing side
   effects: enqueuing background jobs, calling external APIs, or dispatching
   further commands.

6. **Process Manager** -- a stateful event handler that coordinates multi-step
   workflows across aggregates. It listens for events, maintains state, and
   dispatches commands to drive the workflow forward.

7. **Projector** -- an event handler that builds read-optimized database
   records (projections) from events. Projections are what the API and UI
   query.

```
Command ──▶ Router ──▶ Aggregate ──▶ Event(s) ──▶ Event Store
                                        │
                        ┌───────────────┼───────────────┐
                        ▼               ▼               ▼
                   Projectors     Event Handlers   Process Managers
                   (read models)  (side effects)   (orchestration)
                        │               │               │
                        ▼               ▼               ▼
                   PostgreSQL      Oban Jobs        More Commands
                   (projections)   (background)     (next steps)
```

---

## Application and Router

### CQRS Application

**Module:** `CQRS` (`apps/cqrs/lib/cqrs.ex`)

The Commanded application. Provides convenience functions for dispatching
commands:

- `create_contact/2` -- builds a deterministic UUID from
  `user_id:remote_source:remote_id` and dispatches `Leads.Commands.Create`
- `update_contact/3` -- dispatches `Leads.Commands.Update`
- `delete_contact/2` -- dispatches `Leads.Commands.Delete`
- `jitter_contact_ptt/2` -- dispatches `Leads.Commands.JitterPtt`
- `create_meeting/1` -- builds a deterministic UUID from the provider meeting
  ID and dispatches `Meetings.Commands.Create`
- `create_correspondence/1` -- dispatches `Leads.Commands.Correspond` for
  each contact ID in the list
- `select_address/3` -- dispatches `Leads.Commands.SelectAddress`

### Router

**Module:** `CQRS.Router` (`apps/cqrs/lib/cqrs/router.ex`)

Routes commands to aggregates. All commands pass through the
`CommandValidation` middleware, which calls the `Certifiable` protocol on
each command struct to validate it before dispatch.

| Commands | Aggregate | Identity | Lifespan |
|:---------|:----------|:---------|:---------|
| All `Enrichments.Commands.*` (10 commands) | `EnrichmentAggregate` | `:id` | `EnrichmentAggregate.Lifespan` |
| All `Leads.Commands.*` (9 commands) | `LeadAggregate` | `:id` | `LeadAggregate.Lifespan` |
| `Meetings.Commands.Create` | `MeetingAggregate` | `:id` | `MeetingAggregate.Lifespan` |

### Middleware

**`CQRS.Middleware.CommandValidation`** -- Validates every command using the
`CQRS.Certifiable` protocol before dispatch. If `certify/1` returns errors,
the pipeline is halted.

**`CQRS.Middleware.CommandValidation.ValidatePhone`** -- Rejects phone
numbers starting with commercial area codes (800, 833, 844, 855, 866, 877,
888, 900).

---

## Aggregates

### Lead Aggregate

**Module:** `CQRS.Leads.LeadAggregate`

The lead aggregate manages the lifecycle of a single contact. It is the most
important aggregate in the system. Its ID is a deterministic UUID derived
from the user, remote source, and remote ID, which prevents duplicate
contacts from the same import source.

**State fields:** `id`, `anniversary`, `avatar`, `birthday`, `city`,
`correspondence_ids`, `date_of_home_purchase`, `email`, `emails`,
`enrichment_id`, `enrichment_type`, `first_name`, `is_deleted`, `is_favorite`,
`is_hidden`, `jitter`, `last_name`, `latitude`, `longitude`, `phone`,
`phone_numbers`, `ptt`, `remote_id`, `remote_source`, `state`, `street_1`,
`street_2`, `unified_contact_id`, `user_id`, `zip`

**Lifespan:** Stops after `LeadDeleted` event. Runs indefinitely otherwise.

| Command | Behavior | Event(s) Produced |
|:--------|:---------|:------------------|
| `Create` (new aggregate) | Emits creation event with all contact fields | `LeadCreated` |
| `Create` (deleted aggregate) | Re-creates over a previously deleted aggregate | `LeadCreated` |
| `Create` (existing aggregate) | No-op. Logs a warning. | (none) |
| `Delete` | Emits deletion event | `LeadDeleted` |
| `Update` | Diffs each attribute against current state. Only emits if something changed. | `LeadUpdated` (or none) |
| `Unify` | Links contact to enrichment data and updates address/PTT | `LeadUnified` |
| `JitterPtt` | Updates AI-adjusted PTT score. No-op if score unchanged. | `PttJittered` (or none) |
| `InviteContact` | Records that a contact was invited to a calendar meeting | `ContactInvited` |
| `Correspond` | Records email correspondence. Deduplicates by `source_id`. | `ContactCorresponded` (or none) |
| `SelectAddress` | Sets the contact's address to a chosen value | `AddressSelected` |
| `ResetPttHistory` | Zeros out PTT and clears score history | `LeadUpdated` + `PttHistoryReset` |

---

### Enrichment Aggregate

**Module:** `CQRS.Enrichments.EnrichmentAggregate`

The enrichment aggregate manages the lifecycle of enriching a single contact
with external data. It tracks which providers have been queried, what data
was returned, and the final composed result. The aggregate supports two flows:
a legacy per-provider flow and a newer composable provider flow.

**State fields:** `id`, `addresses`, `emails`, `first_name`, `last_name`,
`phone`, `ptt`, `timestamp`, `last_provider_requested`,
`last_provider_succeeded`, `last_provider_failed`,
`provider_request_timestamp`, `provider_success_timestamp`,
`provider_failure_timestamp`, `last_composition_timestamp`,
`alternate_names`

**Lifespan:** Uses timeouts (4-10 minutes) to keep the aggregate alive while
enrichment is in progress. Stops on unrecoverable errors.

| Command | Behavior | Event(s) Produced |
|:--------|:---------|:------------------|
| `RequestEnrichment` | Begins enrichment for a phone number | `EnrichmentRequested` |
| `EnrichWithEndato` | Records Endato results (legacy flow) | `EnrichedWithEndato` |
| `EnrichWithFaraday` | Records Faraday results (legacy flow) | `EnrichedWithFaraday` |
| `EnrichWithTrestle` | Records Trestle results (legacy flow) | `EnrichedWithTrestle` |
| `Jitter` | Applies random jitter to PTT. No-op if PTT is 0. | `Jittered` (or none) |
| `RequestProviderEnrichment` | Requests data from a specific provider (composable flow) | `ProviderEnrichmentRequested` |
| `CompleteProviderEnrichment` | Records a provider's response (composable flow) | `ProviderEnrichmentCompleted` |
| `RequestEnrichmentComposition` | Requests merging of all provider results | `EnrichmentCompositionRequested` |
| `CompleteEnrichmentComposition` | Records the final merged enrichment result | `EnrichmentComposed` |
| `Reset` | Clears all enrichment data to allow re-enrichment | `EnrichmentReset` |

---

### Meeting Aggregate

**Module:** `CQRS.Meetings.MeetingAggregate`

The meeting aggregate represents a calendar event synced from Google
Calendar. Its ID is a deterministic UUID derived from the provider's event
ID, which prevents duplicate meeting records during sync.

**State fields:** `attendees`, `calendar_id`, `end_time`, `id`, `kind`,
`link`, `location`, `name`, `source_id`, `start_time`, `status`,
`timestamp`, `user_id`

**Lifespan:** Runs indefinitely.

| Command | Behavior | Event(s) Produced |
|:--------|:---------|:------------------|
| `Create` (new aggregate) | Emits creation event with all meeting fields | `MeetingCreated` |
| `Create` (existing aggregate) | No-op. Meeting already exists. | (none) |

---

## Commands

### Lead Commands

| Command | Description | Required Fields |
|:--------|:------------|:----------------|
| `Create` | Create a new contact | `id`, `phone`, `timestamp`, `user_id` |
| `Update` | Update contact attributes | `id`, `attrs` (map of changes), `timestamp`, `user_id` |
| `Delete` | Delete a contact | `id` |
| `Unify` | Link contact to enrichment data | `id`, `enrichment_id` |
| `JitterPtt` | Set AI-adjusted PTT score | `id`, `score`, `timestamp` |
| `InviteContact` | Record meeting invitation | `id`, `calendar_id`, `meeting_id`, `name`, `source_id`, `user_id` |
| `Correspond` | Record email correspondence | `id`, `user_id` |
| `SelectAddress` | Choose a mailing address | `id`, `street_1`, `city`, `state`, `zip` |
| `ResetPttHistory` | Clear PTT history | `id` |

### Enrichment Commands

| Command | Description | Required Fields |
|:--------|:------------|:----------------|
| `RequestEnrichment` | Begin enrichment for a phone number | `id`, `phone`, `user_id`, `timestamp` |
| `EnrichWithEndato` | Store Endato results (legacy) | `id`, `phone`, `timestamp` |
| `EnrichWithFaraday` | Store Faraday results (legacy) | `id`, `phone`, `timestamp` |
| `EnrichWithTrestle` | Store Trestle results (legacy) | `id`, `phone`, `timestamp` |
| `Jitter` | Apply random jitter to PTT | `id`, `timestamp` |
| `RequestProviderEnrichment` | Request enrichment from a named provider | `id`, `provider_type`, `contact_data`, `timestamp` |
| `CompleteProviderEnrichment` | Record a provider's response | `id`, `provider_type`, `status`, `timestamp` |
| `RequestEnrichmentComposition` | Merge all provider results | `id`, `provider_data`, `composition_rules`, `timestamp` |
| `CompleteEnrichmentComposition` | Record the final merged result | `id`, `composed_data`, `data_sources`, `provider_scores`, `timestamp` |
| `Reset` | Clear all enrichment data | `id`, `timestamp` |

### Meeting Commands

| Command | Description | Required Fields |
|:--------|:------------|:----------------|
| `Create` | Record a calendar meeting | `id`, `calendar_id`, `name`, `source_id`, `user_id` |

---

## Events

### Lead Events

| Event | Description | Key Fields |
|:------|:------------|:-----------|
| `LeadCreated` | A contact was created | All contact fields, `user_id`, `timestamp` |
| `LeadUpdated` | One or more contact fields changed | `attrs` (new values), `metadata` (list of `{field, old, new}` diffs) |
| `LeadDeleted` | A contact was deleted | `id`, `user_id`, `timestamp` |
| `LeadUnified` | A contact was linked to enrichment data | `enrichment_id`, `enrichment_type`, `ptt`, address fields |
| `PttJittered` | AI-adjusted PTT score was set | `score`, `timestamp` |
| `ContactInvited` | A contact was invited to a meeting | Meeting fields: `calendar_id`, `meeting_id`, `name`, times |
| `ContactCorresponded` | Email correspondence was recorded | `direction`, `from`, `to`, `subject`, `source`, `source_id` |
| `AddressSelected` | A mailing address was chosen | `street_1`, `street_2`, `city`, `state`, `zip` |
| `PttHistoryReset` | PTT score history was cleared | `reason` |

### Enrichment Events

| Event | Description | Key Fields |
|:------|:------------|:-----------|
| `EnrichmentRequested` | Enrichment was initiated | `phone`, `first_name`, `last_name`, `user_id` |
| `EnrichedWithEndato` | Endato returned data (legacy) | `addresses`, `emails`, `first_name`, `last_name`, `phone` |
| `EnrichedWithFaraday` | Faraday returned data (legacy) | All ~70 demographic/property/lifestyle fields |
| `EnrichedWithTrestle` | Trestle returned data (legacy) | `addresses`, `emails`, `first_name`, `last_name`, `age_range` |
| `Jittered` | PTT was randomly jittered | `score` |
| `EndatoEnrichmentRequested` | Endato API call was requested (legacy) | `phone`, `first_name`, `last_name`, `email` |
| `FaradayEnrichmentRequested` | Faraday API call was requested (legacy) | `phone`, `first_name`, `last_name`, `addresses`, `emails` |
| `ProviderEnrichmentRequested` | A provider was requested (composable) | `provider_type`, `contact_data`, `provider_config` |
| `ProviderEnrichmentCompleted` | A provider responded (composable) | `provider_type`, `status`, `enrichment_data`, `quality_metadata` |
| `EnrichmentCompositionRequested` | Composition of provider results was requested | `provider_data`, `composition_rules` |
| `EnrichmentComposed` | Provider results were merged into final form | `composed_data`, `data_sources`, `provider_scores`, `phone` |
| `EnrichmentReset` | All enrichment data was cleared | `id`, `timestamp` |

### Meeting Events

| Event | Description | Key Fields |
|:------|:------------|:-----------|
| `MeetingCreated` | A calendar meeting was recorded | `attendees`, `calendar_id`, `name`, `start_time`, `end_time`, `user_id` |

---

## Process Managers

Process managers are stateful workflows that listen for events and dispatch
commands to drive multi-step processes forward.

### Unification Manager

**Module:** `WaltUi.ProcessManagers.UnificationManager`

Decides what to do when a new contact is created: either link it to existing
enrichment data (if the phone number has been enriched before) or kick off a
new enrichment request.

**Trigger:** `LeadCreated`

**Flow:**

```
LeadCreated
  │
  ├─ Phone invalid or name is familial? ──▶ STOP (no enrichment)
  │
  ├─ Existing enrichment data found for phone?
  │    │
  │    ├─ Name matches (Jaro > 0.70)? ──▶ Dispatch Unify
  │    │
  │    └─ Name doesn't match? ──▶ Enqueue UnificationJob (OpenAI fallback)
  │
  └─ No existing data? ──▶ Dispatch RequestEnrichment
```

**Database reads:** Trestle and Faraday projections (by phone UUID)

---

### Enrichment Orchestration Manager

**Module:** `WaltUi.ProcessManagers.EnrichmentOrchestrationManager`

Coordinates the multi-provider enrichment pipeline. After enrichment is
requested, this manager sequences provider calls and triggers composition
when all providers have responded.

**Triggers:** `EnrichmentRequested`, `ProviderEnrichmentCompleted`

**Flow:**

```
EnrichmentRequested
  │
  └─▶ Dispatch RequestProviderEnrichment (Trestle)
        │
        ▼
ProviderEnrichmentCompleted (Trestle)
  │
  ├─ Trestle has addresses (not PO boxes)?
  │    └─▶ Dispatch RequestProviderEnrichment (Faraday)
  │          │
  │          ▼
  │   ProviderEnrichmentCompleted (Faraday)
  │    └─▶ Dispatch RequestEnrichmentComposition
  │
  └─ No usable addresses?
       └─▶ Dispatch RequestEnrichmentComposition (Trestle only)
```

**State recovery:** If process manager state is lost (crash/restart), it
recovers provider data from the Trestle and Endato projections.

---

### Contact Enrichment Manager

**Module:** `WaltUi.ProcessManagers.ContactEnrichmentManager`

After enrichment data is composed, this manager links it to all contacts that
share the same phone number. Also handles PTT score propagation after the
Jitter AI model runs.

**Triggers:** `EnrichmentComposed`, `Jittered`

**Flow:**

```
EnrichmentComposed
  │
  ├─ Find all contacts with matching phone
  │    │
  │    ├─ Contact has no enrichment yet?
  │    │    ├─ Name matches (Jaro > 0.70)? ──▶ Dispatch Unify
  │    │    └─ Name doesn't match? ──▶ Enqueue UnificationJob (OpenAI)
  │    │
  │    └─ Contact already enriched?
  │         └─▶ Dispatch Update (refresh enrichment fields)
  │
Jittered
  │
  └─ Find all contacts linked to this enrichment
       └─▶ Dispatch JitterPtt (update each contact's score)
```

---

### Calendar Meetings Manager

**Module:** `WaltUi.ProcessManagers.CalendarMeetingsManager`

When a meeting is synced from Google Calendar, this manager checks whether
any of the meeting attendees match existing contacts and creates invitation
records for them.

**Trigger:** `MeetingCreated`

**Flow:**

```
MeetingCreated
  │
  └─ For each attendee email:
       ├─ Contact found by email? ──▶ Dispatch InviteContact
       └─ No match? ──▶ Skip
```

---

### Enrichment Reset Manager

**Module:** `WaltUi.ProcessManagers.EnrichmentResetManager`

When enrichment data is reset (due to error recovery or manual action), this
manager clears the enrichment fields from all contacts that were using it.

**Trigger:** `EnrichmentReset`

**Flow:**

```
EnrichmentReset
  │
  └─ Find all contacts with matching enrichment_id
       └─▶ Dispatch Update (clear enrichment_id, ptt, address fields)
```

---

## Event Handlers

Event handlers perform side effects in response to events. Unlike process
managers, they are stateless.

### Provider Enrichment Requested Handler

**Module:** `WaltUi.Handlers.ProviderEnrichmentRequestedHandler`

Bridges CQRS events to Oban background jobs. When a provider enrichment is
requested, this handler enqueues the appropriate API job.

| Event | Action |
|:------|:-------|
| `ProviderEnrichmentRequested` (trestle) | Enqueues `TrestleJob` |
| `ProviderEnrichmentRequested` (faraday) | Enqueues `FaradayJob` |

---

### Enrichment Composition Requested Handler

**Module:** `WaltUi.Handlers.EnrichmentCompositionRequestedHandler`

When composition is requested, this handler calls the `Enrichment.Composer`
module to merge provider results, then dispatches
`CompleteEnrichmentComposition` with the merged data.

| Event | Action |
|:------|:-------|
| `EnrichmentCompositionRequested` | Calls `Composer.compose/1`, dispatches `CompleteEnrichmentComposition` |

---

### Email Sync on Lead Created

**Module:** `WaltUi.Handlers.EmailSyncOnLeadCreated`

| Event | Action |
|:------|:-------|
| `LeadCreated` | Enqueues `SyncContactEmailsJob` (Gmail sync for contact's emails) |

---

### Email Sync on Contact Update

**Module:** `WaltUi.Handlers.EmailSyncOnContactUpdate`

| Event | Action |
|:------|:-------|
| `LeadUpdated` (email or emails changed) | Enqueues `SyncContactEmailsJob` |

---

### Calendar Sync on Lead Created

**Module:** `WaltUi.Handlers.CalendarSyncOnLeadCreated`

| Event | Action |
|:------|:-------|
| `LeadCreated` | Enqueues `SyncContactCalendarEventsJob` |

---

### Calendar Sync on Contact Update

**Module:** `WaltUi.Handlers.CalendarSyncOnContactUpdate`

| Event | Action |
|:------|:-------|
| `LeadUpdated` (email or emails changed) | Enqueues `SyncContactCalendarEventsJob` |

---

### Geocode on Address Change

**Module:** `WaltUi.Handlers.GeocodeOnAddressChange`

Enqueues a geocoding job when a contact's address changes. Only runs for
premium users.

| Event | Action |
|:------|:-------|
| `LeadUpdated` (address fields changed) | Enqueues `GeocodeContactAddressJob` (premium only) |
| `LeadUnified` | Enqueues `GeocodeContactAddressJob` (premium only) |

---

### Search Handler

**Module:** `WaltUi.Handlers.Search`

Keeps the TypeSense full-text search index in sync with contact events.

| Event | Action |
|:------|:-------|
| `LeadCreated` | Indexes new contact document in TypeSense |
| `LeadUpdated` | Updates fields in TypeSense document |
| `LeadUnified` | Updates enrichment fields (city, ptt, address) in TypeSense |
| `LeadDeleted` | Removes document from TypeSense |

---

## Projectors

Projectors build read-optimized database records from events. They are the
write side of the projection tables documented in the data dictionary.

### Contact Projector

**Module:** `WaltUi.Projectors.Contact`
**Consistency:** strong

| Event | Action |
|:------|:-------|
| `LeadCreated` | INSERT contact record (normalizes phone numbers) |
| `LeadDeleted` | DELETE contact record |
| `LeadUpdated` | UPDATE changed fields |
| `LeadUnified` | UPDATE enrichment_id, ptt, and address fields |
| `AddressSelected` | UPDATE address fields |

---

### Contact Creation Projector

**Module:** `WaltUi.Projectors.ContactCreation`
**Consistency:** strong

| Event | Action |
|:------|:-------|
| `LeadCreated` | INSERT record with `type: :create` |
| `LeadDeleted` | INSERT record with `type: :delete` |

---

### Contact Showcase Projector

**Module:** `WaltUi.Projectors.ContactShowcase`
**Consistency:** strong

Maintains a curated list of up to 150 showcased contacts per user, prioritizing
contacts with the best enrichment quality.

| Event | Action |
|:------|:-------|
| `LeadUnified` | UPSERT showcase (may swap `:lesser` for `:best`) |
| `LeadUpdated` (enrichment_type changed) | UPDATE showcase type |
| `LeadDeleted` | DELETE showcase |
| `EnrichmentReset` | DELETE showcases for affected contacts |

---

### Contact Interaction Projector

**Module:** `WaltUi.Projectors.ContactInteraction`
**Consistency:** eventual

| Event | Action |
|:------|:-------|
| `LeadCreated` | INSERT with `activity_type: :contact_created` |
| `ContactInvited` | INSERT with `activity_type: :contact_invited` + meeting metadata |
| `ContactCorresponded` | INSERT with `activity_type: :contact_corresponded` + email metadata |
| `LeadDeleted` | DELETE all interactions for contact |

---

### Enrichment Projector

**Module:** `WaltUi.Projectors.Enrichment`
**Consistency:** strong

| Event | Action |
|:------|:-------|
| `EnrichedWithFaraday` | UPSERT enrichment with demographic data |
| `EnrichmentComposed` | UPSERT enrichment with merged provider data |
| `EnrichmentReset` | DELETE enrichment record |

---

### Endato Projector

**Module:** `WaltUi.Projectors.Endato`
**Consistency:** strong

| Event | Action |
|:------|:-------|
| `EnrichedWithEndato` | UPSERT Endato record |
| `ProviderEnrichmentCompleted` (endato, success) | UPSERT from enrichment_data |
| `EnrichmentReset` | DELETE Endato record |

---

### Faraday Projector

**Module:** `WaltUi.Projectors.Faraday`
**Consistency:** strong

| Event | Action |
|:------|:-------|
| `EnrichedWithFaraday` | UPSERT Faraday record |
| `ProviderEnrichmentCompleted` (faraday, success) | UPSERT from enrichment_data |
| `EnrichmentReset` | DELETE Faraday record |

---

### Trestle Projector

**Module:** `WaltUi.Projectors.Trestle`
**Consistency:** strong

| Event | Action |
|:------|:-------|
| `EnrichedWithTrestle` | UPSERT Trestle record (filters PO box addresses) |
| `ProviderEnrichmentCompleted` (trestle, success) | UPSERT from enrichment_data |
| `EnrichmentReset` | DELETE Trestle record |

---

### Gravatar Projector

**Module:** `WaltUi.Projectors.Gravatar`
**Consistency:** strong

| Event | Action |
|:------|:-------|
| `EnrichedWithEndato` | Tries each Endato email against Gravatar API; stores URL if found |

---

### Jitter Projector

**Module:** `WaltUi.Projectors.Jitter`
**Consistency:** strong

| Event | Action |
|:------|:-------|
| `Jittered` | UPSERT jitter record with AI-adjusted PTT score |
| `EnrichmentReset` | DELETE jitter record |

---

### PTT Score Projector

**Module:** `WaltUi.Projectors.PttScore`
**Consistency:** strong

Maintains a historical time series of PTT scores for trend analysis.

| Event | Action |
|:------|:-------|
| `LeadCreated` (ptt > 0) | INSERT score record |
| `LeadUpdated` (ptt changed) | INSERT score record |
| `LeadUnified` | INSERT score record |
| `PttJittered` | INSERT jitter score record |
| `EnrichmentComposed` | INSERT score records for all linked contacts |
| `LeadDeleted` | DELETE all score records |
| `PttHistoryReset` | DELETE all score records |

---

### Possible Address Projector

**Module:** `WaltUi.Projectors.PossibleAddress`
**Consistency:** eventual

| Event | Action |
|:------|:-------|
| `EnrichedWithEndato` | INSERT valid addresses (requires street, city, state, zip) |
| `EnrichedWithTrestle` | INSERT valid addresses |
| `ProviderEnrichmentCompleted` (endato/trestle, success) | INSERT addresses from enrichment_data |

Uses deterministic UUIDs (UUID5 of enrichment_id + address components) for
deduplication.

---

## End-to-End Flows

### Flow 1: New Contact Creation and Enrichment

This is the most important flow in the system. It traces what happens from
the moment a user creates a contact to when enrichment data appears on
screen.

```
User creates contact via API
  │
  ▼
CQRS.create_contact/2
  │ Builds deterministic UUID, dispatches Create command
  ▼
LeadAggregate.execute(Create)
  │ Produces LeadCreated event
  ▼
LeadCreated event persisted to event store
  │
  ├──▶ Contact Projector ──▶ INSERT into projection_contacts
  ├──▶ ContactCreation Projector ──▶ INSERT analytics record
  ├──▶ ContactInteraction Projector ──▶ INSERT :contact_created
  ├──▶ Search Handler ──▶ Index in TypeSense
  ├──▶ EmailSync Handler ──▶ Enqueue SyncContactEmailsJob
  ├──▶ CalendarSync Handler ──▶ Enqueue SyncContactCalendarEventsJob
  │
  └──▶ UnificationManager (process manager)
         │
         ├─ Existing enrichment for phone?
         │    └─ Name match? ──▶ Dispatch Unify ──▶ LeadUnified
         │
         └─ No existing data?
              └─▶ Dispatch RequestEnrichment
                    │
                    ▼
              EnrichmentRequested
                    │
                    └──▶ EnrichmentOrchestrationManager
                           │
                           ▼
                    RequestProviderEnrichment (Trestle)
                           │
                           └──▶ ProviderEnrichmentRequestedHandler
                                  │ Enqueues TrestleJob
                                  ▼
                           ProviderEnrichmentCompleted (Trestle)
                                  │
                                  ▼
                           RequestProviderEnrichment (Faraday)
                                  │
                                  └──▶ ProviderEnrichmentRequestedHandler
                                         │ Enqueues FaradayJob
                                         ▼
                                  ProviderEnrichmentCompleted (Faraday)
                                         │
                                         ▼
                                  RequestEnrichmentComposition
                                         │
                                         └──▶ CompositionRequestedHandler
                                                │ Calls Composer.compose/1
                                                │ Dispatches CompleteEnrichmentComposition
                                                ▼
                                         EnrichmentComposed
                                                │
                                                ├──▶ Enrichment Projector ──▶ UPSERT
                                                ├──▶ PttScore Projector ──▶ INSERT
                                                │
                                                └──▶ ContactEnrichmentManager
                                                       │ Finds contacts by phone
                                                       │ Dispatches Unify for each
                                                       ▼
                                                LeadUnified
                                                       │
                                                       ├──▶ Contact Projector ──▶ UPDATE
                                                       ├──▶ ContactShowcase Projector
                                                       ├──▶ Geocode Handler ──▶ GeocodeJob
                                                       ├──▶ Search Handler ──▶ Update TypeSense
                                                       └──▶ PttScore Projector ──▶ INSERT
```

### Flow 2: Email Correspondence

```
Gmail sync job detects email involving a contact
  │
  ▼
CQRS.create_correspondence/1
  │ Dispatches Correspond command for each contact
  ▼
LeadAggregate.execute(Correspond)
  │ Deduplicates by source_id
  │ Produces ContactCorresponded event
  ▼
ContactCorresponded
  │
  └──▶ ContactInteraction Projector ──▶ INSERT :contact_corresponded
```

### Flow 3: Calendar Meeting Sync

```
Calendar sync job discovers new meeting
  │
  ▼
CQRS.create_meeting/1
  │ Dispatches Create command to MeetingAggregate
  ▼
MeetingCreated
  │
  └──▶ CalendarMeetingsManager
         │ Looks up each attendee email
         │ Dispatches InviteContact for matches
         ▼
  ContactInvited
         │
         └──▶ ContactInteraction Projector ──▶ INSERT :contact_invited
```

### Flow 4: Enrichment Reset

```
Admin or system triggers enrichment reset
  │
  ▼
EnrichmentAggregate.execute(Reset)
  │ Produces EnrichmentReset event
  ▼
EnrichmentReset
  │
  ├──▶ Enrichment Projector ──▶ DELETE
  ├──▶ Endato Projector ──▶ DELETE
  ├──▶ Faraday Projector ──▶ DELETE
  ├──▶ Trestle Projector ──▶ DELETE
  ├──▶ Jitter Projector ──▶ DELETE
  ├──▶ ContactShowcase Projector ──▶ DELETE
  │
  └──▶ EnrichmentResetManager
         │ Finds all linked contacts
         │ Dispatches Update (clear enrichment fields) for each
         ▼
  LeadUpdated (clearing enrichment_id, ptt, address)
         │
         ├──▶ Contact Projector ──▶ UPDATE
         └──▶ Search Handler ──▶ Update TypeSense
```

---

## Glossary

| Term | Definition |
|:-----|:-----------|
| Aggregate | A domain object that handles commands and produces events. The consistency boundary for writes. |
| Command | A request to change state. A plain Elixir struct dispatched through the router. |
| Composition | The process of merging enrichment data from multiple providers into a single unified record. |
| Event | An immutable fact that something happened. Persisted to the event store. The source of truth. |
| Event Handler | A stateless subscriber that reacts to events with side effects. |
| Event Store | The PostgreSQL-backed append-only log of all events. |
| Jitter | Random perturbation applied to PTT scores to prevent all contacts with the same raw score from appearing identical. |
| Process Manager | A stateful subscriber that coordinates multi-step workflows by listening for events and dispatching commands. |
| Projection | A read-optimized database record built from events. What the API queries. |
| Projector | An event handler that builds projections. |
| PTT | Propensity to Transact. A 0-100 score predicting likelihood of a real estate transaction. |
| Unification | Linking a per-user contact to a phone-number-keyed unified record that holds enrichment data. |
