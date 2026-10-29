enum MealType {
  breakfast,
  lunch,
  dinner,
  snack;

  String get value {
    switch (this) {
      case MealType.breakfast:
        return 'breakfast';
      case MealType.lunch:
        return 'lunch';
      case MealType.dinner:
        return 'dinner';
      case MealType.snack:
        return 'snack';
    }
  }

  String get labelRu {
    switch (this) {
      case MealType.breakfast:
        return 'Завтрак 🍳';
      case MealType.lunch:
        return 'Обед 🍲';
      case MealType.dinner:
        return 'Ужин 🥗';
      case MealType.snack:
        return 'Перекус 🍎';
    }
  }

  static MealType fromString(String val) {
    switch (val.toLowerCase()) {
      case 'breakfast':
        return MealType.breakfast;
      case 'lunch':
        return MealType.lunch;
      case 'dinner':
        return MealType.dinner;
      case 'snack':
        return MealType.snack;
      default:
        return MealType.lunch;
    }
  }
}

class IngredientItem {
  final int? id;
  final String name;
  final double weightG;
  final double calories;
  final double protein;
  final double fat;
  final double carbs;

  IngredientItem({
    this.id,
    required this.name,
    required this.weightG,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  factory IngredientItem.fromJson(Map<String, dynamic> json) {
    return IngredientItem(
      id: json['id'] as int?,
      name: json['name'] as String? ?? 'Продукт',
      weightG: (json['weight_g'] as num?)?.toDouble() ?? 0.0,
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'weight_g': weightG,
      'calories': calories,
      'protein': protein,
      'fat': fat,
      'carbs': carbs,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  IngredientItem copyWithWeight(double newWeight) {
    if (weightG <= 0 || newWeight <= 0) {
      return copyWith(weightG: newWeight);
    }
    final factor = newWeight / weightG;
    return IngredientItem(
      id: id,
      name: name,
      weightG: double.parse(newWeight.toStringAsFixed(1)),
      calories: double.parse((calories * factor).toStringAsFixed(1)),
      protein: double.parse((protein * factor).toStringAsFixed(1)),
      fat: double.parse((fat * factor).toStringAsFixed(1)),
      carbs: double.parse((carbs * factor).toStringAsFixed(1)),
    );
  }

  IngredientItem copyWith({
    int? id,
    String? name,
    double? weightG,
    double? calories,
    double? protein,
    double? fat,
    double? carbs,
  }) {
    return IngredientItem(
      id: id ?? this.id,
      name: name ?? this.name,
      weightG: weightG ?? this.weightG,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      fat: fat ?? this.fat,
      carbs: carbs ?? this.carbs,
    );
  }
}

class FoodAnalysisResult {
  final String dishName;
  final String comment;
  final List<IngredientItem> items;
  final double totalWeightG;
  final double totalCalories;
  final double totalProtein;
  final double totalFat;
  final double totalCarbs;

  FoodAnalysisResult({
    required this.dishName,
    this.comment = '',
    required this.items,
    required this.totalWeightG,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalFat,
    required this.totalCarbs,
  });

  factory FoodAnalysisResult.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>?)
            ?.map((e) => IngredientItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return FoodAnalysisResult(
      dishName: json['dish_name'] as String? ?? 'Блюдо',
      comment: json['comment'] as String? ?? '',
      items: itemsList,
      totalWeightG: (json['total_weight_g'] as num?)?.toDouble() ?? 0.0,
      totalCalories: (json['total_calories'] as num?)?.toDouble() ?? 0.0,
      totalProtein: (json['total_protein'] as num?)?.toDouble() ?? 0.0,
      totalFat: (json['total_fat'] as num?)?.toDouble() ?? 0.0,
      totalCarbs: (json['total_carbs'] as num?)?.toDouble() ?? 0.0,
    );
  }

  FoodAnalysisResult copyWith({
    String? dishName,
    String? comment,
    List<IngredientItem>? items,
  }) {
    final newItems = items ?? this.items;
    final totalWeight = newItems.fold<double>(0.0, (sum, it) => sum + it.weightG);
    final totalCal = newItems.fold<double>(0.0, (sum, it) => sum + it.calories);
    final totalP = newItems.fold<double>(0.0, (sum, it) => sum + it.protein);
    final totalF = newItems.fold<double>(0.0, (sum, it) => sum + it.fat);
    final totalC = newItems.fold<double>(0.0, (sum, it) => sum + it.carbs);

    return FoodAnalysisResult(
      dishName: dishName ?? this.dishName,
      comment: comment ?? this.comment,
      items: newItems,
      totalWeightG: double.parse(totalWeight.toStringAsFixed(1)),
      totalCalories: double.parse(totalCal.toStringAsFixed(1)),
      totalProtein: double.parse(totalP.toStringAsFixed(1)),
      totalFat: double.parse(totalF.toStringAsFixed(1)),
      totalCarbs: double.parse(totalC.toStringAsFixed(1)),
    );
  }
}

class MealRecord {
  final int id;
  final MealType mealType;
  final String dishName;
  final String? comment;
  final String createdAt;
  final List<IngredientItem> items;
  final double totalWeightG;
  final double totalCalories;
  final double totalProtein;
  final double totalFat;
  final double totalCarbs;

  MealRecord({
    required this.id,
    required this.mealType,
    required this.dishName,
    this.comment,
    required this.createdAt,
    required this.items,
    required this.totalWeightG,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalFat,
    required this.totalCarbs,
  });

  factory MealRecord.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>?)
            ?.map((e) => IngredientItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return MealRecord(
      id: json['id'] as int,
      mealType: MealType.fromString(json['meal_type'] as String? ?? 'lunch'),
      dishName: json['dish_name'] as String? ?? 'Блюдо',
      comment: json['comment'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      items: itemsList,
      totalWeightG: (json['total_weight_g'] as num?)?.toDouble() ?? 0.0,
      totalCalories: (json['total_calories'] as num?)?.toDouble() ?? 0.0,
      totalProtein: (json['total_protein'] as num?)?.toDouble() ?? 0.0,
      totalFat: (json['total_fat'] as num?)?.toDouble() ?? 0.0,
      totalCarbs: (json['total_carbs'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DailySummary {
  final String date;
  final int mealsCount;
  final double totalWeightG;
  final double totalCalories;
  final double totalProtein;
  final double totalFat;
  final double totalCarbs;
  final List<MealRecord> meals;

  DailySummary({
    required this.date,
    required this.mealsCount,
    required this.totalWeightG,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalFat,
    required this.totalCarbs,
    required this.meals,
  });

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    final mealsList = (json['meals'] as List<dynamic>?)
            ?.map((e) => MealRecord.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return DailySummary(
      date: json['date'] as String? ?? '',
      mealsCount: json['meals_count'] as int? ?? mealsList.length,
      totalWeightG: (json['total_weight_g'] as num?)?.toDouble() ?? 0.0,
      totalCalories: (json['total_calories'] as num?)?.toDouble() ?? 0.0,
      totalProtein: (json['total_protein'] as num?)?.toDouble() ?? 0.0,
      totalFat: (json['total_fat'] as num?)?.toDouble() ?? 0.0,
      totalCarbs: (json['total_carbs'] as num?)?.toDouble() ?? 0.0,
      meals: mealsList,
    );
  }
}

class NutritionGoals {
  final double calories;
  final double protein;
  final double fat;
  final double carbs;
  final String? updatedAt;

  NutritionGoals({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    this.updatedAt,
  });

  factory NutritionGoals.fromJson(Map<String, dynamic> json) {
    return NutritionGoals(
      calories: (json['calories'] as num?)?.toDouble() ?? 2000.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 90.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 65.0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 250.0,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'calories': calories,
    'protein': protein,
    'fat': fat,
    'carbs': carbs,
  };
}

class EstimateNutritionResult {
  final String name;
  final double weightG;
  final double calories;
  final double protein;
  final double fat;
  final double carbs;
  final String? comment;

  EstimateNutritionResult({
    required this.name,
    required this.weightG,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    this.comment,
  });

  factory EstimateNutritionResult.fromJson(Map<String, dynamic> json) {
    return EstimateNutritionResult(
      name: json['name'] as String? ?? '',
      weightG: (json['weight_g'] as num?)?.toDouble() ?? 100.0,
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
      comment: json['comment'] as String?,
    );
  }
}

