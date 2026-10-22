#!/bin/bash
# Wire this project into Omarchy 4 so Warp follows every theme switch.
#  - installs the theme-set hook into ~/.config/omarchy/hooks/theme-set.d/
#  - runs an initial sync

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$HOME/.config/omarchy/hooks/theme-set.d"

if [[ "$1" == "--uninstall" ]]; then
    rm -f "$HOOKS_DIR/warp-sync"
    echo "✓ Removed Omarchy hook"
    exit 0
fi

if [[ ! -f $HOME/.local/state/omarchy/current/theme.name ]]; then
    echo "⚠ Omarchy 4 state not found (~/.local/state/omarchy/current/theme.name)."
    echo "  The hook will still be installed, but sync_omarchy_theme.sh needs Omarchy 4."
fi

chmod +x "$SCRIPT_DIR"/*.sh

mkdir -p "$HOOKS_DIR"
sed "s|__SYNC_SCRIPT__|$SCRIPT_DIR/sync_omarchy_theme.sh|" \
    "$SCRIPT_DIR/omarchy/theme-set.d-warp-sync" > "$HOOKS_DIR/warp-sync"
chmod +x "$HOOKS_DIR/warp-sync"
echo "✓ Installed hook: $HOOKS_DIR/warp-sync"

echo
"$SCRIPT_DIR/sync_omarchy_theme.sh" --force
