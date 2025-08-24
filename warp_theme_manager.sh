#!/bin/bash

# Advanced Warp Theme Manager
# Usage: 
#   ./warp_theme_manager.sh list           # List available themes
#   ./warp_theme_manager.sh set "ThemeName" # Set theme
#   ./warp_theme_manager.sh current        # Show current theme

WARP_CONFIG="/home/sebs/.config/warp-terminal/user_preferences.json"
WARP_THEMES_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/warp-terminal/themes"

show_usage() {
    echo "Warp Theme Manager"
    echo "Usage:"
    echo "  $0 list                    # List available themes"
    echo "  $0 set \"Theme Name\"        # Set theme"
    echo "  $0 current                 # Show current theme"
    echo "  $0 install-repo            # Install official themes repo"
    echo "  $0 install-omarchy         # Install converted omarchy themes"
    echo "  $0 sync-omarchy            # Sync active omarchy theme to warp"
}

get_current_theme() {
    if [ -f "$WARP_CONFIG" ]; then
        if command -v jq &> /dev/null; then
            jq -r '.prefs.Theme // "Not set"' "$WARP_CONFIG" | sed 's/^"\(.*\)"$/\1/'
        else
            grep '"Theme"' "$WARP_CONFIG" | sed 's/.*"Theme": "\\\\\"\(.*\)\\\\\\"".*/\1/'
        fi
    else
        echo "Config file not found"
    fi
}

list_available_themes() {
    echo "Available themes:"
    echo "Built-in themes:"
    echo "  - Dark"
    echo "  - Light"
    echo "  - Dracula"
    echo "  - And others..."
    echo ""
    
    if [ -d "$WARP_THEMES_DIR" ]; then
        echo "Custom themes in $WARP_THEMES_DIR:"
        find "$WARP_THEMES_DIR" -name "*.yaml" -o -name "*.yml" | while read -r theme_file; do
            theme_name=$(basename "$theme_file" .yaml)
            theme_name=$(basename "$theme_name" .yml)
            # Try to extract the actual theme name from the YAML
            if command -v grep &> /dev/null; then
                actual_name=$(grep "^name:" "$theme_file" 2>/dev/null | sed 's/^name: *\(.*\)$/\1/' | tr -d '"'"'"'')
                if [ -n "$actual_name" ]; then
                    echo "  - $actual_name (file: $theme_name)"
                else
                    echo "  - $theme_name"
                fi
            else
                echo "  - $theme_name"
            fi
        done
    else
        echo "No custom themes directory found. Run '$0 install-repo' to install official themes."
    fi
}

set_theme() {
    local theme_name="$1"
    
    if [ -z "$theme_name" ]; then
        echo "Error: Theme name not provided"
        show_usage
        exit 1
    fi
    
    if [ ! -f "$WARP_CONFIG" ]; then
        echo "Error: Warp config file not found at $WARP_CONFIG"
        exit 1
    fi
    
    # Backup config
    cp "$WARP_CONFIG" "$WARP_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Check if this is a custom theme (has a yaml file)
    local theme_path="${WARP_THEMES_DIR}/${theme_name}.yaml"
    if [ ! -f "$theme_path" ]; then
        theme_path="${WARP_THEMES_DIR}/${theme_name}.yml"
    fi
    
    # Set theme
    if [ -f "$theme_path" ]; then
        # Custom theme - use the new format with path
        echo "Setting custom theme to: $theme_name"
        if command -v jq &> /dev/null; then
            jq --arg name "$theme_name" --arg path "$theme_path" \
                '.prefs.Theme = "{\"Custom\":{\"name\":\"" + $name + "\",\"path\":\"" + $path + "\"}}" | 
                 .prefs.SystemTheme = "false"' \
                "$WARP_CONFIG" > "${WARP_CONFIG}.tmp" && mv "${WARP_CONFIG}.tmp" "$WARP_CONFIG"
            echo "✓ Custom theme changed successfully!"
        else
            echo "Setting custom theme to: $theme_name (using sed)"
            # Escape the path for sed
            escaped_path=$(echo "$theme_path" | sed 's/\//\\\//g')
            sed -i "s/\"Theme\": \"[^\"]*\"/\"Theme\": \"{\\\"Custom\\\":{\\\"name\\\":\\\"$theme_name\\\",\\\"path\\\":\\\"$escaped_path\\\"}}\"/g" "$WARP_CONFIG"
            sed -i 's/"SystemTheme": "true"/"SystemTheme": "false"/g' "$WARP_CONFIG"
            echo "✓ Custom theme changed successfully!"
        fi
    else
        # Built-in theme - use the old format
        echo "Setting built-in theme to: $theme_name"
        if command -v jq &> /dev/null; then
            jq --arg theme "$theme_name" \
                '.prefs.Theme = "\"" + $theme + "\"" | 
                 .prefs.SelectedSystemThemes = "{\"light\":\"" + $theme + "\",\"dark\":\"" + $theme + "\"}" | 
                 .prefs.SystemTheme = "false"' \
                "$WARP_CONFIG" > "${WARP_CONFIG}.tmp" && mv "${WARP_CONFIG}.tmp" "$WARP_CONFIG"
            echo "✓ Built-in theme changed successfully!"
        else
            echo "Setting built-in theme to: $theme_name (using sed)"
            sed -i "s/\"Theme\": \"[^\"]*\"/\"Theme\": \"\\\"$theme_name\\\"\"/g" "$WARP_CONFIG"
            sed -i "s/\"SelectedSystemThemes\": \"[^\"]*\"/\"SelectedSystemThemes\": \"{\\\"light\\\":\\\"$theme_name\\\",\\\"dark\\\":\\\"$theme_name\\\"}\"/g" "$WARP_CONFIG"
            sed -i 's/"SystemTheme": "true"/"SystemTheme": "false"/g' "$WARP_CONFIG"
            echo "✓ Built-in theme changed successfully!"
        fi
    fi
    
    echo "The change should take effect immediately, but you may need to restart Warp if it doesn't."
}

install_themes_repo() {
    echo "Installing official Warp themes repository..."
    mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/warp-terminal"
    cd "${XDG_DATA_HOME:-$HOME/.local/share}/warp-terminal/"
    
    if [ -d "themes" ]; then
        echo "Themes directory already exists. Updating..."
        cd themes && git pull
    else
        git clone https://github.com/warpdotdev/themes.git
    fi
    
    echo "✓ Themes repository installed/updated!"
}

install_omarchy_themes() {
    echo "Installing Omarchy themes..."
    local script_dir="$(dirname "$0")"
    local themes_dir="${XDG_DATA_HOME:-$HOME/.local/share}/warp-terminal/themes"
    
    # Create themes directory if it doesn't exist
    mkdir -p "$themes_dir"
    
    # Check if we have omarchy themes in the local themes folder
    if [ -d "$script_dir/themes" ] && ls "$script_dir/themes"/*.yaml >/dev/null 2>&1; then
        echo "Found local omarchy themes, installing..."
        cp "$script_dir/themes"/*.yaml "$themes_dir/"
        local count=$(ls "$script_dir/themes"/*.yaml 2>/dev/null | wc -l)
        echo "✓ Installed $count omarchy themes!"
    else
        echo "No omarchy themes found. Run the converter first:"
        echo "  $script_dir/convert_omarchy_themes_v2.sh"
        return 1
    fi
}

sync_omarchy_theme() {
    echo "Syncing active Omarchy theme to Warp..."
    local script_dir="$(dirname "$0")"
    local sync_script="$script_dir/sync_omarchy_theme.sh"
    
    if [ -x "$sync_script" ]; then
        "$sync_script"
    else
        echo "Error: Sync script not found or not executable: $sync_script"
        echo "Make sure sync_omarchy_theme.sh exists and is executable."
        return 1
    fi
}

case "${1:-}" in
    "list"|"ls")
        list_available_themes
        echo ""
        echo "Current theme: $(get_current_theme)"
        ;;
    "current"|"show")
        echo "Current theme: $(get_current_theme)"
        ;;
    "set")
        set_theme "$2"
        ;;
    "install-repo"|"install")
        install_themes_repo
        ;;
    "install-omarchy"|"omarchy")
        install_omarchy_themes
        ;;
    "sync-omarchy"|"sync")
        sync_omarchy_theme
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
