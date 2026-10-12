# Token usage and estimated cost

Each provider card shows the token total for **today and the preceding six local calendar dates**, ending at refresh time. A seven-bar chart shows daily token use; the table underneath lists each date, full token count, and estimated USD value. Days without recorded usage are included with zero values. Daily boundaries use the Mac’s local time zone and calendar, including daylight-saving changes. Refresh follows the selected interval and the manual refresh button. The three-dot menu can hide or show the token section for both providers. The preference persists; local token history is not scanned while this section is hidden. Provider quota polling continues.

Only logs available on this Mac are included:

- Codex: `$CODEX_HOME/sessions` and `$CODEX_HOME/archived_sessions`, defaulting to `~/.codex`.
- Claude Code: `$CLAUDE_CONFIG_DIR/projects`, defaulting to `~/.claude/projects`. Subagent logs are included.

The app reads these files locally. It does not upload conversations or token history, create API calls to obtain token totals, or modify the logs. Missing/deleted/cloud-only/other-device history cannot be recovered. Different signed-in accounts whose logs remain on the same Mac may be included; this is a local usage total, not an account billing report.

## Counting

Codex uses differences between successive cumulative token counters, including an older event as the baseline when a conversation spans the cutoff. Repeated notifications and copied fork/archive events are deduplicated. Reset counters use the latest request counters. Cached input is a subset of input, so it is counted once. Reasoning output is already included in output tokens and is not added again. Guardian safety-review sessions are excluded.

Claude messages are deduplicated by model and message ID. Repeated streamed records are merged using the highest counters for that message. Input, cached reads, 5-minute cache writes, 1-hour cache writes, and output are counted separately. Synthetic messages are excluded. Usage is attributed to the timestamp of the logged event, not apportioned across a request that crosses the cutoff.

The scanner streams files and ignores an unfinished trailing line until its newline appears. Unreadable or malformed relevant records produce an incomplete-data notice. No local history is shown as unavailable rather than an invented zero.

## USD estimate

The displayed amount is the **estimated standard API equivalent**, not an invoice, actual subscription charge, credit deduction, or amount owed. Prices were checked on **2026-10-12** against [official OpenAI API pricing](https://developers.openai.com/api/docs/pricing) and [official Claude API pricing](https://platform.claude.com/docs/en/about-claude/pricing).

Rates are USD per million tokens. The rates are embedded in `Sources/TokenHistory.swift`; the app does not fetch prices automatically.

| Model | Input | Cached read | Output |
| --- | ---: | ---: | ---: |
| GPT-6.1 Sol | 2.00 | 0.10 | 10.00 |
| GPT-6 Astra | 10.00 | 1.00 | 50.00 |
| GPT-6 Luna | 0.10 | 0.01 | 0.50 |
| GPT-5.6 Sol | 4.00 | 0.40 | 20.00 |
| Claude Opus 5.5 | 4.00 | 0.20 | 20.00 |
| Claude Sonnet 5.5 | 2.00 | 0.10 | 10.00 |
| Claude Opus 5 / 4.8 / 4.7 / 4.6 / 4.5 | 5.00 | 0.50 | 25.00 |
| Claude Sonnet 5 | 2.00 | 0.20 | 10.00 |
| Claude Sonnet 4.6 / 4.5 | 3.00 | 0.30 | 15.00 |
| Claude Haiku 4.5 | 1.00 | 0.10 | 5.00 |

Cache writes use 1.25× input for 5-minute writes and 2× input for 1-hour writes. Codex cache writes, when present, use 1.25× input. The estimate uses the standard short-context/global API rate, excluding long-context surcharges, fast/priority mode, regional adjustments, taxes, discounts, tools, web search, and subscription fees. Historical usage is valued at this price snapshot, not the price on the date it occurred.

Unknown models still contribute to token totals, but not to the estimated dollar subtotal. The UI flags partial pricing; if every model is unpriced, the cost is shown as “—”. Supported dated Claude snapshots use the rate for the corresponding explicitly supported model, not a guessed rate for an unknown model family.

## Verification

`./test.sh` covers the seven-day cutoff baseline, daily token/cost sums, empty days, local midnight and daylight-saving boundaries, duplicate/fork/stream records, counter resets, cache arithmetic, reasoning double-count prevention, unknown prices, missing logs, and malformed records. `./test.sh --live-history` additionally reads the local history and prints only aggregate counters and estimates, without conversation content or credentials.
