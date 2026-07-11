#!/bin/sh
# OpenWrt/BusyBox 只读网络探针。由控制端通过 SSH stdin 执行。

OK_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

ok() { OK_COUNT=$((OK_COUNT + 1)); printf '[OK]   %s\n' "$1"; }
warn() { WARN_COUNT=$((WARN_COUNT + 1)); printf '[WARN] %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf '[!]    %s\n' "$1"; }

has_cmd() { command -v "$1" >/dev/null 2>&1; }

resolve_a() {
    domain="$1"
    server="$2"
    if has_cmd dig; then
        dig +time=3 +tries=1 +short "@${server}" "$domain" A 2>/dev/null \
            | awk '/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ { print; exit }'
    else
        nslookup "$domain" "$server" 2>/dev/null \
            | awk '/^Address [0-9]+: / {print $3} /^Address: / {print $2}' \
            | awk -v dns="$server" '$0 != dns && $0 != "127.0.0.1" {print; exit}'
    fi
}

printf '%s\n' '=== homelab-doctor OpenWrt network probe ==='
date

for service in 'AdGuardHome' '/etc/openclash/clash' 'openvpn.*ovpnserver'; do
    if pgrep -f "$service" >/dev/null 2>&1; then
        ok "进程存在：${service}"
    else
        warn "未发现进程：${service}"
    fi
done

for port in 53 7874; do
    if netstat -ln 2>/dev/null | grep -Eq "[:.]${port}[[:space:]]"; then
        ok "端口 ${port} 正在监听"
    else
        fail "端口 ${port} 未监听"
    fi
done

DNS_RESULT=$(resolve_a "$SPLIT_DOMAIN" "$DNS_SERVER")
if [ "$DNS_RESULT" = "$SPLIT_EXPECTED_IP" ]; then
    ok "split-DNS：${SPLIT_DOMAIN} → ${DNS_RESULT}"
elif [ -z "$DNS_RESULT" ]; then
    fail "split-DNS：${SPLIT_DOMAIN} 无 A 记录"
else
    fail "split-DNS：${SPLIT_DOMAIN} → ${DNS_RESULT}，期望 ${SPLIT_EXPECTED_IP}"
fi

if has_cmd curl; then
    HTTP_CODE=$(curl -kLsS -o /dev/null -w '%{http_code}' \
        --resolve "${SPLIT_DOMAIN}:443:${SPLIT_EXPECTED_IP}" \
        --connect-timeout 5 --max-time 12 "$SERVICE_URL" 2>/dev/null)
    case "$HTTP_CODE" in
        200|301|302|401|403) ok "服务可达：HTTP ${HTTP_CODE}" ;;
        000|'') warn "路由器自身访问服务失败；需要客户端侧复测" ;;
        *) warn "服务返回 HTTP ${HTTP_CODE}" ;;
    esac
else
    warn '缺少 curl，跳过服务测试'
fi

RUNTIME_CONFIG=""
if has_cmd uci; then
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
else
    warn '无法定位 OpenClash 当前运行配置'
fi

OVPN_CONFIG='/tmp/ovpnserver/ovpnserver'
if [ -f "$OVPN_CONFIG" ]; then
    if grep -Eq "push .*dhcp-option DNS ${VPN_DNS}" "$OVPN_CONFIG"; then
        ok "OpenVPN 已下发 DNS：${VPN_DNS}"
    else
        warn "OpenVPN 未下发 DNS：${VPN_DNS}"
    fi
else
    warn '找不到 OpenVPN 运行配置'
fi

if ip route show 2>/dev/null | grep -Fq "${VPN_SUBNET%/*}"; then
    ok "发现 VPN 子网路由：${VPN_SUBNET}"
else
    warn "未发现 VPN 子网路由：${VPN_SUBNET}"
fi

COUNT=$(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null)
MAX=$(cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null)
if [ -n "$COUNT" ] && [ -n "$MAX" ] && [ "$MAX" -gt 0 ] 2>/dev/null; then
    PERCENT=$((COUNT * 100 / MAX))
    if [ "$PERCENT" -lt 70 ]; then
        ok "conntrack ${COUNT}/${MAX}（${PERCENT}%）"
    else
        warn "conntrack ${COUNT}/${MAX}（${PERCENT}%）"
    fi
fi

printf '%s\n' "SUMMARY ok=${OK_COUNT} warn=${WARN_COUNT} fail=${FAIL_COUNT}"
[ "$FAIL_COUNT" -eq 0 ]
