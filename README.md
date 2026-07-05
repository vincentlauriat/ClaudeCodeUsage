# ClaudeCodeUsage

A native macOS app that visualizes local Claude Code usage — sessions, turns, tokens (input,
output, cache read/creation), and estimated cost — by scanning the JSONL transcripts Claude Code
writes under `~/.claude/projects/**`.

[Download the latest release](https://github.com/vincentlauriat/ClaudeCodeUsage/releases/latest) ·
[Landing page](https://vincentlauriat.github.io/ClaudeCodeUsage/)

## Features

- **Stat cards** — Sessions, Turns, Input Tokens, Output Tokens, Cache Read, Cache Creation,
  Est. Cost
- **Daily usage chart** — stacked bar chart of the last N days (Swift Charts)
- **Filters** — by model, and by date range (Today / This Week / This Month / Prev Month / 7d /
  30d / 90d / All)
- **Auto-refresh** — rescans every 30s (incremental — only reads newly appended transcript
  bytes), plus a manual **Rescan** button for a full re-read
- **Auto-update** — Sparkle-based, checks `appcast.xml` on launch and via "Check for Updates…"

## Requirements

- macOS 14+ (Sonoma)
- Claude Code installed and used at least once (so `~/.claude/projects` has transcripts)

## Installation

Download the latest `.dmg` from [Releases](https://github.com/vincentlauriat/ClaudeCodeUsage/releases/latest),
mount it, and drag **ClaudeCodeUsage.app** to `/Applications`. The app is signed with a Developer
ID certificate and notarized by Apple.

## Development

```bash
brew install xcodegen   # if not already installed
xcodegen generate
open ClaudeCodeUsage.xcodeproj
```

> `.xcodeproj` is not committed. `project.yml` is the source of truth — regenerate after each
> clone or after editing `project.yml`.

### Cutting a release

```bash
SIGNING_IDENTITY="Developer ID Application: …" ./Scripts/release.sh 1.0.1
gh release create v1.0.1 ./ClaudeCodeUsage-1.0.1.dmg --title "v1.0.1" --notes "…"
git add appcast.xml && git commit -m "release: appcast for v1.0.1" && git push
```

`Scripts/release.sh` builds, signs (Developer ID + Hardened Runtime), notarizes, staples,
packages the DMG, and Sparkle-signs it, writing `appcast.xml`. See `ARCHITECTURE_EN.md` for the
full pipeline.

## Notes

- Estimated cost uses an approximate per-model-family pricing table (no exact local pricing API
  exists) — see `ARCHITECTURE_EN.md` for the assumption and the rate table.
- The app does not sandbox itself: it needs unprompted read access to `~/.claude/projects`.
- Sparkle updates are signed with the EdDSA key shared across Vincent's macOS apps (Keychain
  account "MarkdownViewer") — never regenerate it.

## Roadmap
- [ ] Scan-cache persistence across app launches
- [ ] Editable pricing table from the UI
