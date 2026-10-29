from datetime import datetime
from enum import Enum
from typing import Optional, List
from pydantic import BaseModel, Field


class MealType(str, Enum):
    BREAKFAST = "breakfast"  # Завтрак
    LUNCH = "lunch"          # Обед
    DINNER = "dinner"        # Ужин
    SNACK = "snack"          # Перекус

    @property
    def label_ru(self) -> str:
        labels = {
            self.BREAKFAST: "Завтрак 🍳",
            self.LUNCH: "Обед 🍲",
            self.DINNER: "Ужин 🥗",
            self.SNACK: "Перекус 🍎",
        }
        return labels.get(self, "Прием пищи")


class IngredientItem(BaseModel):
    id: Optional[int] = None
    name: str = Field(description="Название ингредиента на русском языке")
    weight_g: float = Field(description="Примерный вес ингредиента в граммах")
    calories: float = Field(description="Калорийность порции в ккал")
    protein: float = Field(description="Белки в граммах")
    fat: float = Field(description="Жиры в граммах")
    carbs: float = Field(description="Углеводы в граммах")


class FoodAnalysisResult(BaseModel):
    dish_name: str = Field(description="Общее понятное название блюда на русском языке")
    comment: str = Field(description="Короткий комментарий диетолога по составу блюда")
    items: list[IngredientItem] = Field(description="Список распознанных ингредиентов")
    total_weight_g: float = Field(description="Общий вес блюда в граммах")
    total_calories: float = Field(description="Суммарная калорийность (ккал)")
    total_protein: float = Field(description="Всего белков (г)")
    total_fat: float = Field(description="Всего жиров (г)")
    total_carbs: float = Field(description="Всего углеводов (г)")


class SaveMealRequest(BaseModel):
    meal_type: MealType = Field(default=MealType.LUNCH, description="Тип приема пищи")
    dish_name: str = Field(description="Название блюда")
    comment: Optional[str] = Field(default="", description="Комментарий")
    items: list[IngredientItem] = Field(description="Список ингредиентов")
    created_at: Optional[str] = Field(default=None, description="Дата и время в формате YYYY-MM-DD HH:MM:SS")

    def to_analysis(self) -> FoodAnalysisResult:
        total_w = sum(it.weight_g for it in self.items)
        total_cal = sum(it.calories for it in self.items)
        total_p = sum(it.protein for it in self.items)
        total_f = sum(it.fat for it in self.items)
        total_c = sum(it.carbs for it in self.items)
        return FoodAnalysisResult(
            dish_name=self.dish_name,
            comment=self.comment or "",
            items=self.items,
            total_weight_g=round(total_w, 1),
            total_calories=round(total_cal, 1),
            total_protein=round(total_p, 1),
            total_fat=round(total_f, 1),
            total_carbs=round(total_c, 1),
        )


class UpdateWeightRequest(BaseModel):
    weight_g: float = Field(gt=0, description="Новый вес в граммах (положительное число)")


class MealRecord(BaseModel):
    id: int
    meal_type: MealType
    dish_name: str
    comment: Optional[str] = None
    created_at: str
    items: list[IngredientItem]
    total_weight_g: float
    total_calories: float
    total_protein: float
    total_fat: float
    total_carbs: float


class DailySummary(BaseModel):
    date: str
    meals_count: int
    total_weight_g: float
    total_calories: float
    total_protein: float
    total_fat: float
    total_carbs: float
    meals: list[MealRecord] = []


class NutritionGoals(BaseModel):
    calories: float = Field(default=2000.0, ge=0, description="Суточная норма калорий (ккал)")
    protein: float = Field(default=90.0, ge=0, description="Суточная норма белков (г)")
    fat: float = Field(default=65.0, ge=0, description="Суточная норма жиров (г)")
    carbs: float = Field(default=250.0, ge=0, description="Суточная норма углеводов (г)")
    updated_at: Optional[str] = Field(default=None, description="Время последнего обновления")


class EstimateNutritionRequest(BaseModel):
    query: str = Field(description="Текстовое описание продукта, например 'хлеб зерновой 30г'")
    weight_g: Optional[float] = Field(default=None, description="Опциональный вес в граммах")


class EstimateNutritionResponse(BaseModel):
    name: str = Field(description="Понятное название продукта на русском языке")
    weight_g: float = Field(description="Вес в граммах")
    calories: float = Field(description="Калорийность (ккал)")
    protein: float = Field(description="Белки (г)")
    fat: float = Field(description="Жиры (г)")
    carbs: float = Field(description="Углеводы (г)")
    comment: Optional[str] = Field(default="", description="Краткий комментарий диетолога")


class BarcodeProductResponse(BaseModel):
    barcode: str = Field(description="Штрихкод продукта")
    name: str = Field(description="Название продукта")
    brand: Optional[str] = Field(default="", description="Бренд или производитель")
    weight_g: float = Field(default=100.0, description="Порция в граммах")
    calories: float = Field(description="Калорийность на указанную порцию (ккал)")
    protein: float = Field(description="Белки на порцию (г)")
    fat: float = Field(description="Жиры на порцию (г)")
    carbs: float = Field(description="Углеводы на порцию (г)")
    calories_100g: float = Field(description="Калорийность на 100 г (ккал)")
    protein_100g: float = Field(description="Белки на 100 г (г)")
    fat_100g: float = Field(description="Жиры на 100 г (г)")
    carbs_100g: float = Field(description="Углеводы на 100 г (г)")
    image_url: Optional[str] = Field(default="", description="URL изображения товара")


class RecipeIngredientItem(BaseModel):
    id: Optional[int] = None
    name: str = Field(description="Название сырого ингредиента")
    weight_g: float = Field(gt=0, description="Вес сырого ингредиента в граммах")
    calories: float = Field(ge=0, description="Калории ингредиента")
    protein: float = Field(ge=0, description="Белки (г)")
    fat: float = Field(ge=0, description="Жиры (г)")
    carbs: float = Field(ge=0, description="Углеводы (г)")


class CreateRecipeRequest(BaseModel):
    title: str = Field(description="Название рецепта или сложного блюда (например: Борщ домашний)")
    description: Optional[str] = Field(default="", description="Описание или заметка к рецепту")
    cooked_weight_g: Optional[float] = Field(default=None, description="Вес готового блюда (с учетом уварки/воды). Если не указан, равен сумме сырых ингредиентов.")
    items: list[RecipeIngredientItem] = Field(min_length=1, description="Список ингредиентов рецепта")


class RecipeRecord(BaseModel):
    id: int
    title: str
    description: Optional[str] = ""
    raw_weight_g: float
    cooked_weight_g: float
    calories_100g: float
    protein_100g: float
    fat_100g: float
    carbs_100g: float
    items: list[RecipeIngredientItem] = []
    created_at: str
    updated_at: str


class LogRecipePortionRequest(BaseModel):
    meal_type: MealType = Field(default=MealType.LUNCH, description="Тип приема пищи")
    portion_weight_g: float = Field(gt=0, description="Вес съеденной порции в граммах")
    created_at: Optional[str] = Field(default=None, description="Дата и время в формате YYYY-MM-DD HH:MM:SS")

