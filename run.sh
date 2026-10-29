#!/usr/bin/env bash

# Скрипт быстрого запуска MyFoodDiary (FastAPI бэкенд + PWA веб-клиент)
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
echo "🥗  Запуск MyFoodDiary"
echo "🥗 ===================================================="
echo "🌐 Веб-приложение PWA:   http://localhost:8000"
echo "📱 На телефоне (Wi-Fi):  http://$(hostname -I 2>/dev/null | awk '{print $1}'):8000"
echo "📚 Swagger API docs:     http://localhost:8000/docs"
echo "----------------------------------------------------"
echo "Нажмите Ctrl+C в этом окне для остановки сервера."
echo "----------------------------------------------------"

exec "$VENV_PY" -m uvicorn server:app --host 0.0.0.0 --port 8000
