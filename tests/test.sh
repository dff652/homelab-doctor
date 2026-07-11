#!/bin/sh
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

pass=0
fail=0

STUB_BIN="${TMP_DIR}/bin"
mkdir -p "$STUB_BIN"
for command_name in ssh pgrep netstat nslookup dig curl uci ip; do
    ln -s "${ROOT}/tests/fixtures/stub-command.sh" "${STUB_BIN}/${command_name}"
done

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

run_probe_case() {
    name="$1"
    target="$2"
    profile="$3"
    expected_status="$4"
    expected_text="$5"
    fixture="${ROOT}/tests/fixtures/${profile}"

    status=0
    output=$(PATH="${STUB_BIN}:${PATH}" \
        HD_FIXTURE_PROFILE="$profile" \
        HD_MIHOMO_RUNTIME_CONFIG="${fixture}/mihomo.yaml" \
        HD_OVPN_CONFIG="${fixture}/openvpn.conf" \
        HD_PROC_ROOT="${fixture}/proc" \
        "${ROOT}/bin/homelab-doctor" --config "${TMP_DIR}/valid.conf" \
        doctor "$target" 2>&1) || status=$?

    if [ "$status" -eq "$expected_status" ] \
        && printf '%s\n' "$output" | grep -Fq "$expected_text"; then
        printf '[OK]   %s\n' "$name"
        pass=$((pass + 1))
    else
        printf '[!]    %s（status=%s，期望包含：%s）\n' \
            "$name" "$status" "$expected_text"
        printf '%s\n' "$output" | sed 's/^/       /'
        fail=$((fail + 1))
    fi
}

run_single_ssh_case() {
    count_file="${TMP_DIR}/ssh-count"
    : > "$count_file"

    if PATH="${STUB_BIN}:${PATH}" \
        HD_FIXTURE_PROFILE=ok \
        HD_SSH_COUNT_FILE="$count_file" \
        HD_MIHOMO_RUNTIME_CONFIG="${ROOT}/tests/fixtures/ok/mihomo.yaml" \
        HD_OVPN_CONFIG="${ROOT}/tests/fixtures/ok/openvpn.conf" \
        HD_PROC_ROOT="${ROOT}/tests/fixtures/ok/proc" \
        "${ROOT}/bin/homelab-doctor" --config "${TMP_DIR}/valid.conf" \
        doctor router >/dev/null 2>&1 \
        && [ "$(wc -l < "$count_file")" -eq 1 ]; then
        printf '[OK]   router：只建立一次 SSH\n'
        pass=$((pass + 1))
    else
        printf '[!]    router：SSH 调用次数不是 1\n'
        fail=$((fail + 1))
    fi
}

run_system_probe_case() {
    name="$1"
    profile="$2"
    expected_status="$3"
    expected_text="$4"
    fixture="${ROOT}/tests/fixtures/${profile}"

    status=0
    output=$(
        {
            cat "${ROOT}/probes/openwrt/common.sh" \
                "${ROOT}/probes/openwrt/system.sh"
            printf '%s\n' 'probe_begin' 'probe_system' 'probe_summary'
        } | PATH="${STUB_BIN}:${PATH}" \
            HD_FIXTURE_PROFILE="$profile" \
            HD_PROC_ROOT="${fixture}/proc" \
            SPLIT_DOMAIN=service.home.example \
            SPLIT_EXPECTED_IP=192.0.2.20 \
            SERVICE_URL=https://service.home.example \
            sh
    ) || status=$?

    if [ "$status" -eq "$expected_status" ] \
        && printf '%s\n' "$output" | grep -Fq "$expected_text"; then
        printf '[OK]   %s\n' "$name"
        pass=$((pass + 1))
    else
        printf '[!]    %s（status=%s，期望包含：%s）\n' \
            "$name" "$status" "$expected_text"
        fail=$((fail + 1))
    fi
}

cp "${ROOT}/config/example.conf" "${TMP_DIR}/valid.conf"
cp "${ROOT}/config/example.conf" "${TMP_DIR}/invalid.conf"
cp "${ROOT}/config/example.conf" "${TMP_DIR}/unsafe.conf"
printf '%s\n' 'UNKNOWN_OPTION=value' >> "${TMP_DIR}/invalid.conf"
printf '%s\n' 'ROUTER_HOST=router.example;id' >> "${TMP_DIR}/unsafe.conf"

run_ok 'CLI语法' sh -n "${ROOT}/bin/homelab-doctor"
run_ok '配置解析器语法' sh -n "${ROOT}/lib/config.sh"
run_ok '探针拼装器语法' sh -n "${ROOT}/lib/doctor.sh"
for probe in "${ROOT}"/probes/openwrt/*.sh; do
    run_ok "探针语法：${probe##*/}" sh -n "$probe"
done
run_ok '示例配置通过校验' "${ROOT}/bin/homelab-doctor" --config "${TMP_DIR}/valid.conf" config validate
run_fail '未知配置项被拒绝' "${ROOT}/bin/homelab-doctor" --config "${TMP_DIR}/invalid.conf" config validate
run_fail '远程参数注入字符被拒绝' "${ROOT}/bin/homelab-doctor" --config "${TMP_DIR}/unsafe.conf" config validate

run_probe_case 'dns：健康判断' dns ok 0 'split-DNS：service.home.example → 192.0.2.20'
run_probe_case 'dns：警告判断' dns warn 0 '[WARN] 未发现 AdGuard Home 进程'
run_probe_case 'dns：故障判断' dns fail 1 '期望 192.0.2.20'
run_probe_case 'mihomo：健康判断' mihomo ok 0 'Fake-IP Filter 已载入：+.nas-vendor.example'
run_probe_case 'mihomo：警告判断' mihomo warn 0 '[WARN] 运行配置未发现 DIRECT 规则'
run_probe_case 'mihomo：故障判断' mihomo fail 1 '[!]    未发现 OpenClash/Mihomo 核心进程'
run_probe_case 'openvpn：健康判断' openvpn ok 0 'OpenVPN 已下发 DNS：192.0.2.1'
run_probe_case 'openvpn：警告判断' openvpn warn 0 '[WARN] OpenVPN 未下发 DNS：192.0.2.1'
run_probe_case 'openvpn：故障判断' openvpn fail 1 '[!]    未发现 VPN 子网路由：10.8.0.0/24'
run_system_probe_case 'system/service：健康判断' ok 0 '最终服务可达：HTTP 200'
run_system_probe_case 'system/service：警告判断' warn 0 'conntrack 800/1000（80%）偏高'
run_system_probe_case 'system/service：故障判断' fail 1 'conntrack 950/1000（95%）接近耗尽'
run_probe_case 'router：健康聚合' router ok 0 'SUMMARY ok=13 warn=0 fail=0'
run_probe_case 'router：警告聚合' router warn 0 'SUMMARY ok=5 warn=8 fail=0'
run_probe_case 'router：聚合故障判断' router fail 1 '[!]'
run_single_ssh_case

printf '%s\n' "SUMMARY pass=${pass} fail=${fail}"
[ "$fail" -eq 0 ]
