# Contact Creation → Enrichment → Unification Flow

## Overview

Walt UI follows a three-phase process for managing contacts: creation, enrichment, and unification. This document describes how these phases work together in a CQRS/Event Sourcing architecture.

## Phase 1: Contact Creation

The contact creation phase establishes the initial contact record:

```
Create → LeadAggregate → LeadCreated → Contact Projection
```

### Components
- **Command**: `CreateLead` - initiated via API, CSV import, or Pub/Sub
- **Aggregate**: `LeadAggregate` - processes command with validation
- **Event**: `LeadCreated` - emitted with contact details
- **Projection**: Contact projector creates `Contact` projection in database

### Side Effects
- `EmailSyncOnLeadCreated` handler triggers if Google account exists
- `UnificationManager` starts to check for existing enrichment data

## Phase 2: Enrichment

The enrichment phase gathers additional data about contacts from multiple providers:

```
RequestEnrichment → EnrichmentAggregate → EnrichmentRequested → Provider Orchestration
                                                                    ↓
                                                         Provider Enrichments
                                                                    ↓
                                                         EnrichmentComposed
```

### Components
- **Command**: `RequestEnrichment` - creates enrichment aggregate (UUID5 of phone)
- **Aggregate**: `EnrichmentAggregate` - emits `EnrichmentRequested` event
- **Orchestration**: `EnrichmentOrchestrationManager` dispatches provider requests:
  - **Trestle**: Names, addresses, alternate names
  - **Endato**: Demographics, addresses, emails (parallel with Trestle)
  - **Faraday**: PTT score, demographics (after Trestle success)

### Provider Flow
1. `EnrichmentOrchestrationManager` dispatches provider requests
2. `ProviderEnrichmentRequestedHandler` bridges events to background jobs:
   - Listens to `ProviderEnrichmentRequested` events
   - Routes by provider type: "trestle" → TrestleJob, "faraday" → FaradayJob, "endato" → EndatoJob
   - Maintains separation between domain logic and infrastructure
3. Provider-specific jobs handle API calls
4. Each provider emits `ProviderEnrichmentCompleted` event
5. After Faraday completes, `RequestEnrichmentComposition` is dispatched
6. `EnrichmentCompositionRequestedHandler` orchestrates data merging:
   - Filters successful providers and delegates to `WaltUi.Enrichment.Composer`
   - Applies intelligent field selection strategies:
     - Age fields: Select by quality score
     - Address fields: Always prefer Trestle
     - Other fields: Provider capabilities, fallback to quality score
   - Dispatches `CompleteEnrichmentComposition` command
7. `EnrichmentComposed` event contains unified data with quality tracking

### Projections
- **Provider-specific**: Trestle, Endato, Faraday projections store raw data
- **PossibleAddress**: Collects addresses from Trestle and Endato responses
- **Enrichment**: Stores combined enrichment data
- **Gravatar**: Side effect that fetches profile pictures when Endato provides emails

## Phase 3: Unification

The unification phase connects enrichment data to contacts:

```
EnrichmentComposed → ContactEnrichmentManager → Decision Logic → Update/Unify Commands
```

### Components
- **Manager**: `ContactEnrichmentManager` handles `EnrichmentComposed` events
- **Decision Logic**:
  - Already enriched contacts → `Update` command
  - Not enriched → Name matching (Jaro distance > 0.70) → `Unify` command
  - No match → `UnificationJob` for OpenAI-powered matching

### Final Updates
- **Commands**: `Unify` or `Update` commands modify contact
- **Events**: `ContactUnified` or `ContactUpdated`
- **Projection**: Contact projector updates final contact data

## Phase 4: PTT Score Jittering

The jittering phase adds randomness to PTT scores:

```
JitterJob → Jitter Command → EnrichmentAggregate → Jittered Event → ContactEnrichmentManager → JitterPtt Commands
```

### Trigger
- Weekly scheduled job runs Sundays at 4:00 AM
- Selects random 25% of enrichments for jittering

### Process Flow
1. `JitterJob` dispatches `Jitter` commands to selected enrichment aggregates
2. `EnrichmentAggregate` applies jitter algorithm:
   - Random factor between -10% to +10%
   - Caps maximum score at 98
   - Converts float to integer
3. Emits `Jittered` event with new score
4. `ContactEnrichmentManager` propagates to contacts via `JitterPtt` commands
5. Lead aggregates update with new jittered scores

### Components
- **Commands**:
  - `CQRS.Enrichments.Commands.Jitter` (enrichment aggregate)
  - `CQRS.Leads.Commands.JitterPtt` (lead aggregate)
- **Events**: `Jittered`, `PttJittered`
- **Projections**: Jitter projection, PTT score projection tracks type `:jitter`

## Phase 5: Enrichment Reset

The enrichment reset phase allows clearing and re-processing of enrichment data:

```
Reset Command → EnrichmentAggregate → EnrichmentReset Event → EnrichmentResetManager → Update Commands
```

### Trigger
- Manual script execution (`WaltUi.Scripts.User.ResetEnrichments`)
- Direct command dispatch for specific enrichments
- Used for data cleanup or refreshing enrichment data

### Process Flow
1. `Reset` command dispatched to `EnrichmentAggregate`
2. `EnrichmentAggregate` clears internal state and emits `EnrichmentReset` event
3. `EnrichmentResetManager` receives event and:
   - Queries all contacts with matching enrichment_id
   - Dispatches `Update` commands to clear enrichment fields
4. Contact fields cleared:
   - enrichment_id → nil
   - ptt → nil
   - address fields (city, state, street_1, street_2, zip) → nil
5. Contacts become eligible for re-enrichment via `EnrichmentCronJob`

### Components
- **Command**: `CQRS.Enrichments.Commands.Reset`
- **Event**: `CQRS.Enrichments.Events.EnrichmentReset`
- **Process Manager**: `EnrichmentResetManager`
- **Re-enrichment**: Handled by periodic `EnrichmentCronJob`

## Additional Components

Beyond the core phases, several other components support the enrichment ecosystem:

### Projectors
- **ContactInteraction**: Tracks contact activity history from `LeadCreated`, `ContactInvited`, `ContactCorresponded`
- **ContactCreation**: Statistics on contact creation/deletion by date
- **ContactShowcase**: Manages showcased contacts based on enrichment quality (up to 150 per user)
- **PttScore**: Maintains PTT score history over time from enrichment events

### Event Handlers
- **EmailSyncOnContactUpdate**: Triggers email sync when contact emails change
- **Search**: Maintains TypeSense search index in real-time for all contact changes

## Key Architecture Points

- **Deterministic IDs**: Enrichment ID is UUID5 of phone number
- **Shared Enrichments**: Multiple contacts can share the same enrichment
- **Async Coordination**: Process managers handle complex workflows
- **Parallel Processing**: Email sync runs independently of enrichment
