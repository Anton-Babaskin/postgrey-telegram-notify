#!/usr/bin/env bash
set -euo pipefail

# 1) Запрашиваем у пользователя данные
read -rp "Telegram Bot Token: " BOT_TOKEN
read -rp "Telegram Chat ID: " CHAT_ID

# Пути для файлов
SCRIPT_PATH=/usr/local/bin/postgrey-telegram-notify.sh
SERVICE_PATH=/etc/systemd/system/postgrey-telegram-notify.service
TIMER_PATH=/etc/systemd/system/postgrey-telegram-notify.timer

echo -e "\n🔧 Installing Postgrey → Telegram notify…"

# 2) Создаём главный скрипт
sudo tee "$SCRIPT_PATH" > /dev/null <<EOF
#!/usr/bin/env bash
set -euo pipefail

BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"

send_telegram() {
  local msg enc
  msg="\$1"
  enc=\$(printf %s "\$msg" | sed -e 's/%/%25/g' -e 's/&/%26/g' -e 's/#/%23/g')
  curl -fsSL --retry 3 --max-time 10 \\
    -d "chat_id=\$CHAT_ID&text=\$enc" \\
    "https://api.telegram.org/bot\$BOT_TOKEN/sendMessage" | jq -e '.ok' >/dev/null
}

LOG=/var/log/mail.log
STATE=/var/lib/postgrey-notify/lastpos
HOST=\$(hostname -f)

mkdir -p "\$(dirname "\$STATE")"
touch "\$STATE"

last=\$(<"\$STATE")
total=\$(wc -l <"\$LOG")
[ "\$total" -le "\$last" ] && exit 0

tail -n +"\$((last+1))" "\$LOG" \\
  | awk '/postgrey/ && /(delayed|greylist|greylisted)/' \\
  | while IFS= read -r line; do
      send_telegram "🕒 Postgrey @ \$HOST\\n\$line"
    done

echo "\$total" >"\$STATE"
EOF

sudo chmod +x "$SCRIPT_PATH"

# 3) Создаём systemd service
sudo tee "$SERVICE_PATH" > /dev/null <<'EOF'
[Unit]
Description=Postgrey Telegram Notify

[Service]
Type=oneshot
ExecStart=/usr/local/bin/postgrey-telegram-notify.sh

[Install]
WantedBy=multi-user.target
EOF

# 4) Создаём systemd timer
sudo tee "$TIMER_PATH" > /dev/null <<'EOF'
[Unit]
Description=Run postgrey-telegram-notify every 5 minutes

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
EOF

# 5) Перезагружаем демона и включаем таймер
sudo systemctl daemon-reload
sudo systemctl enable --now postgrey-telegram-notify.timer

echo -e "\n✅ Installation complete! Timer status:"
systemctl list-timers --no-pager postgrey-telegram-notify.timer
