# Daily Codex billing period starter

OpenAI has reinstated 5 hours limits in Codex. I need a codex session started while I sleep to spread my work over 3 sessions instead of 2. 

This installs a systemd user timer that runs Pi once per day, by default at 05:00 (server local timezone). Pi sends this prompt to OpenAI Codex and then exits (print mode):

> Hi, we start a new 5 hour billing period :) Just say OK.

The job is disabled until explicitly enabled. `disable` stops it without removing the files.

## Requirements

- Ubuntu/Linux with `systemd`, `systemctl --user`, and `loginctl`.
- A user systemd manager that can run unattended. Enable lingering once:

  ```bash
  sudo loginctl enable-linger "$USER"
  ```

  If `systemctl --user` reports `No medium found`, start the user manager and set the runtime directory in the current shell:

  ```bash
  uid=$(id -u)
  sudo systemctl start "user@$uid.service"
  export XDG_RUNTIME_DIR="/run/user/$uid"
  ```

- Pi installed and available to this user.
- Pi already logged in to Codex. This script does not manage credentials.
- Network access

Pi's non-interactive print mode exits  just after the response, `--no-tools` and `--no-session` to mitigate any risk.

## Config

Edit `config.yaml`:

```yaml
time: "05:00"
model: "gpt-5.6-luna"
pi_command: "pi"
```

These are simple scalar YAML settings; `time` is `HH:MM` and uses the systems local timezone. Absolute Pi path can be used when Pi was installed outside `PATH`, ex: `/home/me/.local/bin/pi`.

From this directory:

```bash
chmod +x start-billing-period.sh manage-billing-period.sh

./manage-billing-period.sh check   # verify Pi, model, Codex auth and systemd
./manage-billing-period.sh enable  # install and activate the daily timer
./manage-billing-period.sh status
./manage-billing-period.sh disable # deactivate it
```

Run `enable` again after changing `config.yaml`; it rewrites the user units and applies the new time. Test the action immediately, without waiting for the timer, with:

```bash
./start-billing-period.sh
```

The installed units live under `~/.config/systemd/user/` as `pi-billing-period.service` and `pi-billing-period.timer`. Logs are available with:

```bash
journalctl --user -u pi-billing-period.service
```

The timer does not catch up missed runs after shutdown (`Persistent=false`).
