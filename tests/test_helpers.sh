#!/bin/bash

# Test helper functions for security toolkit tests

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Expected $expected but got $actual}"
    
    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓ Assertion passed: $message${NC}"
        return 0
    else
        echo -e "${RED}✗ Assertion failed: $message${NC}"
        return 1
    fi
}

assert_not_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Expected different from $expected but got $actual}"
    
    if [ "$expected" != "$actual" ]; then
        echo -e "${GREEN}✓ Assertion passed: $message${NC}"
        return 0
    else
        echo -e "${RED}✗ Assertion failed: $message${NC}"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File $file should exist}"
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ Assertion passed: $message${NC}"
        return 0
    else
        echo -e "${RED}✗ Assertion failed: $message${NC}"
        return 1
    fi
}

assert_directory_exists() {
    local dir="$1"
    local message="${2:-Directory $dir should exist}"
    
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓ Assertion passed: $message${NC}"
        return 0
    else
        echo -e "${RED}✗ Assertion failed: $message${NC}"
        return 1
    fi
}

assert_command_exists() {
    local cmd="$1"
    local message="${2:-Command $cmd should exist}"
    
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Assertion passed: $message${NC}"
        return 0
    else
        echo -e "${RED}✗ Assertion failed: $message${NC}"
        return 1
    fi
}

assert_exit_code() {
    local expected_code="$1"
    local actual_code="$2"
    local message="${3:-Expected exit code $expected_code but got $actual_code}"
    
    if [ "$expected_code" = "$actual_code" ]; then
        echo -e "${GREEN}✓ Assertion passed: $message${NC}"
        return 0
    else
        echo -e "${RED}✗ Assertion failed: $message${NC}"
        return 1
    fi
}

# Test setup and teardown functions
setup_test() {
    local test_name="$1"
    echo -e "\n${YELLOW}Setting up test: $test_name${NC}"
    # Create temporary directory for test
    TEST_DIR=$(mktemp -d)
    export TEST_DIR
}

teardown_test() {
    echo -e "\n${YELLOW}Cleaning up test${NC}"
    # Remove temporary directory
    rm -rf "$TEST_DIR"
}

# Mock functions for testing
mock_command() {
    local cmd="$1"
    local output="$2"
    local exit_code="${3:-0}"
    
    # Create mock function
    eval "$cmd() { echo \"$output\"; return $exit_code; }"
    export -f "$cmd"
}

# Utility functions
create_test_file() {
    local file="$1"
    local content="$2"
    
    echo "$content" > "$file"
    chmod +x "$file"
}

# Load test fixtures
load_fixture() {
    local fixture_name="$1"
    local fixture_file="tests/fixtures/$fixture_name.sh"
    
    if [ -f "$fixture_file" ]; then
        source "$fixture_file"
    else
        echo -e "${RED}Fixture not found: $fixture_file${NC}"
        return 1
    fi
}

# Test runner functions
run_test_case() {
    local test_name="$1"
    local test_function="$2"
    
    echo -e "\n${YELLOW}Running test case: $test_name${NC}"
    
    setup_test "$test_name"
    
    if $test_function; then
        echo -e "${GREEN}✓ Test case passed: $test_name${NC}"
        teardown_test
        return 0
    else
        echo -e "${RED}✗ Test case failed: $test_name${NC}"
        teardown_test
        return 1
    fi
} 