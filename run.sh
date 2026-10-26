#!/usr/bin/env bash

# Скрипт быстрого запуска Food Recognition (Веб-сервер PWA + Telegram-бот)
set -e

# Определяем абсолютный путь к каталогу проекта даже при вызове через симлинк
PROJECT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
cd "$PROJECT_DIR"

VENV_PY="$PROJECT_DIR/.venv/bin/python"

if [ ! -f "$VENV_PY" ]; then
    echo "❌ Ошибка: виртуальное окружение .venv не найдено в $PROJECT_DIR/.venv"
    echo "Создайте его: python3 -m venv .venv && .venv/bin/pip install -r requirements.txt"
    exit 1
fi

if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo "⚠️ Внимание: файл .env не найден! Создайте его на основе .env.example"
fi

echo "🥗 ===================================================="
echo "🥗  Запуск Food Recognition"
echo "🥗 ===================================================="
echo "🌐 Веб-приложение PWA:   http://localhost:8000"
echo "📱 На телефоне (Wi-Fi):  http://$(hostname -I 2>/dev/null | awk '{print $1}'):8000"
echo "📚 Swagger API docs:     http://localhost:8000/docs"
echo "🤖 Telegram-бот:         запускается..."
echo "----------------------------------------------------"
echo "Нажмите Ctrl+C в этом окне для остановки всех сервисов."
echo "----------------------------------------------------"

# Аккуратное завершение обоих процессов при Ctrl+C или закрытии окна
cleanup() {
    echo ""
    echo "🛑 Остановка сервисов Food Recognition..."
    [ -n "$BOT_PID" ] && kill "$BOT_PID" 2>/dev/null || true
    [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true
    wait "$BOT_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
    echo "✅ Все сервисы остановлены."
    exit 0
}
trap cleanup SIGINT SIGTERM

# 1. Запуск Telegram-бота в фоне
"$VENV_PY" bot.py &
BOT_PID=$!

# 2. Запуск FastAPI веб-сервера в фоне
"$VENV_PY" -m uvicorn server:app --host 0.0.0.0 --port 8000 &
SERVER_PID=$!

# Ожидание процессов
wait "$SERVER_PID" "$BOT_PID"
