# ClaudeCodeUsage

A native macOS app that visualizes local Claude Code usage — sessions, turns, tokens (input,
output, cache read/creation), and estimated cost — by scanning the JSONL transcripts Claude Code
writes under `~/.claude/projects/**`.

[Download the latest release](https://github.com/vincentlauriat/ClaudeCodeUsage/releases/latest) ·
[Landing page](https://vincentlauriat.github.io/ClaudeCodeUsage/)

## Features

- **Stat cards** — Sessions, Turns, Input Tokens, Output Tokens, Cache Read, Cache Creation,
  Est. Cost
- **Daily usage chart** — dual Y-axis stacked bar chart of the last N days (Cache on a left
  "millions" axis, Input/Output on a right "hundreds of thousands" axis, Swift Charts)
- **Comparison card grid** — sessions-per-week and cost-per-hour trend charts (this
  week/today vs. last week/yesterday), an automatic Insights & Alerts panel (cost swings,
  models missing dedicated pricing, cache hit rate), and a per-model-family cost mix bar
- **Filters** — by model, by project (working directory), and by date range (Today / This Week /
  This Month / Prev Month / 7d / 30d / 90d / All)
- **Breakdown panel** — cost/token table by Project, Agent, or Skill (switchable), sorted by cost
- **Sessions list** — named sessions (from Claude Code's auto-generated title/slug), most recent
  first, with a click-through detail sheet (per-model breakdown, time range)
- **Editable pricing** — gear button opens a per-model-family rate editor (persisted), so Est.
  Cost stays accurate if Anthropic changes prices
- **Auto-refresh** — rescans every 30s (incremental — only reads newly appended transcript
  bytes), plus a manual **Rescan** button for a full re-read. The scan cache is persisted to disk,
  so relaunching the app doesn't have to re-parse transcripts it already read
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
  exists), editable from the app's Pricing sheet — see `ARCHITECTURE_EN.md` for the default rates.
- The app does not sandbox itself: it needs unprompted read access to `~/.claude/projects`.
- Sparkle updates are signed with the EdDSA key shared across Vincent's macOS apps (Keychain
  account "MarkdownViewer") — never regenerate it.
- The `ClaudeCodeUsageTests` target currently can't run in this dev environment (a pre-existing
  test-runner crash, unrelated to app code) — see `TODOS.md`.
