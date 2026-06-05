#!/usr/bin/env bash
set -euo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
TARGET="$CONFIG_HOME/quickshell/ii"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -d "$TARGET" ]]; then
  echo "Quickshell ii config was not found at: $TARGET" >&2
  echo "Set XDG_CONFIG_HOME or copy the files manually." >&2
  exit 1
fi

install -d "$TARGET/modules/ii/bar/codexUsage"
install -d "$TARGET/services"
install -d "$TARGET/scripts/codex-usage"
install -d "$TARGET/assets/icons"

install -m 0644 "$SOURCE_DIR/modules/ii/bar/codexUsage/"*.qml "$TARGET/modules/ii/bar/codexUsage/"
install -m 0644 "$SOURCE_DIR/services/"*.qml "$TARGET/services/"
install -m 0755 "$SOURCE_DIR/scripts/codex-usage/codex_usage.py" "$TARGET/scripts/codex-usage/codex_usage.py"
install -m 0644 "$SOURCE_DIR/assets/icons/codex-color.svg" "$TARGET/assets/icons/codex-color.svg"
install -m 0644 "$SOURCE_DIR/assets/icons/codex-cloud.svg" "$TARGET/assets/icons/codex-cloud.svg"

cat <<'MSG'
Codex Usage files installed.

Next manual steps:
1. Add this import to modules/ii/bar/BarContent.qml:
   import qs.modules.ii.bar.codexUsage

2. Add CodexUsageIndicator where you want it in the bar:
   CodexUsageIndicator {
       visible: Config.options.bar.codexUsage.enable && root.useShortenedForm < 2
       Layout.leftMargin: 6
   }

3. Add Config.options.bar.codexUsage from README.md if it is not present yet.

4. Reload:
   qs -c ii -d
MSG
