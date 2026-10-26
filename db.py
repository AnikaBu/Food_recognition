import os
import sqlite3
from datetime import datetime
from pathlib import Path
from typing import Optional, List
from models import (
    MealType,
    IngredientItem,
    FoodAnalysisResult,
    MealRecord,
    DailySummary,
)

_ENV_DB_PATH = os.getenv("DB_PATH")
DEFAULT_DB_PATH = (
    Path(_ENV_DB_PATH)
    if _ENV_DB_PATH
    else (Path(__file__).resolve().parent / "nutrition.db")
)


def get_connection(db_path: Path = DEFAULT_DB_PATH) -> sqlite3.Connection:
    """Создает соединение с SQLite базой данных и включает внешние ключи."""
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON;")
    return conn


def init_db(db_path: Path = DEFAULT_DB_PATH) -> None:
    """Инициализирует таблицы базы данных и создает индексы."""
    with get_connection(db_path) as conn:
        conn.executescript("""
            CREATE TABLE IF NOT EXISTS meals (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                meal_type TEXT NOT NULL DEFAULT 'lunch',
                dish_name TEXT NOT NULL,
                comment TEXT,
                created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
            );

            CREATE TABLE IF NOT EXISTS meal_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                meal_id INTEGER NOT NULL REFERENCES meals(id) ON DELETE CASCADE,
                name TEXT NOT NULL,
                weight_g REAL NOT NULL,
                calories REAL NOT NULL,
                protein REAL NOT NULL,
                fat REAL NOT NULL,
                carbs REAL NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_meals_created_at ON meals(created_at);
            CREATE INDEX IF NOT EXISTS idx_meal_items_meal_id ON meal_items(meal_id);
        """)


def save_meal(
    analysis: FoodAnalysisResult,
    meal_type: MealType = MealType.LUNCH,
    created_at: Optional[str] = None,
    db_path: Path = DEFAULT_DB_PATH,
) -> int:
    """
    Сохраняет прием пищи и все его ингредиенты в базу данных в единой транзакции.
    Возвращает id созданного приема пищи.
    """
    if created_at is None:
        created_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    with get_connection(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            INSERT INTO meals (meal_type, dish_name, comment, created_at)
            VALUES (?, ?, ?, ?)
            """,
            (meal_type.value, analysis.dish_name, analysis.comment, created_at),
        )
        meal_id = cursor.lastrowid

        items_data = [
            (
                meal_id,
                item.name,
                item.weight_g,
                item.calories,
                item.protein,
                item.fat,
                item.carbs,
            )
            for item in analysis.items
        ]

        cursor.executemany(
            """
            INSERT INTO meal_items (meal_id, name, weight_g, calories, protein, fat, carbs)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            items_data,
        )
        conn.commit()
        return meal_id


def get_meal(meal_id: int, db_path: Path = DEFAULT_DB_PATH) -> Optional[MealRecord]:
    """Возвращает прием пищи со всеми ингредиентами по его id."""
    with get_connection(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM meals WHERE id = ?", (meal_id,))
        meal_row = cursor.fetchone()
        if not meal_row:
            return None

        cursor.execute(
            "SELECT * FROM meal_items WHERE meal_id = ? ORDER BY id ASC", (meal_id,)
        )
        items_rows = cursor.fetchall()

        items = [
            IngredientItem(
                id=row["id"],
                name=row["name"],
                weight_g=row["weight_g"],
                calories=row["calories"],
                protein=row["protein"],
                fat=row["fat"],
                carbs=row["carbs"],
            )
            for row in items_rows
        ]

        total_weight = sum(item.weight_g for item in items)
        total_cal = sum(item.calories for item in items)
        total_p = sum(item.protein for item in items)
        total_f = sum(item.fat for item in items)
        total_c = sum(item.carbs for item in items)

        return MealRecord(
            id=meal_row["id"],
            meal_type=MealType(meal_row["meal_type"]),
            dish_name=meal_row["dish_name"],
            comment=meal_row["comment"],
            created_at=meal_row["created_at"],
            items=items,
            total_weight_g=round(total_weight, 1),
            total_calories=round(total_cal, 1),
            total_protein=round(total_p, 1),
            total_fat=round(total_f, 1),
            total_carbs=round(total_c, 1),
        )


def update_item_weight(
    item_id: int,
    new_weight_g: float,
    db_path: Path = DEFAULT_DB_PATH,
) -> Optional[IngredientItem]:
    """
    Изменяет вес ингредиента и пропорционально пересчитывает его калории, белки, жиры и углеводы.
    Возвращает обновленный ингредиент.
    """
    if new_weight_g <= 0:
        raise ValueError("Вес ингредиента должен быть больше нуля")

    with get_connection(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM meal_items WHERE id = ?", (item_id,))
        row = cursor.fetchone()
        if not row:
            return None

        old_weight = row["weight_g"]
        factor = new_weight_g / old_weight if old_weight > 0 else 1.0

        new_cal = round(row["calories"] * factor, 1)
        new_p = round(row["protein"] * factor, 1)
        new_f = round(row["fat"] * factor, 1)
        new_c = round(row["carbs"] * factor, 1)

        cursor.execute(
            """
            UPDATE meal_items
            SET weight_g = ?, calories = ?, protein = ?, fat = ?, carbs = ?
            WHERE id = ?
            """,
            (new_weight_g, new_cal, new_p, new_f, new_c, item_id),
        )
        conn.commit()

        return IngredientItem(
            id=item_id,
            name=row["name"],
            weight_g=new_weight_g,
            calories=new_cal,
            protein=new_p,
            fat=new_f,
            carbs=new_c,
        )


def delete_meal(meal_id: int, db_path: Path = DEFAULT_DB_PATH) -> bool:
    """Удаляет прием пищи и связанные с ним ингредиенты (каскадно)."""
    with get_connection(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM meals WHERE id = ?", (meal_id,))
        conn.commit()
        return cursor.rowcount > 0


def get_meals_by_date(
    date_str: str,
    db_path: Path = DEFAULT_DB_PATH,
) -> List[MealRecord]:
    """
    Возвращает список всех приемов пищи за конкретную дату (формат: YYYY-MM-DD).
    """
    with get_connection(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT id FROM meals 
            WHERE date(created_at) = date(?)
            ORDER BY created_at ASC
            """,
            (date_str,),
        )
        rows = cursor.fetchall()
        meals = []
        for row in rows:
            record = get_meal(row["id"], db_path=db_path)
            if record:
                meals.append(record)
        return meals


def get_daily_summary(
    date_str: Optional[str] = None,
    db_path: Path = DEFAULT_DB_PATH,
) -> DailySummary:
    """
    Подсчитывает суммарное КБЖУ за указанный день (по умолчанию за сегодня).
    """
    if date_str is None:
        date_str = datetime.now().strftime("%Y-%m-%d")

    meals = get_meals_by_date(date_str, db_path=db_path)

    total_w = sum(m.total_weight_g for m in meals)
    total_cal = sum(m.total_calories for m in meals)
    total_p = sum(m.total_protein for m in meals)
    total_f = sum(m.total_fat for m in meals)
    total_c = sum(m.total_carbs for m in meals)

    return DailySummary(
        date=date_str,
        meals_count=len(meals),
        total_weight_g=round(total_w, 1),
        total_calories=round(total_cal, 1),
        total_protein=round(total_p, 1),
        total_fat=round(total_f, 1),
        total_carbs=round(total_c, 1),
        meals=meals,
    )
