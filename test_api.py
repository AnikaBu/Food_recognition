import pytest
from pathlib import Path
from fastapi.testclient import TestClient
from server import app
import db

client = TestClient(app)

import os

@pytest.fixture(autouse=True)
def isolate_db():
    orig_env = os.environ.get("DB_PATH")
    orig_db_path = db.DEFAULT_DB_PATH
    test_db_path = Path("test_api.db")
    if test_db_path.exists():
        test_db_path.unlink()
    os.environ["DB_PATH"] = str(test_db_path)
    db.DEFAULT_DB_PATH = test_db_path
    db.init_db(test_db_path)
    yield
    if orig_env is not None:
        os.environ["DB_PATH"] = orig_env
    else:
        os.environ.pop("DB_PATH", None)
    db.DEFAULT_DB_PATH = orig_db_path
    if test_db_path.exists():
        test_db_path.unlink()

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

    # 4.1 Тестирование обновления приема пищи (название, категория, ингредиенты)
    resp_update_meal = client.put(
        f"/api/meals/{meal_id}",
        json={
            "dish_name": "Индейка запеченная с травами",
            "meal_type": "dinner",
            "comment": "Вкусный ужин",
            "items": [
                {
                    "id": item_id,
                    "name": "Индейка запеченная",
                    "weight_g": 250.0,
                    "calories": 325.0,
                    "protein": 60.0,
                    "fat": 5.0,
                    "carbs": 0.0,
                }
            ],
        },
    )
    assert resp_update_meal.status_code == 200
    updated_meal_data = resp_update_meal.json()
    assert updated_meal_data["dish_name"] == "Индейка запеченная с травами"
    assert updated_meal_data["meal_type"] == "dinner"
    assert updated_meal_data["total_calories"] == 325.0
    print("✅ 4.1. PUT /api/meals/{id} — прием пищи успешно обновлен (название, категория, КБЖУ).")

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

    new_goals = {
        "calories": 2150.0,
        "protein": 115.0,
        "fat": 65.0,
        "carbs": 240.0,
        "gender": "female",
        "age": 27,
        "height_cm": 168.0,
        "weight_kg": 59.0,
        "activity_level": "light",
        "goal": "lose_weight",
    }
    resp_put_goals = client.put("/api/goals", json=new_goals)
    assert resp_put_goals.status_code == 200
    saved_goals = resp_put_goals.json()
    assert saved_goals["calories"] == 2150.0
    assert saved_goals["protein"] == 115.0
    assert saved_goals["gender"] == "female"
    assert saved_goals["age"] == 27
    assert saved_goals["height_cm"] == 168.0
    assert saved_goals["weight_kg"] == 59.0
    assert saved_goals["activity_level"] == "light"
    assert saved_goals["goal"] == "lose_weight"
    print("✅ 6.2. PUT /api/goals — цели и параметры профиля успешно обновлены и сохранены в БД.")

    # 6.3 Тестирование недельного обзора КБЖУ через эндпоинт /api/stats/weekly
    resp_weekly = client.get("/api/stats/weekly")
    assert resp_weekly.status_code == 200
    weekly_data = resp_weekly.json()
    assert "days" in weekly_data
    assert len(weekly_data["days"]) == 7
    assert "avg_calories" in weekly_data
    assert "target_calories" in weekly_data
    assert weekly_data["target_calories"] == 2150.0
    print(f"✅ 6.3. GET /api/stats/weekly — недельный обзор успешно получен (7 дней, цель: {weekly_data['target_calories']} ккал).")


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

    # 8. Тестирование поиска по штрихкоду через эндпоинт /api/barcode/{barcode}
    # 8.1 Некорректный формат штрихкода (слишком короткий или буквы)
    resp_invalid_bc = client.get("/api/barcode/invalid-code")
    assert resp_invalid_bc.status_code == 400
    print("✅ 8.1. GET /api/barcode/{code} — валидация формата штрихкода (400) работает.")

    # 8.2 Поиск заведомо несуществующего штрихкода (должен вернуть 404)
    # Чтобы тест работал даже в изолированном окружении, можно замокать fetch_open_food_facts
    from unittest.mock import patch
    with patch("barcode_service.fetch_open_food_facts", return_value=None):
        resp_404_bc = client.get("/api/barcode/9999999999999")
        assert resp_404_bc.status_code == 404
        assert "не найден" in resp_404_bc.json()["detail"]
    print("✅ 8.2. GET /api/barcode/{code} — обработка отсутствующего продукта (404) работает.")

    # 8.3 Успешный поиск продукта (с моком и/или реальным запросом при наличии сети)
    mock_off_data = {
        "status": 1,
        "product": {
            "product_name_ru": "Тестовый напиток Кола",
            "brands": "Кола Компани",
            "serving_quantity": 250,
            "nutriments": {
                "energy-kcal_100g": 42.0,
                "proteins_100g": 0.0,
                "fat_100g": 0.0,
                "carbohydrates_100g": 10.6,
            }
        }
    }
    with patch("barcode_service.fetch_open_food_facts", return_value=mock_off_data):
        resp_mock_bc = client.get("/api/barcode/5449000000996")
        assert resp_mock_bc.status_code == 200
        bc_data = resp_mock_bc.json()
        assert bc_data["name"] == "Тестовый напиток Кола"
        assert bc_data["brand"] == "Кола Компани"
        assert bc_data["weight_g"] == 250.0
        assert bc_data["calories_100g"] == 42.0
        assert bc_data["calories"] == 105.0  # 42 * 2.5
        assert bc_data["carbs"] == 26.5      # 10.6 * 2.5
    print("✅ 8.3. GET /api/barcode/{code} — успешный расчет порции и КБЖУ на 100г работает корректно.")

    # 8.4 Поиск продукта с отсутствующим КБЖУ в Open Food Facts -> обогащение через Gemini AI
    from models import EstimateNutritionResponse
    mock_off_empty_nutriments = {
        "status": 1,
        "product": {
            "product_name": "Carski sir",
            "brands": "Pilos",
            "serving_quantity": 100,
            "nutriments": {}
        }
    }
    mock_ai_response = EstimateNutritionResponse(
        name="Сыр Царский (Pilos)",
        weight_g=100.0,
        calories=356.0,
        protein=25.0,
        fat=28.0,
        carbs=0.5,
        comment="Полутвердый сыр, отличный источник белка"
    )
    with patch("barcode_service.fetch_open_food_facts", return_value=mock_off_empty_nutriments), \
         patch("vision.estimate_food_nutrition_by_text", return_value=mock_ai_response):
        resp_enriched_bc = client.get("/api/barcode/20146603")
        assert resp_enriched_bc.status_code == 200
        enr_data = resp_enriched_bc.json()
        assert enr_data["calories_100g"] == 356.0
        assert enr_data["protein_100g"] == 25.0
        assert enr_data["fat_100g"] == 28.0
        assert enr_data["carbs_100g"] == 0.5
        assert enr_data["calories"] == 356.0
    print("✅ 8.4. GET /api/barcode/{code} — автоматическое обогащение КБЖУ через Gemini AI работает корректно.")

    # 9. Тестирование эндпоинтов управления рецептами (/api/recipes)
    # 9.1 Создание рецепта сложного блюда
    recipe_payload = {
        "title": "Домашний борщ",
        "description": "Классический красный борщ со свеклой и говядиной",
        "cooked_weight_g": 2000.0,
        "items": [
            {"name": "Говядина мякоть", "weight_g": 500.0, "calories": 950.0, "protein": 95.0, "fat": 65.0, "carbs": 0.0},
            {"name": "Свекла", "weight_g": 300.0, "calories": 130.0, "protein": 4.5, "fat": 0.3, "carbs": 27.0},
            {"name": "Капуста белокочанная", "weight_g": 300.0, "calories": 80.0, "protein": 5.4, "fat": 0.3, "carbs": 14.1},
            {"name": "Картофель", "weight_g": 400.0, "calories": 308.0, "protein": 8.0, "fat": 1.6, "carbs": 64.0},
        ]
    }
    # Всего сырого: 1500г. Калории: 950 + 130 + 80 + 308 = 1468 ккал.
    # Готовое с бульоном: 2000г. На 100г: 1468 * (100 / 2000) = 73.4 ккал.
    resp_create_rec = client.post("/api/recipes", json=recipe_payload)
    assert resp_create_rec.status_code == 201
    rec_data = resp_create_rec.json()
    recipe_id = rec_data["id"]
    assert rec_data["title"] == "Домашний борщ"
    assert rec_data["raw_weight_g"] == 1500.0
    assert rec_data["cooked_weight_g"] == 2000.0
    assert rec_data["calories_100g"] == 73.4
    print(f"✅ 9.1. POST /api/recipes — рецепт '{rec_data['title']}' создан (ID: {recipe_id}, 100г = {rec_data['calories_100g']} ккал).")

    # 9.2 Получение списка рецептов
    resp_list_rec = client.get("/api/recipes")
    assert resp_list_rec.status_code == 200
    assert any(r["id"] == recipe_id for r in resp_list_rec.json())
    print("✅ 9.2. GET /api/recipes — список рецептов успешно получен.")

    # 9.3 Внесение порции 350г в дневник питания через /api/recipes/{id}/log
    resp_log = client.post(f"/api/recipes/{recipe_id}/log", json={"meal_type": "lunch", "portion_weight_g": 350.0})
    assert resp_log.status_code == 201
    logged_meal = resp_log.json()
    assert logged_meal["total_weight_g"] == 350.0
    # 73.4 * 3.5 = 256.9 ккал
    assert abs(logged_meal["total_calories"] - 256.9) < 0.2
    print(f"✅ 9.3. POST /api/recipes/{{id}}/log — порция {logged_meal['total_weight_g']}г внесена в дневник ({logged_meal['total_calories']} ккал).")

    # Очищаем созданный прием пищи
    client.delete(f"/api/meals/{logged_meal['id']}")

    # 9.4 Удаление рецепта
    resp_del_rec = client.delete(f"/api/recipes/{recipe_id}")
    assert resp_del_rec.status_code == 200
    assert client.get(f"/api/recipes/{recipe_id}").status_code == 404
    print("✅ 9.4. DELETE /api/recipes/{id} — рецепт успешно удален.")

    # 10. Тестирование персонального каталога продуктов (/api/products)
    # Сохраняем продукт в каталог через upsert
    db.upsert_saved_product(
        name="Творог 5% мягкий",
        brand="Савушкин",
        calories_100g=85.0,
        protein_100g=11.0,
        fat_100g=5.0,
        carbs_100g=2.5,
        barcode="4810268034567",
    )

    # 10.1 Поиск для автокомплита
    resp_search = client.get("/api/products/search?q=творог")
    assert resp_search.status_code == 200
    products = resp_search.json()
    assert len(products) >= 1
    found = next((p for p in products if "Творог" in p["name"]), None)
    assert found is not None
    assert found["brand"] == "Савушкин"
    assert found["calories_100g"] == 85.0
    print("✅ 10.1. GET /api/products/search — автодополнение по названию работает корректно.")

    # 10.2 Мгновенное чтение штрихкода из локального каталога SQLite без сети
    from barcode_service import _BARCODE_CACHE
    _BARCODE_CACHE.pop("4810268034567", None)

    with patch("barcode_service.fetch_open_food_facts", side_effect=Exception("Should not call external API")):
        resp_local_bc = client.get("/api/barcode/4810268034567")
        assert resp_local_bc.status_code == 200
        lbc = resp_local_bc.json()
        assert lbc["name"] == "Творог 5% мягкий"
        assert lbc["brand"] == "Савушкин"
        assert lbc["calories_100g"] == 85.0
    print("✅ 10.2. GET /api/barcode/{code} — мгновенный ответ из локальной базы без сетевых запросов.")

    # 10.3 Удаление продукта из каталога
    resp_del_prod = client.delete(f"/api/products/{found['id']}")
    assert resp_del_prod.status_code == 200
    assert client.delete(f"/api/products/{found['id']}").status_code == 404
    print("✅ 10.3. DELETE /api/products/{id} — удаление продукта из каталога работает корректно.")

    # 11. Тестирование расширенного модуля штрихкодов: GS1 префиксы, локализация (Сербия/Балканы), санитизация и ИИ-фоллбэк
    from barcode_service import (
        get_region_by_barcode_prefix,
        is_nutrition_data_corrupt,
        extract_localized_product_name,
        estimate_product_by_barcode_with_gemini,
        _BARCODE_CACHE,
    )
    from models import BarcodeProductResponse

    # 11.1 Проверка GS1 префиксов регионов
    assert "Сербия" in get_region_by_barcode_prefix("8600043000016")
    assert "Россия" in get_region_by_barcode_prefix("4601234567890")
    assert "Хорватия" in get_region_by_barcode_prefix("3851234567890")
    assert "Германия" in get_region_by_barcode_prefix("4001234567890")
    print("✅ 11.1. get_region_by_barcode_prefix — корректное определение GS1 префиксов (Сербия 860, РФ 460, Хорватия 385).")

    # 11.2 Проверка санитизации краудсорсинговых данных
    # Корректные данные: Plazma keks (424 ккал, 11.9г Б, 12г Ж, 67г У)
    assert not is_nutrition_data_corrupt(424.0, 11.9, 12.0, 67.0)
    # Опечатка 1: 1232 г углеводов (как в Knjaz Miloš в OFF)
    assert is_nutrition_data_corrupt(0.0, 0.0, 0.0, 1232.0)
    # Опечатка 2: Сумма макросов > 105 г
    assert is_nutrition_data_corrupt(500.0, 50.0, 40.0, 30.0)
    # Опечатка 3: Калорийность > 950 ккал
    assert is_nutrition_data_corrupt(1200.0, 10.0, 10.0, 10.0)
    # Опечатка 4: Отрицательные значения
    assert is_nutrition_data_corrupt(-10.0, 0.0, 0.0, 0.0)
    print("✅ 11.2. is_nutrition_data_corrupt — фильтрация аномалий краудсорсинга работает надежно.")

    # 11.3 Проверка извлечения локализованных названий (Сербия, Балканы)
    raw_serbian_prod = {
        "product_name_sr": "Plazma Keks Mleveni",
        "generic_name_sr": "Keks obogaćen vitaminima",
        "product_name": "",
    }
    assert extract_localized_product_name(raw_serbian_prod) == "Plazma Keks Mleveni"

    raw_latin_sr_prod = {
        "product_name_sr-latn": "Moja Kravica Sveže Mleko",
        "product_name": None,
    }
    assert extract_localized_product_name(raw_latin_sr_prod) == "Moja Kravica Sveže Mleko"
    print("✅ 11.3. extract_localized_product_name — сербские и балканские локализованные теги успешно извлекаются.")

    # 11.4 Проверка ИИ-фоллбэка через Gemini при 404 от Open Food Facts
    _BARCODE_CACHE.pop("8609999999999", None)
    mock_gemini_prod = BarcodeProductResponse(
        barcode="8609999999999",
        name="Serbian Homemade Ajvar",
        brand="Bakina Tajna",
        weight_g=100.0,
        calories=142.0,
        protein=1.8,
        fat=11.2,
        carbs=8.5,
        calories_100g=142.0,
        protein_100g=1.8,
        fat_100g=11.2,
        carbs_100g=8.5,
        image_url="",
    )
    with patch("barcode_service.fetch_open_food_facts", return_value=None), \
         patch("barcode_service.estimate_product_by_barcode_with_gemini", return_value=mock_gemini_prod):
        resp_ai_bc = client.get("/api/barcode/8609999999999")
        assert resp_ai_bc.status_code == 200
        ai_bc_data = resp_ai_bc.json()
        assert ai_bc_data["name"] == "Serbian Homemade Ajvar"
        assert ai_bc_data["brand"] == "Bakina Tajna"
        assert ai_bc_data["calories_100g"] == 142.0
    print("✅ 11.4. GET /api/barcode/{code} — ИИ-фоллбэк через Gemini при 404 Open Food Facts успешно возвращает продукт.")

    # 11.5 Проверка авто-привязки штрихкода при сохранении блюда из комментария
    save_barcode_meal_payload = {
        "meal_type": "snack",
        "dish_name": "Печенье Plazma Bambi",
        "comment": "Перекус на ходу (Штрихкод: 8600043000016)",
        "items": [
            {
                "name": "Печенье Plazma Bambi",
                "weight_g": 50.0,
                "calories": 212.0,
                "protein": 5.95,
                "fat": 6.0,
                "carbs": 33.5,
            }
        ],
    }
    resp_meal_bc = client.post("/api/meals", json=save_barcode_meal_payload)
    assert resp_meal_bc.status_code == 201
    meal_bc_id = resp_meal_bc.json()["id"]

    # Проверяем, что в персональном каталоге SQLite штрихкод автоматически привязался к продукту
    from db import get_saved_product_by_barcode
    saved_from_meal = get_saved_product_by_barcode("8600043000016")
    assert saved_from_meal is not None
    assert "Печенье Plazma" in saved_from_meal.name
    assert abs(saved_from_meal.calories_100g - 424.0) < 0.5
    print("✅ 11.5. POST /api/meals — штрихкод из комментария автоматически привязан к персональному каталогу SQLite.")

    # Очищаем созданный прием пищи
    client.delete(f"/api/meals/{meal_bc_id}")

    print("\n🎉 Все тесты FastAPI бэкенда пройдены успешно!")

if __name__ == "__main__":
    test_api_endpoints()
