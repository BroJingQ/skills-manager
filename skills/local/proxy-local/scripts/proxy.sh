#!/bin/bash
# 代理状态管理脚本

PROXY_STATE_FILE="$HOME/.claude_proxy_state"
PROXY_URL="${CLASH_PROXY_URL:-http://127.0.0.1:7890}"

show_help() {
    echo "用法: proxy.sh [on|off|status|env]"
    echo ""
    echo "命令:"
    echo "  on      - 开启代理模式"
    echo "  off     - 关闭代理模式"
    echo "  status  - 查看代理状态"
    echo "  env     - 输出代理环境变量（用于 eval \$(proxy.sh env)）"
    echo ""
    echo "环境变量:"
    echo "  CLASH_PROXY_URL - 自定义代理地址（默认: http://127.0.0.1:7890）"
}

cmd_on() {
    echo "$PROXY_URL" > "$PROXY_STATE_FILE"
    echo "✓ 代理模式已开启"
    echo "  代理地址: $PROXY_URL"

    # 配置 GitHub CLI 代理
    if command -v gh >/dev/null 2>&1; then
        gh config set http_proxy "$PROXY_URL" 2>/dev/null || true
        gh config set https_proxy "$PROXY_URL" 2>/dev/null || true
        echo "  GitHub CLI: 已配置代理"
    fi
}

cmd_off() {
    if [ -f "$PROXY_STATE_FILE" ]; then
        rm "$PROXY_STATE_FILE"
    fi

    # 清除 GitHub CLI 代理配置
    if command -v gh >/dev/null 2>&1; then
        gh config set http_proxy "" 2>/dev/null || true
        gh config set https_proxy "" 2>/dev/null || true
        echo "  GitHub CLI: 已清除代理配置"
    fi

    echo "✓ 代理模式已关闭"
}

cmd_status() {
    if [ -f "$PROXY_STATE_FILE" ]; then
        local url=$(cat "$PROXY_STATE_FILE")
        echo "状态: 开启"
        echo "代理地址: $url"
        # 测试代理连接
        if curl -s --max-time 3 -x "$url" -I https://github.com > /dev/null 2>&1; then
            echo "连接测试: ✓ 正常"
        else
            echo "连接测试: ✗ 无法连接（请检查 Clash 是否运行）"
        fi
    else
        echo "状态: 关闭"
    fi
}

cmd_env() {
    if [ -f "$PROXY_STATE_FILE" ]; then
        local url=$(cat "$PROXY_STATE_FILE")
        echo "export HTTP_PROXY=$url"
        echo "export HTTPS_PROXY=$url"
        echo "export http_proxy=$url"
        echo "export https_proxy=$url"
    fi
}

cmd_test() {
    if [ -f "$PROXY_STATE_FILE" ]; then
        local url=$(cat "$PROXY_STATE_FILE")
        echo "测试代理连接 ($url)..."
        if curl -s --max-time 5 -x "$url" -I https://github.com > /dev/null 2>&1; then
            echo "✓ 代理工作正常"
        else
            echo "✗ 代理连接失败"
            exit 1
        fi
    else
        echo "✗ 代理未开启"
        exit 1
    fi
}

# 主逻辑
case "${1:-}" in
    on)
        cmd_on
        ;;
    off)
        cmd_off
        ;;
    status)
        cmd_status
        ;;
    env)
        cmd_env
        ;;
    test)
        cmd_test
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        cmd_status
        ;;
esac
