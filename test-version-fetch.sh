#!/bin/bash

# Test script to debug version fetching issues in GitHub Actions
# This script tests different methods of fetching the mitmproxy version

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Test 1: Original method
test_original_method() {
    print_info "=== Test 1: Original method ==="

    local version
    version=$(curl -s "https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest" | \
        grep '"tag_name"' | \
        cut -d'"' -f4 | \
        sed 's/^v//' | \
        tr -d '\n\r')

    print_debug "Raw version result: '$version'"
    print_debug "Version length: ${#version}"

    if [ -z "$version" ]; then
        print_error "Version is empty!"
        return 1
    else
        print_info "Version found: '$version'"
        return 0
    fi
}

# Test 2: With verbose curl
test_verbose_curl() {
    print_info "=== Test 2: Verbose curl ==="

    print_debug "Testing with verbose curl..."
    local response
    response=$(curl -v "https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest" 2>&1)
    print_debug "Curl response (first 500 chars):"
    echo "$response" | head -c 500
    echo ""

    local version
    version=$(curl -s "https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest" | \
        grep '"tag_name"' | \
        cut -d'"' -f4 | \
        sed 's/^v//' | \
        tr -d '\n\r')

    print_debug "Version from verbose test: '$version'"
}

# Test 3: Check API response directly
test_api_response() {
    print_info "=== Test 3: Check API response ==="

    local response
    response=$(curl -s "https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest")

    print_debug "API response length: ${#response}"
    print_debug "First 200 chars of response:"
    echo "$response" | head -c 200
    echo ""

    # Check if response contains tag_name
    if echo "$response" | grep -q '"tag_name"'; then
        print_info "Response contains 'tag_name' field"

        # Extract tag_name value
        local tag_name
        tag_name=$(echo "$response" | grep '"tag_name"' | cut -d'"' -f4)
        print_debug "Raw tag_name: '$tag_name'"

        # Remove 'v' prefix
        local version
        version=$(echo "$tag_name" | sed 's/^v//' | tr -d '\n\r')
        print_debug "Processed version: '$version'"

        if [ -z "$version" ]; then
            print_error "Processed version is empty!"
        else
            print_info "Final version: '$version'"
        fi
    else
        print_error "Response does not contain 'tag_name' field"
    fi
}

# Test 4: Using jq if available
test_with_jq() {
    print_info "=== Test 4: Using jq ==="

    if command -v jq >/dev/null 2>&1; then
        print_debug "jq is available, testing with jq..."

        local version
        version=$(curl -s "https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest" | \
            jq -r '.tag_name' | \
            sed 's/^v//')

        print_debug "Version from jq: '$version'"

        if [ -z "$version" ] || [ "$version" = "null" ]; then
            print_error "jq method failed or returned null"
        else
            print_info "jq version: '$version'"
        fi
    else
        print_warning "jq is not available, skipping jq test"
    fi
}

# Test 5: Check network connectivity
test_network_connectivity() {
    print_info "=== Test 5: Network connectivity ==="

    print_debug "Testing basic connectivity..."
    if ping -c 1 api.github.com >/dev/null 2>&1; then
        print_info "Ping to api.github.com successful"
    else
        print_warning "Ping to api.github.com failed"
    fi

    print_debug "Testing HTTPS connectivity..."
    if curl -s --connect-timeout 10 "https://api.github.com" >/dev/null; then
        print_info "HTTPS connection to api.github.com successful"
    else
        print_error "HTTPS connection to api.github.com failed"
    fi

    print_debug "Testing specific API endpoint..."
    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest")
    print_debug "HTTP status code: $status_code"

    if [ "$status_code" = "200" ]; then
        print_info "API endpoint returns 200 OK"
    else
        print_error "API endpoint returns status code: $status_code"
    fi
}

# Test 6: Environment variables
test_environment() {
    print_info "=== Test 6: Environment variables ==="

    print_debug "Current user: $(whoami)"
    print_debug "Current directory: $(pwd)"
    print_debug "PATH: $PATH"
    print_debug "SHELL: $SHELL"
    print_debug "TZ: ${TZ:-not set}"
    print_debug "LANG: ${LANG:-not set}"
    print_debug "LC_ALL: ${LC_ALL:-not set}"

    # Check if we're in a container
    if [ -f /.dockerenv ]; then
        print_debug "Running inside Docker container"
    else
        print_debug "Not running inside Docker container"
    fi

    # Check if we're in GitHub Actions
    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        print_debug "Running in GitHub Actions"
        print_debug "GITHUB_ACTIONS: $GITHUB_ACTIONS"
        print_debug "GITHUB_WORKFLOW: ${GITHUB_WORKFLOW:-not set}"
        print_debug "GITHUB_RUN_ID: ${GITHUB_RUN_ID:-not set}"
    else
        print_debug "Not running in GitHub Actions"
    fi
}

# Test 7: Different curl options
test_curl_options() {
    print_info "=== Test 7: Different curl options ==="

    # Test with different user agents
    print_debug "Testing with default user agent..."
    local version1
    version1=$(curl -s "https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest" | \
        grep '"tag_name"' | cut -d'"' -f4 | sed 's/^v//' | tr -d '\n\r')
    print_debug "Default UA result: '$version1'"

    print_debug "Testing with GitHub CLI user agent..."
    local version2
    version2=$(curl -s -H "User-Agent: GitHub CLI" "https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest" | \
        grep '"tag_name"' | cut -d'"' -f4 | sed 's/^v//' | tr -d '\n\r')
    print_debug "GitHub CLI UA result: '$version2'"

    print_debug "Testing with custom user agent..."
    local version3
    version3=$(curl -s -H "User-Agent: mitmproxy-installer/1.0" "https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest" | \
        grep '"tag_name"' | cut -d'"' -f4 | sed 's/^v//' | tr -d '\n\r')
    print_debug "Custom UA result: '$version3'"
}

# Main function
main() {
    print_info "Starting mitmproxy version fetch debugging..."
    print_info "Timestamp: $(date)"
    print_info "=========================================="

    # Run all tests
    test_environment
    echo ""

    test_network_connectivity
    echo ""

    test_api_response
    echo ""

    test_original_method
    echo ""

    test_verbose_curl
    echo ""

    test_with_jq
    echo ""

    test_curl_options
    echo ""

    print_info "=========================================="
    print_info "Debugging completed!"
}

# Run main function
main "$@"
