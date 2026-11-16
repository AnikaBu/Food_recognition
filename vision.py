import os
import sys
import json
import time
from pathlib import Path
from typing import Union, Optional
from dotenv import load_dotenv
from PIL import Image
from models import (
    FoodAnalysisResult,
    EstimateNutritionResponse,
    WeeklyMacroSummary,
    WeeklyReportResponse,
)

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


def _generate_structured_json(contents: list, schema_cls, error_prefix: str):
    """Выполняет запрос в Gemini со структурированным JSON-ответом и перебором резервных моделей."""
    from google.genai import types

    client = get_gemini_client()
    last_error = None

    for model_name in MODELS_TO_TRY:
        for attempt in range(2):
            try:
                response = client.models.generate_content(
                    model=model_name,
                    contents=contents,
                    config=types.GenerateContentConfig(
                        response_mime_type="application/json",
                        response_json_schema=schema_cls.model_json_schema(),
                    ),
                )
                data = json.loads(response.text)
                return schema_cls(**data)
            except Exception as e:
                last_error = e
                time.sleep(1.5)

    raise RuntimeError(f"{error_prefix}. Ошибка: {last_error}")


def analyze_food_image(image_input: Union[str, Path, Image.Image]) -> FoodAnalysisResult:
    """
    Принимает путь к файлу или уже открытый объект PIL.Image.
    Отправляет в Gemini API и возвращает FoodAnalysisResult.
    """
    if isinstance(image_input, (str, Path)):
        img = Image.open(image_input)
    elif isinstance(image_input, Image.Image):
        img = image_input
    else:
        raise TypeError("image_input должен быть путем к файлу или объектом PIL.Image")

    return _generate_structured_json(
        contents=[img, PROMPT_FOOD_ANALYSIS],
        schema_cls=FoodAnalysisResult,
        error_prefix="Не удалось распознать блюдо через Gemini",
    )


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
    user_content = f"Описание продукта: '{query}'"
    if weight_g is not None and weight_g > 0:
        user_content += f", вес порции: {weight_g} г"

    return _generate_structured_json(
        contents=[PROMPT_ESTIMATE_NUTRITION, user_content],
        schema_cls=EstimateNutritionResponse,
        error_prefix="Не удалось оценить КБЖУ через Gemini",
    )


PROMPT_WEEKLY_REPORT = (
    "Ты дружелюбный и внимательный нутрициолог-аналитик. "
    "Проанализируй статистику питания пользователя за 7-дневный период и список съеденных блюд. "
    "Правила ответа (строго на русском языке): "
    "1. headline: краткий и емкий заголовок-резюме (до 8-10 слов), например «Хороший баланс, но стоит добавить белка». "
    "2. summary: 2-3 живых предложения о том, как прошла неделя по калориям и БЖУ в активные дни (опираясь только на активные дни с едой, не ругай за пустые дни без записей). "
    "3. strengths: 1-3 конкретных повода похвалить (что удалось хорошо). "
    "4. recommendations: 2-3 практичных совета с учетом реальных блюд из рациона пользователя (какие продукты добавить для добора белка или чем скорректировать перебор жиров/углеводов)."
)


def generate_weekly_nutrition_report(
    summary: WeeklyMacroSummary,
    context: dict,
    targets: dict,
) -> WeeklyReportResponse:
    """Генерирует персональный ИИ-отчет за неделю на основе агрегатов КБЖУ и реальных блюд."""
    meals_by_day = context.get("meals_by_day", {})
    day_lines = []
    for d in summary.days:
        if d.meals_count == 0 and d.calories == 0:
            continue
        dishes = meals_by_day.get(d.date, [])
        dish_names = ", ".join(f"{m['dish_name']} ({m['calories']:.0f} ккал)" for m in dishes[:8])
        day_lines.append(
            f"- {d.day_name} ({d.date}): {d.calories:.0f} ккал, Б {d.protein:.0f}г, Ж {d.fat:.0f}г, У {d.carbs:.0f}г | Блюда: {dish_names}"
        )

    payload_text = (
        f"Период: {summary.start_date} – {summary.end_date}. "
        f"Активных дней с записями: {summary.active_days} из 7.\n"
        f"Суточные цели пользователя: {targets['calories']:.0f} ккал, "
        f"Белки {targets['protein']:.0f} г, Жиры {targets['fat']:.0f} г, Углеводы {targets['carbs']:.0f} г.\n"
        f"Среднее в активный день: {summary.avg_calories:.0f} ккал, "
        f"Белки {summary.avg_protein:.0f} г, Жиры {summary.avg_fat:.0f} г, Углеводы {summary.avg_carbs:.0f} г.\n"
        f"Тренировки за период: {context.get('workouts_count', 0)} шт., "
        f"{context.get('workout_minutes', 0)} мин, сожжено ~{context.get('workout_calories', 0):.0f} ккал.\n"
        f"Детализация активных дней:\n" + ("\n".join(day_lines) if day_lines else "Нет данных")
    )

    return _generate_structured_json(
        contents=[PROMPT_WEEKLY_REPORT, payload_text],
        schema_cls=WeeklyReportResponse,
        error_prefix="Не удалось сформировать недельный ИИ-отчет через Gemini",
    )
