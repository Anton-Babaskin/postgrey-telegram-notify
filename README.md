````markdown
# postgrey-telegram-notify

**Monitor Postgrey greylisting events and send notifications to Telegram.**

## Files

- `postgrey_notify_telegram.sh`: script to monitor Postgrey log and forward relevant events to Telegram.
- `telegram_notify.sh`: helper script defining the `send_telegram()` function using Bot API and environment variables.

## Prerequisites

- Linux server with Postfix and Postgrey installed.
- Bash, `curl`, and `jq` available in `$PATH`.
- A Telegram Bot token and chat ID.
- Permissions to copy scripts to `/usr/local/bin` and create `/etc/miab-notify.env`.

## Installation

```bash
# Clone repository and enter directory
git clone https://github.com/Anton-Babaskin/postgrey-telegram-notify.git
cd postgrey-telegram-notify

# Make scripts executable and install
sudo chmod +x postgrey_notify_telegram.sh telegram_notify.sh
sudo cp postgrey_notify_telegram.sh telegram_notify.sh /usr/local/bin/
````

## Configuration

1. Create environment file with your credentials:

   ```bash
   sudo tee /etc/miab-notify.env > /dev/null <<EOF
   BOT_TOKEN="YOUR_TELEGRAM_BOT_TOKEN"
   CHAT_ID="YOUR_CHAT_ID"
   EOF
   ```
2. Secure the file:

   ```bash
   sudo chmod 600 /etc/miab-notify.env
   ```

## Usage

* **Manual test:**

  ```bash
  postgrey_notify_telegram.sh
  ```
* **Automate via cron:**

  ```cron
  */5 * * * * /usr/local/bin/postgrey_notify_telegram.sh
  ```
* **Or use a systemd timer:**

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

## Scripts

<details>
<summary><code>postgrey_notify_telegram.sh</code></summary>

```bash
#!/usr/bin/env bash
set -euo pipefail
source /usr/local/bin/telegram_notify.sh

LOG=/var/log/mail.log
STATE=/var/lib/postgrey-notify/lastpos
HOST=$(hostname -f)

mkdir -p "$(dirname "$STATE")"
touch "$STATE"
last=$(cat "$STATE")
total=$(wc -l <"$LOG")
[ "$total" -le "$last" ] && exit 0

tail -n +"$((last+1))" "$LOG" |
  awk '/postgrey/ && /(delayed|greylist|greylisted)/ {print}' |
  while read -r line; do
    send_telegram "🕒 Postgrey @ ${HOST}\n${line}"
  done

echo "$total" >"$STATE"
```

</details>

<details>
<summary><code>telegram_notify.sh</code></summary>

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

</details>
```
