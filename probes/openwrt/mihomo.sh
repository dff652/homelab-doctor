#!/bin/sh
# OpenClash/Mihomo 运行态、DIRECT 与 Fake-IP Filter 模块。

probe_mihomo() {
    printf '%s\n' '--- Mihomo / OpenClash ---'

    if pgrep -f '/etc/openclash/clash' >/dev/null 2>&1; then
        ok 'OpenClash/Mihomo 核心进程存在'
    else
        fail '未发现 OpenClash/Mihomo 核心进程'
    fi

    if port_is_listening 7874; then
        ok 'OpenClash DNS 端口 7874 正在监听'
    else
        fail 'OpenClash DNS 端口 7874 未监听'
    fi

    RUNTIME_CONFIG="${HD_MIHOMO_RUNTIME_CONFIG:-}"
    if [ -z "$RUNTIME_CONFIG" ] && has_cmd uci; then
        config_path=$(uci -q get openclash.config.config_path 2>/dev/null)
        [ -n "$config_path" ] && RUNTIME_CONFIG="/etc/openclash/$(basename "$config_path")"
    fi

    if [ -n "$RUNTIME_CONFIG" ] && [ -f "$RUNTIME_CONFIG" ]; then
        if grep -Fq "DOMAIN-SUFFIX,${DIRECT_DOMAIN_SUFFIX},DIRECT" "$RUNTIME_CONFIG"; then
            ok "DIRECT 规则已载入：${DIRECT_DOMAIN_SUFFIX}"
        else
            warn "运行配置未发现 DIRECT 规则：${DIRECT_DOMAIN_SUFFIX}"
        fi

        if grep -Fq "IP-CIDR,${LAN_CIDR},DIRECT,no-resolve" "$RUNTIME_CONFIG"; then
            ok "LAN DIRECT 规则已载入：${LAN_CIDR}"
        else
            warn "运行配置未发现 LAN DIRECT 规则：${LAN_CIDR}"
        fi

        if grep -Fq "+.${DIRECT_DOMAIN_SUFFIX}" "$RUNTIME_CONFIG"; then
            ok "Fake-IP Filter 已载入：+.${DIRECT_DOMAIN_SUFFIX}"
        else
            warn "运行配置未发现 Fake-IP Filter：+.${DIRECT_DOMAIN_SUFFIX}"
        fi
    else
        warn '无法定位 OpenClash 当前运行配置'
    fi
}
