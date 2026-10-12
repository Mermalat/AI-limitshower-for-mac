# Claude & Codex Limits for GNOME 1.0.0-alpha.1

First GNOME Shell top bar pre-release, distributed separately from the macOS application.

## Features

- Separate Codex and Claude logo indicators with remaining quota percentages.
- Dark expandable provider cards, short-term/weekly quotas and local reset times.
- Last seven local calendar days of token usage, daily bar charts and estimated USD API equivalents.
- Show or hide either provider while keeping at least one visible; optionally hide token details.
- Saved 1–10 minute refresh interval, manual refresh and rate-limit backoff.
- Turkish, English, Spanish, Japanese, Simplified Chinese, German and French.
- Explicit opt-in for Claude usage queries; local history processing and no bundled accounts.

## Install

Requires a Linux GNOME desktop and `/usr/bin/python3` 3.10+. GNOME Shell 45–51 are declared targets, **not a tested compatibility matrix**. Codex CLI / Claude Code must be installed and signed in separately on Linux.

Download `ai-limitshower@mermalat.shell-extension.zip` and run:

```sh
gnome-extensions install --force ai-limitshower@mermalat.shell-extension.zip
```

Log out and back in, then enable:

```sh
gnome-extensions enable ai-limitshower@mermalat
```

Open either indicator and choose Settings. If Codex was installed via npm/NVM, set its absolute executable path there. Claude starts disconnected and requires explicit consent before sending its existing session token to Anthropic's fixed usage endpoint.

[Full installation and troubleshooting guide](https://github.com/Mermalat/AI-limitshower-for-mac/blob/gnome-v1.0.0-alpha.1/gnome/README.md)

## Files and license

- `ai-limitshower@mermalat.shell-extension.zip`: installable GNOME extension, compiled settings schema, assets and runtime source.
- `SHA256SUMS.txt`: SHA-256 integrity checksum; verify with `sha256sum -c SHA256SUMS.txt`.
- GitHub's source archives include the matching sources, installer, build script and tests.

Project code is licensed under **GPL-3.0-only**. OpenAI/Anthropic logos remain their owners' trademarks and are covered by the third-party notices, not the project code license.

## Validation and known limits

All **16 automated tests passed**, along with JavaScript syntax checks, strict GSettings schema compilation and ZIP content verification. Tests cover token aggregation, cache pricing, deduplication, consent, provider visibility, translations and worker cleanup; Shell lifecycle tests use API doubles.

**This alpha has not yet been run in a real GNOME session.** Actual rendering, version compatibility, Linux provider connections, scaling and Wayland/Xorg behavior remain unverified. Theme and font differences may affect visual parity. It is not published to extensions.gnome.org.

USD values use the project's October 12, 2026 standard API price snapshot. They are estimated API equivalents, **not invoices or subscription charges**; unknown model prices are flagged as incomplete.
