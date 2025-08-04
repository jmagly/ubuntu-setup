#!/bin/bash

# ui-helper.sh - Enhanced UI functions for Ubuntu Security Toolkit
# Provides consistent, visually appealing output across all scripts

# Enhanced color definitions
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'
export GRAY='\033[0;90m'
export NC='\033[0m' # No Color

# Bold versions
export BOLD_RED='\033[1;31m'
export BOLD_GREEN='\033[1;32m'
export BOLD_BLUE='\033[1;34m'

# Background colors
export BG_RED='\033[41m'
export BG_GREEN='\033[42m'
export BG_YELLOW='\033[43m'
export BG_BLUE='\033[44m'

# Unicode symbols (with fallbacks)
if [[ $TERM != "dumb" ]] && command -v tput &> /dev/null && tput setaf 1 &> /dev/null; then
    export CHECK_MARK="✓"
    export CROSS_MARK="✗"
    export ARROW="→"
    export BULLET="•"
    export WARNING_SIGN="⚠"
    export INFO_SIGN="ℹ"
    export GEAR="⚙"
    export LOCK="🔒"
    export SHIELD="🛡"
    export PACKAGE="📦"
else
    # Fallback ASCII symbols
    export CHECK_MARK="[OK]"
    export CROSS_MARK="[X]"
    export ARROW="->"
    export BULLET="*"
    export WARNING_SIGN="!"
    export INFO_SIGN="i"
    export GEAR="*"
    export LOCK="[L]"
    export SHIELD="[S]"
    export PACKAGE="[P]"
fi

# Function to print a horizontal line
print_line() {
    local char="${1:--}"
    local width="${2:-80}"
    printf '%*s\n' "$width" '' | tr ' ' "$char"
}

# Function to print a header with box
print_header() {
    local title="$1"
    local width=80
    local padding=$(( (width - ${#title} - 2) / 2 ))
    
    echo
    echo -e "${BOLD_BLUE}$(print_line '=' $width)${NC}"
    printf "${BOLD_BLUE}=%*s%s%*s=${NC}\n" $padding "" "$title" $((width - padding - ${#title} - 2)) ""
    echo -e "${BOLD_BLUE}$(print_line '=' $width)${NC}"
    echo
}

# Function to print a section header
print_section() {
    local title="$1"
    echo
    echo -e "${BOLD_BLUE}${ARROW} $title${NC}"
    echo -e "${GRAY}$(print_line '-' ${#title})${NC}"
}

# Enhanced status printing functions
print_status() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} ${GEAR} $1"
}

print_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} ${CHECK_MARK} ${GREEN}$1${NC}"
}

print_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')]${NC} ${CROSS_MARK} ${RED}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')]${NC} ${WARNING_SIGN}  ${YELLOW}$1${NC}"
}

print_info() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} ${INFO_SIGN}  ${CYAN}$1${NC}"
}

# Function to print a progress indicator
print_progress() {
    local current="$1"
    local total="$2"
    local task="$3"
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r${BLUE}[%3d%%]${NC} [${GREEN}%*s${NC}%*s] %s" \
        "$percent" \
        "$filled" "" \
        "$empty" "" \
        "$task" | sed 's/ /=/g'
}

# Function to print a spinner
spin() {
    local pid=$1
    local task=$2
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local temp
    
    echo -n " "
    while kill -0 $pid 2>/dev/null; do
        temp=${spinstr#?}
        printf "\r${BLUE}%c${NC} %s" "$spinstr" "$task"
        spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
    done
    printf "\r"
}

# Function to print a task with status
print_task() {
    local task="$1"
    local status="$2"
    local width=60
    local task_width=$((width - 10))
    
    # Truncate long tasks
    if [ ${#task} -gt $task_width ]; then
        task="${task:0:$((task_width-3))}..."
    fi
    
    printf "  ${BULLET} %-*s" "$task_width" "$task"
    
    case "$status" in
        "success"|"pass"|"ok")
            echo -e "[${GREEN}${CHECK_MARK} PASS${NC}]"
            ;;
        "fail"|"error")
            echo -e "[${RED}${CROSS_MARK} FAIL${NC}]"
            ;;
        "warning"|"warn")
            echo -e "[${YELLOW}${WARNING_SIGN} WARN${NC}]"
            ;;
        "skip"|"skipped")
            echo -e "[${GRAY}  SKIP${NC}]"
            ;;
        "running"|"progress")
            echo -e "[${BLUE}  ....${NC}]"
            ;;
        *)
            echo -e "[${GRAY}  $status${NC}]"
            ;;
    esac
}

# Function to ask for confirmation
confirm() {
    local prompt="${1:-Continue?}"
    local default="${2:-n}"
    local response
    
    if [ "$default" = "y" ]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    echo -ne "${YELLOW}${WARNING_SIGN} $prompt${NC}"
    read -r response
    
    response=${response:-$default}
    [[ "$response" =~ ^[Yy]$ ]]
}

# Function to display a menu
display_menu() {
    local title="$1"
    shift
    local options=("$@")
    local choice
    
    print_section "$title"
    
    for i in "${!options[@]}"; do
        echo -e "  ${CYAN}$((i+1))${NC}) ${options[$i]}"
    done
    
    echo
    echo -n "Enter choice [1-${#options[@]}]: "
    read -r choice
    
    echo "$choice"
}

# Function to show a summary box
show_summary() {
    local title="$1"
    shift
    local items=("$@")
    local width=70
    
    echo
    echo -e "${GREEN}$(print_line '─' $width)${NC}"
    echo -e "${GREEN}│${NC} ${BOLD_GREEN}$title${NC}"
    echo -e "${GREEN}$(print_line '─' $width)${NC}"
    
    for item in "${items[@]}"; do
        echo -e "${GREEN}│${NC} ${item}"
    done
    
    echo -e "${GREEN}$(print_line '─' $width)${NC}"
    echo
}

# Function to display an error box
show_error_box() {
    local title="ERROR: $1"
    local message="$2"
    local width=70
    
    echo
    echo -e "${RED}$(print_line '█' $width)${NC}"
    echo -e "${BG_RED}${WHITE} $title ${NC}"
    echo -e "${RED}$(print_line '─' $width)${NC}"
    echo -e "${RED}$message${NC}"
    echo -e "${RED}$(print_line '█' $width)${NC}"
    echo
}

# Function to display a warning box
show_warning_box() {
    local title="WARNING: $1"
    local message="$2"
    local width=70
    
    echo
    echo -e "${YELLOW}$(print_line '▓' $width)${NC}"
    echo -e "${BG_YELLOW}${BLACK} $title ${NC}"
    echo -e "${YELLOW}$(print_line '─' $width)${NC}"
    echo -e "${YELLOW}$message${NC}"
    echo -e "${YELLOW}$(print_line '▓' $width)${NC}"
    echo
}

# Function to display installation statistics
show_stats() {
    local installed="$1"
    local failed="$2"
    local skipped="$3"
    local total=$((installed + failed + skipped))
    
    echo
    print_section "Installation Statistics"
    echo -e "  ${GREEN}${CHECK_MARK} Installed:${NC} $installed"
    echo -e "  ${RED}${CROSS_MARK} Failed:${NC}    $failed"
    echo -e "  ${GRAY}─ Skipped:${NC}   $skipped"
    echo -e "  ${BLUE}═ Total:${NC}     $total"
    echo
}

# Export all functions
export -f print_line
export -f print_header
export -f print_section
export -f print_status
export -f print_success
export -f print_error
export -f print_warning
export -f print_info
export -f print_progress
export -f spin
export -f print_task
export -f confirm
export -f display_menu
export -f show_summary
export -f show_error_box
export -f show_warning_box
export -f show_stats