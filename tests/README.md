# Security Toolkit Test Suite

This directory contains the test suite for the security toolkit scripts. The test suite is designed to ensure the reliability and maintainability of the scripts.

## Directory Structure

```
tests/
├── unit/              # Unit tests for individual scripts
├── integration/       # Integration tests for script interactions
├── fixtures/          # Test fixtures and mock data
├── test_helpers.sh    # Common test helper functions
└── run_tests.sh       # Test runner script
```

## Running Tests

To run all tests:

```bash
./run_tests.sh
```

To run specific test files:

```bash
./unit/test_clamav_scripts.sh
./unit/test_fail2ban_scripts.sh
./unit/test_monitoring_scripts.sh
```

## Test Categories

### Unit Tests
- Test individual script functionality
- Verify script existence and permissions
- Check command dependencies
- Validate output formats
- Test error handling

### Integration Tests
- Test script interactions
- Verify data flow between scripts
- Check system-wide functionality
- Validate configuration changes

## Writing Tests

1. Create a new test file in the appropriate directory (unit/ or integration/)
2. Source the test helpers:
   ```bash
   source "$(dirname "$0")/../test_helpers.sh"
   ```
3. Define test cases using the provided assertion functions
4. Use the `run_test_case` function to execute tests

### Available Assertions

- `assert_equals expected actual [message]`
- `assert_not_equals expected actual [message]`
- `assert_file_exists file [message]`
- `assert_directory_exists dir [message]`
- `assert_command_exists cmd [message]`
- `assert_exit_code expected actual [message]`

### Test Setup and Teardown

Use the provided functions for test setup and cleanup:

```bash
setup_test "Test Name"
# ... test code ...
teardown_test
```

### Mocking Commands

Use the `mock_command` function to mock system commands:

```bash
mock_command "systemctl" "active" 0
```

## Adding New Tests

1. Create a new test file in the appropriate directory
2. Follow the existing test file structure
3. Add test cases using the provided helper functions
4. Update this README if adding new test categories or helper functions

## Best Practices

1. Keep tests focused and atomic
2. Use meaningful test names
3. Clean up after tests
4. Mock external dependencies
5. Test both success and failure cases
6. Document complex test scenarios

## Continuous Integration

The test suite is designed to be run in CI environments. The test runner will exit with:
- 0 if all tests pass
- 1 if any test fails

## Troubleshooting

If tests fail:
1. Check if required commands are installed
2. Verify script permissions
3. Check for proper test environment setup
4. Review test output for specific failure messages 