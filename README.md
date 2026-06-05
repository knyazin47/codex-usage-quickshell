# Codex Usage for Quickshell

Codex Usage is a Quickshell module for the `ii` / illogical-impulse style Hyprland bar. It reads local Codex session logs from `~/.codex/sessions` and shows a compact top-bar indicator plus a smooth click-open usage panel.

The module is Codex-only. It does not read Claude projects or cloud billing pages.

## Features

- Top-bar `Codex` indicator with theme-aware icon.
- Click-open popup in the visual style of the system panel.
- Local token totals for today, week, last turn, input, cached input, output, and reasoning tokens.
- 5-hour and weekly limit cards when limit metadata is available in local Codex session records.
- Activity bars for the last 18 hours.
- Smooth loading skeletons and animated value changes instead of full visual resets on refresh.
- Settings drawer with staged changes and Apply / Cancel.
- Live light/dark theme following `gsettings org.gnome.desktop.interface color-scheme`.
- Collector pauses when the module is disabled in config.

## Requirements

- Quickshell with a config using the `qs.modules.common`, `qs.services`, and `qs.modules.ii.bar` import layout.
- Python 3.10+.
- Codex Desktop or Codex CLI writing session files under `~/.codex/sessions`.
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
    property string accentStyle: "codex" // codex, violet, clean
}
```

Reload Quickshell:

```bash
qs -c ii -d
```

## Privacy

The collector reads local Codex session JSONL files in `~/.codex/sessions`. It emits numeric usage aggregates to Quickshell and does not send data over the network.

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

Large session histories can be expensive to scan frequently. The UI defaults to 15 seconds and clamps refresh values to at least 5 seconds.

## License

MIT
