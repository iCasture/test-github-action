#!/bin/bash

# Test script specifically for Docker build network issues
# This tests the exact scenario from the original docker-network-helper

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Test network connectivity first
test_network_connectivity() {
    print_info "=== Testing network connectivity ==="

    # Test basic connectivity
    if ping -c 1 api.github.com >/dev/null 2>&1; then
        print_info "✓ Ping to api.github.com successful"
    else
        print_warning "✗ Ping to api.github.com failed"
    fi

    # Test HTTPS connectivity
    if curl -s --connect-timeout 10 "https://api.github.com" >/dev/null; then
        print_info "✓ HTTPS connection to api.github.com successful"
    else
        print_error "✗ HTTPS connection to api.github.com failed"
        return 1
    fi

    # Test specific API endpoint
    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest")
    print_debug "HTTP status code: $status_code"

    if [ "$status_code" = "200" ]; then
        print_info "✓ API endpoint returns 200 OK"
    elif [ "$status_code" = "403" ]; then
        print_warning "✗ API endpoint returns 403 Forbidden - likely rate limiting or User-Agent issue"
        print_debug "This is the likely cause of the empty version issue!"
    else
        print_error "✗ API endpoint returns status code: $status_code"
        return 1
    fi
}

# Test the exact function from the original script
test_version_fetch() {
    print_info "=== Testing version fetch (exact original method) ==="

    print_info "Fetching latest mitmproxy version from GitHub API ..." >&2

    local version
    version=$(curl -s "https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest" | \
        grep '"tag_name"' | \
        cut -d'"' -f4 | \
        sed 's/^v//' | \
        tr -d '\n\r')

    print_info "Fetched latest mitmproxy version: '$version'" >&2

    if [ -z "$version" ]; then
        print_error "Failed to get version from GitHub API"
        print_debug "This is likely due to 403 Forbidden response"
        return 1
    fi

    print_info "Latest version found: $version" >&2
    echo "$version"
}

# Test with proper User-Agent
test_version_fetch_with_ua() {
    print_info "=== Testing version fetch with proper User-Agent ==="

    print_info "Fetching latest mitmproxy version from GitHub API with User-Agent ..." >&2

    local version
    version=$(curl -s -H "User-Agent: mitmproxy-installer/1.0" "https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest" | \
        grep '"tag_name"' | \
        cut -d'"' -f4 | \
        sed 's/^v//' | \
        tr -d '\n\r')

    print_info "Fetched latest mitmproxy version with UA: '$version'" >&2

    if [ -z "$version" ]; then
        print_error "Failed to get version from GitHub API even with User-Agent"
        return 1
    fi

    print_info "Latest version found with UA: $version" >&2
    echo "$version"
}

# Test with different approaches
test_alternative_methods() {
    print_info "=== Testing alternative methods ==="

    # Method 1: With timeout
    print_debug "Method 1: With timeout"
    local version1
    version1=$(timeout 30 curl -s "https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest" | \
        grep '"tag_name"' | \
        cut -d'"' -f4 | \
        sed 's/^v//' | \
        tr -d '\n\r')
    print_debug "Timeout method result: '$version1'"

    # Method 2: With retry
    print_debug "Method 2: With retry"
    local version2
    for i in {1..3}; do
        print_debug "Attempt $i"
        version2=$(curl -s --retry 3 --retry-delay 1 "https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest" | \
            grep '"tag_name"' | \
            cut -d'"' -f4 | \
            sed 's/^v//' | \
            tr -d '\n\r')
        if [ -n "$version2" ]; then
            break
        fi
        sleep 1
    done
    print_debug "Retry method result: '$version2'"

    # Method 3: With verbose output for debugging
    print_debug "Method 3: With verbose output"
    local response
    response=$(curl -v "https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest" 2>&1)
    print_debug "Verbose response (first 500 chars):"
    echo "$response" | head -c 500
    echo ""

    local version3
    version3=$(echo "$response" | grep '"tag_name"' | \
        cut -d'"' -f4 | \
        sed 's/^v//' | \
        tr -d '\n\r')
    print_debug "Verbose method result: '$version3'"
}

# Test environment variables
test_environment() {
    print_info "=== Testing environment variables ==="

    print_debug "TARGETPLATFORM: ${TARGETPLATFORM:-not set}"
    print_debug "BUILDPLATFORM: ${BUILDPLATFORM:-not set}"
    print_debug "User: $(whoami)"
    print_debug "PWD: $(pwd)"
    print_debug "PATH: $PATH"
    print_debug "SHELL: $SHELL"
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

# Main function
main() {
    print_info "Starting Docker build network debugging..."
    print_info "Timestamp: $(date)"
    print_info "=========================================="

    # Test environment
    test_environment
    echo ""

    # Test network connectivity
    if ! test_network_connectivity; then
        print_error "Network connectivity test failed!"
        exit 1
    fi
    echo ""

    # Test version fetch (original method - likely to fail)
    if version=$(test_version_fetch); then
        print_info "SUCCESS: Version fetched successfully with original method: '$version'"
    else
        print_warning "FAILED: Original method failed (expected due to 403)"
        echo ""

        # Test with User-Agent
        if version=$(test_version_fetch_with_ua); then
            print_info "SUCCESS: Version fetched successfully with User-Agent: '$version'"
        else
            print_error "FAILED: Both methods failed"
            echo ""
            test_alternative_methods
            exit 1
        fi
    fi
    echo ""

    # Test alternative methods
    test_alternative_methods
    echo ""

    print_info "=========================================="
    print_info "Docker build network debugging completed!"
}

main "$@"
