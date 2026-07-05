# ClaudeCodeUsage

A native macOS app that visualizes local Claude Code usage — sessions, turns, tokens (input,
output, cache read/creation), and estimated cost — by scanning the JSONL transcripts Claude Code
writes under `~/.claude/projects/**`.

## Features

- **Stat cards** — Sessions, Turns, Input Tokens, Output Tokens, Cache Read, Cache Creation,
  Est. Cost
- **Daily usage chart** — stacked bar chart of the last N days (Swift Charts)
- **Filters** — by model, and by date range (Today / This Week / This Month / Prev Month / 7d /
  30d / 90d / All)
- **Auto-refresh** — rescans every 30s (incremental — only reads newly appended transcript
  bytes), plus a manual **Rescan** button for a full re-read

## Requirements

- macOS 14+ (Sonoma)
- Claude Code installed and used at least once (so `~/.claude/projects` has transcripts)

## Development

```bash
brew install xcodegen   # if not already installed
xcodegen generate
open ClaudeCodeUsage.xcodeproj
```

> `.xcodeproj` is not committed. `project.yml` is the source of truth — regenerate after each
> clone or after editing `project.yml`.

## Notes

- Estimated cost uses an approximate per-model-family pricing table (no exact local pricing API
  exists) — see `ARCHITECTURE_EN.md` for the assumption and the rate table.
- The app does not sandbox itself: it needs unprompted read access to `~/.claude/projects`.

## Roadmap
- [ ] Code signing / notarization / DMG release pipeline
- [ ] Sparkle auto-update
