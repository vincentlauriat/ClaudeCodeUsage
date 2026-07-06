# ARCHITECTURE — ClaudeCodeUsage

## Overview
Native macOS SwiftUI app that scans local Claude Code JSONL transcripts and renders a usage
dashboard (sessions, turns, tokens, cache, editable estimated cost, a daily dual-Y-axis chart),
with a project filter, a cost breakdown by project/agent/skill, and a named sessions list with
detail. The scan cache is persisted across launches.

## Data source
Claude Code writes one append-only JSONL transcript per session at:
```
~/.claude/projects/<encoded-project-path>/<sessionId>.jsonl
~/.claude/projects/<encoded-project-path>/<sessionId>/subagents/agent-*.jsonl   (sub-agents)
```
Lines with `type == "assistant"` and a `message.usage` object carry the token counts we need:
`message.model`, `usage.input_tokens`, `usage.output_tokens`,
`usage.cache_creation_input_tokens`, `usage.cache_read_input_tokens`, plus `sessionId`,
`timestamp`, `cwd` (real working directory), and — only on sub-agent turns —
`attributionAgent`/`attributionSkill`. Standalone `type: "ai-title"` lines (`{aiTitle,
sessionId}`) and the `slug` field (present on various lines in the main session file) give each
session a human-readable name. The app never writes to these files.

## Module layout
```
ClaudeCodeUsage/
  App/ClaudeCodeUsageApp.swift      entry point, single window
  Models/
    UsageEvent                      one assistant turn with usage (+ cwd, agent/skill attribution)
    DailyUsage                      per-day aggregate (chart)
    UsageSummary                    aggregate for stat cards
    DateRangeFilter                 Today/This Week/.../All
    ModelPricing                    the 4 rates (input/output/cache write/cache read) + cost formula
    PricingSettings                 the 4 pricing tiers, editable, persisted in UserDefaults
    SessionInfo                     a session's title/slug/cwd (metadata not on every line)
    SessionSummary                  per-session aggregate (sessions list)
    BreakdownDimension / BreakdownRow  breakdown by project / agent / skill
  Services/
    TranscriptScanner               incremental scan of *.jsonl files (events + SessionInfo),
                                     cache persisted to disk across launches
    PricingCalculator                cost estimation from UsageEvent list + PricingSettings
  ViewModels/
    UsageViewModel                  filters (model/project/range), 30s auto-refresh, aggregation,
                                     dimension breakdown, sessions, editable pricing
  Views/
    ContentView, HeaderView, FilterBarView, StatCardView, DailyUsageChartView,
    BreakdownView, SessionsListView, SessionDetailView, PricingSettingsView
```

## Scanning strategy
`~/.claude/projects` holds ~80 project directories with potentially hundreds of transcripts.
To keep 30s auto-refresh cheap:
- In-memory cache keyed by file path: `(mtime, bytesReadSoFar, parsedEvents)`
- Each scan only reads bytes appended since the last read (transcripts are append-only)
- The **Rescan** button clears the cache (memory + disk) and forces a full re-read
- Scanning runs off the main thread (`Task` at `.utility` priority); results are published back
  via `@MainActor`
- **Persisted across launches**: the cache (`[String: FileState]` + `[String: SessionInfo]`) is
  serialized to JSON at `~/Library/Application Support/ClaudeCodeUsage/scan-cache.json`, loaded
  lazily on the process's first scan and rewritten only when at least one file actually had new
  bytes read — an auto-refresh with no new activity writes nothing. This avoids re-parsing
  already-seen JSON, but doesn't eliminate directory-enumeration cost (a `stat()` per file is
  still needed on every scan to detect changes).

## Tech stack
- SwiftUI + Swift Charts (no external dependency needed for the MVP)
- macOS 14+ deployment target
- xcodegen: `project.yml` is the source of truth, `.xcodeproj` is regenerated and not committed
  (same convention as the sibling project `RTKInfos`)
- No App Sandbox — the app needs unprompted read access to `~/.claude/projects/**`

## Cost estimation — editable pricing
There is no local pricing API, so costs are estimated from a per-model-family rate table
(input / output / cache-write / cache-read per million tokens), originally based on Anthropic's
known pricing ratios (output ≈ 5× input, cache write ≈ 1.25× input, cache read ≈ 0.1× input) —
see `PricingSettings.default` for the values. Unknown models fall back to Sonnet-tier rates.
These rates are now **editable from the UI** (`PricingSettingsView`, opened via the header's
gear button) and persisted in `UserDefaults`: Vincent can correct them himself if Anthropic
publishes different rates, without waiting for an app update.

## Chart — dual Y axis (faithful replica of the original screenshot)
The reference screenshot shows two mismatched Y axes (Cache in millions, Input/Output in
hundreds of thousands) applied to a *single* stacked bar — which has no consistent mathematical
meaning (the MVP originally simplified to one axis for exactly this reason). Per Vincent's
explicit request, `DailyUsageChartView` now faithfully reproduces that dual axis: all 4 series
are normalized onto a shared 0...1 scale, each divided by the max of *its own* axis group
(`cacheMax` for Cache Read/Creation, `ioMax` for Input/Output — `UsageSeries.isCacheAxis`), then
two sets of `AxisMarks` (`.leading` formatted via `cacheMax`, `.trailing` formatted via `ioMax`)
are drawn at the same fractions `[0, .25, .5, .75, 1]`. The result visually matches the original
capture but keeps the same intentional mathematical inconsistency.

## Release pipeline (signing, notarization, Sparkle)
`Scripts/release.sh` (adapted from the sibling project RTKInfos' template) does, given a version:
1. Checks `project.yml`'s `MARKETING_VERSION` matches, regenerates the Xcode project.
2. Builds Release with `CODE_SIGNING_ALLOWED=NO` (works around a macOS Sequoia+ xattr that
   breaks `codesign --force` right after an Xcode build), then stages the built app via
   `ditto --noextattr` to strip those attributes.
3. Codesigns depth-first with Hardened Runtime: `Sparkle.framework`'s nested `Autoupdate`,
   `Downloader.xpc`, `Installer.xpc`, `Updater.app`, the framework itself, then the app.
4. Packages a DMG with a Finder icon-view layout (app + `/Applications` alias).
5. Submits to Apple's notary service (`xcrun notarytool`, keychain profile
   `AppliMacVincentGithub`, shared across Vincent's apps) and staples the ticket.
6. Signs the DMG with the Sparkle EdDSA key (`sign_update --account MarkdownViewer` — this app
   reuses the key shared across Vincent's macOS apps rather than minting its own) and writes
   `appcast.xml` at the repo root, served via `raw.githubusercontent.com`.

`SUFeedURL`/`SUPublicEDKey` live in `Info.plist`; `AppDelegate` (via
`@NSApplicationDelegateAdaptor`) wires `SPUStandardUpdaterController` and a "Check for
Updates…" menu item. **Never regenerate the Sparkle key** — it would break auto-update for every
app sharing it.

## Out of scope
- A Sparkle EdDSA key dedicated to this app (currently shares "MarkdownViewer"'s, an explicit
  choice — trades trust isolation between apps for simpler key management)
- Running the `ClaudeCodeUsageTests` target (pre-existing test-runner crash, `More than one
  NSApplication instance was created` — see `TODOS.md`)
