# AGENTS.md

## Project

This project installs a systemd user timer that runs Pi once per day to start an OpenAI Codex billing period.

## Changes

- Keep scripts POSIX-friendly where practical; they currently use Bash.
- Prefer the smallest change that preserves unattended systemd execution.
- Do not add dependencies for simple shell behavior.
- Keep generated unit settings in `manage-billing-period.sh`.

## Checks

Before finishing a change, run:

```bash
bash -n common.sh start-billing-period.sh manage-billing-period.sh
```

For timer changes, inspect the generated unit with `systemctl --user cat` on a host with a running user systemd manager.
