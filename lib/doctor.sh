#!/bin/sh

hd_probe_modules() {
    case "$1" in
        dns) printf '%s\n' 'dns' ;;
        mihomo) printf '%s\n' 'mihomo' ;;
        openvpn) printf '%s\n' 'openvpn' ;;
        router) printf '%s\n' 'dns' 'mihomo' 'openvpn' 'system' ;;
        *) return 1 ;;
    esac
}

hd_probe_bundle() {
    target="$1"
    modules=$(hd_probe_modules "$target") || return 1

    cat "${ROOT_DIR}/probes/openwrt/common.sh" || return 1
    for module in $modules; do
        cat "${ROOT_DIR}/probes/openwrt/${module}.sh" || return 1
    done

    printf '\nprobe_begin\n'
    for module in $modules; do
        printf 'probe_%s\n' "$module"
    done
    printf 'probe_summary\n'
}

hd_doctor_remote() {
    target="$1"
    hd_probe_modules "$target" >/dev/null || {
        hd_fail "未知诊断目标：${target}"
        return 2
    }

    hd_heading "连接 ${ROUTER_USER}@${ROUTER_HOST} 执行 ${target} 只读探针"
    hd_probe_bundle "$target" | ssh -o BatchMode=yes \
        -o "ConnectTimeout=${SSH_CONNECT_TIMEOUT}" \
        "${ROUTER_USER}@${ROUTER_HOST}" \
        "DNS_SERVER='${DNS_SERVER}' SPLIT_DOMAIN='${SPLIT_DOMAIN}' SPLIT_EXPECTED_IP='${SPLIT_EXPECTED_IP}' SERVICE_URL='${SERVICE_URL}' DIRECT_DOMAIN_SUFFIX='${DIRECT_DOMAIN_SUFFIX}' LAN_CIDR='${LAN_CIDR}' VPN_DNS='${VPN_DNS}' VPN_SUBNET='${VPN_SUBNET}' sh -s"
}
