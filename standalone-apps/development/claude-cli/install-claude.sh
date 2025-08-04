#!/bin/bash

# install-claude.sh - Install Claude CLI
# Standalone installer for Claude command-line interface

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check for Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed"
        print_status "Please install Node.js first:"
        print_status "  ./standalone-apps/development/nodejs/install-nodejs.sh"
        exit 1
    fi
    
    # Check for npm
    if ! command -v npm &> /dev/null; then
        print_error "npm is not installed"
        exit 1
    fi
    
    local node_version=$(node --version | cut -d'v' -f2)
    local major_version=$(echo $node_version | cut -d'.' -f1)
    
    if [ "$major_version" -lt 18 ]; then
        print_error "Node.js version 18 or higher is required"
        print_status "Current version: $node_version"
        exit 1
    fi
    
    print_success "Prerequisites met (Node.js $node_version)"
}

# Install Claude CLI
install_claude() {
    print_status "Installing Claude CLI..."
    
    # Install globally via npm
    if sudo npm install -g @anthropic-ai/claude-cli; then
        print_success "Claude CLI installed successfully"
    else
        print_error "Failed to install Claude CLI"
        exit 1
    fi
}

# Configure Claude CLI
configure_claude() {
    print_status "Configuring Claude CLI..."
    
    # Check if already configured
    if [ -f "$HOME/.config/claude/config.json" ]; then
        print_warning "Claude CLI already configured"
        read -p "Reconfigure? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    print_status "To configure Claude CLI, you'll need an API key from:"
    echo "  https://console.anthropic.com/account/keys"
    echo
    
    read -p "Do you have your API key ready? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Running Claude CLI configuration..."
        claude configure
    else
        print_warning "Skipping configuration. You can configure later with: claude configure"
    fi
}

# Install useful Claude-related tools
install_claude_tools() {
    print_status "Installing additional Claude tools..."
    
    # Create claude helpers directory
    local claude_dir="$HOME/.local/share/claude"
    mkdir -p "$claude_dir"
    
    # Create a simple Claude chat script
    cat > "$claude_dir/claude-chat.sh" << 'EOF'
#!/bin/bash
# Simple Claude chat interface

echo "Claude Chat Interface"
echo "Type 'exit' to quit"
echo "====================="
echo

while true; do
    echo -n "You: "
    read -r input
    
    if [ "$input" = "exit" ]; then
        echo "Goodbye!"
        break
    fi
    
    echo -n "Claude: "
    claude chat "$input"
    echo
done
EOF
    
    chmod +x "$claude_dir/claude-chat.sh"
    
    # Create alias file
    cat > "$claude_dir/claude-aliases.sh" << 'EOF'
# Claude CLI aliases
alias claude-chat="$HOME/.local/share/claude/claude-chat.sh"
alias claude-help="claude --help"
alias claude-version="claude --version"

# Function to quickly ask Claude a question
ask() {
    claude chat "$*"
}

# Function to analyze a file with Claude
analyze-file() {
    if [ -z "$1" ]; then
        echo "Usage: analyze-file <filename>"
        return 1
    fi
    
    if [ ! -f "$1" ]; then
        echo "File not found: $1"
        return 1
    fi
    
    echo "Analyzing $1 with Claude..."
    cat "$1" | claude chat "Please analyze this file and provide insights: $(basename $1)"
}
EOF
    
    print_success "Created helper scripts in $claude_dir"
}

# Verify installation
verify_installation() {
    print_status "Verifying installation..."
    
    if command -v claude &> /dev/null; then
        local version=$(claude --version 2>/dev/null || echo "unknown")
        print_success "Claude CLI installed: $version"
        print_status "Binary location: $(which claude)"
    else
        print_error "Claude CLI not found in PATH"
        return 1
    fi
}

# Show usage information
show_usage() {
    echo
    echo "========================================"
    echo "     Claude CLI Usage Guide"
    echo "========================================"
    echo
    echo "Basic commands:"
    echo "  claude configure        # Set up API key"
    echo "  claude chat <message>   # Send a message to Claude"
    echo "  claude --help          # Show all commands"
    echo
    echo "Examples:"
    echo "  claude chat \"What is the weather today?\""
    echo "  claude chat \"Explain quantum computing\""
    echo "  echo \"Hello\" | claude chat \"Translate to Spanish\""
    echo
    echo "Helper scripts installed:"
    echo "  ~/.local/share/claude/claude-chat.sh     # Interactive chat"
    echo "  ~/.local/share/claude/claude-aliases.sh  # Useful aliases"
    echo
    echo "To use aliases, add to your ~/.bashrc:"
    echo "  source ~/.local/share/claude/claude-aliases.sh"
    echo
}

# Main installation
main() {
    echo
    echo "========================================"
    echo "     Claude CLI Installation"
    echo "========================================"
    echo
    
    check_prerequisites
    install_claude
    configure_claude
    install_claude_tools
    verify_installation
    show_usage
    
    echo "========================================"
    echo "     Installation Complete!"
    echo "========================================"
    echo
    
    if [ ! -f "$HOME/.config/claude/config.json" ]; then
        print_warning "Don't forget to configure your API key:"
        echo "  claude configure"
    fi
}

# Run main function
main "$@"