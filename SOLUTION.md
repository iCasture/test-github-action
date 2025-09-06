# mitmproxy Version Fetch Issue - Solution

## 问题总结

**问题描述**：在 `docker-network-helper` 项目中，`install-mitmproxy.sh` 脚本在本地执行正常，但在 GitHub Actions 的 Docker 构建过程中返回空字符串。

**根本原因**：GitHub API 在 Docker 构建环境中返回 **403 Forbidden** 错误，导致版本获取失败。

## 问题分析

### 1. 环境差异
- **本地环境**：有适当的 User-Agent 和网络环境，GitHub API 正常响应
- **GitHub Actions 直接运行**：网络环境正常，GitHub API 正常响应  
- **Docker 构建环境**：被 GitHub API 识别为可疑请求源，返回 403 Forbidden

### 2. 具体表现
```bash
# 原始命令
version=$(curl -s "https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest" | \
    grep '"tag_name"' | \
    cut -d'"' -f4 | \
    sed 's/^v//' | \
    tr -d '\n\r')

# 结果：version 为空字符串
```

### 3. 调试发现
- HTTP 状态码：403 Forbidden
- 原因：缺少适当的 HTTP 头部信息
- 影响：导致 `grep` 无法找到 `"tag_name"` 字段

## 解决方案

### 方案 1：简单修复（推荐）

修改 `install-mitmproxy.sh` 中的 `get_latest_version()` 函数：

```bash
# 原始代码
version=$(curl -s "https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest" | \
    grep '"tag_name"' | \
    cut -d'"' -f4 | \
    sed 's/^v//' | \
    tr -d '\n\r')

# 修复后的代码
version=$(curl -s \
    -H "User-Agent: mitmproxy-installer/1.0" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest" | \
    grep '"tag_name"' | \
    cut -d'"' -f4 | \
    sed 's/^v//' | \
    tr -d '\n\r')
```

### 方案 2：增强修复（备选）

如果简单修复不够，可以使用多重回退机制：

```bash
get_latest_version() {
    print_info "Fetching latest mitmproxy version from GitHub API ..." >&2

    local version=""
    local methods=(
        "curl -s -H 'User-Agent: mitmproxy-installer/1.0' -H 'Accept: application/vnd.github.v3+json' 'https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest'"
        "curl -s -H 'User-Agent: curl/7.68.0' 'https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest'"
        "curl -s -H 'User-Agent: Docker/20.10.0' 'https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest'"
    )

    # Try each method until one succeeds
    for i in "${!methods[@]}"; do
        local method="${methods[$i]}"
        local response
        if response=$(eval "$method" 2>/dev/null); then
            if echo "$response" | grep -q '"tag_name"'; then
                version=$(echo "$response" | \
                    grep '"tag_name"' | \
                    cut -d'"' -f4 | \
                    sed 's/^v//' | \
                    tr -d '\n\r')
                
                if [ -n "$version" ]; then
                    print_info "Successfully fetched version using method $((i+1)): '$version'" >&2
                    break
                fi
            fi
        fi
        sleep 1  # Add delay between attempts
    done

    if [ -z "$version" ]; then
        print_error "Failed to get version from GitHub API"
        exit 1
    fi

    echo "$version"
}
```

## 实施建议

### 1. 立即修复
使用方案 1 的简单修复，只需要添加两个 HTTP 头部：
- `User-Agent: mitmproxy-installer/1.0`
- `Accept: application/vnd.github.v3+json`

### 2. 测试验证
1. 在本地测试修复后的脚本
2. 在 GitHub Actions 中测试
3. 验证 Docker 构建过程

### 3. 长期考虑
- 考虑使用 GitHub 官方 API 客户端
- 添加错误处理和重试机制
- 考虑使用缓存机制减少 API 调用

## 文件修改

需要修改的文件：`scripts/install-mitmproxy.sh`

修改位置：第 66-70 行的 `get_latest_version()` 函数

## 测试结果

通过测试仓库 [iCasture/test-github-action](https://github.com/iCasture/test-github-action) 验证了：
1. 问题确实存在于 Docker 构建环境中
2. 添加适当的 HTTP 头部可以解决问题
3. 修复方案在本地和 GitHub Actions 中都有效

## 总结

这是一个典型的 API 访问权限问题，通过添加适当的 HTTP 头部信息即可解决。修复简单且风险低，建议立即实施。
