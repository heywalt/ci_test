# Contact Enrichment Job Improvements

## Problem Statement

Production crash at 8:06am MT on 2025-10-20:
```
ContactEnrichmentManager has taken longer than 10000ms to process event #23262570
```

The system was processing an enrichment for a phone number matching **794 contacts**, causing the process manager to timeout after 10 seconds and crash the system.

## Current Enrichment Flow

### 1. Event Emission
- `CompleteEnrichmentComposition` command → `EnrichmentComposed` event
- Event contains enriched data from providers (Endato, Faraday, Trestle)
- Includes: phone number, name, address, PTT score, alternate names

### 2. Process Manager Handles Event
**File**: `apps/walt_ui/lib/walt_ui/process_managers/contact_enrichment_manager.ex`

```elixir
def handle(_state, %EnrichmentComposed{} = event) do
  if event.phone do
    event.id
    |> eventable_contacts_query(event.phone)  # Query ALL contacts with this phone
    |> Repo.all()                              # Could be 794 contacts!
    |> Enum.flat_map(&process_contact(&1, event))  # Process ALL synchronously
  else
    []
  end
end
```

**Current Processing Logic** (lines 97-125):

**Already enriched contacts** (has `enrichment_id`):
- Returns `Update` command synchronously ✓ Fast

**Not yet enriched contacts**:
- No names: Skip
- Jaro match >0.70: Return `Unify` command synchronously ✓ Fast
- Jaro match <0.70: Enqueue `UnificationJob`, return empty ✓ Async via Oban

### 3. Commands Create Events
- `Unify` command → `LeadUnified` event (updates contact with enrichment data)
- `Update` command → `LeadUpdated` event (updates existing enriched contact)

### 4. Projectors/Handlers React
- **Contact projector** (`:strong` consistency): Updates `projection_contacts` table
- **Search handler**: Updates Typesense search index
- **Geocode handler**: Triggers geocoding for address changes
- **Calendar/Email sync handlers**: Triggers contact-specific syncs

## Why Timeout Happens

Even with "fast" operations, processing 794 contacts sequentially takes >10 seconds:

- **Fetching 794 contacts**: ~100ms (fast)
- **Processing each contact**:
  - Jaro distance calculation (first + last name)
  - Alternate name matching (iterate through alternates)
  - Command building or job enqueuing
  - **794 × ~15ms = ~12 seconds** → TIMEOUT

## Critical Insight: Async Already Exists

**The system already uses Oban jobs for enrichment!**

`UnificationJob` (apps/walt_ui/lib/walt_ui/enrichment/unification_job.ex):
- Used when Jaro match score is <0.70
- Calls OpenAI API to confirm identity
- Dispatches `Unify` command via `CQRS.dispatch()`
- Events still flow through projectors with strong consistency
- **Delay is acceptable** - enrichment data is valuable enough to wait

## Proposed Solution

### Move ALL Contact Processing to Oban Jobs

Instead of processing contacts synchronously in the process manager, enqueue one Oban job per contact.

**Benefits**:
✅ Process manager completes instantly (<1ms, no timeout)
✅ Oban handles concurrency via queue limits (already configured)
✅ Each contact processes independently with retries (3-5 attempts)
✅ Failed contacts don't block others
✅ Events still flow through projectors normally
✅ Follows existing pattern (UnificationJob)
✅ Backpressure via queue limits prevents overwhelming the system

**Tradeoffs**:
⚠️ Slight delay in contact enrichment (seconds instead of milliseconds)
⚠️ Commands dispatched asynchronously instead of synchronously

### Why Delay is Acceptable

1. **Already async for GPT cases**: System already accepts async processing for UnificationJob
2. **Enrichment is batch operation**: Enrichments run in background via Oban already
3. **Better than crashing**: Delayed enrichment >> production crash
4. **Natural backpressure**: Queue limits prevent resource exhaustion

## Implementation Plan

### 1. Create New Oban Worker

**File**: `apps/walt_ui/lib/walt_ui/enrichment/contact_enrichment_job.ex`

```elixir
defmodule WaltUi.Enrichment.ContactEnrichmentJob do
  use Oban.Worker,
    queue: :enrichment,
    max_attempts: 3

  alias CQRS.Leads.Commands.{Unify, Update}
  alias WaltUi.Enrichment.UnificationJob

  args_schema do
    field :contact_id, :string, required: true
    field :enrichment_id, :string, required: true
    field :enrichment_data, :map, required: true
    field :provider_scores, :map, required: true
    field :alternate_names, {:array, :string}, default: []
    field :contact_enrichment_id, :string  # Existing enrichment_id on contact
    field :contact_first_name, :string
    field :contact_last_name, :string
    field :user_id, :string, required: true
  end

  @impl Oban.Worker
  def perform(%{args: args}) do
    # Process the contact using the exact same logic from ContactEnrichmentManager
    # Returns :ok or {:error, reason}
  end
end
```

### 2. Modify ContactEnrichmentManager

**File**: `apps/walt_ui/lib/walt_ui/process_managers/contact_enrichment_manager.ex`

```elixir
def handle(_state, %EnrichmentComposed{} = event) do
  if event.phone do
    contacts =
      event.id
      |> eventable_contacts_query(event.phone)
      |> Repo.all()

    # Enqueue job for each contact
    Enum.each(contacts, fn contact ->
      ContactEnrichmentJob.new(%{
        contact_id: contact.id,
        enrichment_id: event.id,
        enrichment_data: event.composed_data,
        provider_scores: event.provider_scores,
        alternate_names: event.alternate_names,
        contact_enrichment_id: contact.enrichment_id,
        contact_first_name: contact.first_name,
        contact_last_name: contact.last_name,
        user_id: contact.user_id
      })
      |> Oban.insert()
    end)

    [] # Return no commands - all processing happens async
  else
    []
  end
end
```

### 3. Update Oban Queue Configuration

**File**: `config/config.exs`

Verify `enrichment` queue has appropriate limits:
```elixir
queues: [
  enrichment: 10,  # Process 10 enrichments concurrently
  # ... other queues
]
```

## Migration Strategy

### Option A: Full Async (Recommended)
- All contact processing via Oban jobs
- Simplest implementation
- Consistent behavior for all contacts

### Option B: Hybrid Approach
- Already-enriched contacts: Process synchronously (fast path)
- Not-yet-enriched contacts: Process via Oban (slow path)
- More complex, but optimizes for common case

**Recommendation**: Option A for simplicity and consistency

## Testing Strategy

1. **Unit tests**: Test ContactEnrichmentJob with various scenarios
2. **Integration test**: Create enrichment with 100+ contacts, verify no timeout
3. **Load test**: Create enrichment with 1000 contacts, verify system stability
4. **Monitor**: AppSignal metrics for job duration and success rate

## Rollback Plan

If issues arise:
1. Revert ContactEnrichmentManager to synchronous processing
2. Add `LIMIT 100` to contact query as temporary fix
3. Investigate and address specific issues
4. Re-deploy async solution

## Success Metrics

- ✅ ContactEnrichmentManager never times out
- ✅ All contacts get enriched (check job success rate >98%)
- ✅ No production crashes due to enrichment processing
- ✅ Average enrichment completion time <30 seconds for 100 contacts
