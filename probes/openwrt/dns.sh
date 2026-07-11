#!/bin/sh
# DNS 与 split-DNS 模块。

probe_dns() {
    printf '%s\n' '--- DNS ---'

    if pgrep -f 'AdGuardHome' >/dev/null 2>&1; then
        ok 'AdGuard Home 进程存在'
    else
        warn '未发现 AdGuard Home 进程'
    fi

    if port_is_listening 53; then
        ok 'DNS 端口 53 正在监听'
    else
        fail 'DNS 端口 53 未监听'
    fi

    DNS_RESULT=$(resolve_a "$SPLIT_DOMAIN" "$DNS_SERVER")
    if [ "$DNS_RESULT" = "$SPLIT_EXPECTED_IP" ]; then
        ok "split-DNS：${SPLIT_DOMAIN} → ${DNS_RESULT}"
    elif [ -z "$DNS_RESULT" ]; then
        fail "split-DNS：${SPLIT_DOMAIN} 无 A 记录"
    else
        fail "split-DNS：${SPLIT_DOMAIN} → ${DNS_RESULT}，期望 ${SPLIT_EXPECTED_IP}"
    fi
}
