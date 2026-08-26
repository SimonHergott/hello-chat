#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
CONFIG_FILE=${PI_BILLING_CONFIG:-"$SCRIPT_DIR/config.yaml"}
UNIT_DIR=${XDG_CONFIG_HOME:-"$HOME/.config"}/systemd/user
SERVICE_NAME=pi-billing-period.service
TIMER_NAME=pi-billing-period.timer

config_value() {
    local key=$1
    awk -v key="$key" '
        /^[[:space:]]*#/ { next }
        {
            line = $0
            sub(/[[:space:]]*#.*/, "", line)
            if (line ~ "^[[:space:]]*" key "[[:space:]]*:") {
                sub("^[^:]*:[[:space:]]*", "", line)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
                if (line ~ /^".*"$/ || (substr(line, 1, 1) == sprintf("%c", 39) && substr(line, length(line), 1) == sprintf("%c", 39)))
                    line = substr(line, 2, length(line) - 2)
                print line
                exit
            }
        }
    ' "$CONFIG_FILE"
}

load_config() {
    [[ -f $CONFIG_FILE ]] || { echo "Missing config: $CONFIG_FILE" >&2; return 1; }

    BILLING_TIME=$(config_value time)
    BILLING_MODEL=$(config_value model)
    configured_pi_command=$(config_value pi_command)
    BILLING_MODEL=${BILLING_MODEL:-gpt-5.6-luna}
    PI_COMMAND=${PI_COMMAND:-${configured_pi_command:-pi}}

    [[ $BILLING_TIME =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]] || {
        echo "Invalid time in $CONFIG_FILE: ${BILLING_TIME:-<empty>} (expected HH:MM)" >&2
        return 1
    }
    [[ $BILLING_MODEL =~ ^[A-Za-z0-9._:/-]+$ ]] || {
        echo "Invalid model in $CONFIG_FILE: $BILLING_MODEL" >&2
        return 1
    }
}

resolve_pi() {
    if [[ $PI_COMMAND == */* ]]; then
        [[ -x $PI_COMMAND ]] || { echo "Pi is not executable: $PI_COMMAND" >&2; return 1; }
        PI_BIN=$PI_COMMAND
    else
        PI_BIN=$(command -v "$PI_COMMAND") || {
            echo "Pi command not found: $PI_COMMAND" >&2
            return 1
        }
    fi
}
