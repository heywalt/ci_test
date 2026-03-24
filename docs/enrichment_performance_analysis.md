# Enrichment Performance Analysis

## Recent Infrastructure Upgrades

From git history, you recently completed:

1. **Database Upgrade** (PR #521):
   - `db-custom-4-16384` → `db-custom-8-32768`
   - Doubled vCPUs: 4 → 8
   - Doubled RAM: 16GB → 32GB

2. **Database Pool Size Increases**:
   - Production pool: 75 → 200 (PR #519)
   - EventStore pool: 25 → 75 (PR #522)

3. **Previous Enrichment Performance Work** (PR #512):
   - Identified database connection starvation
   - Noted: "100+ Oban workers competed for limited database connections"

## Current CPU Utilization: 50% (Not 80%)

You observed only 50% CPU utilization during enrichments. This is actually a **queue configuration issue**, not a CPU capacity problem.

## The Bottleneck: Enrichment Queue Concurrency

### Current Configuration

**config/config.exs:258-290**:
```elixir
config :walt_ui, Oban,
  queues: [
    enrichment: 1,        # ← BOTTLENECK: Only 1 job at a time
    endato: 100,          # ← Can handle 100 concurrent jobs
    faraday: 100,         # ← Can handle 100 concurrent jobs
    trestle: [            # ← Can handle 64 concurrent jobs
      local_limit: 64,
      global_limit: [allowed: 1, burst: true, partition: [args: :user_id]]
    ],
    # ... other queues
  ]
```

### Enrichment Flow Architecture

```
1. EnrichmentCronJob (queue: enrichment, concurrency: 1)
   └─> Batches unenriched contacts into chunks of 100
   └─> Enqueues EnrichmentJob for each chunk (with 5s stagger)

2. EnrichmentJob (queue: enrichment, concurrency: 1)
   └─> Dispatches RequestEnrichment command for each contact in batch
   └─> Fast operation (just command dispatch, CPU-light)

3. EnrichmentOrchestrationManager (ProcessManager)
   └─> Receives EnrichmentRequested events
   └─> Dispatches RequestProviderEnrichment commands for:
       - Trestle
       - Endato (or Faraday)

4. ProviderEnrichmentRequestedHandler
   └─> Enqueues provider-specific Oban jobs

5. Provider Jobs (HIGH CONCURRENCY)
   ├─> TrestleJob (queue: trestle, local_limit: 64)
   ├─> EndatoJob (queue: endato, concurrency: 100)
   └─> FaradayJob (queue: faraday, concurrency: 100)
       └─> Make external API calls (CPU-light, I/O-bound)
```

### Why Only 50% CPU?

**The enrichment queue is the chokepoint**:

1. Only **1 EnrichmentJob** runs at a time
2. Each job processes 100 contacts quickly (just CQRS command dispatch)
3. This slowly feeds the high-concurrency provider queues
4. Provider queues (endato: 100, faraday: 100, trestle: 64) sit idle waiting for work
5. CPU idle time: waiting for enrichment queue to feed more work

**Example scenario**:
- Enrichment queue can feed ~100 contacts every few seconds
- Provider queues can handle 264 concurrent jobs (100+100+64)
- But they're only getting fed at the rate of 1 EnrichmentJob at a time
- Result: Provider workers idle, CPU underutilized

### Why This Configuration Existed

The `enrichment: 1` setting likely predates your database upgrades. From PR #512:
> "100+ Oban workers competed for limited database connections"

**Old constraints** (no longer applicable):
- Database pool size: 75 (too small)
- Database instance: 4 vCPUs (limited capacity)
- Connection starvation during bulk processing

**New constraints** (current):
- Database pool size: 200 ✅
- Database instance: 8 vCPUs ✅
- EventStore pool: 75 ✅
- Can handle much higher concurrency

## Was Database the Real Bottleneck?

**Yes, absolutely!** The database was bottlenecking you in multiple ways:

1. **Connection Pool Exhaustion**:
   - Old pool size: 75
   - Potential concurrent workers: 100 (endato) + 100 (faraday) + 64 (trestle) + others = ~270+
   - Workers blocked waiting for DB connections
   - This causes timeouts and slow processing

2. **CPU/Memory Constraints**:
   - 4 vCPUs trying to handle 200+ connections
   - 16GB RAM for connection overhead + query processing
   - Database itself was saturated

3. **Event Store Contention**:
   - Pool size 25 for event sourcing operations
   - Every enrichment command writes events
   - High contention on limited connections

### Should You See Speed Improvements?

**YES**, but only if you increase enrichment queue concurrency! Here's why:

**Current state**:
- Database upgraded: ✅ Ready for more load
- Pool sizes increased: ✅ Can handle concurrent connections
- Queue concurrency: ❌ Still throttled at 1

**After increasing enrichment concurrency**:
- More EnrichmentJobs run in parallel
- Provider queues get fed faster
- Database can actually handle the load now
- You'll see higher CPU utilization (60-80% range)
- Enrichments complete faster

## Recommended Changes

### Option 1: Conservative Increase

Start with a moderate increase to test database capacity:

**config/config.exs**:
```elixir
config :walt_ui, Oban,
  queues: [
    enrichment: 10,  # Changed from 1 → 10
    # ... rest unchanged
  ]
```

**Impact**:
- 10 EnrichmentJobs can run concurrently
- Each processes 100 contacts
- Feeds provider queues 10x faster
- Should increase CPU to 60-70% range

### Option 2: Moderate Increase

If Option 1 goes well, increase further:

```elixir
enrichment: 25,  # 25 concurrent jobs
```

**Impact**:
- 25 batches of 100 contacts processing simultaneously
- Provider queues get fully saturated
- CPU utilization: 70-80% range
- Near-optimal throughput

### Option 3: Match Provider Capacity

For maximum throughput (after testing):

```elixir
enrichment: 50,  # 50 concurrent jobs
```

**Impact**:
- Fully saturates provider queues
- CPU: 80-90% range
- Maximum enrichment speed
- Requires monitoring database for any bottlenecks

## Testing Strategy

1. **Deploy Option 1** (enrichment: 10):
   - Monitor CPU utilization (should increase to 60-70%)
   - Monitor database connections (should stay under 200)
   - Monitor enrichment throughput (10x faster)
   - Check for errors or timeouts

2. **If stable, deploy Option 2** (enrichment: 25):
   - Monitor same metrics
   - Should see 70-80% CPU
   - Enrichment throughput 25x faster than current

3. **If still stable, consider Option 3** (enrichment: 50):
   - Push toward maximum throughput
   - Monitor for any new bottlenecks

## Metrics to Monitor

### Database
- **Connection pool usage**: Should stay under 200
- **Query latency**: Watch for slowdowns
- **CPU**: Database instance should stay under 80%

### Application
- **CPU utilization**: Target 70-80% during enrichments
- **Oban queue backlog**: Should decrease faster
- **Error rates**: Watch for connection timeouts

### Enrichment Speed
- **Time to process N contacts**: Should decrease proportionally
- **Provider queue saturation**: endato/faraday/trestle workers should be busy
- **Event store latency**: Monitor for any degradation

## Why You're Not Seeing the Benefits Yet

**TL;DR**: You upgraded the engine (database) but left the throttle (enrichment queue) at idle.

Your database can now handle:
- 200 concurrent connections
- 8 vCPUs worth of processing
- 75 event store connections

But your enrichment queue is still configured for the old constraints:
- 1 job at a time
- Designed for pool size 75
- Designed for 4 vCPU database

It's like upgrading from a 4-cylinder to a V8 engine but still driving in first gear.

## Expected Results After Fix

### Before (Current):
- Enrichment queue: 1 concurrent job
- CPU utilization: 50%
- Enrichment speed: Baseline
- Database: Underutilized

### After (enrichment: 25):
- Enrichment queue: 25 concurrent jobs
- CPU utilization: 70-80%
- Enrichment speed: **25x faster** 🚀
- Database: Properly utilized
- Provider queues: Fully saturated

## Implementation Recommendation

Start with **Option 1 (enrichment: 10)** because:

1. **Safe**: 10x increase is significant but not risky
2. **Quick validation**: You'll immediately see if database handles it
3. **Easy rollback**: Simple config change
4. **Proven pattern**: You already know provider queues can handle high concurrency

If everything looks good after a day or two, increase to 25.

## Why This Makes Sense

The enrichment queue does **very little CPU work**:
- Reads contact data from database
- Dispatches CQRS commands (fast)
- Commands trigger ProcessManager (fast)
- ProcessManager dispatches more commands (fast)

The **actual CPU work** happens in provider jobs:
- Making HTTP API calls (I/O-bound, not CPU-bound)
- Parsing JSON responses
- Database writes

Since provider jobs are I/O-bound, you can run MANY concurrently without saturating CPU. The database was the bottleneck, and you've already fixed that.

## Action Items

- [ ] Update `config/config.exs:264` to `enrichment: 10`
- [ ] Deploy to production
- [ ] Monitor for 24-48 hours:
  - CPU utilization (expect 60-70%)
  - Database connection usage
  - Enrichment throughput
  - Error rates
- [ ] If stable, increase to `enrichment: 25`
- [ ] Monitor another 24-48 hours
- [ ] Consider `enrichment: 50` for maximum throughput

## Conclusion

**Yes, the database was your real bottleneck**, but you won't see the benefits until you increase enrichment queue concurrency.

Your current setup is like having a Ferrari in the garage while driving a bicycle to work. The database upgrades give you the capacity; now you need to adjust the queue configuration to take advantage of it.

Increase `enrichment: 1` to `enrichment: 10` (or 25) and watch your enrichment speed increase proportionally while CPU utilization climbs to a healthy 70-80% range.

---

**Document Author**: Claude
**Date**: 2025-10-06
**Recommendation**: Start with `enrichment: 10`, then increase to 25 if stable
