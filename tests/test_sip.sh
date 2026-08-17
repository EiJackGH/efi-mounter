#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${REPO_DIR}/lib/errors.sh"

# Override exit in raise_error so test process doesn't exit prematurely
raise_error() {
    local CODE="$1"
    local DETAILS="$2"
    echo "RAISED_ERROR:${CODE}"
    return 1
}

source "${REPO_DIR}/lib/disk.sh"

TEST_FAILED=0

# Test 1: When csrutil command is not found, check_sip_status returns 0
csrutil() {
    return 127
}
export -f csrutil

OUTPUT=$(check_sip_status 2>&1 || true)
if [ -n "$OUTPUT" ]; then
    echo "[FAIL] Test 1: Expected no output when csrutil missing, got: $OUTPUT"
    TEST_FAILED=1
else
    echo "[PASS] Test 1: Handled missing csrutil gracefully."
fi

# Test 2: When csrutil reports SIP enabled, check_sip_status calls raise_error ERR_106
csrutil() {
    echo "System Integrity Protection status: enabled."
}

OUTPUT=$(check_sip_status 2>&1 || true)
if [[ "$OUTPUT" == *"RAISED_ERROR:ERR_106"* ]]; then
    echo "[PASS] Test 2: Correctly raised ERR_106 when SIP status is enabled."
else
    echo "[FAIL] Test 2: Expected ERR_106 when SIP enabled, got: $OUTPUT"
    TEST_FAILED=1
fi

# Test 3: When csrutil reports SIP disabled, check_sip_status passes
csrutil() {
    echo "System Integrity Protection status: disabled."
}

OUTPUT=$(check_sip_status 2>&1 || true)
if [ -n "$OUTPUT" ]; then
    echo "[FAIL] Test 3: Expected no error when SIP disabled, got: $OUTPUT"
    TEST_FAILED=1
else
    echo "[PASS] Test 3: Passed when SIP status is disabled."
fi

if [ $TEST_FAILED -ne 0 ]; then
    echo "Tests failed."
    exit 1
else
    echo "All tests passed successfully."
    exit 0
fi
