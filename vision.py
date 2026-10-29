import os
import sys
import json
import time
from pathlib import Path
from typing import Union, Optional
from dotenv import load_dotenv
from PIL import Image
from models import FoodAnalysisResult, EstimateNutritionResponse

load_dotenv()

PROMPT_FOOD_ANALYSIS = (
    "Ты опытный диетолог и специалист по точному распознаванию блюд. "
    "Внимательно изучи предоставленную фотографию. "
    "1. Определи общее название блюда на русском языке. "
    "2. Раздели блюдо на конкретные составляющие ингредиенты. "
    "3. Оцени примерный вес каждого ингредиента в граммах. "
    "4. Рассчитай калорийность (ккал), белки, жиры и углеводы для каждого ингредиента и для всего блюда суммарно. "
    "5. Если на фото видны соусы, подливы, масло или панировка — обязательно включи их отдельными ингредиентами. "
    "6. Дай краткий полезный комментарий диетолога по составу."
)

MODELS_TO_TRY = ["gemini-3.5-flash-lite", "gemini-3.8-flash", "gemini-3.5-flash"]


def get_gemini_client():
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key or api_key == "your_gemini_api_key_here":
        raise ValueError("GEMINI_API_KEY не задан в .env файле!")
    from google import genai
    return genai.Client(api_key=api_key)


def analyze_food_image(image_input: Union[str, Path, Image.Image]) -> FoodAnalysisResult:
    """
    Принимает путь к файлу или уже открытый объект PIL.Image.
    Отправляет в Gemini API и возвращает FoodAnalysisResult.
    """
    from google.genai import types

    client = get_gemini_client()

    if isinstance(image_input, (str, Path)):
        img = Image.open(image_input)
    elif isinstance(image_input, Image.Image):
        img = image_input
    else:
        raise TypeError("image_input должен быть путем к файлу или объектом PIL.Image")

    last_error = None

    for model_name in MODELS_TO_TRY:
        for attempt in range(2):
            try:
                response = client.models.generate_content(
                    model=model_name,
                    contents=[img, PROMPT_FOOD_ANALYSIS],
                    config=types.GenerateContentConfig(
                        response_mime_type="application/json",
                        response_json_schema=FoodAnalysisResult.model_json_schema(),
                    ),
                )
                raw_json = response.text
                data = json.loads(raw_json)
                return FoodAnalysisResult(**data)
            except Exception as e:
                last_error = e
                time.sleep(1.5)

    raise RuntimeError(f"Не удалось распознать блюдо через Gemini. Ошибка: {last_error}")


PROMPT_ESTIMATE_NUTRITION = (
    "Ты опытный диетолог и специалист по точному расчету состава продуктов. "
    "Пользователь передал текстовое описание продукта или блюда. "
    "Твоя задача: "
    "1. Сформулировать чистое понятное название продукта на русском языке (без указания граммовки в названии). "
    "2. Определить точный вес в граммах. Если вес указан пользователем в тексте (например '30г', '150 грамм', '2 куска ~60г') или передан параметром — используй его. Если вес вообще не указан, возьми стандартный размер порции или 100г. "
    "3. Точно рассчитать калорийность (ккал), белки, жиры и углеводы именно для этого веса. "
    "4. Дать короткий полезный комментарий диетолога по составу."
)


def estimate_food_nutrition_by_text(query: str, weight_g: Optional[float] = None) -> EstimateNutritionResponse:
    """
    Принимает строку запроса (например: 'хлеб зерновой 30г' или 'куриное филе')
    и опциональный вес в граммах.
    Отправляет в Gemini API и возвращает EstimateNutritionResponse.
    """
    from google.genai import types

    client = get_gemini_client()

    user_content = f"Описание продукта: '{query}'"
    if weight_g is not None and weight_g > 0:
        user_content += f", вес порции: {weight_g} г"

    last_error = None

    for model_name in MODELS_TO_TRY:
        for attempt in range(2):
            try:
                response = client.models.generate_content(
                    model=model_name,
                    contents=[PROMPT_ESTIMATE_NUTRITION, user_content],
                    config=types.GenerateContentConfig(
                        response_mime_type="application/json",
                        response_json_schema=EstimateNutritionResponse.model_json_schema(),
                    ),
                )
                raw_json = response.text
                data = json.loads(raw_json)
                return EstimateNutritionResponse(**data)
            except Exception as e:
                last_error = e
                time.sleep(1.5)

    raise RuntimeError(f"Не удалось оценить КБЖУ через Gemini. Ошибка: {last_error}")
