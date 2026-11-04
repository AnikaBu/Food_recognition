import os
import sqlite3
from datetime import datetime, timedelta
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
    WeeklyMacroDay,
    WeeklyMacroSummary,
    SavedProductRecord,
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
    conn.create_function("lower", 1, lambda s: s.lower() if isinstance(s, str) else s)
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
                gender TEXT,
                age INTEGER,
                height_cm REAL,
                weight_kg REAL,
                activity_level TEXT,
                goal TEXT,
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

            CREATE TABLE IF NOT EXISTS saved_products (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                barcode TEXT UNIQUE,
                name TEXT NOT NULL,
                brand TEXT DEFAULT '',
                calories_100g REAL NOT NULL,
                protein_100g REAL NOT NULL,
                fat_100g REAL NOT NULL,
                carbs_100g REAL NOT NULL,
                use_count INTEGER DEFAULT 1,
                created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
                updated_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
            );

            CREATE INDEX IF NOT EXISTS idx_meals_created_at ON meals(created_at);
            CREATE INDEX IF NOT EXISTS idx_meal_items_meal_id ON meal_items(meal_id);
            CREATE INDEX IF NOT EXISTS idx_recipes_updated_at ON recipes(updated_at);
            CREATE INDEX IF NOT EXISTS idx_recipe_items_recipe_id ON recipe_items(recipe_id);
            CREATE INDEX IF NOT EXISTS idx_saved_products_barcode ON saved_products(barcode);
            CREATE INDEX IF NOT EXISTS idx_saved_products_name ON saved_products(name);
            CREATE INDEX IF NOT EXISTS idx_saved_products_usage ON saved_products(use_count DESC, updated_at DESC);
        """)

        # Миграция: автоматическое добавление колонок калькулятора, если таблица была создана ранее
        existing_goal_cols = {col[1] for col in conn.execute("PRAGMA table_info(nutrition_goals);").fetchall()}
        for col_name, col_type in [
            ("gender", "TEXT"),
            ("age", "INTEGER"),
            ("height_cm", "REAL"),
            ("weight_kg", "REAL"),
            ("activity_level", "TEXT"),
            ("goal", "TEXT"),
        ]:
            if col_name not in existing_goal_cols:
                conn.execute(f"ALTER TABLE nutrition_goals ADD COLUMN {col_name} {col_type};")
        conn.commit()



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


def update_meal(
    meal_id: int,
    dish_name: Optional[str] = None,
    meal_type: Optional[MealType] = None,
    comment: Optional[str] = None,
    items: Optional[List[IngredientItem]] = None,
    db_path: Optional[Path] = None,
) -> Optional[MealRecord]:
    """
    Обновляет данные приема пищи: название, категорию (завтрак, обед и т.д.),
    комментарий и/или список ингредиентов с их КБЖУ.
    Возвращает обновленную запись MealRecord.
    """
    with get_connection(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT id FROM meals WHERE id = ?", (meal_id,))
        if not cursor.fetchone():
            return None

        updates = []
        params = []
        if dish_name is not None and dish_name.strip():
            updates.append("dish_name = ?")
            params.append(dish_name.strip())
        if meal_type is not None:
            updates.append("meal_type = ?")
            params.append(meal_type.value)
        if comment is not None:
            updates.append("comment = ?")
            params.append(comment.strip())

        if updates:
            params.append(meal_id)
            cursor.execute(f"UPDATE meals SET {', '.join(updates)} WHERE id = ?", params)

        if items is not None:
            cursor.execute("DELETE FROM meal_items WHERE meal_id = ?", (meal_id,))
            items_data = [
                (
                    meal_id,
                    it.name.strip(),
                    round(float(it.weight_g), 1),
                    round(float(it.calories), 1),
                    round(float(it.protein), 1),
                    round(float(it.fat), 1),
                    round(float(it.carbs), 1),
                )
                for it in items
            ]
            cursor.executemany(
                """
                INSERT INTO meal_items (meal_id, name, weight_g, calories, protein, fat, carbs)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                items_data,
            )
        conn.commit()

    return get_meal(meal_id, db_path=db_path)



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
    """Получает текущие суточные цели по КБЖУ и параметры профиля из базы данных."""
    init_db(db_path)
    with get_connection(db_path) as conn:
        row = conn.execute(
            """SELECT calories, protein, fat, carbs, gender, age, height_cm, weight_kg,
                      activity_level, goal, updated_at
               FROM nutrition_goals WHERE id = 1;"""
        ).fetchone()
        if row:
            keys = row.keys()
            return NutritionGoals(
                calories=float(row["calories"]),
                protein=float(row["protein"]),
                fat=float(row["fat"]),
                carbs=float(row["carbs"]),
                gender=row["gender"] if "gender" in keys and row["gender"] is not None else None,
                age=int(row["age"]) if "age" in keys and row["age"] is not None else None,
                height_cm=float(row["height_cm"]) if "height_cm" in keys and row["height_cm"] is not None else None,
                weight_kg=float(row["weight_kg"]) if "weight_kg" in keys and row["weight_kg"] is not None else None,
                activity_level=row["activity_level"] if "activity_level" in keys and row["activity_level"] is not None else None,
                goal=row["goal"] if "goal" in keys and row["goal"] is not None else None,
                updated_at=str(row["updated_at"]) if row["updated_at"] is not None else None,
            )
        return NutritionGoals()


def update_goals(
    goals: NutritionGoals,
    db_path: Optional[Path] = None,
) -> NutritionGoals:
    """Обновляет суточные цели по КБЖУ и параметры профиля в базе данных."""
    init_db(db_path)
    with get_connection(db_path) as conn:
        conn.execute(
            """
            INSERT INTO nutrition_goals (
                id, calories, protein, fat, carbs,
                gender, age, height_cm, weight_kg, activity_level, goal,
                updated_at
            )
            VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now', 'localtime'))
            ON CONFLICT(id) DO UPDATE SET
                calories = excluded.calories,
                protein = excluded.protein,
                fat = excluded.fat,
                carbs = excluded.carbs,
                gender = coalesce(excluded.gender, nutrition_goals.gender),
                age = coalesce(excluded.age, nutrition_goals.age),
                height_cm = coalesce(excluded.height_cm, nutrition_goals.height_cm),
                weight_kg = coalesce(excluded.weight_kg, nutrition_goals.weight_kg),
                activity_level = coalesce(excluded.activity_level, nutrition_goals.activity_level),
                goal = coalesce(excluded.goal, nutrition_goals.goal),
                updated_at = excluded.updated_at;
            """,
            (
                goals.calories,
                goals.protein,
                goals.fat,
                goals.carbs,
                goals.gender,
                goals.age,
                goals.height_cm,
                goals.weight_kg,
                goals.activity_level,
                goals.goal,
            ),
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


def get_weekly_macro_summary(
    date_str: Optional[str] = None,
    mode: str = "week",
    db_path: Optional[Path] = None,
) -> WeeklyMacroSummary:
    """
    Рассчитывает агрегированные данные КБЖУ за 7 дней (понедельник-воскресенье или последние 7 дней).
    - date_str: дата отсчета (по умолчанию сегодня).
    - mode: 'week' (с понедельника по воскресенье недели, содержащей date_str) или 'trailing' (7 дней до date_str включительно).
    """
    init_db(db_path)
    if date_str:
        try:
            target_date = datetime.strptime(date_str, "%Y-%m-%d").date()
        except ValueError:
            target_date = datetime.now().date()
    else:
        target_date = datetime.now().date()

    today_date = datetime.now().date()

    if mode == "trailing":
        # 7 дней до target_date включительно
        start_date = target_date - timedelta(days=6)
        day_dates = [start_date + timedelta(days=i) for i in range(7)]
    else:
        # Режим 'week': с понедельника (weekday == 0) по воскресенье
        start_date = target_date - timedelta(days=target_date.weekday())
        day_dates = [start_date + timedelta(days=i) for i in range(7)]

    end_date = day_dates[-1]

    # Словарь дней недели: weekday(): 0 = Monday ... 6 = Sunday
    day_names = ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"]
    day_letters = ["П", "В", "С", "Ч", "П", "С", "В"]

    start_str = start_date.strftime("%Y-%m-%d")
    end_str = end_date.strftime("%Y-%m-%d")

    with get_connection(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT date(m.created_at) as day_str,
                   COUNT(DISTINCT m.id) as cnt,
                   COALESCE(SUM(i.calories), 0.0) as sum_cal,
                   COALESCE(SUM(i.protein), 0.0) as sum_p,
                   COALESCE(SUM(i.fat), 0.0) as sum_f,
                   COALESCE(SUM(i.carbs), 0.0) as sum_c
            FROM meals m
            LEFT JOIN meal_items i ON m.id = i.meal_id
            WHERE date(m.created_at) >= date(?) AND date(m.created_at) <= date(?)
            GROUP BY day_str
            """,
            (start_str, end_str),
        )
        rows = cursor.fetchall()

    day_stats = {}
    for r in rows:
        day_stats[r["day_str"]] = {
            "cnt": r["cnt"],
            "cal": round(float(r["sum_cal"] or 0), 1),
            "p": round(float(r["sum_p"] or 0), 1),
            "f": round(float(r["sum_f"] or 0), 1),
            "c": round(float(r["sum_c"] or 0), 1),
        }

    days_list: list[WeeklyMacroDay] = []
    total_cal = 0.0
    total_p = 0.0
    total_f = 0.0
    total_c = 0.0

    for d in day_dates:
        d_str = d.strftime("%Y-%m-%d")
        w_idx = d.weekday()
        stat = day_stats.get(d_str, {"cnt": 0, "cal": 0.0, "p": 0.0, "f": 0.0, "c": 0.0})

        cal = stat["cal"]
        p = stat["p"]
        f = stat["f"]
        c = stat["c"]

        total_cal += cal
        total_p += p
        total_f += f
        total_c += c

        days_list.append(
            WeeklyMacroDay(
                date=d_str,
                day_name=day_names[w_idx],
                day_letter=day_letters[w_idx],
                is_today=(d == today_date),
                calories=cal,
                protein=p,
                fat=f,
                carbs=c,
                meals_count=stat["cnt"],
            )
        )

    avg_cal = round(total_cal / 7.0, 1)
    avg_p = round(total_p / 7.0, 1)
    avg_f = round(total_f / 7.0, 1)
    avg_c = round(total_c / 7.0, 1)

    goals = get_goals(db_path=db_path)

    return WeeklyMacroSummary(
        start_date=start_str,
        end_date=end_str,
        days=days_list,
        avg_calories=avg_cal,
        avg_protein=avg_p,
        avg_fat=avg_f,
        avg_carbs=avg_c,
        target_calories=goals.calories,
        target_protein=goals.protein,
        target_fat=goals.fat,
        target_carbs=goals.carbs,
    )


# =====================================================================
# ------------------ Персональный каталог продуктов -------------------
# =====================================================================

def get_saved_product_by_barcode(
    barcode: str,
    db_path: Optional[Path] = None,
) -> Optional[SavedProductRecord]:
    """Возвращает сохраненный продукт по штрихкоду или None, если он не найден."""
    clean_code = (barcode or "").strip()
    if not clean_code:
        return None
    resolved_path = get_db_path(db_path)
    with get_connection(resolved_path) as conn:
        row = conn.execute(
            """
            SELECT id, barcode, name, brand, calories_100g, protein_100g, fat_100g, carbs_100g, use_count, updated_at
            FROM saved_products
            WHERE barcode = ?;
            """,
            (clean_code,),
        ).fetchone()
        if not row:
            return None
        return SavedProductRecord(
            id=row["id"],
            barcode=row["barcode"],
            name=row["name"],
            brand=row["brand"] or "",
            calories_100g=float(row["calories_100g"]),
            protein_100g=float(row["protein_100g"]),
            fat_100g=float(row["fat_100g"]),
            carbs_100g=float(row["carbs_100g"]),
            use_count=int(row["use_count"]),
            updated_at=str(row["updated_at"]),
        )


def upsert_saved_product(
    name: str,
    calories_100g: float,
    protein_100g: float,
    fat_100g: float,
    carbs_100g: float,
    barcode: Optional[str] = None,
    brand: Optional[str] = None,
    db_path: Optional[Path] = None,
) -> int:
    """
    Добавляет продукт в каталог или обновляет его данные/счетчик использования.
    Возвращает id сохраненного продукта.
    """
    clean_name = (name or "").strip()
    clean_barcode = (barcode or "").strip() or None
    clean_brand = (brand or "").strip()

    resolved_path = get_db_path(db_path)
    with get_connection(resolved_path) as conn:
        if clean_barcode:
            existing = conn.execute(
                "SELECT id, use_count FROM saved_products WHERE barcode = ?;",
                (clean_barcode,),
            ).fetchone()
        else:
            existing = conn.execute(
                "SELECT id, use_count FROM saved_products WHERE lower(name) = lower(?) AND (barcode IS NULL OR barcode = '');",
                (clean_name,),
            ).fetchone()

        if existing:
            prod_id = existing["id"]
            conn.execute(
                """
                UPDATE saved_products
                SET name = ?,
                    brand = coalesce(nullif(?, ''), brand),
                    calories_100g = ?,
                    protein_100g = ?,
                    fat_100g = ?,
                    carbs_100g = ?,
                    use_count = use_count + 1,
                    updated_at = datetime('now', 'localtime')
                WHERE id = ?;
                """,
                (clean_name, clean_brand, calories_100g, protein_100g, fat_100g, carbs_100g, prod_id),
            )
            conn.commit()
            return prod_id
        else:
            cur = conn.execute(
                """
                INSERT INTO saved_products (barcode, name, brand, calories_100g, protein_100g, fat_100g, carbs_100g, use_count, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, 1, datetime('now', 'localtime'), datetime('now', 'localtime'));
                """,
                (clean_barcode, clean_name, clean_brand, calories_100g, protein_100g, fat_100g, carbs_100g),
            )
            conn.commit()
            return cur.lastrowid


def search_saved_products(
    query: str = "",
    limit: int = 10,
    db_path: Optional[Path] = None,
) -> list[SavedProductRecord]:
    """Ищет продукты по названию/бренду с сортировкой по популярности использования."""
    resolved_path = get_db_path(db_path)
    q = (query or "").strip()
    with get_connection(resolved_path) as conn:
        if q:
            pattern = f"%{q.lower()}%"
            rows = conn.execute(
                """
                SELECT id, barcode, name, brand, calories_100g, protein_100g, fat_100g, carbs_100g, use_count, updated_at
                FROM saved_products
                WHERE lower(name) LIKE ? OR lower(brand) LIKE ?
                ORDER BY use_count DESC, updated_at DESC
                LIMIT ?;
                """,
                (pattern, pattern, limit),
            ).fetchall()
        else:
            rows = conn.execute(
                """
                SELECT id, barcode, name, brand, calories_100g, protein_100g, fat_100g, carbs_100g, use_count, updated_at
                FROM saved_products
                ORDER BY use_count DESC, updated_at DESC
                LIMIT ?;
                """,
                (limit,),
            ).fetchall()

        return [
            SavedProductRecord(
                id=r["id"],
                barcode=r["barcode"],
                name=r["name"],
                brand=r["brand"] or "",
                calories_100g=float(r["calories_100g"]),
                protein_100g=float(r["protein_100g"]),
                fat_100g=float(r["fat_100g"]),
                carbs_100g=float(r["carbs_100g"]),
                use_count=int(r["use_count"]),
                updated_at=str(r["updated_at"]),
            )
            for r in rows
        ]


def delete_saved_product(
    product_id: int,
    db_path: Optional[Path] = None,
) -> bool:
    """Удаляет продукт из каталога по id."""
    resolved_path = get_db_path(db_path)
    with get_connection(resolved_path) as conn:
        cur = conn.execute("DELETE FROM saved_products WHERE id = ?;", (product_id,))
        conn.commit()
        return cur.rowcount > 0


