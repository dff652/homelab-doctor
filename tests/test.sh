#!/bin/sh
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

pass=0
fail=0

run_ok() {
    name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        printf '[OK]   %s\n' "$name"
        pass=$((pass + 1))
    else
        printf '[!]    %s\n' "$name"
        fail=$((fail + 1))
    fi
}

run_fail() {
    name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        printf '[!]    %s（意外成功）\n' "$name"
        fail=$((fail + 1))
    else
        printf '[OK]   %s\n' "$name"
        pass=$((pass + 1))
    fi
}

cp "${ROOT}/config/example.conf" "${TMP_DIR}/valid.conf"
cp "${ROOT}/config/example.conf" "${TMP_DIR}/invalid.conf"
printf '%s\n' 'UNKNOWN_OPTION=value' >> "${TMP_DIR}/invalid.conf"

run_ok 'CLI语法' sh -n "${ROOT}/bin/homelab-doctor"
run_ok '配置解析器语法' sh -n "${ROOT}/lib/config.sh"
run_ok 'OpenWrt探针语法' sh -n "${ROOT}/probes/openwrt/network.sh"
run_ok '示例配置通过校验' "${ROOT}/bin/homelab-doctor" --config "${TMP_DIR}/valid.conf" config validate
run_fail '未知配置项被拒绝' "${ROOT}/bin/homelab-doctor" --config "${TMP_DIR}/invalid.conf" config validate

printf '%s\n' "SUMMARY pass=${pass} fail=${fail}"
[ "$fail" -eq 0 ]
