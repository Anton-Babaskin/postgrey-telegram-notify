#!/usr/bin/env bash
set -euo pipefail

# Interactive installer for Postgrey → Telegram notifier
read -rp "Enter your Telegram Bot Token: " BOT_TOKEN
read -rp "Enter your Telegram Chat ID: " CHAT_ID

# Paths configuration
BIN_DIR=/usr/local/bin
STATE_DIR=/var/lib/postgrey-telegram-notify
SERVICE_FILE=/etc/systemd/system/postgrey-telegram-notify.service
TIMER_FILE=/etc/systemd/system/postgrey-telegram-notify.timer

echo "Installing Postgrey Telegram notifier…"

# 1) Create Telegram helper script
sudo tee "${BIN_DIR}/telegram_notify.sh" > /dev/null <<EOF
#!/usr/bin/env bash
set -euo pipefail

# Telegram Bot credentials
BOT_TOKEN="${BOT_TOKEN}"
CHAT_ID="${CHAT_ID}"

# Send a message via Telegram Bot API
send_telegram() {
  local msg encoded
  msg="\$1"
  encoded=\$(printf '%s' "\$msg" | sed -e 's/%/%25/g' -e 's/&/%26/g' -e 's/#/%23/g')
  curl -fsSL --retry 3 --max-time 10 \\
    -d "chat_id=\$CHAT_ID&text=\$encoded" \\
    "https://api.telegram.org/bot\$BOT_TOKEN/sendMessage" \\
    | jq -e '.ok' >/dev/null
}
EOF
sudo chmod 755 "${BIN_DIR}/telegram_notify.sh"

# 2) Create main notifier script
sudo tee "${BIN_DIR}/postgrey-telegram-notify.sh" > /dev/null <<EOF
#!/usr/bin/env bash
set -euo pipefail

# Load Telegram helper
source /usr/local/bin/telegram_notify.sh

LOG_FILE=/var/log/mail.log
STATE_FILE=${STATE_DIR}/lastpos
HOSTNAME=\$(hostname -f)

# Initialize state file
mkdir -p "\$(dirname "\$STATE_FILE")"
touch "\$STATE_FILE"

last=\$(<"\$STATE_FILE")
total=\$(wc -l <"\$LOG_FILE")
[ "\$total" -le "\$last" ] && exit 0

# Parse new log entries for greylist and final delivery status
tail -n +"\$((last+1))" "\$LOG_FILE" | \
awk '
  /postgrey/ && /(delayed|greylist|greylisted)/ { print "GREY", \$0 }
  /postfix\\/(smtp|local|lmtp|bounce)/ && /status=(sent|bounced|deferred)/ { print "STAT", \$0 }
' | while read -r type line; do
  if [ "\$type" = "GREY" ]; then
    send_telegram "🕒 Greylist @ \$HOSTNAME\n\$line"
  else
    id=\$(echo "\$line" | grep -oP '\\b[0-9A-F]{10,}\\b')
    to=\$(echo "\$line" | grep -oP 'to=<\\K[^>]+')
    status=\$(echo "\$line" | grep -oP 'status=\\K[^ ]+')
    send_telegram "📬 Delivery @ \$HOSTNAME\nQueueID: \$id\nTo: \$to\nStatus: \$status"
  fi
done

# Update state
echo "\$total" >"\$STATE_FILE"
EOF
sudo chmod 755 "${BIN_DIR}/postgrey-telegram-notify.sh"

# 3) Create systemd service unit
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Postgrey Telegram Notify Service

[Service]
Type=oneshot
ExecStart=${BIN_DIR}/postgrey-telegram-notify.sh

[Install]
WantedBy=multi-user.target
EOF

# 4) Create systemd timer unit
sudo tee "$TIMER_FILE" > /dev/null <<EOF
[Unit]
Description=Run postgrey-telegram-notify every 5 minutes

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
EOF

# 5) Reload systemd and enable timer
sudo systemctl daemon-reload
sudo systemctl enable --now postgrey-telegram-notify.timer

echo "Installation complete. Timer is active:"
systemctl list-timers postgrey-telegram-notify.timer --no-pager
