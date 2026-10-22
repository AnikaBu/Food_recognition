import sys
from vision import analyze_food_image
from models import FoodAnalysisResult

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
    img_file = sys.argv[1] if len(sys.argv) > 1 else "sample_dish.jpg"
    print(f"⏳ Отправляем изображение '{img_file}' в нейросеть...")
    result = analyze_food_image(img_file)
    print_card(result)
