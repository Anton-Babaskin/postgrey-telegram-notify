# 🎉 postgrey-telegram-notify

![GitHub Workflow](https://img.shields.io/github/actions/workflow/status/Anton-Babaskin/postgrey-telegram-notify/ci.yml?style=flat-square) ![License](https://img.shields.io/github/license/Anton-Babaskin/postgrey-telegram-notify?style=flat-square)

> Real-time Telegram alerts for Postgrey greylisting events and Postfix delivery statuses.

---

## 🚀 Key Features

- Interactive first-run setup for Bot Token and Chat ID
- Unified script parses both greylist triggers and delivery statuses
- Built-in systemd timer for automated scheduling
- Clean, emoji-enhanced Telegram messages

---

## 🧰 Prerequisites

Ensure your server has:

- Debian/Ubuntu with systemd
- Bash shell
- curl
- jq

Install dependencies:

    sudo apt update && sudo apt install -y curl jq

---

## 📦 Installation

1. Clone the repo:

    git clone https://github.com/Anton-Babaskin/postgrey-telegram-notify.git
    cd postgrey-telegram-notify

2. Run the installer:

    chmod +x setup_postgrey_notify.sh
    sudo ./setup_postgrey_notify.sh

3. Enter your Telegram Bot Token and Chat ID when prompted.

---

## ⚙️ Scheduling with systemd

The installer creates two units automatically:

- /etc/systemd/system/postgrey-telegram-notify.service
- /etc/systemd/system/postgrey-telegram-notify.timer

Enable and start the timer (done by installer):

    sudo systemctl daemon-reload
    sudo systemctl enable --now postgrey-telegram-notify.timer

To check status:

    systemctl list-timers postgrey-telegram-notify.timer
    journalctl -u postgrey-telegram-notify.service -n 20 --no-pager

---

## 🛠️ Usage Examples

- Manual run:

    sudo /usr/local/bin/postgrey-telegram-notify.sh

- View logs:

    journalctl -u postgrey-telegram-notify.service --no-pager

- Reset state (force reprocessing of logs):

    sudo rm -f /var/lib/postgrey-telegram-notify/lastpos

---

## 📝 Example Alerts

- Greylist event:

    🕒 Greylist @ mail.example.com
    Jul 30 12:34:56 mail postfix/postgrey[1234]: greylisted, delaying for 300s

- Delivery status:

    📬 Delivery @ mail.example.com
    QueueID: ABCDEF1234
    To: user@example.com
    Status: sent

---

## 🤝 Contributing

PRs and issues are welcome!

---

## 📄 License

MIT
