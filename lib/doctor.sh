#!/bin/sh

hd_probe_modules() {
    case "$1" in
        dns) printf '%s\n' 'dns' ;;
        mihomo) printf '%s\n' 'mihomo' ;;
        openvpn) printf '%s\n' 'openvpn' ;;
        firewall) printf '%s\n' 'firewall' ;;
        router) printf '%s\n' 'dns' 'mihomo' 'openvpn' 'firewall' 'system' ;;
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

# 仅为目标模块拼装远程环境变量赋值（值已由配置校验收紧）。
hd_probe_remote_env() {
    target="$1"
    keys=$(hd_probe_env_keys_for "$target") || return 1
    env_assign=""
    for key in $keys; do
        value=$(hd_config_value "$key")
        if [ -n "$env_assign" ]; then
            env_assign="${env_assign} "
        fi
        env_assign="${env_assign}${key}='${value}'"
    done
    printf '%s' "$env_assign"
}

# 退出状态约定（控制端）：
#   0  诊断完成且无 [!]（允许仅有 [WARN]）
#   1  远程诊断得到明确故障证据（存在 [!]）
#   2  本地错误：用法、配置缺失/非法、未知目标
#   3  SSH/传输错误：连不上、认证失败、超时等（非模块 [!]）
hd_doctor_remote() {
    target="$1"
    hd_probe_modules "$target" >/dev/null || {
        hd_fail "未知诊断目标：${target}"
        return 2
    }

    remote_env=$(hd_probe_remote_env "$target") || {
        hd_fail "无法构建远程环境：${target}"
        return 2
    }

    if [ -n "$remote_env" ]; then
        remote_sh="${remote_env} sh -s"
    else
        remote_sh='sh -s'
    fi

    hd_heading "连接 ${ROUTER_USER}@${ROUTER_HOST} 执行 ${target} 只读探针"

    status=0
    hd_probe_bundle "$target" | ssh -o BatchMode=yes \
        -o "ConnectTimeout=${SSH_CONNECT_TIMEOUT}" \
        "${ROUTER_USER}@${ROUTER_HOST}" \
        "$remote_sh" || status=$?

    # OpenSSH 自身失败通常为 255；不把传输错误伪装成模块诊断 [!]。
    if [ "$status" -eq 255 ]; then
        hd_fail "SSH 连接失败：${ROUTER_USER}@${ROUTER_HOST}（非远程模块诊断结果）"
        return 3
    fi

    return "$status"
}
