# Omarchy to Warp Theme Sync

Automatically sync your Omarchy theme changes with Warp Terminal on Linux.

## Overview

This project provides a seamless way to sync your active Omarchy theme with Warp Terminal. When you change themes in Omarchy, simply run the sync script to apply the same theme in Warp with all the correct colors extracted from Omarchy's alacritty configuration.

## ✨ Features

- 🎨 **Automatic Theme Detection** - Detects your active Omarchy theme
- 🔄 **Smart Conversion** - Converts Omarchy alacritty themes to Warp format on-demand
- 🎯 **Perfect Color Mapping** - Extracts all colors from alacritty.toml files
- 🚀 **One-Command Sync** - Single script does everything
- 💾 **Safe Operations** - Automatic backups before changes
- 🎨 **Custom Theme Support** - Handles custom themes with proper path mapping

## Quick Start

### 1. Clone the Repository
```bash
git clone <repo-url>
cd omarchy-warp
```

### 2. Make Scripts Executable
```bash
chmod +x *.sh
```

### 3. Sync Your Theme
```bash
./sync_omarchy_theme.sh
```

That's it! Your active Omarchy theme is now applied to Warp Terminal.

## Usage

### Basic Sync
```bash
# Sync active Omarchy theme to Warp
./sync_omarchy_theme.sh
```

### Theme Management
```bash
# List available themes
./warp_theme_manager.sh list

# Set a specific theme
./warp_theme_manager.sh set "theme_name"

# Show current theme
./warp_theme_manager.sh current
```

### Automation Ideas

#### Add to Shell Startup
Add to your `.bashrc` or `.zshrc` for automatic sync:
```bash
# Auto-sync Omarchy theme to Warp on terminal start
~/path/to/omarchy-warp/sync_omarchy_theme.sh
```

#### Create an Alias
```bash
# Add to your shell config
alias sync-theme='~/path/to/omarchy-warp/sync_omarchy_theme.sh'

# Then just run:
sync-theme
```

#### File Watcher (Advanced)
Use `inotifywait` to automatically sync when Omarchy theme changes:
```bash
#!/bin/bash
# Watch for Omarchy theme changes
inotifywait -m -e modify ~/.config/omarchy/current/theme |
while read path action file; do
    ~/path/to/omarchy-warp/sync_omarchy_theme.sh
done
```

## How It Works

### The Magic Behind the Sync

1. **📍 Theme Detection**: Reads the symlink at `~/.config/omarchy/current/theme` to find your active theme
2. **🎨 Color Extraction**: Parses `alacritty.toml` files to extract all terminal colors
3. **🔧 Smart Conversion**: Converts Omarchy theme format to Warp YAML format
4. **📁 Installation**: Places the theme in Warp's themes directory
5. **⚡ Activation**: Updates Warp config with the Custom theme format

### Theme Conversion Details

The sync script intelligently converts themes by:
- **Primary Colors**: Background, foreground from `[colors.primary]` section
- **Terminal Colors**: All 16 colors (8 normal + 8 bright) from `[colors.normal]` and `[colors.bright]`
- **Cursor Color**: Uses cursor color if defined, otherwise falls back to foreground
- **Smart Fallbacks**: Provides sensible defaults for missing colors

## Project Structure

```
omarchy-warp/
├── sync_omarchy_theme.sh      # 🎯 Main sync script (all-in-one)
├── warp_theme_manager.sh      # 🔧 Advanced theme management
├── themes/                    # 📁 Generated Warp theme files
│   ├── everforest.yaml
│   ├── gruvbox.yaml
│   └── ...
└── README.md                  # 📖 This file
```

## Script Details

### sync_omarchy_theme.sh ⭐
**The main script that does everything**

```bash
# Basic usage
./sync_omarchy_theme.sh

# Show help
./sync_omarchy_theme.sh --help
```

**What it does:**
- Detects your active Omarchy theme automatically
- Converts the theme to Warp format (only when needed)
- Installs the theme to Warp's themes directory
- Sets the theme as active in Warp configuration
- Handles all color parsing and validation
- Provides colored output with clear status messages

### warp_theme_manager.sh 🔧
**Advanced theme management utility**

```bash
# Available commands
./warp_theme_manager.sh list              # List all themes
./warp_theme_manager.sh current           # Show current theme  
./warp_theme_manager.sh set "theme_name"  # Set specific theme
./warp_theme_manager.sh install-repo      # Install official themes
```

**Features:**
- Supports both built-in and custom themes
- Proper Custom theme format handling (required for custom themes)
- Automatic SystemTheme disabling for custom themes
- Theme discovery and listing
- Official Warp themes repository integration

## Theme Format

Generated Warp themes follow this structure:
```yaml
name: theme_name
accent: '#color'
cursor: '#color' 
background: '#color'
foreground: '#color'
details: darker  # or "lighter"
terminal_colors:
  bright:
    black: '#color'
    red: '#color'
    # ... 6 more bright colors
  normal:
    black: '#color' 
    red: '#color'
    # ... 6 more normal colors
```

## Requirements

- **Warp Terminal** (Linux version)
- **Omarchy** theme manager with alacritty integration
- **Bash** shell
- **Optional**: `jq` for better JSON handling (fallback to `sed`)

## Configuration Paths

The scripts work with these standard paths:
- **Omarchy active theme**: `~/.config/omarchy/current/theme`
- **Omarchy themes**: `~/.config/omarchy/themes/`
- **Warp config**: `~/.config/warp-terminal/user_preferences.json`
- **Warp themes**: `~/.local/share/warp-terminal/themes/`

## Troubleshooting

### Theme Not Syncing
```bash
# Check if Omarchy theme symlink exists
ls -la ~/.config/omarchy/current/theme

# Manually run sync with verbose output
./sync_omarchy_theme.sh
```

### Colors Look Wrong
The script prioritizes alacritty.toml files. Make sure your Omarchy theme includes properly formatted alacritty configuration.

### Warp Not Recognizing Theme
- Restart Warp Terminal after theme changes
- Ensure SystemTheme is disabled in Warp settings
- Check that the theme file exists in `~/.local/share/warp-terminal/themes/`

### Permission Issues
```bash
# Make scripts executable
chmod +x *.sh

# Check directory permissions
ls -la ~/.config/warp-terminal/
```

## Contributing

Ideas for enhancements:
- Integration with system dark/light mode detection
- Support for more terminal color formats
- Theme preview generation
- Automatic theme switching based on time of day

## License

MIT License - Use and modify freely.

## Links

- [Warp Terminal](https://www.warp.dev/)
- [Omarchy Theme Manager](https://github.com/eeasuper/omarchy)
- [Official Warp Themes](https://github.com/warpdotdev/themes)