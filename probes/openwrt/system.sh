#!/bin/sh
# 最终服务连通性与路由器承载模块。

probe_system() {
    printf '%s\n' '--- System / Service ---'

    if has_cmd curl; then
        HTTP_CODE=$(curl -kLsS -o /dev/null -w '%{http_code}' \
            --resolve "${SPLIT_DOMAIN}:443:${SPLIT_EXPECTED_IP}" \
            --connect-timeout 5 --max-time 12 "$SERVICE_URL" 2>/dev/null)
        case "$HTTP_CODE" in
            200|301|302|401|403) ok "最终服务可达：HTTP ${HTTP_CODE}" ;;
            000|'') warn '路由器自身访问最终服务失败；需要客户端侧复测' ;;
            *) warn "最终服务返回 HTTP ${HTTP_CODE}" ;;
        esac
    else
        warn '缺少 curl，跳过最终服务测试'
    fi

    PROC_ROOT="${HD_PROC_ROOT:-/proc}"
    COUNT=$(sed -n '1p' "${PROC_ROOT}/sys/net/netfilter/nf_conntrack_count" 2>/dev/null)
    MAX=$(sed -n '1p' "${PROC_ROOT}/sys/net/netfilter/nf_conntrack_max" 2>/dev/null)
    if [ -n "$COUNT" ] && [ -n "$MAX" ] && [ "$MAX" -gt 0 ] 2>/dev/null; then
        PERCENT=$((COUNT * 100 / MAX))
        if [ "$PERCENT" -lt 70 ]; then
            ok "conntrack ${COUNT}/${MAX}（${PERCENT}%）"
        elif [ "$PERCENT" -lt 90 ]; then
            warn "conntrack ${COUNT}/${MAX}（${PERCENT}%）偏高"
        else
            fail "conntrack ${COUNT}/${MAX}（${PERCENT}%）接近耗尽"
        fi
    else
        warn '无法读取 conntrack 使用量'
    fi
}
