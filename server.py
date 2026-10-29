import io
import os
import time
import signal
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
    NutritionGoals,
    EstimateNutritionRequest,
    EstimateNutritionResponse,
)
from vision import analyze_food_image, estimate_food_nutrition_by_text

# Загружаем настройки из .env
load_dotenv()

HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "8000"))
IDLE_TIMEOUT_MINUTES = int(os.getenv("IDLE_TIMEOUT_MINUTES", "0"))

_last_activity_time = time.time()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Жизненный цикл приложения: инициализация ресурсов при старте."""
    db.init_db()
    print("✅ База данных SQLite успешно инициализирована.")

    idle_task = None
    if IDLE_TIMEOUT_MINUTES > 0:
        async def idle_watcher():
            idle_limit = IDLE_TIMEOUT_MINUTES * 60
            print(f"⏱️ Таймер автозасыпания активен: выключение через {IDLE_TIMEOUT_MINUTES} мин без активности.")
            while True:
                await asyncio.sleep(15)
                idle_sec = time.time() - _last_activity_time
                if idle_sec >= idle_limit:
                    print(f"💤 Сервер простаивал {IDLE_TIMEOUT_MINUTES} мин без активности. Завершение работы до следующего запроса...")
                    os.kill(os.getpid(), signal.SIGTERM)
                    break

        idle_task = asyncio.create_task(idle_watcher())

    yield

    if idle_task:
        idle_task.cancel()


app = FastAPI(
    title="MyFoodDiary API",
    description="Единый бэкенд для распознавания еды, анализа КБЖУ и ведения дневника питания.",
    version="1.0.4",
    lifespan=lifespan,
)


@app.middleware("http")
async def track_activity(request: Request, call_next):
    """Отслеживает время последнего входящего запроса для таймера автозасыпания."""
    global _last_activity_time
    _last_activity_time = time.time()
    return await call_next(request)


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
        "app": "MyFoodDiary API",
        "version": "1.0.4",
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
    content = await file.read()
    if not content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Передан пустой файл изображения",
        )

    # Проверяем, является ли файл реальным изображением через Pillow
    try:
        pil_image = Image.open(io.BytesIO(content))
        pil_image.load()
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Загруженный файл должен быть изображением (image/jpeg, image/png и т.д.)",
        )

    try:
        # Выполняем синхронный запрос к Gemini в отдельном потоке, чтобы не блокировать сервер
        result = await asyncio.to_thread(analyze_food_image, pil_image)
        return result
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Ошибка анализа изображения через Gemini: {str(e)}",
        )


@app.post(
    "/api/estimate-nutrition",
    response_model=EstimateNutritionResponse,
    status_code=status.HTTP_200_OK,
    tags=["Распознавание и ИИ"],
    summary="Оценить КБЖУ продукта или блюда по тексту через Gemini",
)
async def estimate_nutrition_endpoint(payload: EstimateNutritionRequest):
    """
    Принимает текстовое описание продукта/блюда (например: 'хлеб зерновой 30г')
    и рассчитывает калории, белки, жиры и углеводы через Gemini.
    """
    query = payload.query.strip()
    if not query:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Текстовый запрос не может быть пустым",
        )

    try:
        result = await asyncio.to_thread(
            estimate_food_nutrition_by_text,
            query=query,
            weight_g=payload.weight_g,
        )
        return result
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Ошибка оценки КБЖУ через Gemini: {str(e)}",
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


@app.get(
    "/api/goals",
    response_model=NutritionGoals,
    tags=["Настройки"],
    summary="Получить суточные цели КБЖУ",
)
def get_nutrition_goals_endpoint():
    """Возвращает сохраненные суточные цели пользователя по калориям, белкам, жирам и углеводам."""
    return db.get_goals()


@app.put(
    "/api/goals",
    response_model=NutritionGoals,
    tags=["Настройки"],
    summary="Обновить суточные цели КБЖУ",
)
def update_nutrition_goals_endpoint(goals: NutritionGoals):
    """Обновляет и сохраняет в базе данных суточные цели по калориям и макронутриентам."""
    return db.update_goals(goals)


# Раздача PWA-клиента (HTML, CSS, JS, манифест и иконки)
frontend_dir = Path(__file__).resolve().parent / "frontend"
if frontend_dir.exists():
    app.mount("/", StaticFiles(directory=str(frontend_dir), html=True), name="frontend")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("server:app", host=HOST, port=PORT, reload=True)
