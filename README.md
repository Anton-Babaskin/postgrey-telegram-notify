# 🎉 postgrey-telegram-notify
![GitHub Workflow](https://img.shields.io/github/actions/workflow/status/Anton-Babaskin/postgrey-telegram-notify/ci.yml?style=flat-square) ![License](https://img.shields.io/github/license/Anton-Babaskin/postgrey-telegram-notify?style=flat-square)

> **Monitor Postgrey greylisting events and get real-time alerts in Telegram.**

---

## 🚀 Features

- 🕵️‍♂️ **Log Monitoring**: Scans `/var/log/mail.log` for greylisting triggers.
- 💬 **Telegram Alerts**: Sends cleanly formatted messages via the Bot API.
- 🔄 **Automation**: Schedule with Cron or a `systemd` timer.

## 🧰 Requirements

| Component        | Requirement                                   |
| ---------------- | --------------------------------------------- |
| OS               | Debian-compatible Linux                       |
| Services         | Postfix + Postgrey                            |
| CLI Tools        | Bash, `curl`, `jq`                            |
| Permissions      | Write `/usr/local/bin`, create `/etc/miab-notify.env` |

## 📦 Installation

```bash
# Clone the repository
git clone https://github.com/Anton-Babaskin/postgrey-telegram-notify.git
cd postgrey-telegram-notify

# Install scripts
sudo chmod +x postgrey_notify_telegram.sh telegram_notify.sh
sudo mv postgrey_notify_telegram.sh telegram_notify.sh /usr/local/bin/
```

## ⚙️ Configuration

1. **Create** `/etc/miab-notify.env` with your bot credentials:

   ```bash
   sudo tee /etc/miab-notify.env > /dev/null <<EOF
   BOT_TOKEN="YOUR_TELEGRAM_BOT_TOKEN"
   CHAT_ID="YOUR_CHAT_ID"
   EOF
   ```

2. **Lock down** permissions:

   ```bash
   sudo chmod 600 /etc/miab-notify.env
   ```

3. **Test** the setup:

   ```bash
   source /usr/local/bin/telegram_notify.sh
   send_telegram "✅ Test alert from $(hostname -f)"
   ```

## ⏱️ Usage

- **Run manually**:

  ```bash
  postgrey_notify_telegram.sh
  ```

- **Cron** (every 5 minutes):

  ```cron
  */5 * * * * /usr/local/bin/postgrey_notify_telegram.sh
  ```

- **systemd timer**:

  ```ini
  [Unit]
  Description=Postgrey Telegram Notify Service

  [Service]
  ExecStart=/usr/local/bin/postgrey_notify_telegram.sh

  [Install]
  WantedBy=multi-user.target

  [Timer]
  OnCalendar=*:0/5
  Persistent=true
  ```

## 📂 Scripts Overview

| Script                        | Purpose                                        |
| ----------------------------- | ---------------------------------------------- |
| `postgrey_notify_telegram.sh` | Monitor greylisting events and forward to Telegram |
| `telegram_notify.sh`          | Define `send_telegram()` using Bot API         |

### `postgrey_notify_telegram.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
source /usr/local/bin/telegram_notify.sh

LOG=/var/log/mail.log
STATE=/var/lib/postgrey-notify/lastpos
HOST=$(hostname -f)

mkdir -p "$(dirname "$STATE")"

touch "$STATE"
last=$(<"$STATE")
total=$(wc -l <"$LOG")
[ "$total" -le "$last" ] && exit 0

tail -n +"$((last+1))" "$LOG" \
  | awk '/postgrey/ && /(delayed|greylist|greylisted)/' \
  | while IFS= read -r line; do
      send_telegram "🕒 Postgrey @ ${HOST}\n${line}"
    done

echo "$total" >"$STATE"
```

### `telegram_notify.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
source /etc/miab-notify.env

send_telegram() {
  local msg enc
  msg="$1"
  enc=$(printf %s "$msg" \
    | sed -e 's/%/%25/g' -e 's/&/%26/g' -e 's/#/%23/g')
  curl -fsSL --retry 3 --max-time 10 \
    -d "chat_id=$CHAT_ID&text=$enc" \
    "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
    | jq -e '.ok' >/dev/null
}
```

---

## 🤝 Contributing

PRs and issues are welcome. Let’s make greylisting monitoring easier!

## 📄 License

[MIT](LICENSE)
