## Memory optimization

Weekly token-history scans now drain temporary Foundation parsing objects after each 64 KiB chunk. This prevents temporary objects from accumulating across the entire scan and leaving large allocator regions resident afterward.

Measured on the development Apple Silicon Mac:

| Measurement | Before | After |
| --- | ---: | ---: |
| 50,000-event fixture: additional resident memory | 67 MiB | 1 MiB |
| 200,000-event fixture, three scans: resident peak | 276 MiB | 12 MiB |
| Installed app: observed resident memory | About 306 MiB | About 74–79 MiB |

The installed-app figures are snapshots after different running durations, not an equal-duration soak test or a memory guarantee for every Mac. Token totals and pricing calculations are unchanged by this optimization. A regression test now checks memory growth through the actual history reader.

[Full performance report and reproduction steps](https://github.com/Mermalat/AI-limitshower-for-mac/blob/v1.3.0/docs/PERFORMANCE.md)

## Also included since v1.2.0

- Weekly token totals and estimated USD API equivalents for Codex and Claude, with daily bar charts and date/token/cost tables.
- Show or hide token details; expand each provider independently using its header arrow.
- Fixed overlapping labels and graphs during panel resizing.
- Deduplication of repeated/forked/streamed usage records, cache pricing, and warnings for incomplete history or unknown model prices.
- **AIlimitshower.app** with a rocket icon for Finder and Raycast. Launching the app opens its usage panel. The bundle identifier and saved preferences are preserved.

USD values are API-equivalent estimates, **not invoices or subscription charges**.

## Installation and files

Requires **macOS 13+**. Download `TopBarClaudeCodexLimits-1.3.0-universal.dmg`, open it and drag **AIlimitshower.app** to Applications. The DMG includes both **Apple Silicon and Intel** architectures. Codex CLI and Claude Code must be installed and signed in separately.

- `TopBarClaudeCodexLimits-1.3.0-universal.dmg`: installable macOS application.
- `TopBarClaudeCodexLimits-1.3.0-source.tar.gz`: matching source, tests, assets and build scripts.
- `SHA256SUMS.txt`: file-integrity checksums. Verify with `shasum -a 256 -c SHA256SUMS.txt`.

Source code is **GPL-3.0-only**. Third-party brand assets remain covered by the third-party notices. The independent GNOME alpha remains a separate release.

## Validation and limits

Passed the offline provider/accounting tests, seven-day/date/cache/deduplication tests, provider/language/settings tests, actual window-resizing tests and the memory regression test. Both macOS architectures were built, the code signature verified, and the DMG integrity checked.

The application is ad-hoc signed and does **not** include an Apple Developer ID signature or notarization. Intel hardware execution and a long-duration memory soak have not been tested.
