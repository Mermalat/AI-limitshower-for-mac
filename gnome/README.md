# Claude & Codex Limits for GNOME

GNOME Shell top bar port of the macOS application. The extension uses the same supplied logos, dark rounded provider cards, green/copper accents, remaining quota summaries, expandable details, weekly token charts, and daily USD estimates. macOS sources remain separate and unchanged.

**Status:** installable development build. GNOME Shell 45–51 are declared targets, not a tested compatibility matrix. This port was built on macOS; it has **not yet been run in a real GNOME session**. Automated tests exercise counters, translations and lifecycle using Shell API doubles. Visual parity, Wayland/Xorg behavior and actual Linux account connections still require the smoke test below. GNOME theme, fonts and scaling can affect the final appearance.

## Features

- Separate Codex and Claude logo/percentage indicators. Either opens the shared provider panel.
- Remaining short-term/weekly quota, reset times and last successful update time. Failed refreshes keep the last successful quota and mark it with `!`.
- Independently expandable cards. One provider can be hidden; the last visible provider cannot be hidden. Layout adjusts naturally; long content scrolls within the screen.
- Configurable refresh interval from 1 to 10 minutes, default 5; manual refresh has a 30-second minimum. Claude rate limiting respects a minimum five-minute retry delay.
- Today and the previous six local calendar days: token total, USD API equivalent, a bar chart and daily date/token/cost rows. Token details can be hidden.
- Turkish, English, Spanish, Japanese, Simplified Chinese, German and French. Settings persist in GSettings. Reopen Preferences after changing language to translate that window.
- Claude limit queries require explicit consent. Local token counters can be displayed without connecting Claude.

## Requirements

A Linux GNOME desktop, GNOME Shell 45 or later in the declared target range, `/usr/bin/python3` version 3.10+, and the GNOME Extensions command line tool. No pip/npm dependencies are used at runtime. Preferences use GNOME's GTK 4 / libadwaita environment.

Codex CLI and/or Claude Code must already be installed and signed in on **that Linux machine**. The extension does not copy accounts from macOS or perform login. macOS Keychain credentials are not used on Linux.

For a source build, also install `glib-compile-schemas` (provided by `libglib2.0-bin` on Ubuntu/Debian or `glib2` on Fedora). Developer tests additionally require Node.js 18+.

## Install the ready ZIP

Run these commands in the folder containing the ZIP:

```sh
gnome-extensions install --force ai-limitshower@mermalat.shell-extension.zip
```

Log out and log back in so GNOME discovers the new extension, then enable it:

```sh
gnome-extensions enable ai-limitshower@mermalat
```

Open either top bar indicator, choose **Settings**, and configure the providers, language, token display and refresh interval. Expand the Claude card and choose **Enable Claude connection**, or enable it in Settings, to authorize a usage request. You can revoke this consent in Settings.

If Codex is installed through npm/NVM in a different directory, put its **absolute executable path** in the optional Codex CLI path setting and press Apply. The default search checks `~/.local/bin/codex`, `/usr/local/bin/codex`, and `/usr/bin/codex`. A typical path can be found with `command -v codex` in your terminal. Shell commands are never interpreted from this setting.

To verify the ZIP's SHA-256 checksum:

```sh
sha256sum -c SHA256SUMS.txt
```

## Install from the repository

From the repository root:

```sh
./gnome/install.sh
```

The installer builds the ZIP, backs up an existing installation beside its directory, installs it for the current user and attempts to enable it. It does not require sudo or change system files. Log out and back in if the indicators do not appear. The user installation is at `~/.local/share/gnome-shell/extensions/ai-limitshower@mermalat` (or the corresponding `XDG_DATA_HOME` path).

Build without installing:

```sh
python3 gnome/package.py
```

Outputs: `gnome/dist/ai-limitshower@mermalat.shell-extension.zip` and `gnome/dist/SHA256SUMS.txt`. The ZIP contains only extension code, assets, schema, translations, price table and license notices. It contains no accounts, credentials, personal usage logs or macOS binaries.

Disable or remove:

```sh
gnome-extensions disable ai-limitshower@mermalat
gnome-extensions uninstall ai-limitshower@mermalat
```

## Data and estimates

Codex quotas come from a short-lived `codex app-server` process using `initialize`, `initialized`, and `account/rateLimits/read`. It does not create model requests. Claude quotas use the current OAuth token from `~/.claude/.credentials.json`, sent only to `https://api.anthropic.com/api/oauth/usage`, with normal HTTPS certificate verification and redirects disabled. There is no token refresh/login implementation; an expired session must be renewed in Claude Code.

Weekly counters come from local JSONL logs:

- Codex: `$CODEX_HOME/sessions` and `$CODEX_HOME/archived_sessions`, defaulting to `~/.codex`.
- Claude: `$CLAUDE_CONFIG_DIR/projects`, defaulting to `~/.claude`.

The worker extracts usage counters and model identifiers, deduplicates copied Codex events and streamed Claude messages, and excludes guardian/automatic review events. Transcript bodies are not returned, uploaded or saved. A missing history is shown as unavailable; unknown model prices and unreadable relevant records are explicitly marked as incomplete. Deleted history cannot be recovered.

USD amounts are **estimated standard short-context API equivalents, not invoices or subscription charges**. Input, cached reads, output and Claude cache writes are priced separately. The model table is the macOS project's snapshot dated **October 12, 2026**; unsupported model tokens are counted but not priced. Long-context premiums, fast-mode pricing, regional pricing, tools, taxes, discounts and actual subscription billing are excluded. See the repository's [token accounting documentation](../docs/TOKEN_USAGE.md).

Settings contain preferences and an optional CLI path, never credentials. Disabling the extension removes timers, indicators and settings signal handlers, cancels pending workers, and terminates their Codex child process on Linux. Quota jobs and history scanning run outside the Shell process so log parsing does not block the desktop.

## Development and verification

```sh
./gnome/test.sh
```

This runs Python counter/RPC/consent tests, JavaScript translation/chart/provider tests, a Shell API double for enable/disable and stale callbacks, syntax checks, strict schema compilation and ZIP content verification. API doubles cannot validate actual GNOME rendering or API availability.

Before distributing this as a stable Linux release, test in each advertised GNOME version:

1. Install, log in, enable, and verify both logos and quota labels appear.
2. Open either indicator. Expand/collapse each card repeatedly; verify no overlapping labels/graphs and correct one-provider resizing. Check small screens and 200% scaling.
3. Sign in to Codex on Linux and verify quotas/reset times against the CLI. Check the optional CLI path with an NVM installation.
4. Confirm Claude remains disconnected initially. Grant consent and compare its quotas with Claude Code. Revoke consent and confirm the quota clears.
5. Check all seven languages, 1/10-minute intervals and saved settings after logging in again.
6. Hide either provider; ensure the final provider cannot be hidden. Hide token details and confirm charts disappear.
7. Compare the seven local dates and daily totals against known fixture logs. Verify missing history, unsupported prices and malformed rows show the expected notices.
8. Disconnect the network: old quotas must show `!` and a safe error. Disable the extension while updating: no indicator, timer or worker should survive. Re-enable it.
9. Repeat on Wayland and Xorg where supported, including more than one monitor.

Useful troubleshooting commands:

```sh
gnome-extensions info ai-limitshower@mermalat
gnome-extensions prefs ai-limitshower@mermalat
journalctl --user -b | rg 'ai-limitshower|GNOME Shell|JS ERROR'
```

If GNOME reports an unsupported Shell version, do not force compatibility without testing its API changes.

## Code map

| File | Purpose |
| --- | --- |
| `extension/extension.js` | Two indicators, expandable popup cards, timer and async worker lifecycle |
| `extension/prefs.js` | Provider/consent/token/language/refresh/path preferences |
| `extension/logic.js` | Translations, locale, provider guard and graph scaling |
| `extension/backend.py` | Read-only quota queries, local weekly aggregation and safe errors |
| `extension/stylesheet.css` | Dark card design and green/copper charts |
| `extension/translations.json` | Shared macOS translations plus GNOME settings labels |
| `extension/prices.json` | Dated USD API price snapshot |
| `extension/schemas/` | Persistent GSettings preferences |
| `package.py`, `install.sh`, `test.sh` | ZIP building, user installation and local verification |

Uses GNOME's [ES module extension structure](https://gjs.guide/extensions/overview/imports-and-modules.html), [async Gio subprocess API](https://gjs.guide/guides/gio/subprocesses.html) and [enable/disable lifecycle guidance](https://gjs.guide/extensions/review-guidelines/review-guidelines.html). The layout handles the [St orientation change introduced in GNOME 48](https://gjs.guide/extensions/upgrading/gnome-shell-48.html).

Source code is GPL-3.0-only. OpenAI and Anthropic logos remain their owners' trademarks; see [LICENSE](extension/LICENSE) and [third-party notices](extension/THIRD_PARTY_NOTICES.md). This is an independent project.
