# Large Onboarding Event: Lessons Learned & Recommendations

**Date**: October 21, 2025
**Event**: 145,325 contacts uploaded by 90+ users over ~6 hours
**Duration**: System processing for 10+ hours (still ongoing at time of writing)
**Incidents**: 3 production crashes, 830 calendar sync errors, slow enrichment pipeline

## What Happened

### Timeline
- **17:26 UTC**: First contacts begin uploading
- **~18:00 UTC**: Contact creation complete, enrichment pipeline begins
- **~20:00 UTC**: System crashes (ContactEnrichmentManager timeout)
- **17:26-23:25 UTC**: Enrichment processing span (~6 hours for most users)
- **23:00 UTC+**: Faraday queue saturated, event processing backlog

### Volume Statistics
- **Total contacts uploaded**: 145,325
- **Number of users**: 90+
- **Largest single user**: 10,746 contacts
- **Enrichment completion rate**: 185-262/min (accelerating)
- **Expected total duration**: 10-12 hours

## Root Causes Identified

### 1. ContactEnrichmentManager Timeout (CRITICAL)
**File**: `apps/walt_ui/lib/walt_ui/process_managers/contact_enrichment_manager.ex:6`

**Problem**:
- Process manager has 10-second timeout
- Queries ALL contacts matching a phone number
- One phone number matched 794 contacts
- Processing 794 contacts synchronously > 10 seconds → timeout → crash

**Impact**: Production crash at 8:06am MT

**Status**: Documented in `contact_enrichment_job_improvements.md`, NOT YET FIXED

### 2. Slow Email Query Performance
**File**: `apps/walt_ui/lib/walt_ui/contacts.ex:267-301`

**Problem**:
- `get_contacts_by_emails/2` taking 8+ seconds (AppSignal worst query)
- Used `or_where()` in loop creating massive OR chain
- No indexes on `email` or `emails` JSONB array
- Called by `SyncContactCalendarEventsJob` (236 jobs queued)

**Fix Applied**:
- ✅ Added composite index on `(user_id, email)`
- ✅ Added GIN index on `emails` JSONB array
- ✅ Rewrote query from OR chain to IN/ANY pattern
- ✅ Deployed via PR #528

### 3. Calendar Duplicate Key Errors
**Error**: 830 violations on `calendars_source_id_index`

**Problem**:
- Global unique constraint on `source_id` prevented shared calendar syncing
- Race conditions from concurrent `SyncContactCalendarEventsJob` instances
- No upsert logic for duplicate handling

**Fix Applied**:
- ✅ Changed unique constraint to `(user_id, source_id)` composite
- ✅ Added upsert logic with `on_conflict` strategy
- ✅ Deployed via PR #528

### 4. Event Processing Bottleneck
**Problem**: Faraday jobs created faster than consumed

**Observation**:
- Trestle jobs completed quickly (64 concurrent workers)
- Created 300-700 Faraday job requests per minute
- Faraday queue saturated at 100 workers, jobs backed up to 9,000+
- Event processing serialization limited job creation rate

**Status**: Working as designed, but slow for this volume

## Current System Throughput

### Measured Performance
- **Contact enrichment**: 185-262/min (accelerating)
- **Faraday job completion**: 150-200/min
- **Event processing**: 285-393 events/min
- **Faraday job creation**: 300-700/min (bursty)

### Pipeline Stages & Concurrency Limits
1. **Contact Created** → `EnrichmentRequested` event
2. **Trestle + Endato** (parallel): 64 + 100 workers
3. **Faraday** (after Trestle): 100 workers ← **Current bottleneck**
4. **Composition** (synchronous event handler): No queue
5. **ContactEnrichmentManager** (process manager): 10s timeout
6. **OpenAI UnificationJob**: 1 per contact globally

### Capacity Math
- **Current**: ~240 enrichments/min average
- **145k contacts**: 604 minutes = **~10 hours**
- **Target for 4-hour onboarding**: Need 600+/min throughput

## Immediate Action Items

### 1. Fix ContactEnrichmentManager Timeout (HIGH PRIORITY)
**Status**: Documented, not implemented

**Solution**: Move processing to Oban jobs
- Create `ProcessContactEnrichmentJob` worker
- Enqueue one job per contact (instead of synchronous processing)
- Eliminates 10-second timeout risk
- Handles high-volume phone numbers gracefully

**Reference**: `docs/contact_enrichment_job_improvements.md`

### 2. Monitor for Additional Crashes
**Status**: Ongoing

**Action**: Review logs for crash patterns
- 3 crashes occurred during onboarding
- Only 1 identified (ContactEnrichmentManager timeout)
- Need to identify other 2 crash causes

## Future Prevention Strategies

### 1. Upload Rate Limiting
**Recommendation**: Implement per-user upload throttling

```elixir
# Config suggestion
config :walt_ui, :contact_upload,
  max_per_hour: 5_000,      # Per user
  max_concurrent_users: 20,  # System-wide
  burst_allowance: 10_000    # One-time large import
```

**Benefits**:
- Spreads load over time
- Prevents pipeline saturation
- Allows system to keep up with enrichment

**Tradeoff**: Slower onboarding for users with large lists

### 2. Queue Depth Monitoring & Alerts
**Recommendation**: Add AppSignal/alerts for queue saturation

**Thresholds**:
- **Warning**: Faraday queue > 5,000
- **Critical**: Faraday queue > 10,000
- **Action**: Any queue growing >1,000/min for 5+ minutes

**Response**: Auto-scale workers or throttle upstream

### 3. Graceful Degradation
**Recommendation**: Skip enrichment when system is overloaded

```elixir
# Pseudo-code
def handle_enrichment_request(contact) do
  if queue_depth(:faraday) > 10_000 do
    Logger.warning("Skipping enrichment due to queue saturation")
    :skip
  else
    enqueue_enrichment(contact)
  end
end
```

**Benefits**: Prevents cascading failures, maintains core functionality

### 4. Auto-Scaling Oban Workers
**Recommendation**: Dynamic concurrency based on queue depth

```elixir
# Oban Pro feature
queues: [
  faraday: [
    local_limit: 100,
    global_limit: [
      allowed: fn -> calculate_dynamic_limit(:faraday) end
    ]
  ]
]

defp calculate_dynamic_limit(queue) do
  case queue_depth(queue) do
    depth when depth > 10_000 -> 200  # Scale up
    depth when depth > 5_000 -> 150
    _else -> 100  # Normal
  end
end
```

### 5. Batch Upload Processing
**Recommendation**: Process CSV uploads in background, not real-time

**Current Flow**:
```
User uploads CSV → All contacts created immediately → Enrichment flood
```

**Proposed Flow**:
```
User uploads CSV → Stored in GCS → Background job processes in chunks
  → 1,000 contacts/minute → Gradual enrichment
```

**Benefits**:
- Controlled ingestion rate
- Better user feedback (progress bar)
- System never overwhelmed

### 6. Separate "Onboarding" Enrichment Queue
**Recommendation**: Dedicated queue for bulk uploads vs. individual additions

```elixir
queues: [
  faraday: 100,              # Individual contact enrichment
  faraday_bulk: 50,          # Bulk upload enrichment (lower priority)
]
```

**Benefits**:
- Bulk uploads don't starve individual user actions
- Can throttle bulk separately
- Better queue visibility

## Capacity Planning

### Current Throughput Analysis
| Stage | Concurrency | Throughput | Bottleneck? |
|-------|-------------|------------|-------------|
| Trestle | 64 (1 per user) | 300-700/min | ✅ Completed quickly |
| Faraday | 100 | 150-200/min | ⚠️ **Yes** (for this volume) |
| Composition | N/A (sync) | 285-393/min | ✅ Fast enough |
| ContactEnrichmentManager | N/A (10s timeout) | ? | ❌ **Crashes** |
| OpenAI | 1 per contact | 55/min | Future bottleneck |

### Scaling Recommendations

**For 4-Hour Max Onboarding** (150k contacts):
- **Target**: 625 enrichments/min
- **Faraday workers**: Increase to 300-400
- **ContactEnrichmentManager**: Fix timeout (move to Oban)
- **OpenAI**: May need 5-10 concurrent per contact

**For 2-Hour Max Onboarding** (aggressive):
- **Target**: 1,250 enrichments/min
- **Faraday workers**: 600-800
- **Trestle workers**: Increase from 64 to 100+
- **Database**: Consider read replicas for projections
- **Event Store**: May need partitioning

### Cost Considerations
- **Faraday API**: ~$0.01 per enrichment → 150k = $1,500
- **Trestle API**: ~$0.02 per enrichment → 150k = $3,000
- **OpenAI API**: ~$0.001 per call → 50k calls = $50
- **Total per onboarding**: ~$4,550

Higher throughput = same cost, just faster.

## Monitoring Dashboard (Recommended)

### Key Metrics to Track
1. **Queue Depths** (real-time):
   - Faraday available vs. executing
   - Trestle available vs. executing
   - OpenAI available vs. executing

2. **Enrichment Rate** (per minute):
   - Contacts enriched/min
   - By user (detect stuck users)
   - By stage (identify bottlenecks)

3. **Error Rates**:
   - Cancelled jobs (`:no_match_type`, `:unknown_error`)
   - Timeout crashes
   - Database query performance

4. **System Health**:
   - Event processing lag
   - Database connection pool usage
   - Memory/CPU per node

### Alert Thresholds
- Queue depth > 10,000: Page on-call
- Enrichment rate < 100/min for 10+ min: Investigate
- Error rate > 5%: Alert
- Any process manager timeout: Page immediately

## Testing Strategy

### Load Testing (Before Next Onboarding)
1. **Synthetic Load**: Upload 50k test contacts, measure throughput
2. **Stress Test**: Upload 200k contacts, verify no crashes
3. **Spike Test**: 10 users upload 10k each simultaneously
4. **Soak Test**: 24-hour continuous enrichment processing

### Metrics to Validate
- No crashes under 200k contact load
- <6 hour processing time for 150k contacts
- <5% error rate
- Queue depths stay below 15k

## Action Plan Summary

### Immediate (This Week)
- [ ] Implement `ContactEnrichmentJob` (async processing)
- [ ] Identify cause of other 2 crashes
- [ ] Add queue depth monitoring/alerts
- [ ] Document current throughput baseline

### Short-Term (Next Sprint)
- [ ] Increase Faraday workers to 200
- [ ] Implement batch CSV upload processing
- [ ] Add graceful degradation for queue saturation
- [ ] Create monitoring dashboard

### Long-Term (Next Quarter)
- [ ] Upload rate limiting per user
- [ ] Auto-scaling Oban workers
- [ ] Separate bulk vs. individual enrichment queues
- [ ] Load testing suite
- [ ] Event processing optimization

## Conclusion

The system successfully processed 145k contacts without permanent data loss, but experienced:
- **3 crashes** (1 identified, 2 unknown)
- **10+ hour processing time** (target: 4 hours)
- **Pipeline saturation** (Faraday queue peaked at 9k+)

**Root cause**: System designed for steady-state (100-1,000 contacts/day), not bulk onboarding (145k in 6 hours).

**Primary fix needed**: ContactEnrichmentManager async processing (prevents crashes).

**Performance improvements**: Increase Faraday concurrency, implement rate limiting, add monitoring.

**Long-term**: Design explicit "onboarding mode" with different throughput characteristics.
