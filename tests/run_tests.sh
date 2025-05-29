#!/bin/bash

# Test runner for security toolkit scripts
# This script runs all tests and provides a summary

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Function to run a test file
run_test() {
    local test_file="$1"
    local test_name=$(basename "$test_file")
    
    echo -e "\n${YELLOW}Running test: ${test_name}${NC}"
    
    if [ ! -x "$test_file" ]; then
        chmod +x "$test_file"
    fi
    
    if "$test_file"; then
        echo -e "${GREEN}✓ Test passed: ${test_name}${NC}"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}✗ Test failed: ${test_name}${NC}"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
}

# Function to run all tests in a directory
run_test_suite() {
    local test_dir="$1"
    local test_type="$2"
    
    echo -e "\n${YELLOW}=== Running ${test_type} Tests ===${NC}"
    
    if [ ! -d "$test_dir" ]; then
        echo -e "${RED}Test directory not found: ${test_dir}${NC}"
        return 1
    fi
    
    for test_file in "$test_dir"/*.sh; do
        if [ -f "$test_file" ]; then
            run_test "$test_file"
        fi
    done
}

# Main execution
echo "Starting test suite..."

# Run unit tests
run_test_suite "tests/unit" "Unit"

# Run integration tests
run_test_suite "tests/integration" "Integration"

# Print summary
echo -e "\n${YELLOW}=== Test Summary ===${NC}"
echo "Total tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
echo -e "Skipped: ${YELLOW}$SKIPPED_TESTS${NC}"

# Exit with appropriate status
if [ $FAILED_TESTS -gt 0 ]; then
    exit 1
else
    exit 0
fi 