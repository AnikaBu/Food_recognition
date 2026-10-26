import os
import io
import logging
import asyncio
from typing import Dict, Any

from dotenv import load_dotenv
from PIL import Image

from aiogram import Bot, Dispatcher, F, types
from aiogram.filters import CommandStart, Command
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.fsm.storage.memory import MemoryStorage
from aiogram.types import (
    InlineKeyboardMarkup,
    InlineKeyboardButton,
    CallbackQuery,
    Message,
)

import db
from models import MealType, FoodAnalysisResult, IngredientItem
from vision import analyze_food_image

# Загружаем переменные окружения
load_dotenv()

TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
if not TOKEN:
    raise ValueError("TELEGRAM_BOT_TOKEN не найден в .env!")

# Настройка логирования
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

# Инициализация бота и диспетчера
bot = Bot(token=TOKEN)
dp = Dispatcher(storage=MemoryStorage())


# Состояния FSM (Конечный автомат для диалогов)
class FoodForm(StatesGroup):
    waiting_for_new_weight = State()  # Ожидание ввода нового веса от пользователя


def format_meal_text(analysis_data: Dict[str, Any], current_meal_type: MealType) -> str:
    """Форматирует карточку блюда для отправки пользователю."""
    dish_name = analysis_data["dish_name"]
    comment = analysis_data.get("comment", "")
    items = analysis_data["items"]
    total_w = sum(it["weight_g"] for it in items)
    total_cal = sum(it["calories"] for it in items)
    total_p = sum(it["protein"] for it in items)
    total_f = sum(it["fat"] for it in items)
    total_c = sum(it["carbs"] for it in items)

    lines = [
        f"🍽️ *{dish_name.upper()}*",
        f"Категория: *{current_meal_type.label_ru}*",
        f"💬 _{comment}_\n" if comment else "",
        "📋 *Состав порции:*",
    ]

    for idx, it in enumerate(items, 1):
        lines.append(
            f"{idx}. *{it['name']}*: {it['weight_g']:.0f}г — "
            f"`{it['calories']:.0f} ккал` (Б: {it['protein']:.1f}г, Ж: {it['fat']:.1f}г, У: {it['carbs']:.1f}г)"
        )

    lines.append("\n📊 *ИТОГО ПО БЛЮДУ:*")
    lines.append(f"⚖️ Вес: *{total_w:.0f} г*")
    lines.append(f"🔥 Калории: *{total_cal:.0f} ккал*")
    lines.append(f"🥩 Б: *{total_p:.1f}г* | 🥑 Ж: *{total_f:.1f}г* | 🍞 У: *{total_c:.1f}г*")

    return "\n".join(lines)


def build_meal_keyboard(current_meal_type: MealType, items: list) -> InlineKeyboardMarkup:
    """Создает инлайн-кнопки для управления карточкой блюда."""
    # Ряд 1: Выбор типа приема пищи
    types_buttons = []
    for mt in [MealType.BREAKFAST, MealType.LUNCH, MealType.DINNER, MealType.SNACK]:
        text = f"✅ {mt.label_ru}" if mt == current_meal_type else mt.label_ru
        types_buttons.append(InlineKeyboardButton(text=text, callback_data=f"set_type:{mt.value}"))

    # Разложим кнопки типов в 2 ряда по 2 кнопки
    kb = [
        [types_buttons[0], types_buttons[1]],
        [types_buttons[2], types_buttons[3]],
    ]

    # Ряд 2: Кнопки для изменения веса каждого ингредиента
    for idx, it in enumerate(items):
        kb.append([
            InlineKeyboardButton(
                text=f"✏️ Изменить вес: {it['name']} ({it['weight_g']:.0f}г)",
                callback_data=f"edit_weight:{idx}",
            )
        ])

    # Ряд 3: Кнопка сохранения и отмены
    kb.append([
        InlineKeyboardButton(text="💾 Сохранить в дневник", callback_data="save_meal"),
        InlineKeyboardButton(text="❌ Отмена", callback_data="cancel_meal"),
    ])

    return InlineKeyboardMarkup(inline_keyboard=kb)


@dp.message(CommandStart())
async def cmd_start(message: Message, state: FSMContext):
    """Приветственное сообщение."""
    await state.clear()
    text = (
        "👋 *Привет! Я твой персональный AI-дневник питания MyFoodDiary.*\n\n"
        "📸 **Как мной пользоваться:**\n"
        "1. Просто **отправь мне фото** своей тарелки с едой.\n"
        "2. Нейросеть Gemini мгновенно распознает блюдо, взвесит ингредиенты и посчитает КБЖУ.\n"
        "3. Ты сможешь скорректировать вес и сохранить прием пищи в дневник.\n\n"
        "📊 **Команды:**\n"
        "/today — посмотреть съеденные калории и БЖУ за сегодня\n"
        "/help — помощь и инструкция"
    )
    await message.answer(text, parse_mode="Markdown")


@dp.message(Command("help"))
async def cmd_help(message: Message):
    """Справка по боту."""
    text = (
        "ℹ️ *Инструкция по использованию:*\n\n"
        "• Для лучшего распознавания фотографируйте тарелку сверху при хорошем освещении.\n"
        "• Если нейросеть ошиблась с граммовкой — нажмите кнопку `✏️ Изменить вес` под блюдом.\n"
        "• Все данные хранятся локально в вашей защищенной базе SQLite.\n"
        "• Посмотреть статистику за сегодня: команда /today."
    )
    await message.answer(text, parse_mode="Markdown")


@dp.message(Command("today"))
async def cmd_today(message: Message):
    """Выводит суточный отчет по съеденным КБЖУ за сегодня."""
    summary = db.get_daily_summary()

    if summary.meals_count == 0:
        await message.answer("🥣 За сегодня пока нет сохраненных приемов пищи. Отправьте фото еды, чтобы начать!")
        return

    lines = [
        f"📅 *ДНЕВНИК ПИТАНИЯ ЗА СЕГОДНЯ* ({summary.date})",
        f"Всего приемов пищи: *{summary.meals_count}*\n",
        "🎯 *ИТОГИ ДНЯ:*",
        f"🔥 Всего калорий: *{summary.total_calories:.0f} ккал*",
        f"⚖️ Общий вес еды: *{summary.total_weight_g:.0f} г*",
        f"🥩 Белки: *{summary.total_protein:.1f} г*",
        f"🥑 Жиры: *{summary.total_fat:.1f} г*",
        f"🍞 Углеводы: *{summary.total_carbs:.1f} г*\n",
        "🕒 *Список приемов пищи за день:*",
    ]

    for idx, meal in enumerate(summary.meals, 1):
        time_part = meal.created_at.split()[1][:5] if " " in meal.created_at else ""
        lines.append(f"{idx}. {meal.meal_type.label_ru} ({time_part}): *{meal.dish_name}* — `{meal.total_calories:.0f} ккал`")

    await message.answer("\n".join(lines), parse_mode="Markdown")


@dp.message(F.photo)
async def handle_food_photo(message: Message, state: FSMContext):
    """Обработка фотографии блюда."""
    await state.clear()
    status_msg = await message.answer("🔍 *Изучаю ваше блюдо через Gemini Vision...* Пожалуйста, подождите 2-3 секунды ⏳", parse_mode="Markdown")

    try:
        # Берем фото в максимальном разрешении (последний элемент в списке photo)
        photo = message.photo[-1]
        file_info = await bot.get_file(photo.file_id)

        # Скачиваем прямо в оперативную память (io.BytesIO), не сохраняя на диск!
        photo_bytes = io.BytesIO()
        await bot.download_file(file_info.file_path, photo_bytes)
        photo_bytes.seek(0)

        # Открываем через Pillow
        pil_img = Image.open(photo_bytes)

        # Распознаем блюдо в отдельном потоке, чтобы не блокировать бота
        loop = asyncio.get_running_loop()
        analysis: FoodAnalysisResult = await loop.run_in_executor(None, analyze_food_image, pil_img)

        # Сохраняем в память сессии пользователя
        meal_data = analysis.model_dump()
        current_meal_type = MealType.LUNCH

        await state.update_data(meal_data=meal_data, current_meal_type=current_meal_type.value)

        text = format_meal_text(meal_data, current_meal_type)
        kb = build_meal_keyboard(current_meal_type, meal_data["items"])

        await status_msg.delete()
        await message.answer(text, reply_markup=kb, parse_mode="Markdown")

    except Exception as e:
        logger.error(f"Ошибка распознавания: {e}", exc_info=True)
        await status_msg.edit_text(f"❌ Произошла ошибка при анализе фото: {e}")


@dp.callback_query(F.data.startswith("set_type:"))
async def cb_set_meal_type(callback: CallbackQuery, state: FSMContext):
    """Смена типа приема пищи (Завтрак, Обед, Ужин, Перекус)."""
    new_type_str = callback.data.split(":")[1]
    new_type = MealType(new_type_str)

    data = await state.get_data()
    meal_data = data.get("meal_data")
    if not meal_data:
        await callback.answer("Сессия устарела. Отправьте фото заново.", show_alert=True)
        return

    await state.update_data(current_meal_type=new_type.value)

    text = format_meal_text(meal_data, new_type)
    kb = build_meal_keyboard(new_type, meal_data["items"])

    await callback.message.edit_text(text, reply_markup=kb, parse_mode="Markdown")
    await callback.answer(f"Выбрано: {new_type.label_ru}")


@dp.callback_query(F.data.startswith("edit_weight:"))
async def cb_request_weight_edit(callback: CallbackQuery, state: FSMContext):
    """Пользователь нажал кнопку изменения веса конкретного ингредиента."""
    item_index = int(callback.data.split(":")[1])

    data = await state.get_data()
    meal_data = data.get("meal_data")
    if not meal_data or item_index >= len(meal_data["items"]):
        await callback.answer("Ошибка: ингредиент не найден", show_alert=True)
        return

    item = meal_data["items"][item_index]
    await state.update_data(editing_item_index=item_index)
    await state.set_state(FoodForm.waiting_for_new_weight)

    await callback.message.answer(
        f"✏️ Введите новый вес в граммах для: *{item['name']}*\n"
        f"Текущий вес: `{item['weight_g']:.0f}г`.\n\n"
        "Напишите просто число (например: `200`):",
        parse_mode="Markdown"
    )
    await callback.answer()


@dp.message(FoodForm.waiting_for_new_weight)
async def process_new_weight(message: Message, state: FSMContext):
    """Обработка введенного пользователем нового веса в граммах."""
    raw_text = message.text.strip().replace(",", ".")
    try:
        new_weight = float(raw_text)
        if new_weight <= 0:
            raise ValueError()
    except ValueError:
        await message.answer("⚠️ Пожалуйста, введите корректное положительное число граммов (например: `150`).")
        return

    data = await state.get_data()
    meal_data = data.get("meal_data")
    item_index = data.get("editing_item_index")
    current_meal_type = MealType(data.get("current_meal_type", MealType.LUNCH.value))

    if meal_data and item_index is not None and item_index < len(meal_data["items"]):
        item = meal_data["items"][item_index]
        old_weight = item["weight_g"]
        factor = new_weight / old_weight if old_weight > 0 else 1.0

        # Пересчитываем КБЖУ пропорционально новому весу
        item["weight_g"] = new_weight
        item["calories"] = round(item["calories"] * factor, 1)
        item["protein"] = round(item["protein"] * factor, 1)
        item["fat"] = round(item["fat"] * factor, 1)
        item["carbs"] = round(item["carbs"] * factor, 1)

        await state.update_data(meal_data=meal_data)
        await state.set_state(None)

        text = format_meal_text(meal_data, current_meal_type)
        kb = build_meal_keyboard(current_meal_type, meal_data["items"])

        await message.answer("✅ Вес и КБЖУ пересчитаны:")
        await message.answer(text, reply_markup=kb, parse_mode="Markdown")
    else:
        await message.answer("⚠️ Не удалось найти редактируемое блюдо. Попробуйте отправить фото заново.")
        await state.clear()


@dp.callback_query(F.data == "save_meal")
async def cb_save_meal(callback: CallbackQuery, state: FSMContext):
    """Сохранение блюда в базу данных SQLite."""
    data = await state.get_data()
    meal_data = data.get("meal_data")
    current_meal_type = MealType(data.get("current_meal_type", MealType.LUNCH.value))

    if not meal_data:
        await callback.answer("Данные устарели. Пожалуйста, отправьте фото снова.", show_alert=True)
        return

    try:
        # Переводим словарь обратно в объект FoodAnalysisResult
        items = [IngredientItem(**it) for it in meal_data["items"]]
        analysis = FoodAnalysisResult(
            dish_name=meal_data["dish_name"],
            comment=meal_data.get("comment", ""),
            items=items,
            total_weight_g=sum(it.weight_g for it in items),
            total_calories=sum(it.calories for it in items),
            total_protein=sum(it.protein for it in items),
            total_fat=sum(it.fat for it in items),
            total_carbs=sum(it.carbs for it in items),
        )

        meal_id = db.save_meal(analysis, meal_type=current_meal_type)
        await state.clear()

        await callback.message.edit_text(
            f"🎉 *Прием пищи успешно записан в дневник!*\n"
            f"ID записи: `#{meal_id}`\n"
            f"Категория: *{current_meal_type.label_ru}*\n"
            f"Калории: *{analysis.total_calories:.0f} ккал*\n\n"
            "Посмотреть итоги за сегодня можно по команде /today.",
            parse_mode="Markdown"
        )
        await callback.answer("Сохранено в дневник!")

    except Exception as e:
        logger.error(f"Ошибка сохранения в БД: {e}", exc_info=True)
        await callback.answer("Ошибка при сохранении в базу данных", show_alert=True)


@dp.callback_query(F.data == "cancel_meal")
async def cb_cancel_meal(callback: CallbackQuery, state: FSMContext):
    """Отмена сохранения блюда."""
    await state.clear()
    await callback.message.edit_text("❌ Запись отменена. Отправьте новое фото в любой момент!")
    await callback.answer("Отменено")


async def main():
    """Точка входа запуска бота."""
    # Инициализируем базу данных, если еще не создана
    db.init_db()
    logger.info("База данных проверена и готова к работе.")

    logger.info("Запуск Telegram-бота (polling)...")
    # Удаляем вебхуки, чтобы бот точно отвечал на запросы polling
    await bot.delete_webhook(drop_pending_updates=True)
    await dp.start_polling(bot)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except (KeyboardInterrupt, SystemExit):
        logger.info("Бот остановлен.")
