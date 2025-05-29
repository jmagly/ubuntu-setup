#!/bin/bash

# Unit tests for Fail2ban scripts

# Source test helpers
source "$(dirname "$0")/../test_helpers.sh"

# Test variables
SCRIPT_DIR="$(dirname "$0")/../../common/fail2ban"
F2B_GEOBAN_SCRIPT="$SCRIPT_DIR/f2b-geoban.sh"
F2B_REPORT_SCRIPT="$SCRIPT_DIR/f2b-report-module.sh"
F2B_SUMMARY_SCRIPT="$SCRIPT_DIR/f2b-summary.sh"
UPDATE_GEOIP_SCRIPT="$SCRIPT_DIR/update-geoip.sh"

# Test cases
test_fail2ban_scripts_exist() {
    assert_file_exists "$F2B_GEOBAN_SCRIPT" "Fail2ban geoban script should exist"
    assert_file_exists "$F2B_REPORT_SCRIPT" "Fail2ban report script should exist"
    assert_file_exists "$F2B_SUMMARY_SCRIPT" "Fail2ban summary script should exist"
    assert_file_exists "$UPDATE_GEOIP_SCRIPT" "GeoIP update script should exist"
}

test_fail2ban_commands_exist() {
    assert_command_exists "fail2ban-client" "fail2ban-client command should be available"
    assert_command_exists "geoiplookup" "geoiplookup command should be available"
}

test_f2b_geoban_output_formats() {
    # Test table output
    local table_output
    table_output=$("$F2B_GEOBAN_SCRIPT" -t 5)
    assert_equals "0" "$?" "Table output should succeed"
    assert_not_equals "" "$table_output" "Table output should not be empty"
    
    # Test CSV output
    local csv_output
    csv_output=$("$F2B_GEOBAN_SCRIPT" -t 5 -f csv)
    assert_equals "0" "$?" "CSV output should succeed"
    assert_not_equals "" "$csv_output" "CSV output should not be empty"
    
    # Test JSON output
    local json_output
    json_output=$("$F2B_GEOBAN_SCRIPT" -t 5 -f json)
    assert_equals "0" "$?" "JSON output should succeed"
    assert_not_equals "" "$json_output" "JSON output should not be empty"
}

test_f2b_report_module() {
    # Test text report
    local text_output
    text_output=$("$F2B_REPORT_SCRIPT" text)
    assert_equals "0" "$?" "Text report should succeed"
    assert_not_equals "" "$text_output" "Text report should not be empty"
    
    # Test JSON report
    local json_output
    json_output=$("$F2B_REPORT_SCRIPT" json)
    assert_equals "0" "$?" "JSON report should succeed"
    assert_not_equals "" "$json_output" "JSON report should not be empty"
}

test_f2b_summary_output() {
    local summary_output
    summary_output=$("$F2B_SUMMARY_SCRIPT")
    assert_equals "0" "$?" "Summary output should succeed"
    assert_not_equals "" "$summary_output" "Summary output should not be empty"
}

test_geoip_update() {
    # Create test GeoIP directory
    local test_geoip_dir="$TEST_DIR/GeoIP"
    mkdir -p "$test_geoip_dir"
    
    # Mock the GeoIP database path
    local original_geoip_path
    original_geoip_path=$(grep -r "/usr/share/GeoIP" "$UPDATE_GEOIP_SCRIPT" | head -1 | cut -d'"' -f2)
    sed -i "s|$original_geoip_path|$test_geoip_dir|" "$UPDATE_GEOIP_SCRIPT"
    
    # Run the update script
    "$UPDATE_GEOIP_SCRIPT"
    
    # Check if GeoIP database was created
    assert_directory_exists "$test_geoip_dir" "GeoIP directory should be created"
    
    # Restore original GeoIP path
    sed -i "s|$test_geoip_dir|$original_geoip_path|" "$UPDATE_GEOIP_SCRIPT"
}

# Run all test cases
echo "Running Fail2ban script tests..."

run_test_case "Fail2ban Scripts Exist" test_fail2ban_scripts_exist
run_test_case "Fail2ban Commands Exist" test_fail2ban_commands_exist
run_test_case "Fail2ban Geoban Output Formats" test_f2b_geoban_output_formats
run_test_case "Fail2ban Report Module" test_f2b_report_module
run_test_case "Fail2ban Summary Output" test_f2b_summary_output
run_test_case "GeoIP Update" test_geoip_update

# Exit with appropriate status
if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}All Fail2ban script tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some Fail2ban script tests failed!${NC}"
    exit 1
fi 