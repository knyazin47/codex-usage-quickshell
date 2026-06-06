# Codex Usage for Quickshell

Codex Usage is a Quickshell module for the `ii` / illogical-impulse style Hyprland bar. It shows a compact top-bar indicator plus a smooth click-open usage panel for Codex usage and limits.

The module is Codex-only. It does not read Claude projects or cloud billing pages.

## Features

- Top-bar `Codex` indicator with theme-aware icon.
- Click-open popup in the visual style of the system panel.
- Local token totals for today, week, last turn, input, cached input, output, and reasoning tokens.
- Live 5-hour and weekly limit cards from the local Codex app server, with cache and local session-log fallback.
- Source badge for limit freshness: `live`, `cache`, `stale`, or `local`.
- Activity bars for the last 18 hours.
- Smooth loading skeletons and animated value changes instead of full visual resets on refresh.
- Settings drawer with staged changes, palette presets, generated custom palette, and Apply / Cancel.
- Live light/dark theme following `gsettings org.gnome.desktop.interface color-scheme`.
- Collector pauses when the module is disabled in config.

## Requirements

- Quickshell with a config using the `qs.modules.common`, `qs.services`, and `qs.modules.ii.bar` import layout.
- Python 3.10+.
- Codex Desktop or Codex CLI writing session files under `~/.codex/sessions`.
- `codex` on `PATH` or in a common user install path for live account limits. The collector falls back to cached or local session metadata when unavailable.
- Optional: `gsettings` for live system light/dark detection.

## Install

```bash
git clone https://github.com/knyazin47/codex-usage-quickshell.git
cd codex-usage-quickshell
./install.sh
```

The installer copies the module files into:

```text
~/.config/quickshell/ii/modules/ii/bar/codexUsage
~/.config/quickshell/ii/services
~/.config/quickshell/ii/scripts/codex-usage
~/.config/quickshell/ii/assets/icons
```

Then add the import to `~/.config/quickshell/ii/modules/ii/bar/BarContent.qml`:

```qml
import qs.modules.ii.bar.codexUsage
```

Place the indicator where you want it in the bar. A good spot is near system resources and media:

```qml
CodexUsageIndicator {
    visible: Config.options.bar.codexUsage.enable && root.useShortenedForm < 2
    Layout.leftMargin: 6
}
```

Add the config object under `Config.options.bar` in `~/.config/quickshell/ii/modules/common/Config.qml`:

```qml
property JsonObject codexUsage: JsonObject {
    property bool enable: true
    property string language: "auto" // auto, ru, en
    property bool showActivity: true
    property bool showTokenBreakdown: true
    property bool showDetailedLimits: true
    property int refreshInterval: 15 // seconds
    property string accentStyle: "codex" // codex, violet, mint, rose, clean, custom
    property int customAccentHue: 220 // 0-360
    property string customAccentBase: "#86a8ff"
    property int customAccentTemperature: 0 // -100 cool, 0 balanced, 100 warm
}
```

Reload Quickshell:

```bash
qs -c ii -d
```

## Privacy

The collector reads local Codex session JSONL files in `~/.codex/sessions` for token totals. By default it also asks the local Codex app server for the current account rate-limit snapshot, so limits stay fresh after mobile usage or reset windows.

Live limit snapshots are cached under:

```text
${XDG_CACHE_HOME:-~/.cache}/codex-usage-quickshell/rate_limits.json
```

Disable live limit refresh if you want local-only behavior:

```bash
CODEX_USAGE_LIVE_LIMITS=0 ~/.config/quickshell/ii/scripts/codex-usage/codex_usage.py
```

Workspace names are not collected by default. Enable them explicitly only if you want that data:

```bash
CODEX_USAGE_INCLUDE_WORKSPACE=1 ~/.config/quickshell/ii/scripts/codex-usage/codex_usage.py
```

If you publish screenshots, remember that aggregate token counts may be visible.

## Tuning

The collector defaults to scanning the last 8 days of session files. You can override this for debugging:

```bash
CODEX_USAGE_DAYS=14 ~/.config/quickshell/ii/scripts/codex-usage/codex_usage.py
```

Archived sessions are skipped by default to keep refreshes light. Include them explicitly:

```bash
CODEX_USAGE_INCLUDE_ARCHIVED=1 ~/.config/quickshell/ii/scripts/codex-usage/codex_usage.py
```

Large session histories can be expensive to scan frequently. The UI defaults to 15 seconds and clamps refresh values to at least 5 seconds. Live limit refresh has a short timeout and falls back to cached or local session metadata if the Codex app server cannot respond.

Live limit cache timing can be tuned:

```bash
CODEX_USAGE_LIVE_CACHE_SECONDS=60 ~/.config/quickshell/ii/scripts/codex-usage/codex_usage.py
CODEX_USAGE_LIVE_STALE_SECONDS=900 ~/.config/quickshell/ii/scripts/codex-usage/codex_usage.py
```

## License

MIT
