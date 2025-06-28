#!/bin/bash

# Test suite for assign_ips.sh

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
readonly SCRIPT_PATH="${PROJECT_DIR}/assign_ips.sh"

# Test configuration
readonly TEST_FQDN_FILE="${SCRIPT_DIR}/test_fqdns.txt"
readonly TEST_SUBNET_FILE="${SCRIPT_DIR}/test_subnets.txt"
readonly TEST_OUTPUT_FILE="${SCRIPT_DIR}/test_output.csv"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test functions
log_test() {
    echo -e "${YELLOW}[TEST]${NC} $*"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
    ((TESTS_FAILED++))
}

run_test() {
    local test_name="$1"
    shift
    ((TESTS_RUN++))
    
    log_test "Running: $test_name"
    
    if "$@"; then
        log_pass "$test_name"
        return 0
    else
        log_fail "$test_name"
        return 1
    fi
}

# Setup test files
setup_test_files() {
    cat > "$TEST_FQDN_FILE" << 'EOF'
# Test FQDN file
test01.example.com
test02.example.com
web[1-3].test.com
EOF

    cat > "$TEST_SUBNET_FILE" << 'EOF'
# Test subnet file
192.168.100.0/24
10.0.100.0/24
EOF
}

# Cleanup test files
cleanup_test_files() {
    rm -f "$TEST_FQDN_FILE" "$TEST_SUBNET_FILE" "$TEST_OUTPUT_FILE"
}

# Test cases
test_help_option() {
    "$SCRIPT_PATH" -h >/dev/null 2>&1
}

test_invalid_option() {
    ! "$SCRIPT_PATH" -x >/dev/null 2>&1
}

test_missing_required_args() {
    ! "$SCRIPT_PATH" >/dev/null 2>&1
}

test_nonexistent_file() {
    ! "$SCRIPT_PATH" -f nonexistent.txt -n "$TEST_SUBNET_FILE" >/dev/null 2>&1
}

test_valid_execution() {
    timeout 30 "$SCRIPT_PATH" -f "$TEST_FQDN_FILE" -n "$TEST_SUBNET_FILE" -s 200 -e 210 >/dev/null 2>&1
}

test_output_formats() {
    for format in csv json table; do
        timeout 30 "$SCRIPT_PATH" -f "$TEST_FQDN_FILE" -n "$TEST_SUBNET_FILE" -F "$format" -s 200 -e 210 >/dev/null 2>&1 || return 1
    done
}

test_output_file() {
    timeout 30 "$SCRIPT_PATH" -f "$TEST_FQDN_FILE" -n "$TEST_SUBNET_FILE" -o "$TEST_OUTPUT_FILE" -s 200 -e 210 >/dev/null 2>&1
    [[ -f "$TEST_OUTPUT_FILE" ]]
}

# Main test runner
main() {
    echo "Starting DNS-IP-Mapper test suite..."
    echo "Script path: $SCRIPT_PATH"
    
    # Setup
    setup_test_files
    
    # Run tests
    run_test "Help option" test_help_option
    run_test "Invalid option handling" test_invalid_option
    run_test "Missing required arguments" test_missing_required_args
    run_test "Nonexistent file handling" test_nonexistent_file
    run_test "Valid execution" test_valid_execution
    run_test "Output formats" test_output_formats
    run_test "Output file creation" test_output_file
    
    # Cleanup
    cleanup_test_files
    
    # Results
    echo
    echo "Test Results:"
    echo "  Tests run: $TESTS_RUN"
    echo "  Passed: $TESTS_PASSED"
    echo "  Failed: $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    fi
}

# Check if script exists
if [[ ! -f "$SCRIPT_PATH" ]]; then
    echo "Error: Script not found at $SCRIPT_PATH"
    exit 1
fi

# Make script executable
chmod +x "$SCRIPT_PATH"

# Run tests
main "$@"