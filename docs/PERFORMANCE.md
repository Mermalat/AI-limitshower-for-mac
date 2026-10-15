# Memory regression: token history scans

Measured on the development Apple Silicon Mac on October 15, 2026. Values are snapshots, not a cross-machine memory guarantee.

## Cause and fix

Weekly history is streamed in 64 KiB chunks, but Foundation's autoreleased parsing objects previously accumulated across the whole scan. ARC alone did not drain these temporary objects. The large allocation peak also left empty allocator regions resident after completion.

`TokenHistory.lines` now drains an autorelease pool after each chunk, including the JSON parsing callback. Token totals, deduplication, date boundaries and the existing 16 MiB line limit are unchanged.

## Before / after

| Measurement | Before | After |
| --- | ---: | ---: |
| 50,000-event fixture: additional resident memory during a scan | 67 MiB | 1 MiB |
| 200,000-event fixture, three scans: resident peak | 276 MiB | 12 MiB |
| Two local history scans in a standalone process: final resident memory | 132 MiB | 26 MiB |
| Installed app: observed resident memory | Approximately 306 MiB | Approximately 79 MiB |
| Installed app: observed physical footprint | 78.7 MiB | 34.7 MiB |

The old app had been running for over 13 hours; the new app measurement was taken after restarting and completing its initial refresh. These are not equal-duration soak tests. Both application snapshots showed 0% CPU at measurement time. No long-duration soak or Intel hardware measurement has been completed.

## Reproduce

`./test.sh` includes a 50,000-event fixture through the actual history reader, verifies counters, and rejects resident growth of 32 MiB or more. The fixture repeats a single event, so a growing record dictionary cannot explain the allocation growth.

After running the test suite:

```sh
build/memory-tests --stress
```

This repeats the original 200,000-event / three-scan workload. It generates temporary synthetic logs and deletes them afterward.

Optional measurement of local history, without querying either provider:

```sh
build/memory-tests --real
```

This reads the same local counters as the app and prints memory measurements only, not conversation contents or credentials. It does not change local history or send it anywhere.
