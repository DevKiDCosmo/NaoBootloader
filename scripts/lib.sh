#!/bin/bash

# lib.sh - Universal Debugging and Logging Library for NaoBootloader
# This library provides common functions for all scripts

# ==============================================================================
# COLOR DEFINITIONS
# ==============================================================================

# ANSI Color codes
export COLOR_RESET='\033[0m'
export COLOR_BLACK='\033[0;30m'
export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[0;33m'
export COLOR_BLUE='\033[0;34m'
export COLOR_MAGENTA='\033[0;35m'
export COLOR_CYAN='\033[0;36m'
export COLOR_WHITE='\033[0;37m'

# Bright colors
export COLOR_BRIGHT_BLACK='\033[1;30m'
export COLOR_BRIGHT_RED='\033[1;31m'
export COLOR_BRIGHT_GREEN='\033[1;32m'
export COLOR_BRIGHT_YELLOW='\033[1;33m'
export COLOR_BRIGHT_BLUE='\033[1;34m'
export COLOR_BRIGHT_MAGENTA='\033[1;35m'
export COLOR_BRIGHT_CYAN='\033[1;36m'
export COLOR_BRIGHT_WHITE='\033[1;37m'

# Background colors
export COLOR_BG_RED='\033[41m'
export COLOR_BG_GREEN='\033[42m'
export COLOR_BG_YELLOW='\033[43m'
export COLOR_BG_BLUE='\033[44m'

# Text styles
export TEXT_BOLD='\033[1m'
export TEXT_DIM='\033[2m'
export TEXT_UNDERLINE='\033[4m'
export TEXT_BLINK='\033[5m'
export TEXT_REVERSE='\033[7m'

# ==============================================================================
# LOGGING LEVELS
# ==============================================================================

export LOG_LEVEL_TRACE=0
export LOG_LEVEL_DEBUG=1
export LOG_LEVEL_INFO=2
export LOG_LEVEL_WARN=3
export LOG_LEVEL_ERROR=4
export LOG_LEVEL_FATAL=5

# Current log level (default: INFO)
export CURRENT_LOG_LEVEL=${CURRENT_LOG_LEVEL:-$LOG_LEVEL_INFO}

# ==============================================================================
# LOGGING FUNCTIONS
# ==============================================================================

log_trace() {
    [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_TRACE ] && echo -e "${COLOR_BRIGHT_BLACK}[TRACE]${COLOR_RESET} $*"
}

log_debug() {
    [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_DEBUG ] && echo -e "${COLOR_CYAN}[DEBUG]${COLOR_RESET} $*"
}

log_info() {
    [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ] && echo -e "${COLOR_GREEN}[INFO]${COLOR_RESET} $*"
}

log_warn() {
    [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_WARN ] && echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*"
}

log_error() {
    [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_ERROR ] && echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

log_fatal() {
    [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_FATAL ] && echo -e "${COLOR_BG_RED}${COLOR_WHITE}[FATAL]${COLOR_RESET} $*" >&2
}

log_success() {
    echo -e "${COLOR_BRIGHT_GREEN}[✓]${COLOR_RESET} $*"
}

log_failure() {
    echo -e "${COLOR_BRIGHT_RED}[✗]${COLOR_RESET} $*" >&2
}

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

# Print a banner
print_banner() {
    local title="$1"
    local width=80
    echo -e "${COLOR_BRIGHT_CYAN}"
    echo "================================================================================"
    printf "%-*s\n" $width "$title"
    echo "================================================================================"
    echo -e "${COLOR_RESET}"
}

# Print a section header
print_section() {
    local title="$1"
    echo ""
    echo -e "${COLOR_BRIGHT_YELLOW}=== $title ===${COLOR_RESET}"
    echo ""
}

# Print a separator line
print_separator() {
    echo -e "${COLOR_BRIGHT_BLACK}--------------------------------------------------------------------------------${COLOR_RESET}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if running as root
is_root() {
    [ "$(id -u)" -eq 0 ]
}

# Require root privileges
require_root() {
    if ! is_root; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Confirm action
confirm() {
    local message="$1"
    local response
    echo -ne "${COLOR_YELLOW}$message [y/N]: ${COLOR_RESET}"
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

# Check if file exists
file_exists() {
    [ -f "$1" ]
}

# Check if directory exists
dir_exists() {
    [ -d "$1" ]
}

# Get file size in human-readable format
get_file_size() {
    local file="$1"
    if file_exists "$file"; then
        ls -lh "$file" | awk '{print $5}'
    else
        echo "N/A"
    fi
}

# Run command with error handling
run_command() {
    local description="$1"
    shift
    
    log_debug "Running: $*"
    
    if "$@"; then
        log_success "$description"
        return 0
    else
        log_failure "$description"
        return 1
    fi
}

# ==============================================================================
# ERROR HANDLING
# ==============================================================================

# Exit with error message
die() {
    log_fatal "$*"
    exit 1
}

# Cleanup function (override in your script)
cleanup() {
    log_debug "Cleanup function called"
}

# Set up trap for cleanup
trap cleanup EXIT INT TERM

# ==============================================================================
# VALIDATION FUNCTIONS
# ==============================================================================

# Validate binary file
validate_binary() {
    local file="$1"
    local expected_size="$2"
    
    if ! file_exists "$file"; then
        log_error "Binary file not found: $file"
        return 1
    fi
    
    local actual_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    
    log_debug "Binary: $file ($(get_file_size "$file"))"
    
    if [ -n "$expected_size" ] && [ "$actual_size" -ne "$expected_size" ]; then
        log_warn "Expected size $expected_size bytes, got $actual_size bytes"
        return 1
    fi
    
    return 0
}

# ==============================================================================
# PROGRESS INDICATORS
# ==============================================================================

# Show spinner while command runs
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Progress bar
progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    
    printf "\r["
    printf "%${completed}s" | tr ' ' '='
    printf "%${remaining}s" | tr ' ' '-'
    printf "] %3d%%" $percentage
    
    if [ $current -eq $total ]; then
        echo ""
    fi
}

# ==============================================================================
# SCRIPT INFO
# ==============================================================================

# Get script directory
get_script_dir() {
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
}

# Get project root directory
get_project_root() {
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
}

# ==============================================================================
# EXPORTS
# ==============================================================================

export -f log_trace log_debug log_info log_warn log_error log_fatal
export -f log_success log_failure
export -f print_banner print_section print_separator
export -f command_exists is_root require_root confirm
export -f file_exists dir_exists get_file_size
export -f run_command die cleanup
export -f validate_binary
export -f spinner progress_bar
export -f get_script_dir get_project_root
