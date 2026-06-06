# Changelog

## 0.3.0

- Added a live limit cache so short UI refresh intervals do not start the Codex app server on every tick.
- Added `live`, `cache`, `stale`, and `local` source labels for limit freshness.
- Added `CODEX_USAGE_LIVE_CACHE_SECONDS` and `CODEX_USAGE_LIVE_STALE_SECONDS` tuning knobs.
- Expanded the accent setting into palette swatches with `mint` and `rose` presets.
- Added richer comments around live-limit cache behavior to make maintenance easier.

## 0.2.0

- Added live Codex account rate-limit refresh through the local Codex app server.
- Added local reset-window correction so expired session metadata no longer keeps stale low remaining percentages.
- Documented `CODEX_USAGE_LIVE_LIMITS=0` for local-only limit metadata.

## 0.1.0

- Initial public module package.
- Added Codex-only local usage collector.
- Added Quickshell service, top-bar indicator, popup card, theme watcher, and installer.
