# ARCHITECTURE — ClaudeCodeUsage

## Overview
Native macOS SwiftUI app that scans local Claude Code JSONL transcripts and renders a usage
dashboard (sessions, turns, tokens, cache, estimated cost, daily stacked bar chart).

## Data source
Claude Code writes one append-only JSONL transcript per session at:
```
~/.claude/projects/<encoded-project-path>/<sessionId>.jsonl
```
Lines with `type == "assistant"` and a `message.usage` object carry the token counts we need:
`message.model`, `usage.input_tokens`, `usage.output_tokens`,
`usage.cache_creation_input_tokens`, `usage.cache_read_input_tokens`, plus `sessionId` and
`timestamp`. The app never writes to these files.

## Module layout
```
ClaudeCodeUsage/
  App/ClaudeCodeUsageApp.swift      entry point, single window
  Models/
    UsageEvent                      one assistant turn with usage
    DailyUsage                      per-day aggregate (chart)
    UsageSummary                    aggregate for stat cards
    DateRangeFilter                 Today/This Week/.../All
    ModelPricing                    per-model-family pricing table
  Services/
    TranscriptScanner               incremental scan of *.jsonl files
    PricingCalculator                cost estimation from UsageEvent list
  ViewModels/
    UsageViewModel                  filters, 30s auto-refresh, aggregation
  Views/
    ContentView, HeaderView, FilterBarView, StatCardView, DailyUsageChartView
```

## Scanning strategy
`~/.claude/projects` holds ~80 project directories with potentially hundreds of transcripts.
To keep 30s auto-refresh cheap:
- In-memory cache keyed by file path: `(mtime, bytesReadSoFar, parsedEvents)`
- Each scan only reads bytes appended since the last read (transcripts are append-only)
- The **Rescan** button clears the cache and forces a full re-read
- Scanning runs off the main thread (`Task` at `.utility` priority); results are published back
  via `@MainActor`

## Tech stack
- SwiftUI + Swift Charts (no external dependency needed for the MVP)
- macOS 14+ deployment target
- xcodegen: `project.yml` is the source of truth, `.xcodeproj` is regenerated and not committed
  (same convention as the sibling project `RTKInfos`)
- No App Sandbox — the app needs unprompted read access to `~/.claude/projects/**`

## Cost estimation — assumption
There is no local pricing API, so costs are estimated from a per-model-family rate table
(input / output / cache-write / cache-read per million tokens), using Anthropic's known pricing
ratios (output ≈ 5× input, cache write ≈ 1.25× input, cache read ≈ 0.1× input). See
`PLAN.md` for the exact table. Unknown models fall back to Sonnet-tier rates. The table lives in
`ModelPricing.swift` so it can be corrected without touching the rest of the app.

## Chart — deliberate simplification
The reference screenshot shows two mismatched Y axes (Cache in millions, Input/Output in
hundreds of thousands) applied to a *single* stacked bar — which has no consistent mathematical
meaning. The MVP renders one consistent Y axis (auto-formatted K/M) for all four stacked series.
A true dual-axis overlay can be added later if requested.

## Out of scope (MVP)
- Code signing / notarization / DMG packaging (standard repo pipeline, only on explicit request)
- Sparkle auto-update
- Scan-cache persistence across app launches
- Exact dual-axis chart rendering
- In-app editable pricing table
