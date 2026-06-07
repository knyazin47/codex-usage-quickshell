# Changelog

## 0.4.6

- Kept the Codex usage service alive from the bar indicator instead of only loading it with the popup.
- Reused proxy settings from the running Codex Desktop app-server when Quickshell starts with a minimal environment.

## 0.4.5

- Kept live-probe refresh compatible with Quickshell installs that do not accept typed QML function annotations.
- Applied the auto-probe behavior to the installed Quickshell config so the live panel can recover from `local` after Codex Desktop starts.

## 0.4.4

- Fixed live-limit refresh getting stuck on stale local session metadata when the Codex app server briefly returned an empty rate-limit payload.
- Made the refresh button bypass the short live-limit cache and retry immediately after an in-flight refresh.
- Made automatic refresh probe live limits again while the source is `local` or `stale`, so starting Codex Desktop later can switch the panel back to live data.

## 0.4.3

- Removed Apply / Cancel and made language and refresh interval apply immediately.
- Added a soft fade pulse when language changes so translated text swaps less abruptly.
- Updated the settings drawer to behave as a fully live control surface.

## 0.4.2

- Replaced the custom palette color chips with a continuous hue slider.
- Removed the extra custom palette preview strip.
- Made `show` toggles apply immediately and animate the main sections in and out.
- Replaced the source badge with a small status dot beside the `Codex Usage` title.

## 0.4.1

- Made palette selection, base color, and warm/cool temperature apply immediately while editing.
- Kept Apply / Cancel for non-palette settings only.
- Put the settings body in a scrollable area so custom palette controls no longer push Apply off-screen.

## 0.4.0

- Added a `custom` palette mode driven by one base color plus a warm/cool temperature slider.
- Kept the native Codex palette as a first-class preset for one-click reset.
- Made the main left usage gauge follow the selected palette in normal usage states.
- Removed the small Codex logo from the rail header and made the `Codex` title larger.
- Made live limit discovery more reliable when Quickshell starts with a minimal `PATH`.
- Added fallback error details to the limit source tooltip.

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
