> **Note.** This build is not yet advertised to Sparkle: `appcast.xml` still points at v1.3.0, so
> existing installs will not be offered the update automatically for now. Download the DMG below
> to get it. The feed will be updated shortly.

## Fixed

- **Sessions per week — weekly total.** The footer summed the per-weekday counts, but each day is
  deduplicated on its own, so a session spanning midnight was counted twice. With a full week of
  activity it read 40 for 29 distinct sessions — a 38% overcount, visibly inconsistent with the
  SESSIONS figure right above it. The total is now deduplicated over the whole 7-day window.
  The per-weekday chart is unchanged: a session active on two days does belong in both bars.

## Internal

- `Scripts/release.sh` now publishes the GitHub release and pushes `appcast.xml` itself, and
  preflights everything that can invalidate a release — including that `CURRENT_PROJECT_VERSION`
  exceeds the published `sparkle:version`, since Sparkle compares `CFBundleVersion` and a
  marketing-only bump would ship an update nobody is offered.
- Landing page honours `prefers-reduced-motion`.
