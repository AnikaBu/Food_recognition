import os
import sys
import json
from pathlib import Path
from dotenv import load_dotenv
from pydantic import BaseModel, Field
from PIL import Image

# Загружаем переменные окружения из .env
load_dotenv()

# Описание структуры ответа (Схема данных)
class IngredientItem(BaseModel):
    name: str = Field(description="Название ингредиента на русском языке")
    weight_g: float = Field(description="Примерный вес ингредиента в граммах")
    calories: float = Field(description="Калорийность порции в ккал")
    protein: float = Field(description="Белки в граммах")
    fat: float = Field(description="Жиры в граммах")
    carbs: float = Field(description="Углеводы в граммах")

class FoodAnalysisResult(BaseModel):
    dish_name: str = Field(description="Общее понятное название блюда на русском языке")
    comment: str = Field(description="Короткий комментарий диетолога по составу блюда")
    items: list[IngredientItem] = Field(description="Список распознанных ингредиентов")
    total_weight_g: float = Field(description="Общий вес блюда в граммах")
    total_calories: float = Field(description="Суммарная калорийность (ккал)")
    total_protein: float = Field(description="Всего белков (г)")
    total_fat: float = Field(description="Всего жиров (г)")
    total_carbs: float = Field(description="Всего углеводов (г)")


def analyze_food_image(image_path: str) -> FoodAnalysisResult:
    """Отправляет изображение в Gemini API и возвращает структурированный анализ КБЖУ."""
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key or api_key == "your_gemini_api_key_here":
        print("\n❌ ОШИБКА: Не указан GEMINI_API_KEY в файле .env!")
        print("👉 Получите бесплатный ключ на: https://aistudio.google.com/")
        print("👉 Вставьте его в файл .env в формате: GEMINI_API_KEY=AIzaSy...\n")
        sys.exit(1)

    path = Path(image_path)
    if not path.exists():
        print(f"\n❌ ОШИБКА: Файл изображения не найден: {image_path}\n")
        sys.exit(1)

    from google import genai
    from google.genai import types

    # Инициализация клиента Gemini
    client = genai.Client(api_key=api_key)
    
    # Открываем изображение через Pillow
    image = Image.open(path)

    prompt = (
        "Ты опытный диетолог и специалист по распознаванию блюд. "
        "Внимательно изучи предоставленную фотографию. "
        "Определи состав блюда, оцени примерный вес каждого ингредиента в граммах "
        "и рассчитай КБЖУ для каждого ингредиента и для блюда в целом. "
        "Если на фото есть видимые соусы или следы масла, учти их в составе."
    )

    print(f"⏳ Отправляем изображение '{path.name}' в нейросеть...")

    # Актуальные модели Gemini
    models_to_try = ["gemini-3.5-flash-lite", "gemini-3.8-flash", "gemini-3.5-flash"]
    last_error = None

    import time
    for model_name in models_to_try:
        for attempt in range(2):
            try:
                response = client.models.generate_content(
                    model=model_name,
                    contents=[image, prompt],
                    config=types.GenerateContentConfig(
                        response_mime_type="application/json",
                        response_json_schema=FoodAnalysisResult.model_json_schema(),
                    ),
                )
                raw_json = response.text
                data = json.loads(raw_json)
                print(f"✨ Распознано успешно моделью: {model_name}")
                return FoodAnalysisResult(**data)
            except Exception as e:
                last_error = e
                time.sleep(1.5)

    raise RuntimeError(f"Не удалось получить ответ от моделей Gemini. Последняя ошибка: {last_error}")


def print_card(result: FoodAnalysisResult):
    """Выводит красивую карточку результата в консоль."""
    sep = "═" * 55
    thin_sep = "─" * 55

    print("\n" + sep)
    print(f"🍽️  БЛЮДО: {result.dish_name.upper()}")
    print(f"💬 Заметка: {result.comment}")
    print(thin_sep)
    print(f"{'Ингредиент':<22} | {'Вес':>6} | {'Ккал':>6} | {'Б':>4} | {'Ж':>4} | {'У':>4}")
    print(thin_sep)
    for it in result.items:
        print(f"{it.name[:21]:<22} | {it.weight_g:>5.0f}г | {it.calories:>5.0f} | {it.protein:>4.1f} | {it.fat:>4.1f} | {it.carbs:>4.1f}")
    print(thin_sep)
    print(f"ИТОГО:{'':<16} | {result.total_weight_g:>5.0f}г | {result.total_calories:>5.0f} | {result.total_protein:>4.1f} | {result.total_fat:>4.1f} | {result.total_carbs:>4.1f}")
    print(sep + "\n")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        img_file = sys.argv[1]
    else:
        # Проверяем наличие тестового файла
        img_file = "sample_dish.jpg"

    result = analyze_food_image(img_file)
    print_card(result)
