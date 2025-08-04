#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Variables to store temp files and processes
TEMP_FILES=()
BACKGROUND_PIDS=()

# Function to print colored messages
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "\n${BLUE}[STEP]${NC} ${BOLD}$1${NC}"
}

# Function to clean up resources when the script exits
cleanup() {
    # Kill any background processes
    for pid in "${BACKGROUND_PIDS[@]}"; do
        if ps -p $pid > /dev/null; then
            kill $pid 2>/dev/null
        fi
    done
    
    # Remove temporary files
    for file in "${TEMP_FILES[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file"
        fi
    done
    
    echo ""
    print_message "Cleanup completed."
}

# Register the cleanup function to run on exit
trap cleanup EXIT INT TERM

# Function to display the header
display_header() {
    clear
    echo -e "${BOLD}=============================================${NC}"
    echo -e "${BOLD}   Tezos Node Setup Automation Script        ${NC}"
    echo -e "${BOLD}=============================================${NC}"
    echo -e "   This script will help you set up a Tezos node"
    echo -e "   using Docker with the selected history mode."
    echo -e "${BOLD}=============================================${NC}"
    echo ""
}

# Function to check if Docker is installed and running
check_docker() {
    print_step "Checking prerequisites"
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker."
        exit 1
    fi
    
    print_message "Docker is installed and running."
    
    # Pull the Tezos Docker image to ensure we have the latest
    print_message "Pulling the latest Tezos Docker image..."
    docker pull tezos/tezos-bare:latest
    
    if [ $? -ne 0 ]; then
        print_error "Failed to pull Docker image. Check your internet connection."
        exit 1
    fi
    
    print_message "Tezos Docker image pulled successfully."
}

# Function to get the user ID of the tezos user inside the Docker container
get_docker_user_id() {
    docker run --rm tezos/tezos-bare:latest id -u tezos
}

# Function to get the group ID of the tezos user inside the Docker container
get_docker_group_id() {
    docker run --rm tezos/tezos-bare:latest id -g tezos
}

# Function to set directory permissions
set_directory_permissions() {
    local dir=$1
    local uid=$(get_docker_user_id)
    local gid=$(get_docker_group_id)
    
    print_message "Setting proper permissions for data directory..."
    print_message "Docker tezos user has UID:GID = $uid:$gid"
    
    # Method 1: Try to change ownership if running as root or with sudo
    if [ $(id -u) -eq 0 ]; then
        chown -R $uid:$gid "$dir"
        print_message "Changed ownership of $dir to $uid:$gid"
        return 0
    fi
    
    # Method 2: Make the directory world-writable (less secure but works for testing)
    chmod 777 "$dir"
    print_message "Made $dir world-writable (777 permissions)"
    
    # Check if we have write permissions
    if touch "$dir/test_write_permission" 2>/dev/null; then
        rm "$dir/test_write_permission"
        return 0
    else
        print_error "Could not set sufficient permissions for $dir"
        print_error "Please run this script with sudo or manually set permissions:"
        print_error "sudo chown -R $uid:$gid \"$dir\" or sudo chmod 777 \"$dir\""
        return 1
    fi
}

# Function to get the latest snapshot URL for the selected network and mode
get_snapshot_url() {
    local network=$1
    local mode=$2
    
    # Try multiple snapshot sources in case one fails
    local snapshot_sources=(
        " https://snapshots.tzinit.org/"
        "https://snapshots.tezos.marigold.dev"  # Marigold
        "https://snapshots.tzkt.io"            # TzKT
        "https://mainnet.xtz-shots.io"         # XTZ-Shots
    )
    
    local url=""
    
    # If archive mode is selected, warn the user
    if [ "$mode" == "archive" ]; then
        print_warning "Archive snapshots are very large and not recommended for most users."
        print_warning "This script will try to find an archive snapshot, but may fall back to full mode."
    fi
    
    # Try each source until we find a working one
    for source in "${snapshot_sources[@]}"; do
        case $source in
            *"marigold"*)
                case $network in
                    "mainnet")
                        case $mode in
                            "rolling") url="${source}/api/mainnet/rolling/latest" ;;
                            "full") url="${source}/api/mainnet/full/latest" ;;
                            "archive") url="${source}/api/mainnet/archive/latest" ;;
                        esac
                        ;;
                    "ghostnet")
                        case $mode in
                            "rolling") url="${source}/api/ghostnet/rolling/latest" ;;
                            "full") url="${source}/api/ghostnet/full/latest" ;;
                            "archive") url="${source}/api/ghostnet/archive/latest" ;;
                        esac
                        ;;
                esac
                ;;
                
            *"tzkt"*)
                case $network in
                    "mainnet")
                        case $mode in
                            "rolling") url="${source}/mainnet/rolling" ;;
                            "full") url="${source}/mainnet/full" ;;
                            "archive") 
                                print_warning "TzKT doesn't provide archive snapshots. Using full mode."
                                url="${source}/mainnet/full" 
                                ;;
                        esac
                        ;;
                    "ghostnet")
                        case $mode in
                            "rolling") url="${source}/ghostnet/rolling" ;;
                            "full") url="${source}/ghostnet/full" ;;
                            "archive") 
                                print_warning "TzKT doesn't provide archive snapshots. Using full mode."
                                url="${source}/ghostnet/full" 
                                ;;
                        esac
                        ;;
                esac
                ;;
                
            *"xtz-shots"*)
                case $network in
                    "mainnet")
                        case $mode in
                            "rolling") url="${source}/rolling" ;;
                            "full") url="${source}/full" ;;
                            "archive") 
                                if [ "$network" == "mainnet" ]; then
                                    url="${source}/archive"
                                else
                                    print_warning "XTZ-Shots doesn't provide archive snapshots for testnet. Using full mode."
                                    url="${source}/full"
                                fi
                                ;;
                        esac
                        ;;
                    "ghostnet")
                        case $mode in
                            "rolling") url="https://ghostnet.xtz-shots.io/rolling" ;;
                            "full") url="https://ghostnet.xtz-shots.io/full" ;;
                            "archive") 
                                print_warning "XTZ-Shots doesn't provide archive snapshots for testnet. Using full mode."
                                url="https://ghostnet.xtz-shots.io/full"
                                ;;
                        esac
                        ;;
                esac
                ;;
        esac
        
        # Check if the URL is valid by sending a HEAD request
        if curl --output /dev/null --silent --head --fail "$url"; then
            print_message "Found valid snapshot URL: $url"
            echo "$url"
            return 0
        else
            print_warning "Snapshot URL $url is not accessible. Trying another source..."
        fi
    done
    
    # If we get here, all sources failed
    print_error "Could not find a valid snapshot URL for $network in $mode mode."
    print_error "Check your internet connection or try again later."
    exit 1
}

# Function to human readable size
human_readable_size() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes} B"
    elif [ $bytes -lt 1048576 ]; then
        echo "$(( (bytes + 512) / 1024 )) KB"
    elif [ $bytes -lt 1073741824 ]; then
        echo "$(( (bytes + 524288) / 1048576 )) MB"
    else
        echo "$(( (bytes + 536870912) / 1073741824 )) GB"
    fi
}

# Main function
main() {
    display_header
    check_docker
    
    # Step 1: Choose network
    print_step "Network Selection"
    echo "Select a network:"
    echo "1) Mainnet (Production network)"
    echo "2) Ghostnet (Test network)"
    read -p "Enter your choice (1-2): " network_choice
    
    case $network_choice in
        1)
            NETWORK="mainnet"
            ;;
        2)
            NETWORK="ghostnet"
            ;;
        *)
            print_error "Invalid choice. Exiting..."
            exit 1
            ;;
    esac
    
    print_message "Selected network: ${BOLD}${NETWORK}${NC}"
    
    # Step 2: Choose history mode
    print_step "History Mode Selection"
    echo "Select a history mode:"
    echo "1) Rolling (smallest storage, recent blocks only, ~10GB)"
    echo "2) Full (medium storage, full chain but pruned block history, ~50GB)"
    echo "3) Archive (largest storage, complete blockchain history, ~500GB)"
    read -p "Enter your choice (1-3): " mode_choice
    
    case $mode_choice in
        1)
            HISTORY_MODE="rolling"
            ;;
        2)
            HISTORY_MODE="full"
            ;;
        3)
            HISTORY_MODE="archive"
            ;;
        *)
            print_error "Invalid choice. Exiting..."
            exit 1
            ;;
    esac
    
    print_message "Selected history mode: ${BOLD}${HISTORY_MODE}${NC}"
    
    # Step 3: Choose data directory
    print_step "Data Directory Selection"
    echo "Choose a data directory to store the blockchain data:"
    read -p "Enter the path or press Enter for default [$HOME/tezos-${NETWORK}-${HISTORY_MODE}]: " DATA_DIR
    DATA_DIR=${DATA_DIR:-$HOME/tezos-${NETWORK}-${HISTORY_MODE}}
    
    # Make sure we have the absolute path
    DATA_DIR=$(realpath -m "$DATA_DIR")
    
    print_message "Data directory: ${BOLD}${DATA_DIR}${NC}"
    
    # Check for disk space
    available_space_check() {
        local dir_to_check=$(dirname "$DATA_DIR")
        if [ -d "$dir_to_check" ]; then
            AVAILABLE_SPACE=$(df -B1 --output=avail "$dir_to_check" | tail -n 1)
            
            REQUIRED_SPACE=0
            case $HISTORY_MODE in
                "rolling") REQUIRED_SPACE=15000000000 ;; # 15GB
                "full") REQUIRED_SPACE=60000000000 ;; # 60GB
                "archive") REQUIRED_SPACE=550000000000 ;; # 550GB
            esac
            
            if [ $AVAILABLE_SPACE -lt $REQUIRED_SPACE ]; then
                REQUIRED_HR=$(human_readable_size $REQUIRED_SPACE)
                AVAILABLE_HR=$(human_readable_size $AVAILABLE_SPACE)
                print_warning "Insufficient disk space for ${HISTORY_MODE} mode."
                print_warning "Required: ${REQUIRED_HR}, Available: ${AVAILABLE_HR}"
                read -p "Do you want to continue anyway? (y/N): " continue_choice
                if [[ ! $continue_choice =~ ^[Yy]$ ]]; then
                    print_message "Operation cancelled by the user."
                    exit 0
                fi
            fi
        else
            print_warning "Cannot check available space for non-existent directory path."
            print_warning "Please ensure you have enough disk space for ${HISTORY_MODE} mode."
        fi
    }
    
    available_space_check
    
    # Step 4: Create data directory and set proper permissions
    if [ -d "$DATA_DIR" ]; then
        print_warning "The directory already exists. This might overwrite existing data."
        read -p "Do you want to continue? (y/N): " continue_choice
        if [[ ! $continue_choice =~ ^[Yy]$ ]]; then
            print_message "Operation cancelled by the user."
            exit 0
        fi
    else
        mkdir -p "$DATA_DIR"
        print_message "Created data directory."
    fi
    
    # Set proper permissions for the data directory
    if ! set_directory_permissions "$DATA_DIR"; then
        exit 1
    fi
    
    # Step 5: Initialize node configuration
    print_step "Node Configuration"
    print_message "Initializing node configuration..."
    
    # Determine if we should use the current user ID or the default
    USE_CURRENT_USER=false
    
    if [ "$USE_CURRENT_USER" = true ]; then
        # Option 1: Run Docker as the current user
        USER_ID=$(id -u)
        GROUP_ID=$(id -g)
        
        docker run --rm \
          --user $USER_ID:$GROUP_ID \
          --volume "$DATA_DIR:/home/tezos/.tezos-node" \
          tezos/tezos-bare:latest \
          octez-node config init --network $NETWORK --rpc-addr 0.0.0.0 \
            --history-mode $HISTORY_MODE
    else
        # Option 2: Use the default 'tezos' user in the container (with proper permissions set)
        docker run --rm \
          --volume "$DATA_DIR:/home/tezos/.tezos-node" \
          tezos/tezos-bare:latest \
          octez-node config init --network $NETWORK --rpc-addr 0.0.0.0 \
            --history-mode $HISTORY_MODE
    fi
    
    if [ $? -ne 0 ]; then
        print_error "Failed to initialize node configuration. Exiting..."
        exit 1
    fi
    
    print_message "Node configuration initialized successfully."
    
    # Step 6: Download snapshot
    print_step "Snapshot Download"
    print_message "Finding and downloading snapshot for ${NETWORK} in ${HISTORY_MODE} mode..."
    SNAPSHOT_URL=$(get_snapshot_url $NETWORK $HISTORY_MODE)
    SNAPSHOT_FILE="$HOME/${NETWORK}-${HISTORY_MODE}-snapshot"
    TEMP_FILES+=("$SNAPSHOT_FILE")
    
    print_message "Snapshot URL: $SNAPSHOT_URL"
    print_message "This may take some time depending on your internet connection..."
    
    # Create a temporary file to track the download progress
    PROGRESS_FILE=$(mktemp)
    TEMP_FILES+=("$PROGRESS_FILE")
    
    # Use wget with progress options and redirect output to the progress file
    wget -O "$SNAPSHOT_FILE" "$SNAPSHOT_URL" 2>&1 | tee "$PROGRESS_FILE" &
    WGET_PID=$!
    BACKGROUND_PIDS+=($WGET_PID)
    
    # Show progress by reading from the progress file
    while ps -p $WGET_PID > /dev/null; do
        if [ -f "$PROGRESS_FILE" ]; then
            PROGRESS=$(tail -n 2 "$PROGRESS_FILE" | grep -oP '\d+%' | tail -n 1)
            if [ ! -z "$PROGRESS" ]; then
                echo -ne "Download progress: $PROGRESS\r"
            fi
        fi
        sleep 1
    done
    echo -ne "Download progress: 100%\r"
    echo ""
    
    wait $WGET_PID
    WGET_STATUS=$?
    
    if [ $WGET_STATUS -ne 0 ] || [ ! -f "$SNAPSHOT_FILE" ] || [ ! -s "$SNAPSHOT_FILE" ]; then
        print_error "Failed to download snapshot. Exiting..."
        exit 1
    fi
    
    print_message "Snapshot downloaded successfully."
    
    # Step 7: Import snapshot
    print_step "Snapshot Import"
    print_message "Importing snapshot..."
    print_message "This may take some time depending on your hardware..."
    
    if [ "$USE_CURRENT_USER" = true ]; then
        # Option 1: Run Docker as the current user
        USER_ID=$(id -u)
        GROUP_ID=$(id -g)
        
        docker run --rm \
          --user $USER_ID:$GROUP_ID \
          --volume "$DATA_DIR:/home/tezos/.tezos-node" \
          --volume "$SNAPSHOT_FILE:/snapshot:ro" \
          tezos/tezos-bare:latest \
          octez-node snapshot import /snapshot
    else
        # Option 2: Use the default 'tezos' user in the container (with proper permissions set)
        docker run --rm \
          --volume "$DATA_DIR:/home/tezos/.tezos-node" \
          --volume "$SNAPSHOT_FILE:/snapshot:ro" \
          tezos/tezos-bare:latest \
          octez-node snapshot import /snapshot
    fi
    
    if [ $? -ne 0 ]; then
        print_error "Failed to import snapshot. Exiting..."
        exit 1
    fi
    
    print_message "Snapshot imported successfully."
    
    # Step 8: Start the node
    print_step "Node Startup"
    CONTAINER_NAME="tezos-${NETWORK}-${HISTORY_MODE}"
    
    # Check if a container with this name already exists and remove it
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_warning "A container named ${CONTAINER_NAME} already exists. Removing it..."
        docker rm -f ${CONTAINER_NAME} >/dev/null
    fi
    
    print_message "Starting the node..."
    if [ "$USE_CURRENT_USER" = true ]; then
        # Option 1: Run Docker as the current user
        USER_ID=$(id -u)
        GROUP_ID=$(id -g)
        
        docker run --name ${CONTAINER_NAME} -d \
          --user $USER_ID:$GROUP_ID \
          --volume "$DATA_DIR:/home/tezos/.tezos-node" \
          -p 8732:8732 \
          tezos/tezos-bare:latest \
          octez-node run --rpc-addr 0.0.0.0:8732
    else
        # Option 2: Use the default 'tezos' user in the container (with proper permissions set)
        docker run --name ${CONTAINER_NAME} -d \
          --volume "$DATA_DIR:/home/tezos/.tezos-node" \
          -p 8732:8732 \
          tezos/tezos-bare:latest \
          octez-node run --rpc-addr 0.0.0.0:8732
    fi
    
    if [ $? -ne 0 ]; then
        print_error "Failed to start the node. Exiting..."
        exit 1
    fi
    
    print_message "Node started successfully."
    
    # Step 9: Wait for the node to bootstrap
    print_step "Node Bootstrapping"
    print_message "Waiting for the node to bootstrap..."
    echo "This might take a while. Press Ctrl+C to stop following logs (the node will continue running)."
    echo ""
    
    # Follow the logs
    docker logs -f ${CONTAINER_NAME} &
    LOG_PID=$!
    BACKGROUND_PIDS+=($LOG_PID)
    
    # Check if the node is bootstrapped every 30 seconds
    BOOTSTRAP_COUNTER=0
    MAX_CHECKS=60  # 30 minutes max wait time (60 * 30 seconds)
    
    while [ $BOOTSTRAP_COUNTER -lt $MAX_CHECKS ]; do
        BOOTSTRAP_COUNTER=$((BOOTSTRAP_COUNTER + 1))
        
        if docker exec ${CONTAINER_NAME} octez-client bootstrapped 2>/dev/null; then
            kill $LOG_PID 2>/dev/null
            print_message "Node is bootstrapped!"
            break
        fi
        
        # Check if the node is still running
        if ! docker ps | grep -q ${CONTAINER_NAME}; then
            kill $LOG_PID 2>/dev/null
            print_error "Node container stopped unexpectedly. Check the logs for errors:"
            docker logs ${CONTAINER_NAME} | tail -n 50
            exit 1
        fi
        
        # After 5 minutes, provide an update
        if [ $BOOTSTRAP_COUNTER -eq 10 ]; then
            kill $LOG_PID 2>/dev/null
            print_message "The node is still bootstrapping. This process can take some time."
            print_message "Continuing to follow logs..."
            docker logs -f ${CONTAINER_NAME} &
            LOG_PID=$!
            BACKGROUND_PIDS+=($LOG_PID)
        fi
        
        sleep 30
    done
    
    # If we've reached the maximum number of checks and the node is still not bootstrapped
    if [ $BOOTSTRAP_COUNTER -ge $MAX_CHECKS ]; then
        kill $LOG_PID 2>/dev/null
        print_warning "The node is taking longer than expected to bootstrap."
        print_warning "This is normal for some networks or history modes."
        print_message "The node is still running and will continue bootstrapping in the background."
    fi
    
    # Step 10: Provide summary
    print_step "Setup Complete!"
    echo -e "${BOLD}=============================================${NC}"
    echo -e "${BOLD}   Tezos Node Setup Complete!               ${NC}"
    echo -e "${BOLD}=============================================${NC}"
    echo ""
    echo -e "Network:      ${BOLD}${NETWORK}${NC}"
    echo -e "History Mode: ${BOLD}${HISTORY_MODE}${NC}"
    echo -e "Data Dir:     ${BOLD}${DATA_DIR}${NC}"
    echo -e "Container:    ${BOLD}${CONTAINER_NAME}${NC}"
    echo -e "RPC Endpoint: ${BOLD}http://localhost:8732${NC}"
    echo ""
    echo "Useful commands:"
    echo -e "  ${YELLOW}docker logs -f ${CONTAINER_NAME}${NC}  - Follow node logs"
    echo -e "  ${YELLOW}docker exec ${CONTAINER_NAME} octez-client bootstrapped${NC}  - Check if node is bootstrapped"
    echo -e "  ${YELLOW}docker stop ${CONTAINER_NAME}${NC}  - Stop the node"
    echo -e "  ${YELLOW}docker start ${CONTAINER_NAME}${NC}  - Start the node"
    echo -e "  ${YELLOW}docker rm -f ${CONTAINER_NAME}${NC}  - Remove the container"
    echo ""
    
    # Clean up the snapshot file
    if [ -f "$SNAPSHOT_FILE" ]; then
        print_message "Cleaning up snapshot file..."
        rm -f "$SNAPSHOT_FILE"
    fi
    
    print_message "Thank you for using the Tezos Node Setup Script!"
}

# Run the main function
main