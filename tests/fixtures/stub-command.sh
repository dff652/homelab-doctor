#!/bin/sh

command_name=${0##*/}
profile=${HD_FIXTURE_PROFILE:-ok}

case "$command_name" in
    ssh)
        if [ -n "${HD_SSH_COUNT_FILE:-}" ]; then
            printf '%s\n' ssh >> "$HD_SSH_COUNT_FILE"
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
    *)
        printf '不支持的测试桩命令：%s\n' "$command_name" >&2
        exit 127
        ;;
esac
