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
    NutritionGoals,
    RecipeIngredientItem,
    CreateRecipeRequest,
    RecipeRecord,
)

DEFAULT_DB_PATH = Path(__file__).resolve().parent / "nutrition.db"


def get_db_path(db_path: Optional[Path] = None) -> Path:
    """Динамически возвращает путь к БД с приоритетом DB_PATH из окружения."""
    if db_path is not None:
        return db_path
    env_path = os.getenv("DB_PATH")
    if env_path:
        return Path(env_path)
    return DEFAULT_DB_PATH


def get_connection(db_path: Optional[Path] = None) -> sqlite3.Connection:
    """Создает соединение с SQLite базой данных и включает внешние ключи."""
    resolved_path = get_db_path(db_path)
    conn = sqlite3.connect(resolved_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON;")
    return conn


def init_db(db_path: Optional[Path] = None) -> None:
    """Инициализирует таблицы базы данных и создает индексы."""
    resolved_path = get_db_path(db_path)
    with get_connection(resolved_path) as conn:
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

            CREATE TABLE IF NOT EXISTS nutrition_goals (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                calories REAL NOT NULL DEFAULT 2000.0,
                protein REAL NOT NULL DEFAULT 90.0,
                fat REAL NOT NULL DEFAULT 65.0,
                carbs REAL NOT NULL DEFAULT 250.0,
                updated_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
            );

            INSERT OR IGNORE INTO nutrition_goals (id, calories, protein, fat, carbs)
            VALUES (1, 2000.0, 90.0, 65.0, 250.0);

            CREATE TABLE IF NOT EXISTS recipes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                description TEXT,
                raw_weight_g REAL NOT NULL DEFAULT 0.0,
                cooked_weight_g REAL NOT NULL DEFAULT 0.0,
                calories_100g REAL NOT NULL DEFAULT 0.0,
                protein_100g REAL NOT NULL DEFAULT 0.0,
                fat_100g REAL NOT NULL DEFAULT 0.0,
                carbs_100g REAL NOT NULL DEFAULT 0.0,
                created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
                updated_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
            );

            CREATE TABLE IF NOT EXISTS recipe_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                recipe_id INTEGER NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
                name TEXT NOT NULL,
                weight_g REAL NOT NULL,
                calories REAL NOT NULL,
                protein REAL NOT NULL,
                fat REAL NOT NULL,
                carbs REAL NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_meals_created_at ON meals(created_at);
            CREATE INDEX IF NOT EXISTS idx_meal_items_meal_id ON meal_items(meal_id);
            CREATE INDEX IF NOT EXISTS idx_recipes_updated_at ON recipes(updated_at);
            CREATE INDEX IF NOT EXISTS idx_recipe_items_recipe_id ON recipe_items(recipe_id);
        """)


def save_meal(
    analysis: FoodAnalysisResult,
    meal_type: MealType = MealType.LUNCH,
    created_at: Optional[str] = None,
    db_path: Optional[Path] = None,
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


def get_meal(meal_id: int, db_path: Optional[Path] = None) -> Optional[MealRecord]:
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
    db_path: Optional[Path] = None,
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


def delete_meal(meal_id: int, db_path: Optional[Path] = None) -> bool:
    """Удаляет прием пищи и связанные с ним ингредиенты (каскадно)."""
    with get_connection(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM meals WHERE id = ?", (meal_id,))
        conn.commit()
        return cursor.rowcount > 0


def get_meals_by_date(
    date_str: str,
    db_path: Optional[Path] = None,
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
    db_path: Optional[Path] = None,
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


def get_goals(db_path: Optional[Path] = None) -> NutritionGoals:
    """Получает текущие суточные цели по КБЖУ из базы данных."""
    init_db(db_path)
    with get_connection(db_path) as conn:
        row = conn.execute(
            "SELECT calories, protein, fat, carbs, updated_at FROM nutrition_goals WHERE id = 1;"
        ).fetchone()
        if row:
            return NutritionGoals(
                calories=float(row["calories"]),
                protein=float(row["protein"]),
                fat=float(row["fat"]),
                carbs=float(row["carbs"]),
                updated_at=str(row["updated_at"]),
            )
        return NutritionGoals()


def update_goals(
    goals: NutritionGoals,
    db_path: Optional[Path] = None,
) -> NutritionGoals:
    """Обновляет суточные цели по КБЖУ в базе данных."""
    init_db(db_path)
    with get_connection(db_path) as conn:
        conn.execute(
            """
            INSERT INTO nutrition_goals (id, calories, protein, fat, carbs, updated_at)
            VALUES (1, ?, ?, ?, ?, datetime('now', 'localtime'))
            ON CONFLICT(id) DO UPDATE SET
                calories = excluded.calories,
                protein = excluded.protein,
                fat = excluded.fat,
                carbs = excluded.carbs,
                updated_at = excluded.updated_at;
            """,
            (goals.calories, goals.protein, goals.fat, goals.carbs),
        )
        conn.commit()
    return get_goals(db_path=db_path)


# ---------------------------------------------------------------------
# Рецепты и сложные составные блюда (учет уварки/ужарки)
# ---------------------------------------------------------------------

def _calculate_recipe_macros(cooked_weight_g: Optional[float], items: list[RecipeIngredientItem]):
    """Рассчитывает сырой вес, вес готового блюда и КБЖУ на 100 грамм."""
    raw_w = sum(it.weight_g for it in items)
    raw_cal = sum(it.calories for it in items)
    raw_p = sum(it.protein for it in items)
    raw_f = sum(it.fat for it in items)
    raw_c = sum(it.carbs for it in items)

    final_cooked_w = cooked_weight_g if (cooked_weight_g and cooked_weight_g > 0) else raw_w
    if final_cooked_w <= 0:
        final_cooked_w = 100.0

    factor_100 = 100.0 / final_cooked_w
    cal_100 = round(raw_cal * factor_100, 1)
    p_100 = round(raw_p * factor_100, 1)
    f_100 = round(raw_f * factor_100, 1)
    c_100 = round(raw_c * factor_100, 1)

    return round(raw_w, 1), round(final_cooked_w, 1), cal_100, p_100, f_100, c_100


def create_recipe(data: CreateRecipeRequest, db_path: Optional[Path] = None) -> int:
    """Создает новый рецепт, сохраняет ингредиенты и рассчитывает КБЖУ на 100 г готового блюда."""
    init_db(db_path)
    raw_w, cooked_w, cal_100, p_100, f_100, c_100 = _calculate_recipe_macros(data.cooked_weight_g, data.items)

    with get_connection(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            INSERT INTO recipes (title, description, raw_weight_g, cooked_weight_g,
                                calories_100g, protein_100g, fat_100g, carbs_100g, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, datetime('now', 'localtime'), datetime('now', 'localtime'))
            """,
            (data.title.strip(), (data.description or "").strip(), raw_w, cooked_w, cal_100, p_100, f_100, c_100),
        )
        recipe_id = cursor.lastrowid

        items_data = [
            (recipe_id, it.name.strip(), it.weight_g, it.calories, it.protein, it.fat, it.carbs)
            for it in data.items
        ]
        cursor.executemany(
            """
            INSERT INTO recipe_items (recipe_id, name, weight_g, calories, protein, fat, carbs)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            items_data,
        )
        conn.commit()
        return recipe_id


def get_recipe(recipe_id: int, db_path: Optional[Path] = None) -> Optional[RecipeRecord]:
    """Возвращает детальную информацию о рецепте по id, включая список ингредиентов."""
    init_db(db_path)
    with get_connection(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM recipes WHERE id = ?", (recipe_id,))
        row = cursor.fetchone()
        if not row:
            return None

        cursor.execute("SELECT * FROM recipe_items WHERE recipe_id = ? ORDER BY id ASC", (recipe_id,))
        items_rows = cursor.fetchall()
        items = [
            RecipeIngredientItem(
                id=r["id"],
                name=r["name"],
                weight_g=r["weight_g"],
                calories=r["calories"],
                protein=r["protein"],
                fat=r["fat"],
                carbs=r["carbs"],
            )
            for r in items_rows
        ]

        return RecipeRecord(
            id=row["id"],
            title=row["title"],
            description=row["description"] or "",
            raw_weight_g=row["raw_weight_g"],
            cooked_weight_g=row["cooked_weight_g"],
            calories_100g=row["calories_100g"],
            protein_100g=row["protein_100g"],
            fat_100g=row["fat_100g"],
            carbs_100g=row["carbs_100g"],
            items=items,
            created_at=row["created_at"],
            updated_at=row["updated_at"],
        )


def get_recipes(db_path: Optional[Path] = None) -> list[RecipeRecord]:
    """Возвращает список всех сохраненных рецептов пользователя."""
    init_db(db_path)
    with get_connection(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT id FROM recipes ORDER BY updated_at DESC, id DESC")
        rows = cursor.fetchall()

    result = []
    for r in rows:
        rec = get_recipe(r["id"], db_path=db_path)
        if rec:
            result.append(rec)
    return result


def update_recipe(recipe_id: int, data: CreateRecipeRequest, db_path: Optional[Path] = None) -> Optional[RecipeRecord]:
    """Обновляет рецепт, пересчитывает КБЖУ на 100 г и перезаписывает ингредиенты."""
    init_db(db_path)
    raw_w, cooked_w, cal_100, p_100, f_100, c_100 = _calculate_recipe_macros(data.cooked_weight_g, data.items)

    with get_connection(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT id FROM recipes WHERE id = ?", (recipe_id,))
        if not cursor.fetchone():
            return None

        cursor.execute(
            """
            UPDATE recipes
            SET title = ?, description = ?, raw_weight_g = ?, cooked_weight_g = ?,
                calories_100g = ?, protein_100g = ?, fat_100g = ?, carbs_100g = ?,
                updated_at = datetime('now', 'localtime')
            WHERE id = ?
            """,
            (data.title.strip(), (data.description or "").strip(), raw_w, cooked_w, cal_100, p_100, f_100, c_100, recipe_id),
        )

        cursor.execute("DELETE FROM recipe_items WHERE recipe_id = ?", (recipe_id,))
        items_data = [
            (recipe_id, it.name.strip(), it.weight_g, it.calories, it.protein, it.fat, it.carbs)
            for it in data.items
        ]
        cursor.executemany(
            """
            INSERT INTO recipe_items (recipe_id, name, weight_g, calories, protein, fat, carbs)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            items_data,
        )
        conn.commit()

    return get_recipe(recipe_id, db_path=db_path)


def delete_recipe(recipe_id: int, db_path: Optional[Path] = None) -> bool:
    """Удаляет рецепт и каскадно удаляет связанные ингредиенты."""
    init_db(db_path)
    with get_connection(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM recipes WHERE id = ?", (recipe_id,))
        conn.commit()
        return cursor.rowcount > 0


def log_recipe_portion(
    recipe_id: int,
    meal_type: MealType,
    portion_weight_g: float,
    created_at: Optional[str] = None,
    db_path: Optional[Path] = None,
) -> Optional[MealRecord]:
    """
    Рассчитывает КБЖУ порции на основе сохраненного рецепта (на 100г)
    и вносит ее как полноценный прием пищи в дневник питания.
    """
    recipe = get_recipe(recipe_id, db_path=db_path)
    if not recipe:
        return None

    factor = portion_weight_g / 100.0
    cal = round(recipe.calories_100g * factor, 1)
    p = round(recipe.protein_100g * factor, 1)
    f = round(recipe.fat_100g * factor, 1)
    c = round(recipe.carbs_100g * factor, 1)

    item = IngredientItem(
        name=recipe.title,
        weight_g=round(portion_weight_g, 1),
        calories=cal,
        protein=p,
        fat=f,
        carbs=c,
    )

    analysis = FoodAnalysisResult(
        dish_name=recipe.title,
        comment=f"Рецепт: 100г = {recipe.calories_100g} ккал",
        items=[item],
        total_weight_g=round(portion_weight_g, 1),
        total_calories=cal,
        total_protein=p,
        total_fat=f,
        total_carbs=c,
    )

    meal_id = save_meal(
        analysis=analysis,
        meal_type=meal_type,
        created_at=created_at,
        db_path=db_path,
    )

    return get_meal(meal_id, db_path=db_path)

