# 🎉 postgrey-telegram-notify

One-script solution: interactive setup on first run, monitors Postgrey greylist events and Postfix delivery statuses, sends Telegram alerts.

---

## 🧰 Prerequisites

- Debian-compatible Linux with systemd  
- Bash, curl, jq installed  
- Write access to `/usr/local/bin` and `/etc`

Ensure dependencies:

    sudo apt update && sudo apt install -y curl jq

---

## 📦 Installation

1. Create the notifier script:

    sudo tee /usr/local/bin/postgrey-telegram-notify.sh > /dev/null <<'EOF'
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG=/etc/postgrey-telegram-notify.conf
    if [ ! -f "$CONFIG" ]; then
      read -rp "Telegram Bot Token: " BOT_TOKEN
      read -rp "Telegram Chat ID: " CHAT_ID
      sudo tee "$CONFIG" > /dev/null <<CONFIG_EOF
    BOT_TOKEN="$BOT_TOKEN"
    CHAT_ID="$CHAT_ID"
    CONFIG_EOF
      sudo chmod 600 "$CONFIG"
      echo "Configuration saved to $CONFIG. Run the script again to start monitoring."
      exit 0
    fi
    source "$CONFIG"

    send_telegram() {
      local msg enc
      msg="$1"
      enc=$(printf %s "$msg" | sed -e 's/%/%25/g' -e 's/&/%26/g' -e 's/#/%23/g')
      curl -fsSL --retry 3 --max-time 10 \
        -d "chat_id=$CHAT_ID&text=$enc" \
        "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" | jq -e '.ok' >/dev/null
    }

    LOG=/var/log/mail.log
    STATE=/var/lib/postgrey-telegram-notify/lastpos
    HOST=$(hostname -f)

    mkdir -p "$(dirname "$STATE")"
    touch "$STATE"
    last=$(<"$STATE")
    total=$(wc -l <"$LOG")
    [ "$total" -le "$last" ] && exit 0

    tail -n +"$((last+1))" "$LOG" | \
      awk '
        /postgrey/ && /(delayed|greylist|greylisted)/ { print "GREY", $0 }
        /postfix\/(smtp|local|lmtp|bounce)/ && /status=(sent|bounced|deferred)/ { print "STAT", $0 }
      ' | while read -r type body; do
        if [ "$type" = "GREY" ]; then
          send_telegram "🕒 Greylist @ $HOST\n$body"
        else
          qid=$(echo "$body" | grep -oP '\b[0-9A-F]{10,}\b')
          rcpt=$(echo "$body" | grep -oP 'to=<\K[^>]+' )
          status=$(echo "$body" | grep -oP 'status=\K[^ ]+')
          send_telegram "📬 Delivery @ $HOST\nQueueID: $qid\nTo: $rcpt\nStatus: $status"
        fi
      done

    echo "$total" >"$STATE"
    EOF

2. Make it executable:

    sudo chmod +x /usr/local/bin/postgrey-telegram-notify.sh

3. Run once to configure:

    sudo /usr/local/bin/postgrey-telegram-notify.sh

---

## ⏱️ Scheduling

Create `postgrey-telegram-notify.service` in `/etc/systemd/system/`:

    [Unit]
    Description=Postgrey Telegram Notify

    [Service]
    Type=oneshot
    ExecStart=/usr/local/bin/postgrey-telegram-notify.sh

    [Install]
    WantedBy=multi-user.target

Create `postgrey-telegram-notify.timer` in `/etc/systemd/system/`:

    [Unit]
    Description=Run postgrey-telegram-notify every 5 minutes

    [Timer]
    OnCalendar=*:0/5
    Persistent=true

    [Install]
    WantedBy=timers.target

Enable and start:

    sudo systemctl daemon-reload
    sudo systemctl enable --now postgrey-telegram-notify.timer

---

## 📄 License

MIT
