import json
import logging
import re
import urllib.error
import urllib.request
from typing import Optional

from models import BarcodeProductResponse, GeminiBarcodeResult

logger = logging.getLogger(__name__)

# Простой in-memory кэш для предотвращения повторных сетевых запросов
_BARCODE_CACHE: dict[str, BarcodeProductResponse] = {}

USER_AGENT = "MyFoodDiary/1.0.15 (https://github.com/AnikaBu/Food_recognition)"

PROMPT_BARCODE_RESOLVER = (
    "Ты экспертная система по глобальной базе штрихкодов продуктов питания (GS1, EAN-13, EAN-8, UPC). "
    "Пользователь передал штрихкод продукта питания. "
    "Твоя задача: "
    "1. Определить, какому реальному продукту питания принадлежит данный штрихкод. "
    "2. Учесть страну/регион по префиксу штрихкода (например: 860 — Сербия, 460-469 — Россия, 385 — Хорватия, 400-440 — Германия и т.д.). "
    "3. Если продукт достоверно известен (например: Plazma Keks Bambi, Moja Kravica, Knjaz Miloš, Coca-Cola, Lay's и т.д.), "
    "верни found=true, точное название на понятном языке (на русском или оригинальном сербском/английском), бренд, вес упаковки/порции в граммах и КБЖУ на 100 г. "
    "4. Если штрихкод неизвестен, вымышленный, случайный набор цифр или ты не уверен в продукте, верни found=false."
)


def clean_barcode(barcode: str) -> str:
    """Удаляет пробелы и дефисы из штрихкода."""
    return re.sub(r"[\s\-]", "", barcode or "")


def get_region_by_barcode_prefix(barcode: str) -> str:
    """
    Определяет страну/регион регистрации штрихкода по стандарту GS1.
    Особое внимание уделено Сербии (860), странам Балкан и Восточной Европы.
    """
    if not barcode or len(barcode) < 3:
        return ""
    p3 = barcode[:3]
    p2 = barcode[:2]

    # Сербия и Балканы
    if p3 == "860":
        return "Сербия (Serbia)"
    if p3 == "385":
        return "Хорватия (Croatia)"
    if p3 == "387":
        return "Босния и Герцеговина (Bosnia and Herzegovina)"
    if p3 == "383":
        return "Словения (Slovenia)"
    if p3 == "389":
        return "Черногория (Montenegro)"
    if p3 == "531":
        return "Северная Македония (North Macedonia)"
    if p3 == "380":
        return "Болгария (Bulgaria)"

    # СНГ и Восточная Европа
    if p2 in ("46", "47", "48"):
        num3 = int(p3) if p3.isdigit() else 0
        if 460 <= num3 <= 469:
            return "Россия (Russia)"
        if num3 == 481:
            return "Беларусь (Belarus)"
        if num3 == 482:
            return "Украина (Ukraine)"
        if num3 == 484:
            return "Молдова (Moldova)"
        if num3 == 487:
            return "Казахстан (Kazakhstan)"
        if num3 == 485:
            return "Армения (Armenia)"
        if num3 == 486:
            return "Грузия (Georgia)"
        if num3 == 476:
            return "Азербайджан (Azerbaijan)"
        if num3 == 477:
            return "Литва (Lithuania)"
        if num3 == 475:
            return "Латвия (Latvia)"
        if num3 == 474:
            return "Эстония (Estonia)"

    # Другие страны мира
    num3 = int(p3) if p3.isdigit() else 0
    if 400 <= num3 <= 440:
        return "Германия (Germany)"
    if 300 <= num3 <= 379:
        return "Франция (France)"
    if 800 <= num3 <= 839:
        return "Италия (Italy)"
    if 840 <= num3 <= 849:
        return "Испания (Spain)"
    if 500 <= num3 <= 509:
        return "Великобритания (United Kingdom)"
    if 868 <= num3 <= 869:
        return "Турция (Turkey)"
    if 520 <= num3 <= 521:
        return "Греция (Greece)"
    if p3 == "590":
        return "Польша (Poland)"
    if p3 == "594":
        return "Румыния (Romania)"
    if p3 == "599":
        return "Венгрия (Hungary)"
    if p3 in ("858", "859"):
        return "Чехия / Словакия (Czech / Slovakia)"
    if 0 <= num3 <= 139:
        return "США / Канада (USA / Canada)"

    return ""


def is_nutrition_data_corrupt(
    calories_100g: float,
    protein_100g: float,
    fat_100g: float,
    carbs_100g: float,
) -> bool:
    """
    Проверяет КБЖУ на физическую корректность и выявляет краудсорсинговые ошибки ввода.
    Возвращает True, если данные физически невозможны (опечатки вроде 1232 г углеводов на 100 г воды).
    """
    # Ни одно значение не может быть строго отрицательным
    if calories_100g < 0 or protein_100g < 0 or fat_100g < 0 or carbs_100g < 0:
        return True

    # Ни один макрос на 100 г продукта не может превышать 100 г
    if protein_100g > 100.0 or fat_100g > 100.0 or carbs_100g > 100.0:
        return True

    # Сумма белков, жиров и углеводов не может превышать 105 г на 100 г продукта
    # (допуск 5 г на погрешности округления)
    if (protein_100g + fat_100g + carbs_100g) > 105.0:
        return True

    # Калорийность на 100 г не может превышать 950 ккал (калорийность чистого масла ~900 ккал)
    if calories_100g > 950.0:
        return True

    # Если есть существенные макросы (>25 г суммарно), но калории равны 0
    if (protein_100g + fat_100g + carbs_100g) > 25.0 and calories_100g <= 0.1:
        return True

    return False


def extract_localized_product_name(p: dict) -> str:
    """
    Извлекает наиболее точное человекочитаемое наименование продукта
    с учетом локализации (русский, сербский/балканский, английский, оригинал).
    """
    candidates = [
        p.get("product_name_ru"),
        p.get("product_name"),
        p.get("product_name_sr"),
        p.get("product_name_sr-latn"),
        p.get("product_name_sr-cyrl"),
        p.get("generic_name_sr"),
        p.get("generic_name_sr-latn"),
        p.get("generic_name_sr-cyrl"),
        p.get("product_name_hr"),
        p.get("generic_name_hr"),
        p.get("product_name_bs"),
        p.get("generic_name_bs"),
        p.get("product_name_en"),
        p.get("generic_name_ru"),
        p.get("generic_name_en"),
        p.get("generic_name"),
        p.get("product_name_de"),
        p.get("product_name_fr"),
        p.get("product_name_it"),
        p.get("product_name_es"),
    ]
    for c in candidates:
        if c and isinstance(c, str):
            clean = c.strip()
            if clean and clean.lower() not in ("unknown", "n/a", "none", "null", "продукт без названия"):
                return clean
    return "Продукт без названия"


def estimate_product_by_barcode_with_gemini(barcode: str) -> Optional[BarcodeProductResponse]:
    """
    Интеллектуальный поиск продукта по штрихкоду через Gemini AI.
    Используется как фоллбэк, когда продукт отсутствует в Open Food Facts (404).
    """
    code = clean_barcode(barcode)
    if not code or not code.isdigit():
        return None

    region = get_region_by_barcode_prefix(code)
    user_content = f"Штрихкод продукта: {code}"
    if region:
        user_content += f", Регион регистрации GS1: {region}"

    try:
        import time
        from google.genai import types
        from vision import MODELS_TO_TRY, get_gemini_client

        client = get_gemini_client()
        last_error = None

        for model_name in MODELS_TO_TRY:
            for _attempt in range(2):
                try:
                    response = client.models.generate_content(
                        model=model_name,
                        contents=[PROMPT_BARCODE_RESOLVER, user_content],
                        config=types.GenerateContentConfig(
                            response_mime_type="application/json",
                            response_json_schema=GeminiBarcodeResult.model_json_schema(),
                        ),
                    )
                    raw_json = response.text
                    data = json.loads(raw_json)
                    parsed = GeminiBarcodeResult(**data)

                    if parsed.found and parsed.name.strip():
                        name = parsed.name.strip()
                        brand = (parsed.brand or "").strip()
                        serving_g = parsed.weight_g if 5.0 <= parsed.weight_g <= 2500.0 else 100.0
                        kcal_100 = max(0.0, min(950.0, float(parsed.calories_100g)))
                        prot_100 = max(0.0, min(100.0, round(float(parsed.protein_100g), 2)))
                        fat_100 = max(0.0, min(100.0, round(float(parsed.fat_100g), 2)))
                        carbs_100 = max(0.0, min(100.0, round(float(parsed.carbs_100g), 2)))

                        factor = serving_g / 100.0
                        result = BarcodeProductResponse(
                            barcode=code,
                            name=name,
                            brand=brand,
                            weight_g=round(serving_g, 1),
                            calories=round(kcal_100 * factor, 1),
                            protein=round(prot_100 * factor, 1),
                            fat=round(fat_100 * factor, 1),
                            carbs=round(carbs_100 * factor, 1),
                            calories_100g=round(kcal_100, 1),
                            protein_100g=prot_100,
                            fat_100g=fat_100,
                            carbs_100g=carbs_100,
                            image_url="",
                        )

                        _BARCODE_CACHE[code] = result
                        # Кэшируем в персональный каталог SQLite
                        try:
                            from db import upsert_saved_product

                            upsert_saved_product(
                                name=name,
                                calories_100g=round(kcal_100, 1),
                                protein_100g=prot_100,
                                fat_100g=fat_100,
                                carbs_100g=carbs_100,
                                barcode=code,
                                brand=brand,
                            )
                        except Exception as e:
                            logger.warning("Не удалось сохранить распознанный Gemini штрихкод в SQLite: %s", e)

                        logger.info("Штрихкод %s успешно определен через Gemini AI: %s (%s)", code, name, brand)
                        return result
                    else:
                        logger.info("Gemini AI не идентифицировал штрихкод %s (found=false)", code)
                        return None
                except Exception as e:
                    last_error = e
                    time.sleep(1.5)
        if last_error:
            logger.warning("Ошибка Gemini при поиске штрихкода %s: %s", code, last_error)
    except Exception as ex:
        logger.warning("Не удалось вызвать Gemini для штрихкода %s: %s", code, ex)

    return None


def fetch_open_food_facts(barcode: str, timeout: float = 6.0) -> Optional[dict]:
    """
    Выполняет HTTP-запрос к публичному REST API Open Food Facts v2.
    Возвращает распарсенный JSON словарь или None, если продукт не найден.
    """
    url = f"https://world.openfoodfacts.org/api/v2/product/{barcode}.json"
    headers = {
        "User-Agent": USER_AGENT,
        "Accept": "application/json",
    }
    req = urllib.request.Request(url, headers=headers)

    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            if response.status == 200:
                data = json.loads(response.read().decode("utf-8"))
                return data
    except urllib.error.HTTPError as e:
        if e.code == 404:
            logger.info("Штрихкод %s не найден в Open Food Facts (404)", barcode)
            return None
        logger.warning("HTTP ошибка при запросе Open Food Facts (%s): %s", barcode, e)
        return None
    except Exception as e:
        logger.error("Ошибка соединения с Open Food Facts (%s): %s", barcode, e)
        return None

    return None


def get_product_by_barcode(barcode: str, timeout: float = 6.0) -> Optional[BarcodeProductResponse]:
    """
    Получает информацию о продукте и его КБЖУ по штрихкоду.
    1. Проверяет in-memory кэш сессии.
    2. Проверяет персональный каталог SQLite (база сохраненных продуктов).
    3. Запрашивает Open Food Facts API (с поддержкой сербских и балканских тегов).
    4. При 404 или отсутствии данных выполняет ИИ-поиск через Gemini Barcode Resolver.
    5. Проверяет корректность КБЖУ на физические ограничения (санитизация краудсорсинга).
    """
    code = clean_barcode(barcode)
    if not code or not code.isdigit() or not (7 <= len(code) <= 14):
        logger.warning("Некорректный формат штрихкода: %s", barcode)
        return None

    if code in _BARCODE_CACHE:
        logger.info("Штрихкод %s возвращен из локального кэша", code)
        return _BARCODE_CACHE[code]

    # 1. Проверяем персональный каталог SQLite (локальная база пользователя)
    try:
        from db import get_saved_product_by_barcode, upsert_saved_product

        saved = get_saved_product_by_barcode(code)
        if saved:
            logger.info("Штрихкод %s найден в персональном каталоге SQLite: %s", code, saved.name)
            # Обновляем счетчик использования
            upsert_saved_product(
                name=saved.name,
                calories_100g=saved.calories_100g,
                protein_100g=saved.protein_100g,
                fat_100g=saved.fat_100g,
                carbs_100g=saved.carbs_100g,
                barcode=saved.barcode,
                brand=saved.brand,
            )
            res = BarcodeProductResponse(
                barcode=code,
                name=saved.name,
                brand=saved.brand or "",
                weight_g=100.0,
                calories=saved.calories_100g,
                protein=saved.protein_100g,
                fat=saved.fat_100g,
                carbs=saved.carbs_100g,
                calories_100g=saved.calories_100g,
                protein_100g=saved.protein_100g,
                fat_100g=saved.fat_100g,
                carbs_100g=saved.carbs_100g,
                image_url="",
            )
            _BARCODE_CACHE[code] = res
            return res
    except Exception as e:
        logger.warning("Ошибка проверки SQLite кэша штрихкодов: %s", e)

    # 2. Запрашиваем Open Food Facts API
    raw_data = fetch_open_food_facts(code, timeout=timeout)
    if not raw_data or raw_data.get("status") != 1 or "product" not in raw_data:
        # Продукт не найден в Open Food Facts -> запускаем Gemini AI Barcode Resolver
        logger.info("Штрихкод %s отсутствует в Open Food Facts, запускаем поиск через Gemini AI", code)
        gemini_res = estimate_product_by_barcode_with_gemini(code)
        if gemini_res:
            return gemini_res
        return None

    p = raw_data["product"]

    # 3. Извлекаем локализованное наименование (сербский, балканские языки, русский, оригинал)
    name = extract_localized_product_name(p)
    brand = (p.get("brands") or "").strip()
    image_url = (p.get("image_front_url") or p.get("image_url") or "").strip()

    nutriments = p.get("nutriments", {})

    # Извлекаем калории на 100 г (ккал или перевод из кДж)
    kcal_100 = nutriments.get("energy-kcal_100g")
    if kcal_100 is None:
        kcal_100 = nutriments.get("energy-kcal")
    if kcal_100 is None and "energy_100g" in nutriments:
        # Перевод кДж в ккал (1 ккал = 4.184 кДж)
        try:
            kcal_100 = float(nutriments["energy_100g"]) / 4.184
        except (ValueError, TypeError):
            kcal_100 = 0.0

    try:
        kcal_100 = float(kcal_100) if kcal_100 is not None else 0.0
    except (ValueError, TypeError):
        kcal_100 = 0.0

    # Извлекаем макронутриенты на 100 г
    def _parse_float(val, default: float = 0.0) -> float:
        try:
            return round(float(val), 2) if val is not None else default
        except (ValueError, TypeError):
            return default

    prot_100 = _parse_float(nutriments.get("proteins_100g"))
    fat_100 = _parse_float(nutriments.get("fat_100g"))
    carbs_100 = _parse_float(nutriments.get("carbohydrates_100g"))

    # Размер порции по умолчанию: если в продукте указан serving_quantity (например 250г / 330мл), берем его
    serving_g = 100.0
    raw_serving_q = p.get("serving_quantity")
    if raw_serving_q:
        try:
            val = float(raw_serving_q)
            if 5.0 <= val <= 2000.0:
                serving_g = val
        except (ValueError, TypeError):
            pass

    # Проверяем наличие КБЖУ и физическую корректность данных
    has_nutriments_data = any(
        k in nutriments
        for k in (
            "energy-kcal_100g",
            "energy-kcal",
            "energy_100g",
            "energy",
            "proteins_100g",
            "fat_100g",
            "carbohydrates_100g",
        )
    )
    is_all_zeros = (kcal_100 == 0.0 and prot_100 == 0.0 and fat_100 == 0.0 and carbs_100 == 0.0)
    data_corrupt = is_nutrition_data_corrupt(kcal_100, prot_100, fat_100, carbs_100)

    # Если данных о КБЖУ нет вовсе, все нули или обнаружены явные опечатки краудсорсинга — калибруем через Gemini AI
    if not has_nutriments_data or is_all_zeros or data_corrupt:
        query_text = f"{name} ({brand})" if (brand and brand.lower() not in name.lower()) else name
        reason = "аномальные значения" if data_corrupt else ("все нули" if is_all_zeros else "нет данных")
        logger.warning("КБЖУ для штрихкода %s (%s) требует калибровки (%s). Запускаем Gemini AI...", code, query_text, reason)
        try:
            from vision import estimate_food_nutrition_by_text

            ai_est = estimate_food_nutrition_by_text(query_text, weight_g=serving_g)
            if ai_est:
                if ai_est.name and len(ai_est.name) > 2 and name == "Продукт без названия":
                    name = ai_est.name
                f100 = 100.0 / ai_est.weight_g if ai_est.weight_g > 0 else 1.0
                kcal_100 = round(ai_est.calories * f100, 1)
                prot_100 = round(ai_est.protein * f100, 2)
                fat_100 = round(ai_est.fat * f100, 2)
                carbs_100 = round(ai_est.carbs * f100, 2)
                logger.info(
                    "КБЖУ для штрихкода %s (%s) успешно откалибровано через Gemini AI: %.1f ккал / 100г",
                    code,
                    query_text,
                    kcal_100,
                )
        except Exception as e:
            logger.warning("Не удалось дополнить/откалибровать КБЖУ для штрихкода %s через Gemini AI: %s", code, e)
            if data_corrupt:
                # Защитная санитизация при недоступности AI: устраняем невозможные значения
                if carbs_100 > 100.0:
                    carbs_100 = 0.0
                if prot_100 > 100.0:
                    prot_100 = 0.0
                if fat_100 > 100.0:
                    fat_100 = 0.0
                if kcal_100 > 950.0:
                    kcal_100 = round(prot_100 * 4.0 + fat_100 * 9.0 + carbs_100 * 4.0, 1)

    # Расчет КБЖУ на порцию serving_g
    factor = serving_g / 100.0
    calories = round(kcal_100 * factor, 1)
    protein = round(prot_100 * factor, 1)
    fat = round(fat_100 * factor, 1)
    carbs = round(carbs_100 * factor, 1)

    result = BarcodeProductResponse(
        barcode=code,
        name=name,
        brand=brand,
        weight_g=round(serving_g, 1),
        calories=calories,
        protein=protein,
        fat=fat,
        carbs=carbs,
        calories_100g=round(kcal_100, 1),
        protein_100g=prot_100,
        fat_100g=fat_100,
        carbs_100g=carbs_100,
        image_url=image_url,
    )

    _BARCODE_CACHE[code] = result

    # Сохраняем в персональный каталог SQLite для мгновенного доступа в будущем
    try:
        from db import upsert_saved_product

        upsert_saved_product(
            name=name,
            calories_100g=round(kcal_100, 1),
            protein_100g=prot_100,
            fat_100g=fat_100,
            carbs_100g=carbs_100,
            barcode=code,
            brand=brand,
        )
    except Exception as e:
        logger.warning("Не удалось сохранить продукт в SQLite каталог: %s", e)

    return result
