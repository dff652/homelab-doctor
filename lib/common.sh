#!/bin/sh

HD_GREEN='\033[0;32m'
HD_YELLOW='\033[1;33m'
HD_RED='\033[0;31m'
HD_BLUE='\033[0;34m'
HD_NC='\033[0m'

hd_ok() {
    printf '%b[OK]%b   %s\n' "$HD_GREEN" "$HD_NC" "$1"
}

hd_warn() {
    printf '%b[WARN]%b %s\n' "$HD_YELLOW" "$HD_NC" "$1"
}

hd_fail() {
    printf '%b[!]%b    %s\n' "$HD_RED" "$HD_NC" "$1"
}

hd_heading() {
    printf '%b%s%b\n' "$HD_BLUE" "$1" "$HD_NC"
}
