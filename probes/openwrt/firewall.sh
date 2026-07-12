#!/bin/sh
# 防火墙只读模块：兼容 fw4/nftables 与 fw3/iptables，不硬编码接口或区域名。

# 判断 nftables 输出是否包含可用防火墙表（OpenWrt fw4 或通用 filter）。
fw_nft_has_table() {
    printf '%s\n' "$1" | grep -Eq \
        'table[[:space:]]+inet[[:space:]]+fw4|table[[:space:]]+ip[[:space:]]+filter|table[[:space:]]+inet[[:space:]]+filter'
}

# 判断 nftables 输出是否包含实际规则动作（忽略 chain 的 policy 声明）。
fw_nft_has_rules() {
    printf '%s\n' "$1" | grep -v 'policy' | grep -Eq \
        '[[:space:]](accept|drop|reject|jump|goto|masquerade|snat|dnat)([[:space:];]|$)'
}

# 判断 iptables -S 输出是否包含链定义或策略。
fw_ipt_has_table() {
    printf '%s\n' "$1" | grep -Eq '^-P[[:space:]]|^-N[[:space:]]|^-A[[:space:]]'
}

# 判断 iptables 是否已有具体规则（而非仅默认策略）。
fw_ipt_has_rules() {
    printf '%s\n' "$1" | grep -Eq '^-A[[:space:]]'
}

probe_firewall() {
    printf '%s\n' '--- Firewall ---'

    has_nft=0
    has_ipt=0
    has_cmd nft && has_nft=1
    has_cmd iptables && has_ipt=1

    if [ "$has_nft" -eq 0 ] && [ "$has_ipt" -eq 0 ]; then
        warn '缺少 nft/iptables，无法探测防火墙'
        return 0
    fi

    backend=''
    ruleset=''

    if [ "$has_nft" -eq 1 ]; then
        ruleset=$(nft list ruleset 2>/dev/null || true)
        if fw_nft_has_table "$ruleset"; then
            backend=nft
        fi
    fi

    if [ -z "$backend" ] && [ "$has_ipt" -eq 1 ]; then
        ruleset=$(iptables -S 2>/dev/null || true)
        if fw_ipt_has_table "$ruleset"; then
            backend=iptables
        fi
    fi

    if [ -z "$backend" ]; then
        # 工具在 PATH 中但读不到表：能力不足，非明确规则缺失。
        warn '无法读取防火墙规则表（nft/iptables 无可用输出）'
        return 0
    fi

    if [ "$backend" = nft ]; then
        ok '检测到 nftables 防火墙表'
        if fw_nft_has_rules "$ruleset"; then
            ok 'nftables 规则已加载'
        else
            fail 'nftables 表存在但未见有效规则'
        fi
        return 0
    fi

    ok '检测到 iptables/fw3 过滤表'
    # zone_* 为 OpenWrt 常见命名，仅作存在性提示，不绑定具体区域。
    if printf '%s\n' "$ruleset" | grep -Eq '^-N[[:space:]]+zone_|^-A[[:space:]]+zone_'; then
        ok '发现 OpenWrt zone_* 链'
    fi
    if fw_ipt_has_rules "$ruleset"; then
        ok 'iptables 规则已加载'
    else
        fail 'iptables 过滤表无有效规则'
    fi
}
