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

hd_validate_config() {
    errors=0

    hd_validate_token ROUTER_HOST "$ROUTER_HOST" '^[A-Za-z0-9._:-]+$' || errors=$((errors + 1))
    hd_validate_token ROUTER_USER "$ROUTER_USER" '^[A-Za-z_][A-Za-z0-9_-]*$' || errors=$((errors + 1))
    hd_validate_token SSH_CONNECT_TIMEOUT "$SSH_CONNECT_TIMEOUT" '^[0-9]+$' || errors=$((errors + 1))
    hd_validate_token DNS_SERVER "$DNS_SERVER" '^[A-Za-z0-9._:-]+$' || errors=$((errors + 1))
    hd_validate_token SPLIT_DOMAIN "$SPLIT_DOMAIN" '^[A-Za-z0-9.-]+$' || errors=$((errors + 1))
    hd_validate_token SPLIT_EXPECTED_IP "$SPLIT_EXPECTED_IP" '^[0-9.]+$' || errors=$((errors + 1))
    hd_validate_token SERVICE_URL "$SERVICE_URL" '^https?://[A-Za-z0-9._:/-]+$' || errors=$((errors + 1))
    hd_validate_token DIRECT_DOMAIN_SUFFIX "$DIRECT_DOMAIN_SUFFIX" '^[A-Za-z0-9.-]+$' || errors=$((errors + 1))
    hd_validate_token LAN_CIDR "$LAN_CIDR" '^[0-9.]+/[0-9]+$' || errors=$((errors + 1))
    hd_validate_token VPN_DNS "$VPN_DNS" '^[0-9.]+$' || errors=$((errors + 1))
    hd_validate_token VPN_SUBNET "$VPN_SUBNET" '^[0-9.]+/[0-9]+$' || errors=$((errors + 1))

    hd_is_ipv4 "$SPLIT_EXPECTED_IP" || {
        printf '[!] SPLIT_EXPECTED_IP 不是有效 IPv4：%s\n' "$SPLIT_EXPECTED_IP" >&2
        errors=$((errors + 1))
    }
    hd_is_ipv4 "$VPN_DNS" || {
        printf '[!] VPN_DNS 不是有效 IPv4：%s\n' "$VPN_DNS" >&2
        errors=$((errors + 1))
    }

    [ "$errors" -eq 0 ]
}
