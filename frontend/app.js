// Состояние приложения
let state = {
  currentDate: getTodayDateString(),
  analyzedMeal: null,
  selectedMealType: "lunch",
  manualSelectedMealType: "lunch",
  deferredPrompt: null,
};

// Утилита получения даты YYYY-MM-DD
function getTodayDateString() {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

// Форматирование даты для заголовка на русском
function formatDateTitle(dateStr) {
  const [y, m, d] = dateStr.split("-").map(Number);
  const target = new Date(y, m - 1, d);
  const today = new Date();
  
  if (dateStr === getTodayDateString()) {
    return "Сегодня, " + target.toLocaleDateString("ru-RU", { day: "numeric", month: "long" });
  }
  
  const yesterday = new Date();
  yesterday.setDate(today.getDate() - 1);
  if (dateStr === yesterday.toISOString().split("T")[0]) {
    return "Вчера, " + target.toLocaleDateString("ru-RU", { day: "numeric", month: "long" });
  }

  return target.toLocaleDateString("ru-RU", { day: "numeric", month: "long", year: "numeric" });
}

// Toast уведомления
function showToast(msg) {
  const toast = document.getElementById("toast");
  toast.textContent = msg;
  toast.classList.add("show");
  setTimeout(() => toast.classList.remove("show"), 3000);
}

// ----------------- PWA Регистрация -----------------
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/sw.js").then(
      (reg) => console.log("SW зарегистрирован:", reg.scope),
      (err) => console.log("Ошибка регистрации SW:", err)
    );
  });
}

window.addEventListener("beforeinstallprompt", (e) => {
  e.preventDefault();
  state.deferredPrompt = e;
  const pwaBtn = document.getElementById("pwaInstallBtn");
  if (pwaBtn) pwaBtn.style.display = "block";
});

document.getElementById("pwaInstallBtn")?.addEventListener("click", async () => {
  if (state.deferredPrompt) {
    state.deferredPrompt.prompt();
    const { outcome } = await state.deferredPrompt.userChoice;
    if (outcome === "accepted") {
      document.getElementById("pwaInstallBtn").style.display = "none";
    }
    state.deferredPrompt = null;
  }
});

// ----------------- Инициализация и события -----------------
document.addEventListener("DOMContentLoaded", () => {
  updateDateDisplay();
  loadDiaryData();

  // Навигация по датам
  document.getElementById("prevDayBtn").addEventListener("click", () => changeDate(-1));
  document.getElementById("nextDayBtn").addEventListener("click", () => changeDate(1));
  
  const dateDisplay = document.getElementById("dateDisplay");
  const hiddenDateInput = document.getElementById("hiddenDateInput");
  
  dateDisplay.addEventListener("click", () => {
    hiddenDateInput.showPicker ? hiddenDateInput.showPicker() : hiddenDateInput.focus();
  });
  
  hiddenDateInput.addEventListener("change", (e) => {
    if (e.target.value) {
      state.currentDate = e.target.value;
      updateDateDisplay();
      loadDiaryData();
    }
  });

  // Загрузка фото
  const fileInput = document.getElementById("fileInput");
  const cameraInput = document.getElementById("cameraInput");

  fileInput.addEventListener("change", (e) => handleFileSelect(e.target.files[0]));
  cameraInput.addEventListener("change", (e) => handleFileSelect(e.target.files[0]));

  // Перетаскивание файлов (Drag & Drop)
  const dropZone = document.getElementById("dropZone");
  dropZone.addEventListener("dragover", (e) => {
    e.preventDefault();
    dropZone.classList.add("dragover");
  });
  dropZone.addEventListener("dragleave", () => dropZone.classList.remove("dragover"));
  dropZone.addEventListener("drop", (e) => {
    e.preventDefault();
    dropZone.classList.remove("dragover");
    if (e.dataTransfer.files.length) {
      handleFileSelect(e.dataTransfer.files[0]);
    }
  });

  // Кнопки категорий блюда в карточке анализа фото
  document.querySelectorAll("#resultCard .type-tab").forEach((tab) => {
    tab.addEventListener("click", () => {
      document.querySelectorAll("#resultCard .type-tab").forEach((t) => t.classList.remove("active"));
      tab.classList.add("active");
      state.selectedMealType = tab.dataset.type;
    });
  });

  // Кнопки категорий в модальном окне ручного ввода
  document.querySelectorAll("#manualMealTypeTabs .type-tab").forEach((tab) => {
    tab.addEventListener("click", () => {
      document.querySelectorAll("#manualMealTypeTabs .type-tab").forEach((t) => t.classList.remove("active"));
      tab.classList.add("active");
      state.manualSelectedMealType = tab.dataset.type;
    });
  });

  // Открытие и закрытие модального окна ручного ввода
  document.getElementById("openManualMealBtn")?.addEventListener("click", openManualMealModal);
  document.getElementById("closeManualModalBtn")?.addEventListener("click", closeManualMealModal);
  document.getElementById("cancelManualBtn")?.addEventListener("click", closeManualMealModal);
  document.getElementById("manualMealModal")?.addEventListener("click", (e) => {
    if (e.target.id === "manualMealModal") closeManualMealModal();
  });

  // Обработка отправки формы ручного ввода
  document.getElementById("manualMealForm")?.addEventListener("submit", handleManualMealSubmit);

  // Кнопка ИИ-расчета КБЖУ в модальном окне ручного ввода
  document.getElementById("manualAiEstimateBtn")?.addEventListener("click", handleAiEstimateClick);

  // Сохранение и отмена
  document.getElementById("saveMealBtn").addEventListener("click", saveMeal);
  document.getElementById("cancelMealBtn").addEventListener("click", cancelAnalyzedMeal);
});

function changeDate(deltaDays) {
  const [y, m, d] = state.currentDate.split("-").map(Number);
  const current = new Date(y, m - 1, d);
  current.setDate(current.getDate() + deltaDays);
  
  const nextYear = current.getFullYear();
  const nextMonth = String(current.getMonth() + 1).padStart(2, "0");
  const nextDay = String(current.getDate()).padStart(2, "0");
  
  state.currentDate = `${nextYear}-${nextMonth}-${nextDay}`;
  updateDateDisplay();
  loadDiaryData();
}

function updateDateDisplay() {
  document.getElementById("dateLabel").textContent = formatDateTitle(state.currentDate);
  document.getElementById("hiddenDateInput").value = state.currentDate;
}

// ----------------- Загрузка дневника (API) -----------------
async function loadDiaryData() {
  try {
    const res = await fetch(`/api/diary?date=${state.currentDate}`);
    if (!res.ok) throw new Error("Не удалось загрузить дневник");
    const data = await res.json();
    renderDailySummary(data);
    renderMealsHistory(data.meals);
  } catch (err) {
    console.error("Ошибка загрузки дневника:", err);
    showToast("⚠️ Ошибка загрузки дневника");
  }
}

function renderDailySummary(summary) {
  document.getElementById("sumCalories").textContent = Math.round(summary.total_calories);
  document.getElementById("sumProtein").textContent = summary.total_protein.toFixed(1);
  document.getElementById("sumFat").textContent = summary.total_fat.toFixed(1);
  document.getElementById("sumCarbs").textContent = summary.total_carbs.toFixed(1);
}

function renderMealsHistory(meals) {
  const container = document.getElementById("mealsHistoryList");
  container.innerHTML = "";

  if (!meals || meals.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        🍽️ В этот день еще нет записей.<br>Сфотографируйте еду выше, чтобы сохранить прием пищи!
      </div>
    `;
    return;
  }

  const mealTypeLabels = {
    breakfast: "Завтрак 🍳",
    lunch: "Обед 🍲",
    dinner: "Ужин 🥗",
    snack: "Перекус 🍎",
  };

  meals.forEach((meal) => {
    const timeStr = meal.created_at.includes(" ") ? meal.created_at.split(" ")[1].slice(0, 5) : "";
    const card = document.createElement("div");
    card.className = "history-item";
    card.innerHTML = `
      <div class="hist-top">
        <div>
          <span class="hist-type-badge">${mealTypeLabels[meal.meal_type] || meal.meal_type} ${timeStr ? "• " + timeStr : ""}</span>
          <div class="hist-title">${meal.dish_name}</div>
        </div>
        <button class="hist-del-btn" title="Удалить" onclick="deleteMeal(${meal.id})">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 6h18m-2 0v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"></path></svg>
        </button>
      </div>
      <div class="hist-macros">
        🔥 <b>${Math.round(meal.total_calories)} ккал</b> • ⚖️ ${Math.round(meal.total_weight_g)}г
        <span style="margin-left: 8px; opacity: 0.8;">(Б: ${meal.total_protein.toFixed(1)}г, Ж: ${meal.total_fat.toFixed(1)}г, У: ${meal.total_carbs.toFixed(1)}г)</span>
      </div>
    `;
    container.appendChild(card);
  });
}

// ----------------- Обработка и анализ фото -----------------
async function handleFileSelect(file) {
  if (!file) return;

  const dropZone = document.getElementById("dropZone");
  const loadingBox = document.getElementById("loadingBox");
  const resultCard = document.getElementById("resultCard");

  dropZone.style.display = "none";
  loadingBox.style.display = "block";
  resultCard.style.display = "none";

  const formData = new FormData();
  formData.append("file", file);

  try {
    const res = await fetch("/api/analyze-photo", {
      method: "POST",
      body: formData,
    });

    if (!res.ok) {
      const errData = await res.json().catch(() => ({}));
      throw new Error(errData.detail || "Ошибка при анализе фото");
    }

    const analysis = await res.json();
    state.analyzedMeal = analysis;
    renderAnalysisResult(analysis);
    showToast("✨ Блюдо успешно распознано!");
  } catch (err) {
    console.error("Ошибка:", err);
    showToast(`❌ ${err.message}`);
    dropZone.style.display = "block";
  } finally {
    loadingBox.style.display = "none";
  }
}

function renderAnalysisResult(analysis) {
  const resultCard = document.getElementById("resultCard");
  document.getElementById("dishTitle").textContent = analysis.dish_name;
  document.getElementById("dishComment").textContent = analysis.comment || "";

  renderIngredientsTable();
  resultCard.style.display = "block";
}

function renderIngredientsTable() {
  const container = document.getElementById("ingredientsList");
  container.innerHTML = "";

  state.analyzedMeal.items.forEach((item, index) => {
    // Сохраняем базовые значения (на 1 грамм), если еще не сохранены
    if (!item.base_cal) {
      const w = item.weight_g > 0 ? item.weight_g : 100;
      item.base_cal = item.calories / w;
      item.base_p = item.protein / w;
      item.base_f = item.fat / w;
      item.base_c = item.carbs / w;
    }

    const row = document.createElement("div");
    row.className = "ingredient-row";
    row.innerHTML = `
      <div class="ing-info">
        <div class="ing-name">${item.name}</div>
        <div class="ing-macros" id="macros_${index}">
          🔥 ${Math.round(item.calories)} ккал (Б: ${item.protein.toFixed(1)}г, Ж: ${item.fat.toFixed(1)}г, У: ${item.carbs.toFixed(1)}г)
        </div>
      </div>
      <div class="ing-weight-ctrl">
        <input type="number" min="1" max="2000" class="weight-input" value="${Math.round(item.weight_g)}" onchange="updateIngredientWeight(${index}, this.value)" />
        <span class="weight-unit">г</span>
      </div>
    `;
    container.appendChild(row);
  });

  updateTotalCardMacros();
}

// Динамический пересчет веса при редактировании
window.updateIngredientWeight = function (index, newWeightVal) {
  const newWeight = parseFloat(newWeightVal);
  if (isNaN(newWeight) || newWeight <= 0) return;

  const item = state.analyzedMeal.items[index];
  item.weight_g = newWeight;
  item.calories = item.base_cal * newWeight;
  item.protein = item.base_p * newWeight;
  item.fat = item.base_f * newWeight;
  item.carbs = item.base_c * newWeight;

  const macrosEl = document.getElementById(`macros_${index}`);
  if (macrosEl) {
    macrosEl.textContent = `🔥 ${Math.round(item.calories)} ккал (Б: ${item.protein.toFixed(1)}г, Ж: ${item.fat.toFixed(1)}г, У: ${item.carbs.toFixed(1)}г)`;
  }

  updateTotalCardMacros();
};

function updateTotalCardMacros() {
  const items = state.analyzedMeal.items;
  const totalCal = items.reduce((sum, it) => sum + it.calories, 0);
  const totalWeight = items.reduce((sum, it) => sum + it.weight_g, 0);
  const totalP = items.reduce((sum, it) => sum + it.protein, 0);
  const totalF = items.reduce((sum, it) => sum + it.fat, 0);
  const totalC = items.reduce((sum, it) => sum + it.carbs, 0);

  document.getElementById("cardTotalText").textContent = 
    `Итого: ${Math.round(totalWeight)}г • ${Math.round(totalCal)} ккал (Б: ${totalP.toFixed(1)}г, Ж: ${totalF.toFixed(1)}г, У: ${totalC.toFixed(1)}г)`;
}

function cancelAnalyzedMeal() {
  state.analyzedMeal = null;
  document.getElementById("resultCard").style.display = "none";
  document.getElementById("dropZone").style.display = "block";
  document.getElementById("fileInput").value = "";
  document.getElementById("cameraInput").value = "";
}

// ----------------- Сохранение в базу данных (API) -----------------
async function saveMeal() {
  if (!state.analyzedMeal) return;

  const saveBtn = document.getElementById("saveMealBtn");
  saveBtn.disabled = true;
  saveBtn.textContent = "Сохранение...";

  // Дата и текущее время для записи
  const now = new Date();
  const timeStr = String(now.getHours()).padStart(2, "0") + ":" + String(now.getMinutes()).padStart(2, "0") + ":00";
  const fullCreatedAt = `${state.currentDate} ${timeStr}`;

  const payload = {
    meal_type: state.selectedMealType,
    dish_name: state.analyzedMeal.dish_name,
    comment: state.analyzedMeal.comment || "",
    items: state.analyzedMeal.items.map((it) => ({
      name: it.name,
      weight_g: it.weight_g,
      calories: it.calories,
      protein: it.protein,
      fat: it.fat,
      carbs: it.carbs,
    })),
    created_at: fullCreatedAt,
  };

  try {
    const res = await fetch("/api/meals", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    if (!res.ok) throw new Error("Не удалось сохранить прием пищи");

    showToast("✅ Прием пищи сохранен в дневник!");
    cancelAnalyzedMeal();
    loadDiaryData();
  } catch (err) {
    console.error("Ошибка сохранения:", err);
    showToast("❌ Ошибка при сохранении блюда");
  } finally {
    saveBtn.disabled = false;
    saveBtn.textContent = "💾 Сохранить в дневник";
  }
}

// ----------------- Удаление блюда (API) -----------------
window.deleteMeal = async function (mealId) {
  if (!confirm("Удалить этот прием пищи из дневника?")) return;

  try {
    const res = await fetch(`/api/meals/${mealId}`, { method: "DELETE" });
    if (!res.ok) throw new Error("Ошибка удаления");
    showToast("🗑️ Запись удалена");
    loadDiaryData();
  } catch (err) {
    console.error("Ошибка удаления:", err);
    showToast("❌ Не удалось удалить запись");
  }
};

// ----------------- Ручное внесение блюда без фото -----------------
function openManualMealModal() {
  const modal = document.getElementById("manualMealModal");
  if (!modal) return;
  const dateLabel = document.getElementById("manualModalDateLabel");
  if (dateLabel) {
    dateLabel.textContent = `Запись на ${formatDateTitle(state.currentDate)}`;
  }
  modal.style.display = "flex";
  document.getElementById("manualDishName")?.focus();
}

function closeManualMealModal() {
  const modal = document.getElementById("manualMealModal");
  if (!modal) return;
  modal.style.display = "none";
  document.getElementById("manualMealForm")?.reset();
  
  // Сбрасываем выбранную категорию на Обед
  state.manualSelectedMealType = "lunch";
  document.querySelectorAll("#manualMealTypeTabs .type-tab").forEach((t) => {
    t.classList.toggle("active", t.dataset.type === "lunch");
  });
}

async function handleManualMealSubmit(e) {
  e.preventDefault();

  const submitBtn = document.getElementById("manualSubmitBtn");
  if (submitBtn) {
    submitBtn.disabled = true;
    submitBtn.textContent = "Сохранение...";
  }

  const dishName = document.getElementById("manualDishName").value.trim();
  const weight = parseFloat(document.getElementById("manualDishWeight").value) || 100;
  const calories = parseFloat(document.getElementById("manualCalories").value) || 0;
  const protein = parseFloat(document.getElementById("manualProtein").value) || 0;
  const fat = parseFloat(document.getElementById("manualFat").value) || 0;
  const carbs = parseFloat(document.getElementById("manualCarbs").value) || 0;
  const comment = document.getElementById("manualComment").value.trim();

  // Формируем дату и время с учетом выбранного в календаре дня
  const now = new Date();
  const timeStr = String(now.getHours()).padStart(2, "0") + ":" +
                  String(now.getMinutes()).padStart(2, "0") + ":" +
                  String(now.getSeconds()).padStart(2, "0");
  const fullCreatedAt = `${state.currentDate} ${timeStr}`;

  const payload = {
    meal_type: state.manualSelectedMealType || "lunch",
    dish_name: dishName,
    comment: comment,
    items: [
      {
        name: dishName,
        weight_g: weight,
        calories: calories,
        protein: protein,
        fat: fat,
        carbs: carbs,
      }
    ],
    created_at: fullCreatedAt,
  };

  try {
    const res = await fetch("/api/meals", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    if (!res.ok) {
      const errData = await res.json().catch(() => ({}));
      throw new Error(errData.detail || "Не удалось сохранить прием пищи");
    }

    showToast(`✅ Блюдо «${dishName}» сохранено в дневник!`);
    closeManualMealModal();
    loadDiaryData();
  } catch (err) {
    console.error("Ошибка сохранения:", err);
    showToast(`❌ Ошибка сохранения: ${err.message}`);
  } finally {
    if (submitBtn) {
      submitBtn.disabled = false;
      submitBtn.textContent = "💾 Сохранить в дневник";
    }
  }
}

async function handleAiEstimateClick() {
  const dishInput = document.getElementById("manualDishName");
  const weightInput = document.getElementById("manualDishWeight");
  const btn = document.getElementById("manualAiEstimateBtn");

  const query = dishInput.value.trim();
  if (!query) {
    showToast("⚠️ Введите название продукта (например: «хлеб зерновой 30г»)");
    dishInput.focus();
    return;
  }

  btn.disabled = true;
  const originalText = btn.innerHTML;
  btn.innerHTML = "⏳ Считаем...";

  const weightVal = parseFloat(weightInput.value);
  const payload = {
    query: query,
    weight_g: (!isNaN(weightVal) && weightVal > 0) ? weightVal : null,
  };

  try {
    const res = await fetch("/api/estimate-nutrition", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.detail || "Не удалось рассчитать КБЖУ");
    }

    const data = await res.json();
    dishInput.value = data.name;
    weightInput.value = Math.round(data.weight_g);
    document.getElementById("manualCalories").value = Math.round(data.calories);
    document.getElementById("manualProtein").value = data.protein.toFixed(1);
    document.getElementById("manualFat").value = data.fat.toFixed(1);
    document.getElementById("manualCarbs").value = data.carbs.toFixed(1);
    if (data.comment) {
      document.getElementById("manualComment").value = data.comment;
    }

    showToast(`✨ Gemini: ${Math.round(data.calories)} ккал (${Math.round(data.weight_g)}г)`);
  } catch (err) {
    console.error("Ошибка ИИ-оценки:", err);
    showToast(`❌ ${err.message}`);
  } finally {
    btn.disabled = false;
    btn.innerHTML = originalText;
  }
}
