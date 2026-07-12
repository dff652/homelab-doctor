#!/bin/sh
# 扫描仓库中的敏感模式；仅使用已跟踪文件，不依赖真实设备凭据。
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

# 只检查 git 跟踪文件，避免扫描本地 gitignored 配置。
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf '[!] 不在 git 仓库中，跳过敏感模式扫描\n' >&2
    exit 1
fi

fail=0

# 私钥与常见 secret 字面量。
if git grep -nI -E \
    'BEGIN (RSA |OPENSSH |EC |DSA )?PRIVATE KEY|AKIA[0-9A-Z]{16}|xox[baprs]-[0-9A-Za-z-]{10,}' \
    -- . \
    ':(exclude)scripts/check-sensitive.sh' \
    ':(exclude)docs/**' \
    ':(exclude)README.md' \
    ':(exclude)SECURITY.md' \
    2>/dev/null; then
    printf '[!] 发现疑似私钥或云密钥模式\n' >&2
    fail=1
else
    printf '[OK]   无私钥/云密钥模式\n'
fi

# 常见 token/password 赋值（排除示例与文档说明）。
if git grep -nI -E \
    '(^|[^A-Za-z_])(password|passwd|api_?key|secret|token|private_key)[[:space:]]*=[[:space:]]*[^#[:space:]]+' \
    -- . \
    ':(exclude)scripts/check-sensitive.sh' \
    ':(exclude)docs/**' \
    ':(exclude)README.md' \
    ':(exclude)SECURITY.md' \
    ':(exclude)LICENSE' \
    2>/dev/null; then
    printf '[!] 发现疑似明文 secret 赋值\n' >&2
    fail=1
else
    printf '[OK]   无明文 secret 赋值\n'
fi

# 订阅链接常见前缀（公开仓不应出现真实订阅）。
if git grep -nI -E 'subscription-userinfo:|clash://install-config|vmess://|vless://|trojan://' \
    -- . \
    ':(exclude)scripts/check-sensitive.sh' \
    2>/dev/null; then
    printf '[!] 发现疑似代理订阅或安装链接\n' >&2
    fail=1
else
    printf '[OK]   无订阅/代理链接模式\n'
fi

if [ "$fail" -ne 0 ]; then
    printf '[!] 敏感模式检查失败\n' >&2
    exit 1
fi

printf '[OK]   敏感模式检查通过\n'
