#!/usr/bin/env bash
# Полностью отключает socket-активацию и останавливает локальный сервер
set -e

systemctl --user disable --now myfooddiary.socket 2>/dev/null || true
systemctl --user stop myfooddiary.service 2>/dev/null || true
rm -f ~/.config/systemd/user/myfooddiary.socket ~/.config/systemd/user/myfooddiary.service
systemctl --user daemon-reload

echo "🛑 Socket-активация MyFoodDiary отключена."
echo "Порт 8000 свободен. Сервер больше не запускается автоматически."
