#!/bin/bash

# Unit tests for ClamAV scripts

# Source test helpers
source "$(dirname "$0")/../test_helpers.sh"

# Test variables
SCRIPT_DIR="$(dirname "$0")/../../common/clamav"
CLAMAV_STATUS_SCRIPT="$SCRIPT_DIR/clamav-status-detailed.sh"
CLAMAV_LOG_SCRIPT="$SCRIPT_DIR/clamav-log-analyzer.sh"
CLAMAV_SCAN_SCRIPT="$SCRIPT_DIR/clamav-daily-scan.sh"

# Test cases
test_clamav_status_script_exists() {
    assert_file_exists "$CLAMAV_STATUS_SCRIPT" "ClamAV status script should exist"
}

test_clamav_log_script_exists() {
    assert_file_exists "$CLAMAV_LOG_SCRIPT" "ClamAV log analyzer script should exist"
}

test_clamav_scan_script_exists() {
    assert_file_exists "$CLAMAV_SCAN_SCRIPT" "ClamAV daily scan script should exist"
}

test_clamav_status_script_executable() {
    assert_command_exists "clamscan" "clamscan command should be available"
    assert_command_exists "freshclam" "freshclam command should be available"
}

test_clamav_log_analyzer_output_format() {
    # Test JSON output
    local json_output
    json_output=$("$CLAMAV_LOG_SCRIPT" json)
    assert_equals "0" "$?" "JSON output should succeed"
    assert_not_equals "" "$json_output" "JSON output should not be empty"
    
    # Test text output
    local text_output
    text_output=$("$CLAMAV_LOG_SCRIPT" text)
    assert_equals "0" "$?" "Text output should succeed"
    assert_not_equals "" "$text_output" "Text output should not be empty"
}

test_clamav_daily_scan_logging() {
    # Create test log directory
    local test_log_dir="$TEST_DIR/log"
    mkdir -p "$test_log_dir"
    
    # Mock the log file path
    local original_logfile
    original_logfile=$(grep "LOGFILE=" "$CLAMAV_SCAN_SCRIPT" | cut -d'=' -f2)
    sed -i "s|$original_logfile|$test_log_dir/daily-scan.log|" "$CLAMAV_SCAN_SCRIPT"
    
    # Run the scan script
    "$CLAMAV_SCAN_SCRIPT"
    
    # Check if log file was created
    assert_file_exists "$test_log_dir/daily-scan.log" "Scan log file should be created"
    
    # Restore original log file path
    sed -i "s|$test_log_dir/daily-scan.log|$original_logfile|" "$CLAMAV_SCAN_SCRIPT"
}

# Run all test cases
echo "Running ClamAV script tests..."

run_test_case "ClamAV Status Script Exists" test_clamav_status_script_exists
run_test_case "ClamAV Log Script Exists" test_clamav_log_script_exists
run_test_case "ClamAV Scan Script Exists" test_clamav_scan_script_exists
run_test_case "ClamAV Status Script Executable" test_clamav_status_script_executable
run_test_case "ClamAV Log Analyzer Output Format" test_clamav_log_analyzer_output_format
run_test_case "ClamAV Daily Scan Logging" test_clamav_daily_scan_logging

# Exit with appropriate status
if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}All ClamAV script tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some ClamAV script tests failed!${NC}"
    exit 1
fi 