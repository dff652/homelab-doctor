#!/bin/sh
# OpenWrt/BusyBox 只读探针公共层。由控制端与模块拼装后经 SSH stdin 执行。

OK_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

ok() {
    OK_COUNT=$((OK_COUNT + 1))
    printf '[OK]   %s\n' "$1"
}

warn() {
    WARN_COUNT=$((WARN_COUNT + 1))
    printf '[WARN] %s\n' "$1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '[!]    %s\n' "$1"
}

has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

port_is_listening() {
    netstat -ln 2>/dev/null | grep -Eq "[:.]${1}[[:space:]]"
}

resolve_a() {
    domain="$1"
    server="$2"

    if has_cmd dig; then
        dig +time=3 +tries=1 +short "@${server}" "$domain" A 2>/dev/null \
            | awk '/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ { print; exit }'
        return
    fi

    if has_cmd nslookup; then
        nslookup "$domain" "$server" 2>/dev/null \
            | awk '/^Address [0-9]+: / {print $3} /^Address: / {print $2}' \
            | awk -v dns="$server" '$0 != dns && $0 != "127.0.0.1" {print; exit}'
    fi
}

probe_begin() {
    printf '%s\n' '=== homelab-doctor OpenWrt read-only probe ==='
    date
}

probe_summary() {
    printf '%s\n' "SUMMARY ok=${OK_COUNT} warn=${WARN_COUNT} fail=${FAIL_COUNT}"
    [ "$FAIL_COUNT" -eq 0 ]
}
