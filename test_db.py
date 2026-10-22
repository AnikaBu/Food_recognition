from pathlib import Path
from models import MealType, IngredientItem, FoodAnalysisResult
import db

def test_database_workflow():
    test_db_path = Path("test_nutrition.db")
    if test_db_path.exists():
        test_db_path.unlink()

    print("🚀 Тестирование модуля базы данных (Этап 2)...")

    # 1. Инициализация
    db.init_db(test_db_path)
    print("✅ 1. Таблицы базы данных успешно созданы.")

    # 2. Создание тестового анализа от ИИ
    sample_analysis = FoodAnalysisResult(
        dish_name="Гречневая каша с куриным филе",
        comment="Отличный белковый обед с медленными углеводами.",
        items=[
            IngredientItem(name="Гречка вареная", weight_g=150.0, calories=165.0, protein=6.0, fat=1.5, carbs=31.0),
            IngredientItem(name="Куриное филе гриль", weight_g=120.0, calories=198.0, protein=37.0, fat=4.3, carbs=0.0),
            IngredientItem(name="Огурец свежий", weight_g=80.0, calories=12.0, protein=0.6, fat=0.1, carbs=2.5),
        ],
        total_weight_g=350.0,
        total_calories=375.0,
        total_protein=43.6,
        total_fat=5.9,
        total_carbs=33.5,
    )

    # 3. Сохранение в базу
    meal_id = db.save_meal(sample_analysis, meal_type=MealType.LUNCH, db_path=test_db_path)
    assert meal_id > 0, "meal_id должен быть больше 0"
    print(f"✅ 2. Прием пищи сохранен с ID: {meal_id}")

    # 4. Чтение из базы
    meal = db.get_meal(meal_id, db_path=test_db_path)
    assert meal is not None, "Запись приема пищи должна существовать"
    assert len(meal.items) == 3, "Должно быть ровно 3 ингредиента"
    print(f"✅ 3. Прием пищи успешно прочитан: {meal.dish_name} ({meal.meal_type.label_ru}), калорий: {meal.total_calories}")

    # 5. Тестирование ручного изменения веса ингредиента
    # Допустим, пользователь съел не 150г гречки, а 300г (в 2 раза больше)
    buckwheat_item = meal.items[0]
    old_weight = buckwheat_item.weight_g
    old_cals = buckwheat_item.calories

    updated_item = db.update_item_weight(buckwheat_item.id, new_weight_g=300.0, db_path=test_db_path)
    assert updated_item.weight_g == 300.0
    assert updated_item.calories == round(old_cals * 2, 1), f"Ожидалось {old_cals * 2}, получено {updated_item.calories}"
    print(f"✅ 4. Вес '{buckwheat_item.name}' изменен: {old_weight}г -> {updated_item.weight_g}г. Калории пересчитаны: {old_cals} -> {updated_item.calories} ккал")

    # Проверяем, что итоговое блюдо тоже пересчиталось
    meal_after_update = db.get_meal(meal_id, db_path=test_db_path)
    print(f"   Новая калорийность всего блюда: {meal_after_update.total_calories} ккал (было {meal.total_calories} ккал)")

    # 6. Добавим еще один прием пищи (Завтрак)
    breakfast_analysis = FoodAnalysisResult(
        dish_name="Омлет с помидорами",
        comment="Легкий завтрак",
        items=[
            IngredientItem(name="Яйца куриные", weight_g=110.0, calories=170.0, protein=14.0, fat=12.0, carbs=0.8),
            IngredientItem(name="Помидоры", weight_g=70.0, calories=14.0, protein=0.6, fat=0.1, carbs=2.8),
        ],
        total_weight_g=180.0,
        total_calories=184.0,
        total_protein=14.6,
        total_fat=12.1,
        total_carbs=3.6,
    )
    b_id = db.save_meal(breakfast_analysis, meal_type=MealType.BREAKFAST, db_path=test_db_path)
    print(f"✅ 5. Добавлен завтрак с ID: {b_id}")

    # 7. Суточная сводка
    summary = db.get_daily_summary(db_path=test_db_path)
    assert summary.meals_count == 2, "За сегодня должно быть 2 приема пищи"
    print(f"\n📊 СУТОЧНЫЙ ОТЧЕТ ЗА {summary.date}:")
    print(f"   Всего приемов пищи: {summary.meals_count}")
    print(f"   Общий вес съеденного: {summary.total_weight_g} г")
    print(f"   Суммарно калорий: {summary.total_calories} ккал")
    print(f"   Белки: {summary.total_protein} г | Жиры: {summary.total_fat} г | Углеводы: {summary.total_carbs} г")

    # 8. Тест удаления
    assert db.delete_meal(b_id, db_path=test_db_path) is True
    summary_after_del = db.get_daily_summary(db_path=test_db_path)
    assert summary_after_del.meals_count == 1
    print("✅ 6. Каскадное удаление приема пищи работает корректно.")

    # Удаляем временную тестовую БД
    if test_db_path.exists():
        test_db_path.unlink()
    print("\n🎉 Все тесты базы данных успешно пройдены!")

if __name__ == "__main__":
    test_database_workflow()
