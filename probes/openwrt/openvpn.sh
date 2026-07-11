#!/bin/sh
# OpenVPN 服务端 DNS 下发与客户端子网路由模块。

probe_openvpn() {
    printf '%s\n' '--- OpenVPN ---'

    if pgrep -f 'openvpn.*ovpnserver' >/dev/null 2>&1; then
        ok 'OpenVPN server 进程存在'
    else
        warn '未发现 OpenVPN server 进程'
    fi

    OVPN_CONFIG="${HD_OVPN_CONFIG:-/tmp/ovpnserver/ovpnserver}"
    if [ -f "$OVPN_CONFIG" ]; then
        if grep -Fq "dhcp-option DNS ${VPN_DNS}" "$OVPN_CONFIG"; then
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
        fail "未发现 VPN 子网路由：${VPN_SUBNET}"
    fi
}
