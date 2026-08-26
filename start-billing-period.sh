#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"
load_config

# PI_COMMAND is set by the systemd unit to the path found during activation.
if [[ -n ${PI_COMMAND:-} && $PI_COMMAND == */* ]]; then
    PI_BIN=$PI_COMMAND
else
    resolve_pi
fi

exec "$PI_BIN" \
    --no-session \
    --no-tools \
    --no-context-files \
    --provider openai-codex \
    --model "$BILLING_MODEL" \
    --print \
    -- "Hi, we start a new 5 hour billing period :) Just say OK."
