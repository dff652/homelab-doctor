#!/bin/sh

command_name=${0##*/}
profile=${HD_FIXTURE_PROFILE:-ok}
# firewall 后端：空/nft（默认 fw4）、iptables/fw3、none（无输出）
fw_backend=${HD_FIREWALL_BACKEND:-}

# 解析桩脚本真实路径，定位 tests/fixtures。
stub_path=$0
if [ -L "$stub_path" ]; then
    stub_target=$(readlink "$stub_path" 2>/dev/null || true)
    case "$stub_target" in
        /*) stub_path=$stub_target ;;
        '') ;;
        *) stub_path=$(dirname "$stub_path")/$stub_target ;;
    esac
fi
FIXTURE_BASE=$(CDPATH='' cd -- "$(dirname -- "$stub_path")" && pwd)

case "$command_name" in
    ssh)
        if [ -n "${HD_SSH_COUNT_FILE:-}" ]; then
            printf '%s\n' ssh >> "$HD_SSH_COUNT_FILE"
        fi
        # 模拟 OpenSSH 传输层失败（连接/认证/超时），退出 255。
        if [ -n "${HD_SSH_FORCE_STATUS:-}" ]; then
            exit "$HD_SSH_FORCE_STATUS"
        fi
        remote_command=''
        for argument do
            remote_command=$argument
        done
        exec sh -c "$remote_command"
        ;;
    pgrep)
        case "$profile:$*" in
            fail:*) exit 1 ;;
            warn:*AdGuardHome*|warn:*openvpn*ovpnserver*) exit 1 ;;
            *) exit 0 ;;
        esac
        ;;
    netstat)
        if [ "$profile" != fail ]; then
            printf '%s\n' \
                'udp 0 0 0.0.0.0:53 0.0.0.0:*' \
                'tcp 0 0 0.0.0.0:7874 0.0.0.0:* LISTEN'
        fi
        ;;
    nslookup)
        if [ "$profile" = fail ]; then
            result='203.0.113.99'
        else
            result='192.0.2.20'
        fi
        printf 'Server: %s\nAddress 1: %s\n\nName: %s\nAddress 1: %s\n' \
            "$2" "$2" "$1" "$result"
        ;;
    dig)
        if [ "$profile" = fail ]; then
            printf '%s\n' '203.0.113.99'
        else
            printf '%s\n' '192.0.2.20'
        fi
        ;;
    curl)
        case "$profile" in
            ok) printf '200' ;;
            warn) printf '000' ;;
            fail) printf '503' ;;
        esac
        ;;
    uci)
        printf '%s\n' '/etc/openclash/fixture.yaml'
        ;;
    ip)
        if [ "$profile" != fail ]; then
            printf '%s\n' '10.8.0.0/24 dev ovpnserver scope link'
        fi
        ;;
    nft)
        case "$fw_backend" in
            iptables|fw3|none) exit 1 ;;
        esac
        case "$profile" in
            warn)
                exit 1
                ;;
            fail)
                cat "${FIXTURE_BASE}/fail/firewall/nft.ruleset"
                ;;
            *)
                cat "${FIXTURE_BASE}/ok/firewall/nft.ruleset"
                ;;
        esac
        ;;
    iptables)
        case "$fw_backend" in
            nft) exit 1 ;;
            none)
                exit 1
                ;;
            iptables|fw3)
                if [ "$profile" = fail ]; then
                    cat "${FIXTURE_BASE}/fail/firewall/iptables.rules"
                else
                    cat "${FIXTURE_BASE}/fw3/firewall/iptables.rules"
                fi
                ;;
            *)
                # 默认优先 nft：仅当 nft 不可用场景由 profile/backend 覆盖。
                # fail 且无 nft 输出时给出空策略表。
                if [ "$profile" = warn ]; then
                    exit 1
                fi
                if [ "$profile" = fail ]; then
                    # nft 已返回空表；iptables 不再抢后端
                    exit 1
                fi
                exit 1
                ;;
        esac
        ;;
    *)
        printf '不支持的测试桩命令：%s\n' "$command_name" >&2
        exit 127
        ;;
esac
