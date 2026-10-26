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
