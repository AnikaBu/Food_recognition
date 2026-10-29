"""
E2E (End-to-End) тесты веб-интерфейса MyFoodDiary с помощью Playwright.

Этот тест запускает настоящий браузер Chromium, открывает веб-страницу приложения,
кликает по всем кнопкам, меняет граммовки и проверяет реакцию интерфейса.

Запуск:
    .venv/bin/pytest test_frontend.py -v
или напрямую:
    .venv/bin/python test_frontend.py
"""

import os
import sys
import time
import threading
import urllib.request
from pathlib import Path

import pytest
import uvicorn
from playwright.sync_api import sync_playwright, Page, expect

# Используем тестовую базу данных, чтобы не засорять основную
TEST_DB_PATH = Path("test_frontend_nutrition.db")
os.environ["DB_PATH"] = str(TEST_DB_PATH)

from server import app
import db

TEST_PORT = 8009
BASE_URL = f"http://127.0.0.1:{TEST_PORT}"


# =====================================================================
# Фикстура: автоматический запуск и остановка тестового веб-сервера
# =====================================================================
@pytest.fixture(scope="session", autouse=True)
def live_server():
    """Запускает FastAPI сервер в отдельном потоке перед тестами и останавливает после."""
    # Очищаем старую тестовую БД, если осталась
    if TEST_DB_PATH.exists():
        TEST_DB_PATH.unlink()

    db.init_db(TEST_DB_PATH)

    config = uvicorn.Config(
        app=app,
        host="127.0.0.1",
        port=TEST_PORT,
        log_level="error"
    )
    server = uvicorn.Server(config)
    server_thread = threading.Thread(target=server.run, daemon=True)
    server_thread.start()

    # Ждем, пока сервер поднимется и начнет отвечать
    server_ready = False
    for _ in range(50):
        try:
            with urllib.request.urlopen(f"{BASE_URL}/api/health", timeout=1) as resp:
                if resp.status == 200:
                    server_ready = True
                    break
        except Exception:
            time.sleep(0.1)

    if not server_ready:
        raise RuntimeError("Не удалось запустить тестовый сервер FastAPI!")

    print(f"\n🚀 Тестовый сервер запущен на {BASE_URL}")

    yield BASE_URL

    # Завершение работы сервера и очистка
    server.should_exit = True
    server_thread.join(timeout=2)
    if TEST_DB_PATH.exists():
        try:
            TEST_DB_PATH.unlink()
        except Exception:
            pass


# =====================================================================
# ТЕСТЫ КНОПОК И ФУНКЦИОНАЛА
# =====================================================================

def test_01_date_navigation_buttons(page: Page):
    """
    Тест 1: Проверка кнопок навигации по датам (‹ Предыдущий день и › Следующий день).
    """
    page.goto(BASE_URL)

    date_label = page.locator("#dateLabel")
    # Ждем появления надписи "Сегодня..."
    expect(date_label).to_contain_text("Сегодня")
    initial_text = date_label.inner_text()

    # --- Кликаем на кнопку "‹ Предыдущий день" ---
    prev_btn = page.locator("#prevDayBtn")
    expect(prev_btn).to_be_visible()
    prev_btn.click()

    # Проверяем: текст изменился на "Вчера, ..."
    expect(date_label).to_contain_text("Вчера")

    # --- Кликаем на кнопку "› Следующий день" ---
    next_btn = page.locator("#nextDayBtn")
    expect(next_btn).to_be_visible()
    next_btn.click()

    # Проверяем: снова вернулись в "Сегодня"
    expect(date_label).to_have_text(initial_text)


def test_02_meal_category_tabs(page: Page):
    """
    Тест 2: Проверка кнопок выбора категории (🍳 Завтрак, 🍲 Обед, 🥗 Ужин, 🍎 Перекус).
    Важная деталь: кнопки категорий находятся внутри карточки блюда (#resultCard),
    поэтому сначала делаем карточку видимой (как в реальном сценарии после распознавания).
    """
    page.goto(BASE_URL)

    # Отображаем карточку результата, чтобы кнопки стали видимыми на экране
    page.evaluate("document.getElementById('resultCard').style.display = 'block'")

    tab_breakfast = page.locator('#resultCard .type-tab[data-type="breakfast"]')
    tab_lunch = page.locator('#resultCard .type-tab[data-type="lunch"]')
    tab_dinner = page.locator('#resultCard .type-tab[data-type="dinner"]')
    tab_snack = page.locator('#resultCard .type-tab[data-type="snack"]')

    # По умолчанию активен "Обед"
    expect(tab_lunch).to_have_class("type-tab active")

    # 1. Кликаем на "Завтрак"
    tab_breakfast.click()
    expect(tab_breakfast).to_have_class("type-tab active")
    expect(tab_lunch).not_to_have_class("active")

    # 2. Кликаем на "Ужин"
    tab_dinner.click()
    expect(tab_dinner).to_have_class("type-tab active")
    expect(tab_breakfast).not_to_have_class("active")

    # 3. Кликаем на "Перекус"
    tab_snack.click()
    expect(tab_snack).to_have_class("type-tab active")
    expect(tab_dinner).not_to_have_class("active")

    # 4. Возвращаемся на "Обед"
    tab_lunch.click()
    expect(tab_lunch).to_have_class("type-tab active")
    expect(tab_snack).not_to_have_class("active")


def test_03_action_buttons_visibility(page: Page):
    """
    Тест 3: Проверка наличия кнопок выбора фото (Камера и Галерея).
    """
    page.goto(BASE_URL)

    # Проверяем кнопки-лейблы
    camera_btn = page.locator('label[for="cameraInput"]')
    gallery_btn = page.locator('label[for="fileInput"]')

    expect(camera_btn).to_be_visible()
    expect(camera_btn).to_contain_text("Камера")

    expect(gallery_btn).to_be_visible()
    expect(gallery_btn).to_contain_text("Галерея")


def test_04_ingredient_weight_recalculation_and_cancel(page: Page):
    """
    Тест 4: Проверка карточки блюда, пересчета веса ингредиента и кнопки 'Отмена'.
    """
    page.goto(BASE_URL)

    # Имитируем, что ИИ распознал тестовое блюдо (вызываем функцию фронтенда)
    mock_meal = {
        "dish_name": "Тестовая паста с сыром",
        "comment": "Сытное итальянское блюдо",
        "items": [
            {
                "name": "Спагетти отварные",
                "weight_g": 150.0,
                "calories": 230.0,
                "protein": 8.0,
                "fat": 1.5,
                "carbs": 45.0
            }
        ],
        "total_weight_g": 150.0,
        "total_calories": 230.0,
        "total_protein": 8.0,
        "total_fat": 1.5,
        "total_carbs": 45.0
    }

    # Передаем объект в JavaScript состояние фронтенда
    page.evaluate("""(meal) => {
        state.analyzedMeal = meal;
        renderAnalysisResult(meal);
    }""", mock_meal)

    # 1. Проверяем, что карточка результата появилась
    result_card = page.locator("#resultCard")
    expect(result_card).to_be_visible()
    expect(page.locator("#dishTitle")).to_have_text("Тестовая паста с сыром")

    # 2. Проверяем пересчет: увеличиваем вес спагетти со 150г до 300г (в 2 раза)
    weight_input = page.locator(".weight-input").first
    expect(weight_input).to_have_value("150")

    # Вводим 300 и эмулируем событие change
    weight_input.fill("300")
    weight_input.dispatch_event("change")

    # Проверяем, что калории удвоились (230 * 2 = 460)
    card_total = page.locator("#cardTotalText")
    expect(card_total).to_contain_text("460 ккал")
    expect(card_total).to_contain_text("300г")

    # 3. Нажимаем кнопку "Отмена"
    cancel_btn = page.locator("#cancelMealBtn")
    cancel_btn.click()

    # Карточка должна скрыться, а зона загрузки фото снова стать видимой
    expect(result_card).not_to_be_visible()
    expect(page.locator("#dropZone")).to_be_visible()


def test_05_save_and_delete_workflow(page: Page):
    """
    Тест 5: Полный сквозной сценарий:
    Клик 'Сохранить в дневник' -> проверка появления в истории -> клик 'Удалить' (корзина).
    """
    page.goto(BASE_URL)

    # Создаем тестовое блюдо
    mock_meal = {
        "dish_name": "Тестовый протеиновый батончик",
        "comment": "Быстрый перекус",
        "items": [
            {
                "name": "Батончик шоколадный",
                "weight_g": 60.0,
                "calories": 210.0,
                "protein": 20.0,
                "fat": 7.0,
                "carbs": 15.0
            }
        ],
        "total_weight_g": 60.0,
        "total_calories": 210.0,
        "total_protein": 20.0,
        "total_fat": 7.0,
        "total_carbs": 15.0
    }

    # Отображаем карточку
    page.evaluate("""(meal) => {
        state.analyzedMeal = meal;
        renderAnalysisResult(meal);
    }""", mock_meal)

    # Выбираем категорию "Перекус"
    page.locator('#resultCard .type-tab[data-type="snack"]').click()

    # --- Кликаем кнопку "💾 Сохранить в дневник" ---
    save_btn = page.locator("#saveMealBtn")
    save_btn.click()

    # 1. Проверяем тост уведомление
    toast = page.locator("#toast")
    expect(toast).to_be_visible()
    expect(toast).to_contain_text("сохранен", ignore_case=True)

    # 2. Проверяем, что блюдо появилось в блоке "История за день"
    history_item = page.locator(".history-item").first
    expect(history_item).to_be_visible()
    expect(history_item).to_contain_text("Тестовый протеиновый батончик")
    expect(history_item).to_contain_text("210 ккал")

    # 3. Проверяем, что суточные метрики вверху обновились
    expect(page.locator("#sumCalories")).to_have_text("210")

    # Регистрируем обработчик диалога: когда браузер вызовет confirm("Удалить...?"),
    # тест автоматически нажмет "OK" (dialog.accept)
    page.once("dialog", lambda dialog: dialog.accept())

    # --- Кликаем кнопку удаления (корзина 🗑️) ---
    delete_btn = history_item.locator(".hist-del-btn")
    delete_btn.click()

    # 4. Проверяем, что карточка удалилась и вернулось пустое состояние
    expect(page.locator(".history-item")).to_have_count(0)
    expect(page.locator("#mealsHistoryList .empty-state")).to_be_visible()

    # Калории за день снова обнулились
    expect(page.locator("#sumCalories")).to_have_text("0")


def test_06_manual_meal_entry_workflow(page: Page):
    """
    Тест 6: Проверка сценария ручного ввода блюда без фото:
    Клик '✍️ Вручную' -> открытие модального окна -> заполнение формы ->
    сохранение -> проверка появления в истории и подсчета КБЖУ.
    """
    page.goto(BASE_URL)

    # 1. Открываем модальное окно ручного ввода
    open_btn = page.locator("#openManualMealBtn")
    expect(open_btn).to_be_visible()
    open_btn.click()

    modal = page.locator("#manualMealModal")
    expect(modal).to_be_visible()

    # 2. Выбираем категорию "Завтрак"
    page.locator('#manualMealTypeTabs .type-tab[data-type="breakfast"]').click()

    # 3. Заполняем поля формы
    page.locator("#manualDishName").fill("Овсянка с медом")
    page.locator("#manualDishWeight").fill("220")
    page.locator("#manualCalories").fill("265")
    page.locator("#manualProtein").fill("9.5")
    page.locator("#manualFat").fill("5.2")
    page.locator("#manualCarbs").fill("45.0")
    page.locator("#manualComment").fill("Домашний полезный завтрак")

    # 4. Нажимаем "Сохранить в дневник"
    page.locator("#manualSubmitBtn").click()

    # Модальное окно должно закрыться
    expect(modal).not_to_be_visible()

    # Тост уведомление
    toast = page.locator("#toast")
    expect(toast).to_be_visible()
    expect(toast).to_contain_text("сохранено", ignore_case=True)

    # 5. Проверяем появление в истории блюд
    history_item = page.locator(".history-item").first
    expect(history_item).to_be_visible()
    expect(history_item).to_contain_text("Овсянка с медом")
    expect(history_item).to_contain_text("265 ккал")
    expect(history_item).to_contain_text("220г")

    # 6. Проверяем обновление счетчиков
    expect(page.locator("#sumCalories")).to_have_text("265")
    expect(page.locator("#sumProtein")).to_have_text("9.5")

    # Удаляем созданную запись для чистоты
    page.once("dialog", lambda dialog: dialog.accept())
    history_item.locator(".hist-del-btn").click()
    expect(page.locator(".history-item")).to_have_count(0)


def test_07_ai_nutrition_estimate_button(page: Page):
    """
    Тест 7: Проверка кнопки '✨ Рассчитать через ИИ' в модальном окне ручного ввода.
    При вводе 'хлеб зерновой 30г' форма должна автоматически заполниться рассчитанными КБЖУ.
    """
    page.goto(BASE_URL)

    # Мокаем вызов /api/estimate-nutrition на уровне window.fetch для надежности UI-теста
    page.evaluate("""() => {
        const origFetch = window.fetch;
        window.fetch = async (url, options) => {
            if (typeof url === 'string' && url.includes('/api/estimate-nutrition')) {
                return new Response(JSON.stringify({
                    name: 'Зерновой хлеб',
                    weight_g: 30.0,
                    calories: 75.0,
                    protein: 3.0,
                    fat: 1.0,
                    carbs: 14.0,
                    comment: 'Сложные углеводы'
                }), { status: 200, headers: { 'Content-Type': 'application/json' } });
            }
            return origFetch(url, options);
        };
    }""")

    # 1. Открываем модальное окно
    page.locator("#openManualMealBtn").click()
    expect(page.locator("#manualMealModal")).to_be_visible()

    # 2. Вводим название продукта
    dish_input = page.locator("#manualDishName")
    dish_input.fill("хлеб зерновой 30г")

    # 3. Нажимаем кнопку "✨ Рассчитать через ИИ"
    ai_btn = page.locator("#manualAiEstimateBtn")
    expect(ai_btn).to_be_visible()
    ai_btn.click()

    # 4. Проверяем автозаполнение полей формы
    expect(dish_input).to_have_value("Зерновой хлеб")
    expect(page.locator("#manualDishWeight")).to_have_value("30")
    expect(page.locator("#manualCalories")).to_have_value("75")
    expect(page.locator("#manualProtein")).to_have_value("3.0")
    expect(page.locator("#manualFat")).to_have_value("1.0")
    expect(page.locator("#manualCarbs")).to_have_value("14.0")
    expect(page.locator("#manualComment")).to_have_value("Сложные углеводы")

    # 5. Закрываем модальное окно
    page.locator("#cancelManualBtn").click()
    expect(page.locator("#manualMealModal")).not_to_be_visible()


def test_08_barcode_lookup_workflow(page: Page):
    """
    Тест 8: Проверка поиска продукта по штрихкоду (Open Food Facts).
    При вводе штрихкода форма должна заполниться наименованием и КБЖУ,
    а при последующем изменении веса КБЖУ должно динамически пересчитываться.
    """
    page.goto(BASE_URL)

    # Мокаем вызов /api/barcode/5449000000996 через window.fetch
    page.evaluate("""() => {
        const origFetch = window.fetch;
        window.fetch = async (url, options) => {
            if (typeof url === 'string' && url.includes('/api/barcode/5449000000996')) {
                return new Response(JSON.stringify({
                    barcode: '5449000000996',
                    name: 'Coca-Cola Original',
                    brand: 'Coca-Cola',
                    weight_g: 250.0,
                    calories: 105.0,
                    protein: 0.0,
                    fat: 0.0,
                    carbs: 26.5,
                    calories_100g: 42.0,
                    protein_100g: 0.0,
                    fat_100g: 0.0,
                    carbs_100g: 10.6,
                    image_url: ''
                }), { status: 200, headers: { 'Content-Type': 'application/json' } });
            }
            return origFetch(url, options);
        };
    }""")

    # 1. Открываем окно ручного ввода
    page.locator("#openManualMealBtn").click()
    expect(page.locator("#manualMealModal")).to_be_visible()

    # 2. Нажимаем кнопку "📦 Штрихкод"
    page.locator("#manualBarcodeBtn").click()
    expect(page.locator("#barcodeModal")).to_be_visible()

    # 3. Вводим штрихкод и нажимаем "Найти"
    page.locator("#barcodeInput").fill("5449000000996")
    page.locator("#barcodeLookupSubmitBtn").click()

    # 4. Проверяем, что окно штрихкода закрылось, а форма ручного ввода заполнилась
    expect(page.locator("#barcodeModal")).not_to_be_visible()
    expect(page.locator("#manualDishName")).to_have_value("Coca-Cola Original (Coca-Cola)")
    expect(page.locator("#manualDishWeight")).to_have_value("250")
    expect(page.locator("#manualCalories")).to_have_value("105")
    expect(page.locator("#manualCarbs")).to_have_value("26.5")

    # 5. Проверяем динамический пересчет КБЖУ при изменении веса (например, изменили с 250г на 500г)
    page.locator("#manualDishWeight").fill("500")
    expect(page.locator("#manualCalories")).to_have_value("210")
    expect(page.locator("#manualCarbs")).to_have_value("53.0")

    # 6. Закрываем окно
    page.locator("#cancelManualBtn").click()
    expect(page.locator("#manualMealModal")).not_to_be_visible()


def test_09_recipes_workflow(page: Page):
    """
    Тест 9: Проверка работы конструктора рецептов (Шаг 3).
    - Открытие окна "Мои рецепты";
    - Открытие конструктора и добавление ингредиентов с расчетом уварки;
    - Сохранение рецепта в базу данных;
    - Внесение взвешенной порции рецепта в дневник питания.
    """
    page.goto(BASE_URL)
    page.wait_for_load_state("networkidle")

    # 1. Открываем окно рецептов
    page.locator("#openRecipesBtn").click()
    expect(page.locator("#recipesListModal")).to_be_visible()

    # 2. Нажимаем кнопку создания рецепта
    page.locator("#openNewRecipeEditorBtn").click()
    expect(page.locator("#recipeEditorModal")).to_be_visible()

    # 3. Заполняем название рецепта
    page.locator("#recipeEditorTitle").fill("Творожная запеканка с изюмом")
    page.locator("#recipeEditorDesc").fill("Фирменный домашний рецепт")

    # 4. Добавляем 2 ингредиента через evaluate в состояние конструктора
    page.evaluate("""() => {
        state.editingRecipeItems = [
            { name: 'Творог 5%', weight_g: 400, calories: 480, protein: 64.0, fat: 20.0, carbs: 12.0 },
            { name: 'Яйцо куриное С0', weight_g: 100, calories: 157, protein: 12.7, fat: 11.5, carbs: 0.7 }
        ];
        renderRecipeEditorItems();
    }""")

    # 5. Проверяем сырой вес (500г) и калории (637 ккал)
    expect(page.locator("#recipeRawWeightSum")).to_have_text("500")
    expect(page.locator("#recipeRawCaloriesSum")).to_have_text("637")

    # 6. Вводим вес готового блюда с учетом уварки (450г)
    page.locator("#recipeEditorCookedWeight").fill("450")
    page.locator("#recipeEditorCookedWeight").dispatch_event("input")

    # 637 * 100 / 450 = 141.55 => 142 ккал на 100г
    expect(page.locator("#rec100Cal")).to_have_text("142")

    # 7. Сохраняем рецепт
    page.locator("#saveRecipeSubmitBtn").click()

    # Окно конструктора закрывается, в списке рецептов появляется созданный рецепт
    expect(page.locator("#recipeEditorModal")).not_to_be_visible()
    expect(page.locator("#recipesListModal")).to_be_visible()

    recipe_card = page.locator("#recipesListContainer .recipe-card").first
    expect(recipe_card).to_be_visible()
    expect(recipe_card.locator(".recipe-card-title")).to_contain_text("Творожная запеканка")

    # 8. Нажимаем "➕ Внести в дневник"
    recipe_card.locator(".btn-log-recipe").click()
    expect(page.locator("#logRecipeModal")).to_be_visible()

    # Задаем вес порции 200г (141.56 * 2 = 283 ккал)
    page.locator("#logRecipeWeightInput").fill("200")
    page.locator("#logRecipeWeightInput").dispatch_event("input")
    expect(page.locator("#logPortionCal")).to_have_text("283")

    # 9. Подтверждаем добавление порции в дневник
    page.locator("#confirmLogRecipeBtn").click()

    # Модальные окна закрываются
    expect(page.locator("#logRecipeModal")).not_to_be_visible()
    expect(page.locator("#recipesListModal")).not_to_be_visible()

    # 10. Проверяем появление записи в дневнике питания
    expect(page.locator("#mealsHistoryList")).to_contain_text("Творожная запеканка с изюмом")
    expect(page.locator("#mealsHistoryList")).to_contain_text("200г")


# =====================================================================
# Возможность прямого запуска через: python test_frontend.py
# =====================================================================

if __name__ == "__main__":
    print("🚀 Запуск E2E тестов веб-интерфейса MyFoodDiary через Playwright...")
    # Передаем аргументы в pytest для красивого вывода
    exit_code = pytest.main([
        "-v",
        "-s",
        __file__,
        "--browser", "chromium",
    ])
    sys.exit(exit_code)
