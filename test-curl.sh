#!/bin/bash

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

response=$(curl -sS -w "%{http_code}" \
    -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Safari/605.1.15" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest")

http_code="${response: -3}"
body="${response::-3}"

version=$(echo "${body}" | grep '"tag_name"' | cut -d'"' -f4 | sed 's/^v//' | tr -d '\n\r')

print_info "Fetched latest mitmproxy version: '$version'" >&2
print_info "GitHub API HTTP status code: '$http_code'" >&2
# print_info "GitHub API response body: '$body'" >&2
