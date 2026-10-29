import json
import logging
import re
import urllib.error
import urllib.request
from typing import Optional

from models import BarcodeProductResponse

logger = logging.getLogger(__name__)

# Простой in-memory кэш для предотвращения повторных сетевых запросов
_BARCODE_CACHE: dict[str, BarcodeProductResponse] = {}

USER_AGENT = "MyFoodDiary/1.0.15 (https://github.com/AnikaBu/Food_recognition)"


def clean_barcode(barcode: str) -> str:
    """Удаляет пробелы и дефисы из штрихкода."""
    return re.sub(r"[\s\-]", "", barcode or "")


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
    Сначала проверяет локальный кэш, затем обращается к Open Food Facts API.
    """
    code = clean_barcode(barcode)
    if not code or not code.isdigit() or not (7 <= len(code) <= 14):
        logger.warning("Некорректный формат штрихкода: %s", barcode)
        return None

    if code in _BARCODE_CACHE:
        logger.info("Штрихкод %s возвращен из локального кэша", code)
        return _BARCODE_CACHE[code]

    raw_data = fetch_open_food_facts(code, timeout=timeout)
    if not raw_data or raw_data.get("status") != 1 or "product" not in raw_data:
        return None

    p = raw_data["product"]

    # Определяем наименование (приоритет русскому, затем английскому/оригинальному)
    name = (
        p.get("product_name_ru")
        or p.get("product_name")
        or p.get("generic_name_ru")
        or p.get("generic_name")
        or "Продукт без названия"
    ).strip()

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
    return result
