#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

check_systemd() {
    command -v systemctl >/dev/null 2>&1 || {
        echo "systemctl not found" >&2
        return 1
    }
    systemctl --user show-environment >/dev/null 2>&1 || {
        echo "The systemd user manager is unavailable (run this as the target user)." >&2
        return 1
    }
    command -v loginctl >/dev/null 2>&1 || {
        echo "loginctl not found; cannot verify unattended user timers" >&2
        return 1
    }
    [[ $(loginctl show-user "$USER" -p Linger --value 2>/dev/null || true) == yes ]] || {
        echo "User lingering is disabled; run: sudo loginctl enable-linger $USER" >&2
        return 1
    }
}

check_pi_and_auth() {
    if ! resolve_pi; then
        return 1
    fi
    "$PI_BIN" --version >/dev/null || {
        echo "Pi could not start: $PI_BIN" >&2
        return 1
    }

    local models
    models=$(timeout 30 "$PI_BIN" --list-models "$BILLING_MODEL" 2>&1) || {
        echo "Pi could not list models:" >&2
        echo "$models" >&2
        return 1
    }
    if ! awk -v model="$BILLING_MODEL" '$1 == "openai-codex" && $2 == model { found = 1 } END { exit !found }' <<<"$models"; then
        echo "Model is not available through openai-codex: $BILLING_MODEL" >&2
        return 1
    fi

    local auth_result auth_status=0
    auth_result=$("$PI_BIN" auth check --provider openai-codex --json 2>&1) || auth_status=$?
    if (( auth_status != 0 )) || [[ $auth_result != *'"status":"ready"'* ]]; then
        echo "OpenAI Codex auth is not ready:" >&2
        echo "$auth_result" >&2
        return 1
    fi
    echo "Pi: $PI_BIN"
    echo "Codex auth: ready"
}

check_requirements() {
    if ! load_config; then
        return 1
    fi

    local ok=0
    if ! check_systemd; then ok=1; fi
    if ! check_pi_and_auth; then ok=1; fi
    return "$ok"
}

check_timer_installation() {
    local timer_unit=$UNIT_DIR/$TIMER_NAME
    [[ -f $timer_unit ]] || {
        echo "Timer: not installed (run '$0 enable')"
        return 1
    }
    grep -Fq "OnCalendar=*-*-* ${BILLING_TIME}:00" "$timer_unit" || {
        echo "Timer: installed with a different time; run '$0 enable'"
        return 1
    }
    echo "Timer: configured for every day at $BILLING_TIME local time"
}

install_units() {
    local script_arg pi_arg config_arg path_arg
    printf -v script_arg '%q' "$SCRIPT_DIR/start-billing-period.sh"
    printf -v pi_arg '%q' "$PI_BIN"
    printf -v config_arg '%q' "$CONFIG_FILE"
    # systemd may retain an older PATH (and therefore an older Node).
    printf -v path_arg '%q' "$(dirname "$PI_BIN"):$PATH"
    mkdir -p "$UNIT_DIR"

    cat >"$UNIT_DIR/$SERVICE_NAME" <<EOF
[Unit]
Description=Start a new OpenAI Codex billing period with Pi

[Service]
Type=oneshot
TimeoutStartSec=10min
Environment=PI_BILLING_CONFIG=$config_arg
Environment=PI_COMMAND=$pi_arg
Environment=PATH=$path_arg
StandardOutput=journal
StandardError=journal
ExecStart=/bin/bash $script_arg
EOF

    cat >"$UNIT_DIR/$TIMER_NAME" <<EOF
[Unit]
Description=Start a new OpenAI Codex billing period daily

[Timer]
OnCalendar=*-*-* ${BILLING_TIME}:00
AccuracySec=1min
Persistent=false
Unit=$SERVICE_NAME

[Install]
WantedBy=timers.target
EOF
}

enable_job() {
    check_requirements || return 1
    install_units
    systemctl --user daemon-reload
    systemctl --user enable "$TIMER_NAME" >/dev/null
    systemctl --user restart "$TIMER_NAME"
    echo "Enabled: daily at $BILLING_TIME local time"
}

disable_job() {
    check_systemd
    if [[ ! -f $UNIT_DIR/$TIMER_NAME ]]; then
        echo "Already disabled (timer is not installed)."
        return
    fi
    systemctl --user disable --now "$TIMER_NAME" >/dev/null
    echo "Disabled."
}

case ${1:-} in
    check)
        check_requirements
        check_timer_installation
        ;;
    enable)
        enable_job
        ;;
    disable)
        disable_job
        ;;
    status)
        if [[ -f $UNIT_DIR/$TIMER_NAME ]]; then
            systemctl --user status "$TIMER_NAME" --no-pager || true
        else
            echo "Not installed."
        fi
        ;;
    *)
        echo "Usage: $0 {check|enable|disable|status}" >&2
        exit 2
        ;;
esac
