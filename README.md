# Omarchy → Warp Theme Sync

Keep Warp Terminal in sync with the active [Omarchy](https://omarchy.org/) theme.

When you switch an Omarchy theme, this utility resolves its semantic palette,
creates a matching Warp custom theme, and selects it automatically. Warp
hot-reloads its settings, so already-open windows update without restarting.

## What it does

- Installs an Omarchy `theme-set` hook that runs after every theme switch.
- Converts the active theme's `colors.toml` to Warp's custom-theme YAML format.
- Covers the background, foreground, accent, cursor, light/dark mode, and all
  16 ANSI colors.
- Writes themes to Warp's standard Linux theme directory.
- Uses Warp's current `settings.toml` configuration and retains a legacy JSON
  fallback for older Warp versions.

## Requirements

- [Omarchy](https://omarchy.org/) with `omarchy-theme-color` available
  (Omarchy 4+ is the primary supported version).
- [Warp Terminal for Linux](https://www.warp.dev/).
- Bash, `awk`, `sed`, and standard GNU userland tools.

## Install

Clone the project somewhere permanent—the installed hook points back to this
checkout—then run the installer:

```bash
git clone https://github.com/sebastienb/omarchy-warp-theme-sync.git
cd omarchy-warp-theme-sync
./install.sh
```

The installer:

1. Installs `~/.config/omarchy/hooks/theme-set.d/warp-sync`.
2. Runs an initial conversion and applies the active Omarchy theme to Warp.

After that, use Omarchy normally. For example:

```bash
omarchy theme set tokyo-night
```

Warp will follow the theme switch automatically. Warp may take a few seconds
to discover its themes directory the first time it is created; subsequent
theme changes are applied live.

## Manual use

```bash
# Sync the currently active Omarchy theme
./sync_omarchy_theme.sh

# Regenerate the theme YAML even when it already exists
./sync_omarchy_theme.sh --force

# Convert and apply a particular installed Omarchy theme
./sync_omarchy_theme.sh tokyo-night

# Use from a hook or another script (errors only)
./sync_omarchy_theme.sh --force --quiet
```

The helper can also inspect or choose a theme directly:

```bash
./warp_theme_manager.sh current
./warp_theme_manager.sh list
./warp_theme_manager.sh set tokyo-night
```

## How it works

1. Reads the active theme from
   `~/.local/state/omarchy/current/theme.name`.
2. Resolves colors from the active theme's `colors.toml` with
   `omarchy-theme-color --all`.
3. Falls back to an Omarchy 2/3 theme symlink and `alacritty.toml` when
   necessary.
4. Saves the generated YAML under
   `${XDG_DATA_HOME:-~/.local/share}/warp-terminal/themes/`.
5. Sets Warp's theme in `~/.config/warp-terminal/settings.toml`, which Warp
   watches for live changes.

## Uninstall

```bash
./install.sh --uninstall
```

This removes only the Omarchy hook. Generated Warp theme files are kept, so
they remain available in Warp's theme picker; remove them manually if you no
longer want them.

## Troubleshooting

Run a verbose sync to see the detected theme and palette source:

```bash
./sync_omarchy_theme.sh --force
```

If the hook cannot find the script, reinstall it from the checkout you intend
to keep. If Warp does not show a custom theme immediately after first install,
wait briefly or restart Warp once; later changes are detected automatically.

## License

[MIT](LICENSE)
