#!/usr/bin/env bash
# Включает запуск сервера по требованию (systemd socket activation)
set -e

PROJECT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
mkdir -p ~/.config/systemd/user

cat << EOF > ~/.config/systemd/user/myfooddiary.socket
[Unit]
Description=MyFoodDiary Socket Activation on Port 8000

[Socket]
ListenStream=0.0.0.0:8000
BindIPv6Only=both

[Install]
WantedBy=sockets.target
EOF

cat << EOF > ~/.config/systemd/user/myfooddiary.service
[Unit]
Description=MyFoodDiary FastAPI Backend Server
Requires=myfooddiary.socket
After=network.target

[Service]
Type=exec
WorkingDirectory=$PROJECT_DIR
EnvironmentFile=-$PROJECT_DIR/.env
Environment="IDLE_TIMEOUT_MINUTES=10"
ExecStart=$PROJECT_DIR/.venv/bin/uvicorn --fd 3 server:app
StandardOutput=journal
StandardError=journal
Restart=on-failure
RestartSec=2
EOF

systemctl --user daemon-reload
systemctl --user enable --now myfooddiary.socket
loginctl enable-linger 2>/dev/null || true

echo "✅ Socket-активация MyFoodDiary успешно включена!"
echo "📡 Порт 8000 слушается в фоне. Сервер просыпается при запросе с телефона и засыпает через 10 мин тишины."
