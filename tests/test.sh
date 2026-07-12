#!/bin/sh
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

pass=0
fail=0

STUB_BIN="${TMP_DIR}/bin"
mkdir -p "$STUB_BIN"
for command_name in ssh pgrep netstat nslookup dig curl uci ip nft iptables; do
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

run_exit_code_case() {
    name="$1"
    expected_status="$2"
    shift 2

    status=0
    output=$("$@" 2>&1) || status=$?

    if [ "$status" -eq "$expected_status" ]; then
        printf '[OK]   %s（exit=%s）\n' "$name" "$status"
        pass=$((pass + 1))
    else
        printf '[!]    %s（exit=%s，期望 %s）\n' "$name" "$status" "$expected_status"
        printf '%s\n' "$output" | sed 's/^/       /'
        fail=$((fail + 1))
    fi
}

run_ssh_transport_fail_case() {
    name='SSH 失败退出 3 且非模块伪装'
    status=0
    output=$(PATH="${STUB_BIN}:${PATH}" \
        HD_SSH_FORCE_STATUS=255 \
        "${ROOT}/bin/homelab-doctor" --config "${TMP_DIR}/valid.conf" \
        doctor dns 2>&1) || status=$?

    if [ "$status" -eq 3 ] \
        && printf '%s\n' "$output" | grep -Fq 'SSH 连接失败' \
        && ! printf '%s\n' "$output" | grep -Fq 'SUMMARY'; then
        printf '[OK]   %s\n' "$name"
        pass=$((pass + 1))
    else
        printf '[!]    %s（status=%s）\n' "$name" "$status"
        printf '%s\n' "$output" | sed 's/^/       /'
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

run_firewall_probe_case() {
    name="$1"
    expected_status="$2"
    expected_text="$3"
    shift 3
    # 剩余参数为环境变量赋值（NAME=value）

    status=0
    output=$(
        {
            cat "${ROOT}/probes/openwrt/common.sh" \
                "${ROOT}/probes/openwrt/firewall.sh"
            printf '%s\n' 'probe_begin' 'probe_firewall' 'probe_summary'
        } | env "$@" PATH="${STUB_BIN}:${PATH}" sh
    ) || status=$?

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

run_firewall_missing_tools_case() {
    name='firewall：缺命令警告'
    bare_bin="${TMP_DIR}/bare-bin"
    mkdir -p "$bare_bin"
    # 仅提供最小运行时，确保 command -v nft/iptables 失败。
    ln -sf "$(command -v sh)" "${bare_bin}/sh"
    ln -sf "$(command -v date)" "${bare_bin}/date"

    status=0
    output=$(
        {
            cat "${ROOT}/probes/openwrt/common.sh" \
                "${ROOT}/probes/openwrt/firewall.sh"
            printf '%s\n' 'probe_begin' 'probe_firewall' 'probe_summary'
        } | PATH="$bare_bin" sh
    ) || status=$?

    if [ "$status" -eq 0 ] \
        && printf '%s\n' "$output" | grep -Fq '缺少 nft/iptables'; then
        printf '[OK]   %s\n' "$name"
        pass=$((pass + 1))
    else
        printf '[!]    %s（status=%s）\n' "$name" "$status"
        printf '%s\n' "$output" | sed 's/^/       /'
        fail=$((fail + 1))
    fi
}

run_dns_missing_tools_case() {
    name='dns：缺命令降级为警告'
    bare_bin="${TMP_DIR}/bare-bin-dns"
    mkdir -p "$bare_bin"
    # 仅提供最小运行时，确保 command -v netstat/ss/dig/nslookup 失败。
    ln -sf "$(command -v sh)" "${bare_bin}/sh"
    ln -sf "$(command -v date)" "${bare_bin}/date"

    status=0
    output=$(
        {
            cat "${ROOT}/probes/openwrt/common.sh" \
                "${ROOT}/probes/openwrt/dns.sh"
            printf '%s\n' 'probe_begin' 'probe_dns' 'probe_summary'
        } | env SPLIT_DOMAIN=service.home.example \
            SPLIT_EXPECTED_IP=192.0.2.20 \
            DNS_SERVER=127.0.0.1 \
            PATH="$bare_bin" sh
    ) || status=$?

    if [ "$status" -eq 0 ] \
        && printf '%s\n' "$output" | grep -Fq '缺少 netstat/ss' \
        && printf '%s\n' "$output" | grep -Fq '缺少 dig/nslookup'; then
        printf '[OK]   %s\n' "$name"
        pass=$((pass + 1))
    else
        printf '[!]    %s（status=%s）\n' "$name" "$status"
        printf '%s\n' "$output" | sed 's/^/       /'
        fail=$((fail + 1))
    fi
}

cp "${ROOT}/config/example.conf" "${TMP_DIR}/valid.conf"
cp "${ROOT}/config/example.conf" "${TMP_DIR}/invalid.conf"
cp "${ROOT}/config/example.conf" "${TMP_DIR}/unsafe.conf"
printf '%s\n' 'UNKNOWN_OPTION=value' >> "${TMP_DIR}/invalid.conf"
printf '%s\n' 'ROUTER_HOST=router.example;id' >> "${TMP_DIR}/unsafe.conf"

# 各命令最小合法配置（不含无关模块参数）。
cat > "${TMP_DIR}/min-dns.conf" <<'EOF'
ROUTER_HOST=192.0.2.1
SPLIT_DOMAIN=service.home.example
SPLIT_EXPECTED_IP=192.0.2.20
EOF

cat > "${TMP_DIR}/min-mihomo.conf" <<'EOF'
ROUTER_HOST=192.0.2.1
DIRECT_DOMAIN_SUFFIX=nas-vendor.example
LAN_CIDR=192.0.2.0/24
EOF

cat > "${TMP_DIR}/min-openvpn.conf" <<'EOF'
ROUTER_HOST=192.0.2.1
VPN_DNS=192.0.2.1
VPN_SUBNET=10.8.0.0/24
EOF

cat > "${TMP_DIR}/min-firewall.conf" <<'EOF'
ROUTER_HOST=192.0.2.1
EOF

# dns 缺 SPLIT_DOMAIN；含无关 VPN 字段也不应挽救缺项。
cat > "${TMP_DIR}/miss-dns.conf" <<'EOF'
ROUTER_HOST=192.0.2.1
SPLIT_EXPECTED_IP=192.0.2.20
VPN_DNS=192.0.2.1
VPN_SUBNET=10.8.0.0/24
EOF

# router 仍要求全部配置，缺 SERVICE_URL 应失败。
cat > "${TMP_DIR}/miss-router.conf" <<'EOF'
ROUTER_HOST=192.0.2.1
SPLIT_DOMAIN=service.home.example
SPLIT_EXPECTED_IP=192.0.2.20
DIRECT_DOMAIN_SUFFIX=nas-vendor.example
LAN_CIDR=192.0.2.0/24
VPN_DNS=192.0.2.1
VPN_SUBNET=10.8.0.0/24
EOF

# 单模块配置中的恶意无关字段仍应拒绝。
cat > "${TMP_DIR}/unsafe-extra.conf" <<'EOF'
ROUTER_HOST=192.0.2.1
SPLIT_DOMAIN=service.home.example
SPLIT_EXPECTED_IP=192.0.2.20
VPN_DNS=192.0.2.1;id
EOF

run_ok 'CLI语法' sh -n "${ROOT}/bin/homelab-doctor"
run_ok '配置解析器语法' sh -n "${ROOT}/lib/config.sh"
run_ok '探针拼装器语法' sh -n "${ROOT}/lib/doctor.sh"
for probe in "${ROOT}"/probes/openwrt/*.sh; do
    run_ok "探针语法：${probe##*/}" sh -n "$probe"
done
run_ok '示例配置通过校验' "${ROOT}/bin/homelab-doctor" --config "${TMP_DIR}/valid.conf" config validate
run_fail '未知配置项被拒绝' "${ROOT}/bin/homelab-doctor" --config "${TMP_DIR}/invalid.conf" config validate
run_fail '远程参数注入字符被拒绝' "${ROOT}/bin/homelab-doctor" --config "${TMP_DIR}/unsafe.conf" config validate

# 按命令校验：最小配置可通过；缺项与恶意值失败。
run_probe_with_config() {
    name="$1"
    config="$2"
    target="$3"
    profile="${4:-ok}"
    fixture="${ROOT}/tests/fixtures/${profile}"

    if PATH="${STUB_BIN}:${PATH}" \
        HD_FIXTURE_PROFILE="$profile" \
        HD_MIHOMO_RUNTIME_CONFIG="${fixture}/mihomo.yaml" \
        HD_OVPN_CONFIG="${fixture}/openvpn.conf" \
        HD_PROC_ROOT="${fixture}/proc" \
        "${ROOT}/bin/homelab-doctor" --config "$config" \
        doctor "$target" >/dev/null 2>&1; then
        printf '[OK]   %s\n' "$name"
        pass=$((pass + 1))
    else
        printf '[!]    %s\n' "$name"
        fail=$((fail + 1))
    fi
}

run_probe_with_config 'dns 最小配置可通过校验' "${TMP_DIR}/min-dns.conf" dns
run_probe_with_config 'mihomo 最小配置可通过校验' "${TMP_DIR}/min-mihomo.conf" mihomo
run_probe_with_config 'openvpn 最小配置可通过校验' "${TMP_DIR}/min-openvpn.conf" openvpn
run_probe_with_config 'firewall 最小配置可通过校验' "${TMP_DIR}/min-firewall.conf" firewall
run_fail 'dns 缺少 SPLIT_DOMAIN 被拒绝' \
    "${ROOT}/bin/homelab-doctor" --config "${TMP_DIR}/miss-dns.conf" doctor dns
run_fail 'router 缺少 SERVICE_URL 被拒绝' \
    "${ROOT}/bin/homelab-doctor" --config "${TMP_DIR}/miss-router.conf" doctor router
run_fail 'config validate 仍要求完整配置' \
    "${ROOT}/bin/homelab-doctor" --config "${TMP_DIR}/min-dns.conf" config validate
run_fail '非必填恶意字段仍被拒绝' \
    "${ROOT}/bin/homelab-doctor" --config "${TMP_DIR}/unsafe-extra.conf" doctor dns

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
run_probe_case 'firewall：fw4 健康判断' firewall ok 0 'nftables 规则已加载'
run_probe_case 'firewall：规则缺失故障' firewall fail 1 'nftables 表存在但未见有效规则'
run_probe_case 'firewall：工具无输出警告' firewall warn 0 '无法读取防火墙规则表'
run_firewall_probe_case 'firewall：fw3 健康判断' 0 'iptables 规则已加载' \
    HD_FIXTURE_PROFILE=ok HD_FIREWALL_BACKEND=iptables
run_firewall_probe_case 'firewall：fw3 规则缺失' 1 'iptables 过滤表无有效规则' \
    HD_FIXTURE_PROFILE=fail HD_FIREWALL_BACKEND=iptables
run_firewall_missing_tools_case
run_dns_missing_tools_case
# router：原 13 ok + firewall 2 ok = 15；warn 原 8 + firewall 1 = 9
run_probe_case 'router：健康聚合' router ok 0 'SUMMARY ok=15 warn=0 fail=0'
run_probe_case 'router：警告聚合' router warn 0 'SUMMARY ok=5 warn=9 fail=0'
run_probe_case 'router：聚合故障判断' router fail 1 '[!]'
run_single_ssh_case

# 退出状态分类
run_exit_code_case '本地配置错误退出 2' 2 \
    "${ROOT}/bin/homelab-doctor" --config "${TMP_DIR}/invalid.conf" config validate
run_exit_code_case '用法错误退出 2' 2 \
    "${ROOT}/bin/homelab-doctor" not-a-command
run_exit_code_case '远程诊断故障退出 1' 1 \
    env PATH="${STUB_BIN}:${PATH}" HD_FIXTURE_PROFILE=fail \
    HD_MIHOMO_RUNTIME_CONFIG="${ROOT}/tests/fixtures/fail/mihomo.yaml" \
    HD_OVPN_CONFIG="${ROOT}/tests/fixtures/fail/openvpn.conf" \
    HD_PROC_ROOT="${ROOT}/tests/fixtures/fail/proc" \
    "${ROOT}/bin/homelab-doctor" --config "${TMP_DIR}/valid.conf" doctor dns
run_exit_code_case '仅警告时退出 0' 0 \
    env PATH="${STUB_BIN}:${PATH}" HD_FIXTURE_PROFILE=warn \
    HD_MIHOMO_RUNTIME_CONFIG="${ROOT}/tests/fixtures/warn/mihomo.yaml" \
    HD_OVPN_CONFIG="${ROOT}/tests/fixtures/warn/openvpn.conf" \
    HD_PROC_ROOT="${ROOT}/tests/fixtures/warn/proc" \
    "${ROOT}/bin/homelab-doctor" --config "${TMP_DIR}/valid.conf" doctor dns
run_ssh_transport_fail_case

printf '%s\n' "SUMMARY pass=${pass} fail=${fail}"
[ "$fail" -eq 0 ]
