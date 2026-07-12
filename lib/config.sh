#!/bin/sh

# 配置解析器：不 source 用户文件，只接受明确白名单，避免配置注入命令。

hd_config_defaults() {
    ROUTER_HOST=""
    ROUTER_USER="root"
    SSH_CONNECT_TIMEOUT="5"
    DNS_SERVER="127.0.0.1"
    SPLIT_DOMAIN=""
    SPLIT_EXPECTED_IP=""
    SERVICE_URL=""
    DIRECT_DOMAIN_SUFFIX=""
    LAN_CIDR=""
    VPN_DNS=""
    VPN_SUBNET=""
}

hd_trim() {
    printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

hd_set_config() {
    key="$1"
    value="$2"

    case "$key" in
        ROUTER_HOST) ROUTER_HOST="$value" ;;
        ROUTER_USER) ROUTER_USER="$value" ;;
        SSH_CONNECT_TIMEOUT) SSH_CONNECT_TIMEOUT="$value" ;;
        DNS_SERVER) DNS_SERVER="$value" ;;
        SPLIT_DOMAIN) SPLIT_DOMAIN="$value" ;;
        SPLIT_EXPECTED_IP) SPLIT_EXPECTED_IP="$value" ;;
        SERVICE_URL) SERVICE_URL="$value" ;;
        DIRECT_DOMAIN_SUFFIX) DIRECT_DOMAIN_SUFFIX="$value" ;;
        LAN_CIDR) LAN_CIDR="$value" ;;
        VPN_DNS) VPN_DNS="$value" ;;
        VPN_SUBNET) VPN_SUBNET="$value" ;;
        *)
            printf '[!] 未知配置项：%s\n' "$key" >&2
            return 1
            ;;
    esac
}

hd_load_config() {
    file="$1"
    hd_config_defaults

    if [ ! -f "$file" ]; then
        printf '[!] 配置文件不存在：%s\n' "$file" >&2
        return 1
    fi

    line_no=0
    while IFS= read -r raw || [ -n "$raw" ]; do
        line_no=$((line_no + 1))
        line=$(hd_trim "$raw")
        case "$line" in
            ''|'#'*) continue ;;
            *=*) ;;
            *)
                printf '[!] 配置第 %s 行缺少 =：%s\n' "$line_no" "$line" >&2
                return 1
                ;;
        esac

        key=$(hd_trim "${line%%=*}")
        value=$(hd_trim "${line#*=}")
        hd_set_config "$key" "$value" || return 1
    done < "$file"
}

hd_is_ipv4() {
    echo "$1" | awk -F. '
        NF != 4 { exit 1 }
        {
            for (i = 1; i <= 4; i++) {
                if ($i !~ /^[0-9]+$/ || $i < 0 || $i > 255) exit 1
            }
        }
    '
}

hd_validate_token() {
    label="$1"
    value="$2"
    pattern="$3"

    if [ -z "$value" ]; then
        printf '[!] %s 不能为空\n' "$label" >&2
        return 1
    fi
    if ! echo "$value" | grep -Eq "$pattern"; then
        printf '[!] %s 格式不合法：%s\n' "$label" "$value" >&2
        return 1
    fi
}

# 若字段非空则按规则校验；空值跳过（用于可选字段）。
hd_validate_token_if_set() {
    label="$1"
    value="$2"
    pattern="$3"

    [ -z "$value" ] && return 0
    hd_validate_token "$label" "$value" "$pattern"
}

# 诊断目标所需的配置键（空格分隔）。
# all / 空：完整配置（config validate 与 doctor router）。
hd_required_keys_for() {
    target="${1:-all}"
    case "$target" in
        dns)
            printf '%s\n' 'ROUTER_HOST ROUTER_USER SSH_CONNECT_TIMEOUT DNS_SERVER SPLIT_DOMAIN SPLIT_EXPECTED_IP'
            ;;
        mihomo)
            printf '%s\n' 'ROUTER_HOST ROUTER_USER SSH_CONNECT_TIMEOUT DIRECT_DOMAIN_SUFFIX LAN_CIDR'
            ;;
        openvpn)
            printf '%s\n' 'ROUTER_HOST ROUTER_USER SSH_CONNECT_TIMEOUT VPN_DNS VPN_SUBNET'
            ;;
        firewall)
            printf '%s\n' 'ROUTER_HOST ROUTER_USER SSH_CONNECT_TIMEOUT'
            ;;
        router|all)
            printf '%s\n' 'ROUTER_HOST ROUTER_USER SSH_CONNECT_TIMEOUT DNS_SERVER SPLIT_DOMAIN SPLIT_EXPECTED_IP SERVICE_URL DIRECT_DOMAIN_SUFFIX LAN_CIDR VPN_DNS VPN_SUBNET'
            ;;
        *)
            return 1
            ;;
    esac
}

# 远程探针环境变量键（不含 SSH 连接参数）。
hd_probe_env_keys_for() {
    target="${1:-}"
    case "$target" in
        dns)
            printf '%s\n' 'DNS_SERVER SPLIT_DOMAIN SPLIT_EXPECTED_IP'
            ;;
        mihomo)
            printf '%s\n' 'DIRECT_DOMAIN_SUFFIX LAN_CIDR'
            ;;
        openvpn)
            printf '%s\n' 'VPN_DNS VPN_SUBNET'
            ;;
        firewall)
            # 防火墙模块不依赖本地诊断配置项。
            :
            ;;
        router)
            printf '%s\n' 'DNS_SERVER SPLIT_DOMAIN SPLIT_EXPECTED_IP SERVICE_URL DIRECT_DOMAIN_SUFFIX LAN_CIDR VPN_DNS VPN_SUBNET'
            ;;
        *)
            return 1
            ;;
    esac
}

hd_config_value() {
    case "$1" in
        ROUTER_HOST) printf '%s' "$ROUTER_HOST" ;;
        ROUTER_USER) printf '%s' "$ROUTER_USER" ;;
        SSH_CONNECT_TIMEOUT) printf '%s' "$SSH_CONNECT_TIMEOUT" ;;
        DNS_SERVER) printf '%s' "$DNS_SERVER" ;;
        SPLIT_DOMAIN) printf '%s' "$SPLIT_DOMAIN" ;;
        SPLIT_EXPECTED_IP) printf '%s' "$SPLIT_EXPECTED_IP" ;;
        SERVICE_URL) printf '%s' "$SERVICE_URL" ;;
        DIRECT_DOMAIN_SUFFIX) printf '%s' "$DIRECT_DOMAIN_SUFFIX" ;;
        LAN_CIDR) printf '%s' "$LAN_CIDR" ;;
        VPN_DNS) printf '%s' "$VPN_DNS" ;;
        VPN_SUBNET) printf '%s' "$VPN_SUBNET" ;;
        *) return 1 ;;
    esac
}

hd_validate_key() {
    key="$1"
    value=$(hd_config_value "$key")

    case "$key" in
        ROUTER_HOST)
            hd_validate_token ROUTER_HOST "$value" '^[A-Za-z0-9._:-]+$'
            ;;
        ROUTER_USER)
            hd_validate_token ROUTER_USER "$value" '^[A-Za-z_][A-Za-z0-9_-]*$'
            ;;
        SSH_CONNECT_TIMEOUT)
            hd_validate_token SSH_CONNECT_TIMEOUT "$value" '^[0-9]+$'
            ;;
        DNS_SERVER)
            hd_validate_token DNS_SERVER "$value" '^[A-Za-z0-9._:-]+$'
            ;;
        SPLIT_DOMAIN)
            hd_validate_token SPLIT_DOMAIN "$value" '^[A-Za-z0-9.-]+$'
            ;;
        SPLIT_EXPECTED_IP)
            hd_validate_token SPLIT_EXPECTED_IP "$value" '^[0-9.]+$' || return 1
            hd_is_ipv4 "$value" || {
                printf '[!] SPLIT_EXPECTED_IP 不是有效 IPv4：%s\n' "$value" >&2
                return 1
            }
            ;;
        SERVICE_URL)
            hd_validate_token SERVICE_URL "$value" '^https?://[A-Za-z0-9._:/-]+$'
            ;;
        DIRECT_DOMAIN_SUFFIX)
            hd_validate_token DIRECT_DOMAIN_SUFFIX "$value" '^[A-Za-z0-9.-]+$'
            ;;
        LAN_CIDR)
            hd_validate_token LAN_CIDR "$value" '^[0-9.]+/[0-9]+$'
            ;;
        VPN_DNS)
            hd_validate_token VPN_DNS "$value" '^[0-9.]+$' || return 1
            hd_is_ipv4 "$value" || {
                printf '[!] VPN_DNS 不是有效 IPv4：%s\n' "$value" >&2
                return 1
            }
            ;;
        VPN_SUBNET)
            hd_validate_token VPN_SUBNET "$value" '^[0-9.]+/[0-9]+$'
            ;;
        *)
            printf '[!] 内部错误：未知校验键 %s\n' "$key" >&2
            return 1
            ;;
    esac
}

# 校验给定目标所需配置。target=all 表示完整配置（config validate）。
# 已设置但不属于必填集合的字段若非空，仍做格式校验以拒绝注入字符。
hd_validate_config() {
    target="${1:-all}"
    errors=0
    required=$(hd_required_keys_for "$target") || {
        printf '[!] 未知校验目标：%s\n' "$target" >&2
        return 1
    }

    for key in $required; do
        hd_validate_key "$key" || errors=$((errors + 1))
    done

    # 非必填但已填写的白名单字段：仍拒绝非法/注入值。
    all_keys='ROUTER_HOST ROUTER_USER SSH_CONNECT_TIMEOUT DNS_SERVER SPLIT_DOMAIN SPLIT_EXPECTED_IP SERVICE_URL DIRECT_DOMAIN_SUFFIX LAN_CIDR VPN_DNS VPN_SUBNET'
    for key in $all_keys; do
        case " $required " in
            *" $key "*) continue ;;
        esac
        value=$(hd_config_value "$key")
        [ -z "$value" ] && continue
        hd_validate_key "$key" || errors=$((errors + 1))
    done

    [ "$errors" -eq 0 ]
}
