#!/bin/bash

# Omarchy to Warp Theme Sync
# Detects the active Omarchy theme, converts it to a Warp theme (if needed)
# and sets it as Warp's active theme.
#
# Supports Omarchy 4 ("Quatro"): theme state lives in
#   ~/.local/state/omarchy/current/{theme.name,theme/}
# and colors come from the semantic colors.toml via `omarchy-theme-color`.
# Falls back to the Omarchy 2/3 layout (~/.config/omarchy/current/theme symlink)
# and to parsing alacritty.toml directly.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMARCHY_STATE="$HOME/.local/state/omarchy/current"
OMARCHY_LEGACY_CURRENT="$HOME/.config/omarchy/current/theme"
OMARCHY_USER_THEMES="$HOME/.config/omarchy/themes"
OMARCHY_SYS_THEMES="${OMARCHY_PATH:-$HOME/.local/share/omarchy}/themes"
WARP_THEMES_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/warp-terminal/themes"

FORCE=0
QUIET=0

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()    { (( QUIET )) || echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { (( QUIET )) || echo -e "${GREEN}✓${NC} $1"; }
log_warning() { (( QUIET )) || echo -e "${YELLOW}⚠${NC} $1"; }
log_error()   { echo -e "${RED}✗${NC} $1" >&2; }

# ---------------------------------------------------------------------------
# Omarchy detection
# ---------------------------------------------------------------------------

# Print the active theme name (snake/kebab-cased, e.g. "tokyo-night")
get_active_omarchy_theme() {
    if [ -f "$OMARCHY_STATE/theme.name" ]; then            # Omarchy 4
        tr -d '[:space:]' < "$OMARCHY_STATE/theme.name"
    elif [ -L "$OMARCHY_LEGACY_CURRENT" ]; then             # Omarchy 2/3
        basename "$(readlink "$OMARCHY_LEGACY_CURRENT")"
    fi
}

# Print the directory that holds the theme's rendered/source files
get_omarchy_theme_dir() {
    local name="$1"
    if [ "$name" = "$(get_active_omarchy_theme)" ] && [ -d "$OMARCHY_STATE/theme" ]; then
        echo "$OMARCHY_STATE/theme"                            # Omarchy 4 (rendered, active theme)
    elif [ -d "$OMARCHY_USER_THEMES/$name" ]; then
        echo "$OMARCHY_USER_THEMES/$name"
    elif [ -d "$OMARCHY_SYS_THEMES/$name" ]; then
        echo "$OMARCHY_SYS_THEMES/$name"
    elif [ -L "$OMARCHY_LEGACY_CURRENT" ]; then
        readlink -f "$OMARCHY_LEGACY_CURRENT"
    fi
}

# ---------------------------------------------------------------------------
# Color extraction
# ---------------------------------------------------------------------------

declare -A theme_colors

# Omarchy 4: semantic palette resolved by omarchy-theme-color (colors.toml)
load_colors_from_omarchy() {
    local theme_dir="$1" key value
    local colors_file="$theme_dir/colors.toml"
    command -v omarchy-theme-color >/dev/null 2>&1 || return 1
    [ -f "$colors_file" ] || return 1

    declare -A palette
    while IFS=$'\t' read -r key value; do
        palette[$key]="$value"
    done < <(omarchy-theme-color --file "$colors_file" --all 2>/dev/null)

    [ -n "${palette[background]}" ] || return 1

    theme_colors[background]="${palette[background]}"
    theme_colors[foreground]="${palette[foreground]}"
    theme_colors[accent]="${palette[accent]}"
    theme_colors[cursor]="${palette[cursor]:-${palette[bright_foreground]}}"
    theme_colors[mode]="${palette[mode]}"

    local i=0 name
    for name in black red green yellow blue magenta cyan white; do
        theme_colors[normal_$name]="${palette[color$i]}"
        theme_colors[bright_$name]="${palette[color$((i + 8))]}"
        ((i++))
    done
    log_info "Colors source: $colors_file (omarchy-theme-color)"
    return 0
}

toml_value() { # $1=section text, $2=key
    echo "$1" | grep -E "^[[:space:]]*$2[[:space:]]*=" | head -1 \
        | sed "s/.*=[ ]*['\"]\\([^'\"]*\\)['\"].*/\\1/"
}

# Fallback: parse alacritty.toml
load_colors_from_alacritty() {
    local file="$1/alacritty.toml"
    [ -f "$file" ] || return 1

    local primary cursor normal bright name
    primary=$(sed -n '/^\[colors\.primary\]/,/^\[/p' "$file")
    cursor=$(sed -n '/^\[colors\.cursor\]/,/^\[/p' "$file")
    normal=$(sed -n '/^\[colors\.normal\]/,/^\[/p' "$file")
    bright=$(sed -n '/^\[colors\.bright\]/,/^\[/p' "$file")

    theme_colors[background]=$(toml_value "$primary" background)
    theme_colors[foreground]=$(toml_value "$primary" foreground)
    theme_colors[cursor]=$(toml_value "$cursor" cursor)
    for name in black red green yellow blue magenta cyan white; do
        theme_colors[normal_$name]=$(toml_value "$normal" "$name")
        theme_colors[bright_$name]=$(toml_value "$bright" "$name")
    done

    [ -n "${theme_colors[background]}" ] || return 1
    log_info "Colors source: $file"
    return 0
}

is_hex() { [[ "$1" =~ ^#[A-Fa-f0-9]{6}$ ]]; }

# ---------------------------------------------------------------------------
# Conversion
# ---------------------------------------------------------------------------

convert_single_theme() {
    local theme_name="$1"
    local theme_dir output_file
    theme_dir=$(get_omarchy_theme_dir "$theme_name")
    output_file="$WARP_THEMES_DIR/${theme_name}.yaml"

    log_info "Converting theme: $theme_name"

    if [ -z "$theme_dir" ] || [ ! -d "$theme_dir" ]; then
        log_error "Theme directory not found for: $theme_name"
        return 1
    fi

    mkdir -p "$WARP_THEMES_DIR"
    theme_colors=()

    load_colors_from_omarchy "$theme_dir" || load_colors_from_alacritty "$theme_dir" || {
        log_error "No colors.toml or alacritty.toml found in $theme_dir"
        return 1
    }

    local bg_color="${theme_colors[background]}"
    local fg_color="${theme_colors[foreground]}"
    local accent_color="${theme_colors[accent]:-$fg_color}"
    local cursor_color="${theme_colors[cursor]:-$fg_color}"

    is_hex "$bg_color"     || bg_color="#000000"
    is_hex "$fg_color"     || fg_color="#ffffff"
    is_hex "$accent_color" || accent_color="$fg_color"
    is_hex "$cursor_color" || cursor_color="$accent_color"

    local defaults=(
        "normal_black:#000000" "normal_red:#cd0000" "normal_green:#00cd00" "normal_yellow:#cdcd00"
        "normal_blue:#0000ee" "normal_magenta:#cd00cd" "normal_cyan:#00cdcd" "normal_white:#e5e5e5"
        "bright_black:#7f7f7f" "bright_red:#ff0000" "bright_green:#00ff00" "bright_yellow:#ffff00"
        "bright_blue:#5c5cff" "bright_magenta:#ff00ff" "bright_cyan:#00ffff" "bright_white:#ffffff"
    )
    declare -A c
    local def name value
    for def in "${defaults[@]}"; do
        name="${def%:*}"; value="${theme_colors[$name]}"
        is_hex "$value" && c[$name]="$value" || c[$name]="${def#*:}"
    done

    # light/dark: prefer Omarchy's mode, else background luminance
    local theme_details="darker"
    if [ "${theme_colors[mode]}" = "light" ]; then
        theme_details="lighter"
    elif [ -z "${theme_colors[mode]}" ]; then
        local hex="${bg_color#\#}"
        local brightness=$(( ($((16#${hex:0:2})) * 299 + $((16#${hex:2:2})) * 587 + $((16#${hex:4:2})) * 114) / 1000 ))
        (( brightness > 128 )) && theme_details="lighter"
    fi

    cat > "$output_file" <<YAML
name: $theme_name
accent: '$accent_color'
cursor: '$cursor_color'
background: '$bg_color'
foreground: '$fg_color'
details: $theme_details
terminal_colors:
  bright:
    black: '${c[bright_black]}'
    blue: '${c[bright_blue]}'
    cyan: '${c[bright_cyan]}'
    green: '${c[bright_green]}'
    magenta: '${c[bright_magenta]}'
    red: '${c[bright_red]}'
    white: '${c[bright_white]}'
    yellow: '${c[bright_yellow]}'
  normal:
    black: '${c[normal_black]}'
    blue: '${c[normal_blue]}'
    cyan: '${c[normal_cyan]}'
    green: '${c[normal_green]}'
    magenta: '${c[normal_magenta]}'
    red: '${c[normal_red]}'
    white: '${c[normal_white]}'
    yellow: '${c[normal_yellow]}'
YAML

    log_success "Created Warp theme: $output_file"
    log_info "bg=$bg_color fg=$fg_color accent=$accent_color cursor=$cursor_color details=$theme_details"
    return 0
}

set_warp_theme() {
    local theme_name="$1"
    log_info "Setting Warp theme to: $theme_name"
    if [ -x "$SCRIPT_DIR/warp_theme_manager.sh" ]; then
        if (( QUIET )); then
            "$SCRIPT_DIR/warp_theme_manager.sh" set "$theme_name" >/dev/null
        else
            "$SCRIPT_DIR/warp_theme_manager.sh" set "$theme_name"
        fi
    else
        log_error "Theme manager not found or not executable: $SCRIPT_DIR/warp_theme_manager.sh"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

usage() {
    cat <<USAGE
Usage: $0 [--force] [--quiet] [theme-name]

Syncs the active Omarchy theme to Warp Terminal. If the theme doesn't exist in
Warp format it is converted first.

Options:
  -f, --force   Re-convert the theme even if a Warp theme already exists
  -q, --quiet   Only print errors (useful from the Omarchy theme-set hook)
  -h, --help    Show this help

Arguments:
  theme-name    Sync this theme instead of the active one (e.g. tokyo-night)
USAGE
}

main() {
    local active_theme="$1"
    (( QUIET )) || { echo "🎨 Omarchy to Warp Theme Sync"; echo "=============================="; }

    [ -n "$active_theme" ] || active_theme=$(get_active_omarchy_theme)
    if [ -z "$active_theme" ]; then
        log_error "Could not determine active Omarchy theme"
        log_error "Looked for $OMARCHY_STATE/theme.name (Omarchy 4) and $OMARCHY_LEGACY_CURRENT (Omarchy 2/3)"
        exit 1
    fi
    log_info "Active Omarchy theme: $active_theme"

    if (( ! FORCE )) && [ -f "$WARP_THEMES_DIR/${active_theme}.yaml" ]; then
        log_success "Warp theme exists: $active_theme"
    else
        (( FORCE )) && log_info "Forcing re-conversion of $active_theme" \
                    || log_warning "Warp theme does not exist: $active_theme"
        convert_single_theme "$active_theme" || { log_error "Failed to convert theme"; exit 1; }
    fi

    if set_warp_theme "$active_theme"; then
        log_success "Successfully synced theme: $active_theme"
    else
        log_error "Failed to set Warp theme"
        exit 1
    fi
}

THEME_ARG=""
while (( $# > 0 )); do
    case "$1" in
        -f|--force) FORCE=1 ;;
        -q|--quiet) QUIET=1 ;;
        -h|--help)  usage; exit 0 ;;
        -*)         log_error "Unknown option: $1"; usage; exit 1 ;;
        *)          THEME_ARG="$1" ;;
    esac
    shift
done

main "$THEME_ARG"
