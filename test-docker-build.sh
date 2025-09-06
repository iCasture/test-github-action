#!/bin/bash

# Test script specifically for Docker build environment
# This simulates the exact conditions in the Dockerfile

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

# Function to get the latest version from GitHub API (exact copy from original script)
get_latest_version() {
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
        return 1
    fi

    print_info "Latest version found: $version" >&2
    echo "$version"
}

# Test the exact function from the original script
main() {
    print_info "Testing version fetch in Docker-like environment..."

    # Set environment variables that might be set in Docker
    export TARGETPLATFORM="${TARGETPLATFORM:-linux/amd64}"

    print_debug "Environment:"
    print_debug "  TARGETPLATFORM: $TARGETPLATFORM"
    print_debug "  User: $(whoami)"
    print_debug "  PWD: $(pwd)"
    print_debug "  PATH: $PATH"

    # Test the exact function
    if version=$(get_latest_version); then
        print_info "SUCCESS: Version fetched successfully: '$version'"
        exit 0
    else
        print_error "FAILED: Could not fetch version"
        exit 1
    fi
}

main "$@"
