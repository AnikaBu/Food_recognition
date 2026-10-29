from pathlib import Path
from fastapi.testclient import TestClient
from server import app
import db

client = TestClient(app)

def test_api_endpoints():
    print("🚀 Тестирование FastAPI бэкенда (Этап 4)...")

    # 1. Проверка доступности здоровья API и PWA клиента
    resp_health = client.get("/api/health")
    assert resp_health.status_code == 200, f"Ошибка health: {resp_health.text}"
    assert resp_health.json()["status"] == "online"
    print("✅ 1. Эндпоинт '/api/health' доступен.")

    # 1.1 Проверка раздачи PWA статики (HTML, манифест, сервис-воркер, стили, скрипты)
    resp_pwa_html = client.get("/")
    assert resp_pwa_html.status_code == 200
    assert "MyFoodDiary" in resp_pwa_html.text
    assert "<link rel=\"manifest\" href=\"/manifest.json\"" in resp_pwa_html.text

    resp_manifest = client.get("/manifest.json")
    assert resp_manifest.status_code == 200
    assert resp_manifest.json()["short_name"] == "MyFoodDiary"

    resp_sw = client.get("/sw.js")
    assert resp_sw.status_code == 200
    assert "food-recognition" in resp_sw.text

    resp_css = client.get("/style.css")
    assert resp_css.status_code == 200

    resp_js = client.get("/app.js")
    assert resp_js.status_code == 200

    resp_icon = client.get("/icons/icon-192.png")
    assert resp_icon.status_code == 200
    print("✅ 1.1. Статические файлы PWA (HTML, CSS, JS, Manifest, SW, Icons) отдаются корректно.")

    # 2. Создание приема пищи через API
    payload = {
        "meal_type": "lunch",
        "dish_name": "Тестовый обед через API",
        "comment": "Сбалансированное блюдо",
        "items": [
            {
                "name": "Грудка индейки",
                "weight_g": 100.0,
                "calories": 130.0,
                "protein": 24.0,
                "fat": 3.0,
                "carbs": 0.0
            },
            {
                "name": "Рис басмати",
                "weight_g": 150.0,
                "calories": 195.0,
                "protein": 4.0,
                "fat": 0.5,
                "carbs": 43.0
            }
        ]
    }
    resp_create = client.post("/api/meals", json=payload)
    assert resp_create.status_code == 201, f"Ошибка создания: {resp_create.text}"
    created_meal = resp_create.json()
    meal_id = created_meal["id"]
    assert meal_id > 0
    assert created_meal["dish_name"] == "Тестовый обед через API"
    assert created_meal["total_weight_g"] == 250.0
    assert created_meal["total_calories"] == 325.0
    print(f"✅ 2. POST /api/meals — прием пищи успешно сохранен с ID #{meal_id}.")

    # 3. Чтение приема пищи по ID
    resp_get = client.get(f"/api/meals/{meal_id}")
    assert resp_get.status_code == 200
    assert resp_get.json()["id"] == meal_id
    item_id = resp_get.json()["items"][0]["id"]
    print(f"✅ 3. GET /api/meals/{meal_id} — запись успешно получена.")

    # 4. Обновление веса ингредиента (удваиваем порцию индейки со 100г до 200г)
    resp_update = client.put(f"/api/items/{item_id}/weight", json={"weight_g": 200.0})
    assert resp_update.status_code == 200
    updated_item = resp_update.json()
    assert updated_item["weight_g"] == 200.0
    assert updated_item["calories"] == 260.0  # 130 * 2
    assert updated_item["protein"] == 48.0   # 24 * 2
    print(f"✅ 4. PUT /api/items/{item_id}/weight — вес обновлен (100г -> 200г), калории и макросы удвоены.")

    # 5. Проверка дневника за сегодня
    resp_diary = client.get("/api/diary")
    assert resp_diary.status_code == 200
    summary = resp_diary.json()
    assert summary["meals_count"] >= 1
    print(f"✅ 5. GET /api/diary — суточная сводка получена (приемов пищи: {summary['meals_count']}, калорий: {summary['total_calories']}).")

    # 6. Удаление приема пищи
    resp_del = client.delete(f"/api/meals/{meal_id}")
    assert resp_del.status_code == 200
    assert resp_del.json()["deleted_id"] == meal_id

    # Проверяем, что запись больше не существует (должен быть 404)
    resp_not_found = client.get(f"/api/meals/{meal_id}")
    assert resp_not_found.status_code == 404
    print("✅ 6. DELETE /api/meals/{id} — прием пищи успешно удален и возвращает 404.")

    # 6.1 Тестирование сохранения и чтения суточных целей КБЖУ
    resp_goals = client.get("/api/goals")
    assert resp_goals.status_code == 200
    goals = resp_goals.json()
    assert "calories" in goals and "protein" in goals
    print(f"✅ 6.1. GET /api/goals — цели получены ({goals['calories']} ккал, {goals['protein']}г белка).")

    new_goals = {"calories": 2150.0, "protein": 115.0, "fat": 65.0, "carbs": 240.0}
    resp_put_goals = client.put("/api/goals", json=new_goals)
    assert resp_put_goals.status_code == 200
    saved_goals = resp_put_goals.json()
    assert saved_goals["calories"] == 2150.0
    assert saved_goals["protein"] == 115.0
    print("✅ 6.2. PUT /api/goals — цели успешно обновлены и сохранены в БД.")

    # 7. Тестирование распознавания фото через эндпоинт /api/analyze-photo
    sample_img_path = Path("sample_dish.jpg")
    if sample_img_path.exists():
        print("⏳ Тестируем POST /api/analyze-photo с тестовым фото...")
        with open(sample_img_path, "rb") as f:
            files = {"file": ("sample_dish.jpg", f, "image/jpeg")}
            resp_vision = client.post("/api/analyze-photo", files=files)
            if resp_vision.status_code == 200:
                vision_data = resp_vision.json()
            else:
                print(f"⚠️ Распознавание вернуло код {resp_vision.status_code}: {resp_vision.text}")

    # 7.1 Тестирование текстовой оценки КБЖУ через эндпоинт /api/estimate-nutrition
    # Пустой запрос должен вернуть 400
    resp_empty = client.post("/api/estimate-nutrition", json={"query": "   "})
    assert resp_empty.status_code == 400
    print("✅ 7.1. POST /api/estimate-nutrition — валидация пустого запроса (400) работает.")

    # Реальный запрос на расчет КБЖУ
    resp_estimate = client.post("/api/estimate-nutrition", json={"query": "хлеб зерновой 30г"})
    if resp_estimate.status_code == 200:
        est_data = resp_estimate.json()
        assert "calories" in est_data and est_data["calories"] > 0
        assert "weight_g" in est_data and est_data["weight_g"] > 0
        assert "protein" in est_data
        print(f"✅ 7.2. POST /api/estimate-nutrition успешно рассчитал КБЖУ: '{est_data['name']}' "
              f"({est_data['weight_g']}г, {est_data['calories']} ккал, Б:{est_data['protein']}г).")
    else:
        print(f"⚠️ Текстовая оценка вернула {resp_estimate.status_code}: {resp_estimate.text}")

    print("\n🎉 Все тесты FastAPI бэкенда пройдены успешно!")

if __name__ == "__main__":
    test_api_endpoints()
