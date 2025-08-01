# 🎉 postgrey-telegram-notify

A one-click installer for monitoring Postgrey greylisting events and sending real-time Telegram alerts.

---

## 🚀 Features

- **Interactive Setup**: Prompts for your Telegram Bot Token and Chat ID.
- **All-In-One Script**: Generates the monitoring script and systemd units in one go.
- **Systemd Timer**: Automatically runs the notifier every 5 minutes.
- **Clean Notifications**: Parses `/var/log/mail.log` and sends only greylisting events.

---

## 🧰 Prerequisites

Ensure you have installed dependencies before running the installer:

    sudo apt update && sudo apt install -y curl jq

- Debian-compatible Linux with systemd
- Bash
- curl
- jq

---

## 📦 Installation

1. Clone the repository and enter the directory:

git clone https://github.com/Anton-Babaskin/postgrey-telegram-notify.git
cd postgrey-telegram-notify

2. Make the installer executable and run it with sudo:

    chmod +x setup_postgrey_notify.sh
    sudo ./setup_postgrey_notify.sh

You will be prompted to enter your `BOT_TOKEN` and `CHAT_ID`. The installer will then:

1. Create `/usr/local/bin/postgrey-telegram-notify.sh` — the notifier script.
2. Generate two systemd units:

       /etc/systemd/system/postgrey-telegram-notify.service
       /etc/systemd/system/postgrey-telegram-notify.timer

3. Reload systemd, enable and start the timer.

---

## 📂 Files

- `setup_postgrey_notify.sh` — interactive installer and script generator.
- `postgrey-telegram-notify.sh` — generated notifier script (located in `/usr/local/bin`).

---

## ⏱️ Usage

- **Test manually**:

    sudo /usr/local/bin/postgrey-telegram-notify.sh

- **Check timer status**:

    systemctl list-timers postgrey-telegram-notify.timer

- **View logs**:

    journalctl -u postgrey-telegram-notify.service -n 50 --no-pager

---

## 🤝 Contributing

PRs and issues are welcome!

## 📄 License

MIT
