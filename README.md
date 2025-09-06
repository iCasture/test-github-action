# mitmproxy Version Fetch Debug Repository

This repository is specifically created to debug the issue where the mitmproxy version fetch works locally but fails in GitHub Actions, returning an empty string.

## Problem Description

In the original `docker-network-helper` repository, the `install-mitmproxy.sh` script uses this command to fetch the latest mitmproxy version:

```bash
version=$(curl -s "https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest" | \
    grep '"tag_name"' | \
    cut -d'"' -f4 | \
    sed 's/^v//' | \
    tr -d '\n\r')
```

This works locally but returns an empty string in GitHub Actions.

## Test Scripts

### 1. `test-version-fetch.sh`
Comprehensive debugging script that tests:
- Original method
- Verbose curl output
- API response analysis
- Network connectivity
- Environment variables
- Different curl options
- jq parsing (if available)

### 2. `test-docker-build.sh`
Simplified script that replicates the exact conditions in the Dockerfile environment.

### 3. `Dockerfile.test`
Dockerfile that tests the version fetch in a Docker build environment similar to the original project.

## GitHub Actions Workflows

The `.github/workflows/debug-version-fetch.yaml` file contains multiple test jobs:

1. **debug-version-fetch**: Runs the debug script in GitHub Actions
2. **debug-in-docker**: Tests in both Alpine and Ubuntu Docker containers
3. **debug-with-different-curl-versions**: Tests with different curl versions
4. **debug-network-issues**: Tests network connectivity and DNS resolution
5. **debug-api-response-format**: Analyzes the API response format
6. **debug-timing-issues**: Tests for timing and rate limiting issues

## How to Use

1. **Local Testing**:
   ```bash
   ./test-version-fetch.sh
   ./test-docker-build.sh
   ```

2. **Docker Testing**:
   ```bash
   docker build -f Dockerfile.test -t mitmproxy-debug .
   ```

3. **GitHub Actions Testing**:
   - Push to this repository
   - The workflows will automatically run
   - Check the Actions tab for detailed logs

## Potential Issues to Investigate

1. **Network Restrictions**: GitHub Actions might have network restrictions
2. **Rate Limiting**: GitHub API might be rate limiting requests
3. **DNS Issues**: DNS resolution might be different in GitHub Actions
4. **Curl Version**: Different curl versions might behave differently
5. **Environment Variables**: Missing or different environment variables
6. **API Response Format**: The API response format might have changed
7. **Timing Issues**: Network timeouts or slow responses

## Expected Output

When working correctly, the script should output something like:
```
[INFO] Fetched latest mitmproxy version: '10.1.5'
[INFO] Latest version found: 10.1.5
```

When failing, it should output:
```
[INFO] Fetched latest mitmproxy version: ''
[ERROR] Failed to get version from GitHub API
```

## Contributing

If you find the root cause or have additional test cases, please add them to the appropriate test script or create a new test case in the GitHub Actions workflow.
