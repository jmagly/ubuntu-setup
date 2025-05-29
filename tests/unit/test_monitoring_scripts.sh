#!/bin/bash

# Unit tests for monitoring scripts

# Source test helpers
source "$(dirname "$0")/../test_helpers.sh"

# Test variables
SCRIPT_DIR="$(dirname "$0")/../../common/monitoring"
DAILY_SCAN_SCRIPT="$SCRIPT_DIR/daily-security-scan.sh"
NETWORK_MONITOR_SCRIPT="$SCRIPT_DIR/network-monitor.sh"
OPTIMIZE_ENTROPY_SCRIPT="$SCRIPT_DIR/optimize-entropy.sh"

# Test cases
test_monitoring_scripts_exist() {
    assert_file_exists "$DAILY_SCAN_SCRIPT" "Daily security scan script should exist"
    assert_file_exists "$NETWORK_MONITOR_SCRIPT" "Network monitor script should exist"
    assert_file_exists "$OPTIMIZE_ENTROPY_SCRIPT" "Optimize entropy script should exist"
}

test_monitoring_commands_exist() {
    assert_command_exists "rkhunter" "rkhunter command should be available"
    assert_command_exists "clamscan" "clamscan command should be available"
    assert_command_exists "chkrootkit" "chkrootkit command should be available"
    assert_command_exists "lynis" "lynis command should be available"
    assert_command_exists "ss" "ss command should be available"
}

test_daily_security_scan() {
    # Create test log directory
    local test_log_dir="$TEST_DIR/log"
    mkdir -p "$test_log_dir"
    
    # Mock the log directory path
    local original_log_dir
    original_log_dir=$(grep "LOG_DIR=" "$DAILY_SCAN_SCRIPT" | cut -d'=' -f2)
    sed -i "s|$original_log_dir|$test_log_dir|" "$DAILY_SCAN_SCRIPT"
    
    # Run the scan script
    "$DAILY_SCAN_SCRIPT"
    
    # Check if log file was created
    assert_directory_exists "$test_log_dir" "Log directory should be created"
    local log_file=$(find "$test_log_dir" -name "security-report-*.log" | head -1)
    assert_file_exists "$log_file" "Security report log file should be created"
    
    # Restore original log directory path
    sed -i "s|$test_log_dir|$original_log_dir|" "$DAILY_SCAN_SCRIPT"
}

test_network_monitor() {
    # Create test log file
    local test_log_file="$TEST_DIR/network-monitor.log"
    
    # Mock the log file path
    local original_log_file
    original_log_file=$(grep "LOGFILE=" "$NETWORK_MONITOR_SCRIPT" | cut -d'=' -f2)
    sed -i "s|$original_log_file|$test_log_file|" "$NETWORK_MONITOR_SCRIPT"
    
    # Run the monitor script
    "$NETWORK_MONITOR_SCRIPT"
    
    # Check if log file was created
    assert_file_exists "$test_log_file" "Network monitor log file should be created"
    
    # Restore original log file path
    sed -i "s|$test_log_file|$original_log_file|" "$NETWORK_MONITOR_SCRIPT"
}

test_optimize_entropy() {
    # Mock systemctl command
    mock_command "systemctl" "active" 0
    
    # Run the optimize script
    local output
    output=$("$OPTIMIZE_ENTROPY_SCRIPT")
    assert_equals "0" "$?" "Optimize entropy script should succeed"
    assert_not_equals "" "$output" "Optimize entropy output should not be empty"
}

# Run all test cases
echo "Running monitoring script tests..."

run_test_case "Monitoring Scripts Exist" test_monitoring_scripts_exist
run_test_case "Monitoring Commands Exist" test_monitoring_commands_exist
run_test_case "Daily Security Scan" test_daily_security_scan
run_test_case "Network Monitor" test_network_monitor
run_test_case "Optimize Entropy" test_optimize_entropy

# Exit with appropriate status
if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}All monitoring script tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some monitoring script tests failed!${NC}"
    exit 1
fi 