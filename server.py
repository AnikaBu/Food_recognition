import io
import os
import asyncio
from pathlib import Path
from typing import Optional, List
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from PIL import Image
from fastapi import FastAPI, File, UploadFile, HTTPException, Query, Request, status
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

import db
from models import (
    MealType,
    FoodAnalysisResult,
    MealRecord,
    DailySummary,
    IngredientItem,
    SaveMealRequest,
    UpdateWeightRequest,
)
from vision import analyze_food_image

# Загружаем настройки из .env
load_dotenv()

HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "8000"))


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Жизненный цикл приложения: инициализация ресурсов при старте."""
    db.init_db()
    print("✅ База данных SQLite успешно инициализирована.")
    yield


app = FastAPI(
    title="Food Recognition API",
    description="Единый бэкенд для распознавания еды, анализа КБЖУ и ведения дневника питания.",
    version="1.0.0",
    lifespan=lifespan,
)

# Разрешаем CORS-запросы для будущих клиентов (PWA и Flutter)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Настройки безопасности и API-ключ
API_KEY = os.getenv("API_KEY")
if API_KEY:
    print("🔒 Включена защита по API-ключу (заголовок X-API-Key).")
else:
    print("ℹ️ Защита по API-ключу отключена (переменная API_KEY не задана).")


@app.middleware("http")
async def verify_api_key_middleware(request: Request, call_next):
    """
    Проверяет секретный заголовок X-API-Key для всех API-эндпоинтов (кроме /api/health),
    если в окружении установлена переменная API_KEY.
    """
    path = request.url.path
    # Защищаем все вызовы /api/ (за исключением /api/health)
    if API_KEY and path.startswith("/api/") and path != "/api/health":
        client_key = request.headers.get("X-API-Key")
        if not client_key or client_key.strip() != API_KEY.strip():
            return JSONResponse(
                status_code=status.HTTP_401_UNAUTHORIZED,
                content={
                    "detail": "Неавторизованный запрос: требуется верный ключ в заголовке X-API-Key"
                },
            )

    response = await call_next(request)
    return response


@app.get("/api/health", tags=["Общее"])
def read_health(request: Request):
    """Проверка доступности API-сервера и статуса авторизации."""
    client_key = request.headers.get("X-API-Key")
    is_valid_key = bool(API_KEY and client_key and client_key.strip() == API_KEY.strip())

    return {
        "status": "online",
        "app": "Food Recognition API",
        "version": "1.0.2",
        "auth_required": bool(API_KEY),
        "auth_valid": is_valid_key if API_KEY else True,
        "docs_url": "/docs",
    }


@app.post(
    "/api/analyze-photo",
    response_model=FoodAnalysisResult,
    tags=["Распознавание ИИ"],
    summary="Распознать блюдо по фотографии через Gemini Vision",
)
async def analyze_photo_endpoint(file: UploadFile = File(...)):
    """
    Принимает фотографию блюда (jpg, png, webp и т.д.).
    Обрабатывает изображение в оперативной памяти (без сохранения на диск)
    и возвращает список ингредиентов, их вес и КБЖУ.
    """
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Загруженный файл должен быть изображением (image/jpeg, image/png и т.д.)",
        )

    try:
        content = await file.read()
        pil_image = Image.open(io.BytesIO(content))

        # Выполняем синхронный запрос к Gemini в отдельном потоке, чтобы не блокировать сервер
        result = await asyncio.to_thread(analyze_food_image, pil_image)
        return result
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Ошибка анализа изображения через Gemini: {str(e)}",
        )


@app.post(
    "/api/meals",
    response_model=MealRecord,
    status_code=status.HTTP_201_CREATED,
    tags=["Дневник питания"],
    summary="Сохранить прием пищи в дневник",
)
def save_meal_endpoint(payload: SaveMealRequest):
    """
    Сохраняет прием пищи со списком ингредиентов в базу данных SQLite.
    Возвращает созданную запись с итоговыми расчетами.
    """
    try:
        analysis = payload.to_analysis()
        meal_id = db.save_meal(
            analysis=analysis,
            meal_type=payload.meal_type,
            created_at=payload.created_at,
        )
        meal_record = db.get_meal(meal_id)
        if not meal_record:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Не удалось получить созданную запись приема пищи",
            )
        return meal_record
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Ошибка сохранения: {str(e)}",
        )


@app.get(
    "/api/meals/{meal_id}",
    response_model=MealRecord,
    tags=["Дневник питания"],
    summary="Получить прием пищи по ID",
)
def get_meal_endpoint(meal_id: int):
    """Возвращает детальную карточку приема пищи и все его ингредиенты."""
    meal = db.get_meal(meal_id)
    if not meal:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Прием пищи с id={meal_id} не найден",
        )
    return meal


@app.put(
    "/api/items/{item_id}/weight",
    response_model=IngredientItem,
    tags=["Дневник питания"],
    summary="Изменить вес ингредиента с пропорциональным пересчетом КБЖУ",
)
def update_item_weight_endpoint(item_id: int, payload: UpdateWeightRequest):
    """
    Изменяет вес ингредиента.
    Калории, белки, жиры и углеводы пересчитываются автоматически.
    """
    updated_item = db.update_item_weight(item_id, payload.weight_g)
    if not updated_item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Ингредиент с id={item_id} не найден",
        )
    return updated_item


@app.delete(
    "/api/meals/{meal_id}",
    tags=["Дневник питания"],
    summary="Удалить прием пищи из дневника",
)
def delete_meal_endpoint(meal_id: int):
    """Удаляет прием пищи и связанные с ним ингредиенты."""
    success = db.delete_meal(meal_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Прием пищи с id={meal_id} не найден",
        )
    return {"success": True, "deleted_id": meal_id}


@app.get(
    "/api/diary",
    response_model=DailySummary,
    tags=["Дневник питания"],
    summary="Получить суточную сводку КБЖУ и список приемов пищи",
)
def get_daily_summary_endpoint(
    date: Optional[str] = Query(
        None,
        description="Дата в формате YYYY-MM-DD (если не указана — сегодняшняя дата)",
    )
):
    """
    Возвращает суммарное количество калорий, белков, жиров, углеводов
    и список всех приемов пищи за указанный день.
    """
    return db.get_daily_summary(date_str=date)


@app.get(
    "/api/diary/meals",
    response_model=List[MealRecord],
    tags=["Дневник питания"],
    summary="Получить только список приемов пищи за конкретную дату",
)
def get_meals_by_date_endpoint(
    date: str = Query(..., description="Дата в формате YYYY-MM-DD")
):
    """Возвращает список всех приемов пищи за указанную дату."""
    return db.get_meals_by_date(date_str=date)


# Раздача PWA-клиента (HTML, CSS, JS, манифест и иконки)
frontend_dir = Path(__file__).resolve().parent / "frontend"
if frontend_dir.exists():
    app.mount("/", StaticFiles(directory=str(frontend_dir), html=True), name="frontend")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("server:app", host=HOST, port=PORT, reload=True)
