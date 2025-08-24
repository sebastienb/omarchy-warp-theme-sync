#!/bin/bash

# Omarchy to Warp Theme Sync
# Automatically detects the active Omarchy theme and sets it in Warp
# If the theme doesn't exist in Warp format, it converts it first

SCRIPT_DIR="$(dirname "$0")"
OMARCHY_CURRENT="/home/sebs/.config/omarchy/current/theme"
OMARCHY_THEMES_DIR="/home/sebs/.config/omarchy/themes"
WARP_THEMES_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/warp-terminal/themes"
PROJECT_THEMES_DIR="$SCRIPT_DIR/themes"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to get active Omarchy theme name
get_active_omarchy_theme() {
    if [ -L "$OMARCHY_CURRENT" ]; then
        local theme_path=$(readlink "$OMARCHY_CURRENT")
        basename "$theme_path"
    else
        echo ""
    fi
}

# Function to check if Warp theme exists
warp_theme_exists() {
    local theme_name="$1"
    [ -f "$WARP_THEMES_DIR/${theme_name}.yaml" ]
}

# Function to convert single theme
convert_single_theme() {
    local theme_name="$1"
    local theme_dir="$OMARCHY_THEMES_DIR/$theme_name"
    local output_file="$PROJECT_THEMES_DIR/${theme_name}.yaml"
    
    log_info "Converting theme: $theme_name"
    
    if [ ! -d "$theme_dir" ]; then
        log_error "Theme directory not found: $theme_dir"
        return 1
    fi
    
    # Create output directory if needed
    mkdir -p "$PROJECT_THEMES_DIR"
    
    # Use the converter function from convert_omarchy_themes_v2.sh
    # We'll source the functions or recreate the core conversion logic here
    
    # Initialize color array
    declare -A theme_colors
    
    # Parse alacritty colors first (preferred source)
    if [ -f "$theme_dir/alacritty.toml" ]; then
        # Parse primary colors - fixed regex to handle quotes properly
        theme_colors[background]=$(sed -n '/^\[colors\.primary\]/,/^\[/p' "$theme_dir/alacritty.toml" | grep '^background' | sed "s/.*=[ ]*['\"]\\([^'\"]*\\)['\"].*/\\1/" | head -1)
        theme_colors[foreground]=$(sed -n '/^\[colors\.primary\]/,/^\[/p' "$theme_dir/alacritty.toml" | grep '^foreground' | sed "s/.*=[ ]*['\"]\\([^'\"]*\\)['\"].*/\\1/" | head -1)
        
        # Check for cursor colors
        if grep -q '\[colors\.cursor\]' "$theme_dir/alacritty.toml"; then
            theme_colors[cursor]=$(sed -n '/\[colors\.cursor\]/,/^\[/p' "$theme_dir/alacritty.toml" | grep '^cursor' | sed "s/.*=[ ]*['\"]\\([^'\"]*\\)['\"].*/\\1/")
        fi
        
        # Parse normal colors
        local normal_section=$(sed -n '/\[colors\.normal\]/,/^\[/p' "$theme_dir/alacritty.toml" 2>/dev/null)
        theme_colors[normal_black]=$(echo "$normal_section" | grep '^black' | sed "s/.*=[ ]*['\"]\\([^'\"]*\\)['\"].*/\\1/")
        theme_colors[normal_red]=$(echo "$normal_section" | grep '^red' | sed "s/.*=[ ]*['\"]\\([^'\"]*\\)['\"].*/\\1/")
        theme_colors[normal_green]=$(echo "$normal_section" | grep '^green' | sed "s/.*=[ ]*['\"]\\([^'\"]*\\)['\"].*/\\1/")
        theme_colors[normal_yellow]=$(echo "$normal_section" | grep '^yellow' | sed "s/.*=[ ]*['\"]\\([^'\"]*\\)['\"].*/\\1/")
        theme_colors[normal_blue]=$(echo "$normal_section" | grep '^blue' | sed "s/.*=[ ]*['\"]\\([^'\"]*\\)['\"].*/\\1/")
        theme_colors[normal_magenta]=$(echo "$normal_section" | grep '^magenta' | sed "s/.*=[ ]*['\"]\\([^'\"]*\\)['\"].*/\\1/")
        theme_colors[normal_cyan]=$(echo "$normal_section" | grep '^cyan' | sed "s/.*=[ ]*['\"]\\([^'\"]*\\)['\"].*/\\1/")
        theme_colors[normal_white]=$(echo "$normal_section" | grep '^white' | sed "s/.*=[ ]*['\"]\\([^'\"]*\\)['\"].*/\\1/")
        
        # Parse bright colors
        local bright_section=$(sed -n '/\[colors\.bright\]/,/^\[/p' "$theme_dir/alacritty.toml" 2>/dev/null)
        theme_colors[bright_black]=$(echo "$bright_section" | grep '^black' | sed "s/.*=[ ]*['\"]\\([^'\"]*\\)['\"].*/\\1/")
        theme_colors[bright_red]=$(echo "$bright_section" | grep '^red' | sed "s/.*=[ ]*['\"]\\([^'\"]*\\)['\"].*/\\1/")
        theme_colors[bright_green]=$(echo "$bright_section" | grep '^green' | sed "s/.*=[ ]*['\"]\\([^'\"]*\\)['\"].*/\\1/")
        theme_colors[bright_yellow]=$(echo "$bright_section" | grep '^yellow' | sed "s/.*=[ ]*['\"]\\([^'\"]*\\)['\"].*/\\1/")
        theme_colors[bright_blue]=$(echo "$bright_section" | grep '^blue' | sed "s/.*=[ ]*['\"]\\([^'\"]*\\)['\"].*/\\1/")
        theme_colors[bright_magenta]=$(echo "$bright_section" | grep '^magenta' | sed "s/.*=[ ]*['\"]\\([^'\"]*\\)['\"].*/\\1/")
        theme_colors[bright_cyan]=$(echo "$bright_section" | grep '^cyan' | sed "s/.*=[ ]*['\"]\\([^'\"]*\\)['\"].*/\\1/")
        theme_colors[bright_white]=$(echo "$bright_section" | grep '^white' | sed "s/.*=[ ]*['\"]\\([^'\"]*\\)['\"].*/\\1/")
    fi
    
    # Fallback to CSS if needed
    if [ -z "${theme_colors[background]}" ] || [ -z "${theme_colors[foreground]}" ]; then
        for css_file in "$theme_dir"/*.css; do
            [ -f "$css_file" ] || continue
            
            while IFS= read -r line; do
                if [[ "$line" =~ @define-color[[:space:]]+([^[:space:]]+)[[:space:]]+([^;]+) ]]; then
                    local var_name="${BASH_REMATCH[1]}"
                    local var_value="${BASH_REMATCH[2]}"
                    
                    # Clean up the value
                    var_value=$(echo "$var_value" | tr -d ' ' | tr -d '"' | tr -d "'")
                    
                    # Add # if missing and validate hex
                    if [[ "$var_value" =~ ^[A-Fa-f0-9]{6}$ ]]; then
                        var_value="#$var_value"
                    fi
                    
                    if [[ "$var_value" =~ ^#[A-Fa-f0-9]{6}$ ]]; then
                        case "$var_name" in
                            "background"|"bg") theme_colors[background]="$var_value" ;;
                            "foreground"|"fg"|"text") theme_colors[foreground]="$var_value" ;;
                            "accent") theme_colors[accent]="$var_value" ;;
                        esac
                    fi
                fi
            done < "$css_file"
        done
    fi
    
    # Set colors with validation and defaults
    local bg_color="${theme_colors[background]}"
    local fg_color="${theme_colors[foreground]}"
    local accent_color="${theme_colors[accent]:-$fg_color}"
    # Use cursor color if defined, otherwise use foreground color
    local cursor_color="${theme_colors[cursor]:-$fg_color}"
    
    # Validate colors
    [[ ! "$bg_color" =~ ^#[A-Fa-f0-9]{6}$ ]] && bg_color="#000000"
    [[ ! "$fg_color" =~ ^#[A-Fa-f0-9]{6}$ ]] && fg_color="#ffffff"
    [[ ! "$accent_color" =~ ^#[A-Fa-f0-9]{6}$ ]] && accent_color="$fg_color"
    [[ ! "$cursor_color" =~ ^#[A-Fa-f0-9]{6}$ ]] && cursor_color="$accent_color"
    
    # Set terminal colors with defaults
    local colors=(
        "normal_black:#000000" "normal_red:#cd0000" "normal_green:#00cd00" "normal_yellow:#cdcd00"
        "normal_blue:#0000ee" "normal_magenta:#cd00cd" "normal_cyan:#00cdcd" "normal_white:#e5e5e5"
        "bright_black:#7f7f7f" "bright_red:#ff0000" "bright_green:#00ff00" "bright_yellow:#ffff00"
        "bright_blue:#5c5cff" "bright_magenta:#ff00ff" "bright_cyan:#00ffff" "bright_white:#ffffff"
    )
    
    declare -A final_colors
    for color_def in "${colors[@]}"; do
        local color_name="${color_def%:*}"
        local default_value="${color_def#*:}"
        local extracted_value="${theme_colors[$color_name]}"
        
        if [[ "$extracted_value" =~ ^#[A-Fa-f0-9]{6}$ ]]; then
            final_colors[$color_name]="$extracted_value"
        else
            final_colors[$color_name]="$default_value"
        fi
    done
    
    # Determine theme details (light/dark)
    local hex=$(echo "$bg_color" | tr -d '#' | tr '[:lower:]' '[:upper:]')
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    local brightness=$((($r * 299 + $g * 587 + $b * 114) / 1000))
    local theme_details="darker"
    [ $brightness -gt 128 ] && theme_details="lighter"
    
    # Create the Warp theme YAML
    cat > "$output_file" << EOF
name: $theme_name
accent: '$accent_color'
cursor: '$cursor_color'
background: '$bg_color'
foreground: '$fg_color'
details: $theme_details
terminal_colors:
  bright:
    black: '${final_colors[bright_black]}'
    blue: '${final_colors[bright_blue]}'
    cyan: '${final_colors[bright_cyan]}'
    green: '${final_colors[bright_green]}'
    magenta: '${final_colors[bright_magenta]}'
    red: '${final_colors[bright_red]}'
    white: '${final_colors[bright_white]}'
    yellow: '${final_colors[bright_yellow]}'
  normal:
    black: '${final_colors[normal_black]}'
    blue: '${final_colors[normal_blue]}'
    cyan: '${final_colors[normal_cyan]}'
    green: '${final_colors[normal_green]}'
    magenta: '${final_colors[normal_magenta]}'
    red: '${final_colors[normal_red]}'
    white: '${final_colors[normal_white]}'
    yellow: '${final_colors[normal_yellow]}'
EOF

    log_success "Created Warp theme: $output_file"
    
    # Print extracted source colors
    log_info "Source colors extracted from $theme_dir:"
    echo "  Primary:"
    echo "    Background: ${theme_colors[background]:-"(not found)"}"
    echo "    Foreground: ${theme_colors[foreground]:-"(not found)"}"
    echo "    Cursor:     ${theme_colors[cursor]:-"(not found)"}"
    echo "  Normal colors:"
    echo "    Black:   ${theme_colors[normal_black]:-"(not found)"}"
    echo "    Red:     ${theme_colors[normal_red]:-"(not found)"}"
    echo "    Green:   ${theme_colors[normal_green]:-"(not found)"}"
    echo "    Yellow:  ${theme_colors[normal_yellow]:-"(not found)"}"
    echo "    Blue:    ${theme_colors[normal_blue]:-"(not found)"}"
    echo "    Magenta: ${theme_colors[normal_magenta]:-"(not found)"}"
    echo "    Cyan:    ${theme_colors[normal_cyan]:-"(not found)"}"
    echo "    White:   ${theme_colors[normal_white]:-"(not found)"}"
    echo "  Bright colors:"
    echo "    Black:   ${theme_colors[bright_black]:-"(not found)"}"
    echo "    Red:     ${theme_colors[bright_red]:-"(not found)"}"
    echo "    Green:   ${theme_colors[bright_green]:-"(not found)"}"
    echo "    Yellow:  ${theme_colors[bright_yellow]:-"(not found)"}"
    echo "    Blue:    ${theme_colors[bright_blue]:-"(not found)"}"
    echo "    Magenta: ${theme_colors[bright_magenta]:-"(not found)"}"
    echo "    Cyan:    ${theme_colors[bright_cyan]:-"(not found)"}"
    echo "    White:   ${theme_colors[bright_white]:-"(not found)"}"
    
    # Print final generated colors
    log_info "Final colors in generated Warp theme:"
    echo "  Primary:"
    echo "    Background: $bg_color"
    echo "    Foreground: $fg_color"
    echo "    Accent:     $accent_color"
    echo "    Cursor:     $cursor_color"
    echo "  Normal colors:"
    echo "    Black:   ${final_colors[normal_black]}"
    echo "    Red:     ${final_colors[normal_red]}"
    echo "    Green:   ${final_colors[normal_green]}"
    echo "    Yellow:  ${final_colors[normal_yellow]}"
    echo "    Blue:    ${final_colors[normal_blue]}"
    echo "    Magenta: ${final_colors[normal_magenta]}"
    echo "    Cyan:    ${final_colors[normal_cyan]}"
    echo "    White:   ${final_colors[normal_white]}"
    echo "  Bright colors:"
    echo "    Black:   ${final_colors[bright_black]}"
    echo "    Red:     ${final_colors[bright_red]}"
    echo "    Green:   ${final_colors[bright_green]}"
    echo "    Yellow:  ${final_colors[bright_yellow]}"
    echo "    Blue:    ${final_colors[bright_blue]}"
    echo "    Magenta: ${final_colors[bright_magenta]}"
    echo "    Cyan:    ${final_colors[bright_cyan]}"
    echo "    White:   ${final_colors[bright_white]}"
    
    return 0
}

# Function to install theme to Warp
install_theme_to_warp() {
    local theme_name="$1"
    local source_file="$PROJECT_THEMES_DIR/${theme_name}.yaml"
    local dest_file="$WARP_THEMES_DIR/${theme_name}.yaml"
    
    if [ ! -f "$source_file" ]; then
        log_error "Source theme file not found: $source_file"
        return 1
    fi
    
    # Create Warp themes directory if needed
    mkdir -p "$WARP_THEMES_DIR"
    
    # Copy theme file
    cp "$source_file" "$dest_file"
    log_success "Installed theme to Warp: $dest_file"
    return 0
}

# Function to set Warp theme
set_warp_theme() {
    local theme_name="$1"
    
    log_info "Setting Warp theme to: $theme_name"
    
    # Use the theme manager to set the theme
    if [ -x "$SCRIPT_DIR/warp_theme_manager.sh" ]; then
        "$SCRIPT_DIR/warp_theme_manager.sh" set "$theme_name"
        return $?
    else
        log_error "Theme manager not found or not executable: $SCRIPT_DIR/warp_theme_manager.sh"
        return 1
    fi
}

# Main sync logic
main() {
    echo "🎨 Omarchy to Warp Theme Sync"
    echo "=============================="
    
    # Get active Omarchy theme
    local active_theme=$(get_active_omarchy_theme)
    
    if [ -z "$active_theme" ]; then
        log_error "Could not determine active Omarchy theme"
        log_info "Check that $OMARCHY_CURRENT exists and is a valid symlink"
        exit 1
    fi
    
    log_info "Active Omarchy theme: $active_theme"
    
    # Check if Warp theme exists
    if warp_theme_exists "$active_theme"; then
        log_success "Warp theme exists: $active_theme"
    else
        log_warning "Warp theme does not exist: $active_theme"
        log_info "Converting theme from Omarchy format..."
        
        if convert_single_theme "$active_theme"; then
            log_success "Theme converted successfully"
            
            log_info "Installing theme to Warp..."
            if install_theme_to_warp "$active_theme"; then
                log_success "Theme installed successfully"
            else
                log_error "Failed to install theme to Warp"
                exit 1
            fi
        else
            log_error "Failed to convert theme"
            exit 1
        fi
    fi
    
    # Set the theme in Warp
    if set_warp_theme "$active_theme"; then
        log_success "Successfully synced theme: $active_theme"
        echo ""
        log_info "Omarchy and Warp are now using the same theme!"
    else
        log_error "Failed to set Warp theme"
        exit 1
    fi
}

# Show usage if help requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $0"
    echo ""
    echo "Automatically syncs the active Omarchy theme to Warp Terminal."
    echo "If the theme doesn't exist in Warp format, it will be converted first."
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "The script will:"
    echo "1. Detect the active Omarchy theme from $OMARCHY_CURRENT"
    echo "2. Check if the theme exists in Warp format"
    echo "3. Convert the theme if needed"
    echo "4. Install the theme to Warp"
    echo "5. Set the theme as active in Warp"
    exit 0
fi

# Run main function
main
