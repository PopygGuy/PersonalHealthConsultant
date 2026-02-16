import 'dart:math';
import '../models/user_profile.dart';

enum DayType { training, rest, refeed }

class DayPlan {
  final DayType type;
  final String title;
  final int calories;
  final int protein;
  final int fat;
  final int carbs;
  final String description;
  final List<String> tips;

  DayPlan({
    required this.type,
    required this.title,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.description,
    required this.tips,
  });
}

class DietPlan {
  final DayPlan trainingDay;
  final DayPlan restDay;
  final DayPlan refeedDay;
  final double tdee;

  DietPlan({
    required this.trainingDay,
    required this.restDay,
    required this.refeedDay,
    required this.tdee,
  });
}

class HealthEngine {
  static const List<String> _carbSources = [
    "🍚 Источники углеводов: гречка, бурый рис, киноа, овсянка.",
    "🍠 Отличный выбор сегодня: батат, запеченный картофель или паста из твердых сортов.",
    "🍌 Фрукты: бананы (перед тренировкой), яблоки и грейпфруты (в любое время).",
    "🥪 Цельнозерновой хлеб — хороший источник энергии и клетчатки."
  ];

  static const List<String> _proteinSources = [
    "🍗 Белок: куриная грудка, индейка, кролик.",
    "🐟 Рыба: тунец, треска или хек (нежирные сорта).",
    "🥚 Яйца — эталонный белок. Можно есть 2 желтка, остальные белки.",
    "🥛 Творог или греческий йогурт — отличный перекус перед сном."
  ];

  static const List<String> _fatSources = [
    "🥑 Жиры: авокадо, оливковое масло (в салат).",
    "🥜 Орехи: миндаль или грецкий орех (но строго по весам!).",
    "🍳 Желтки яиц и жирная рыба (семга, форель) — источники Омега-3.",
    "🧈 Сливочное масло 82.5% — можно 10г с утра для гормонов."
  ];

  static const List<String> _veggieTips = [
    "🥦 Добавьте брокколи или цветную капусту — объем большой, калорий мало.",
    "🥒 Огурцы и зелень можно есть практически без ограничений.",
    "🥗 Начинайте обед с большой порции салата, чтобы быстрее насытиться.",
    "🍅 Помидоры после термообработки выделяют ликопин (полезно для сердца)."
  ];

  static DietPlan generatePlan(UserProfile user) {
    double bmr;
    if (user.gender == Gender.male) {
      bmr = (10 * user.weight) + (6.25 * user.height) - (5 * user.age) + 5;
    } else {
      bmr = (10 * user.weight) + (6.25 * user.height) - (5 * user.age) - 161;
    }

    double multiplier;
    switch (user.activityLevel) {
      case ActivityLevel.sedentary: multiplier = 1.2; break;
      case ActivityLevel.light: multiplier = 1.375; break;
      case ActivityLevel.moderate: multiplier = 1.55; break;
      case ActivityLevel.active: multiplier = 1.725; break;
      case ActivityLevel.veryActive: multiplier = 1.9; break;
    }
    double tdee = bmr * multiplier;

    int userSeed = user.age + user.weight.round() + user.height.round();

    return DietPlan(
      tdee: tdee,
      trainingDay: _calculateDay(user, tdee, DayType.training, userSeed + 1),
      restDay: _calculateDay(user, tdee, DayType.rest, userSeed + 2),
      refeedDay: _calculateDay(user, tdee, DayType.refeed, userSeed + 3),
    );
  }

  static DayPlan _calculateDay(UserProfile user, double tdee, DayType type, int seed) {
    double targetCalories = tdee;
    
    double proteinPerKg = 1.8;
    double fatPerKg = 1.0;
    
    String title = "";
    String desc = "";

    double heightM = user.height / 100;
    double bmi = user.weight / (heightM * heightM);
    bool highBmi = bmi > 27;

    switch (user.goal) {
      case HealthGoal.loseWeight:
        if (type == DayType.training) {
          targetCalories = tdee * 0.85; 
          title = "Тренировка";
          desc = "Дефицит + Углеводы для работы.";
          proteinPerKg = highBmi ? 1.6 : 2.0; 
          fatPerKg = 0.8; 
        } else if (type == DayType.rest) {
          targetCalories = tdee * 0.75; 
          title = "Отдых (Low Carb)";
          desc = "Максимум белка, минимум углей.";
          proteinPerKg = highBmi ? 1.8 : 2.2; 
          fatPerKg = 1.0; 
        } else {
          targetCalories = tdee * 0.95;
          title = "Рефид (углеводная поддержка)";
          desc = "Кратковременное повышение углеводов для поддержки дефицита.";
          proteinPerKg = 1.6;
          fatPerKg = 0.6;
        }
        break;

      case HealthGoal.maintain:
        targetCalories = tdee;
        if (type == DayType.training) {
          title = "Активный день";
          desc = "Баланс энергии.";
          proteinPerKg = highBmi ? 1.5 : 1.8;
          fatPerKg = 1.0;
        } else if (type == DayType.rest) {
           targetCalories = tdee * 0.95;
           title = "Легкий день";
           desc = "Комфортное питание.";
           proteinPerKg = highBmi ? 1.5 : 1.8;
           fatPerKg = 1.1; 
        } else {
           targetCalories = tdee;
           title = "Рефид (плановая подпитка)";
           desc = "Повышение углеводов без выхода за разумные калории.";
           proteinPerKg = 1.6;
           fatPerKg = 0.8;
        }
        break;

      case HealthGoal.gainMuscle:
        if (type == DayType.training) {
          targetCalories = tdee * 1.15;
          title = "День роста";
          desc = "Профицит для анаболизма.";
          proteinPerKg = 1.8; 
          fatPerKg = 0.9;
        } else if (type == DayType.rest) {
          targetCalories = tdee * 1.05;
          title = "Восстановление";
          desc = "Питание мышц.";
          proteinPerKg = 2.0;
          fatPerKg = 1.0;
        } else {
          targetCalories = tdee * 1.10;
          title = "Рефид (контроль углеводов)";
          desc = "Углеводная подпитка при сохранении контроля по жирам.";
          proteinPerKg = 1.7;
          fatPerKg = 0.8;
        }
        break;
    }

    int protein = (user.weight * proteinPerKg).round();
    int fat = (user.weight * fatPerKg).round();
    
    double consumedKcal = (protein * 4) + (fat * 9);
    double remaining = targetCalories - consumedKcal;
    int carbs = (remaining / 4).round();

    if (carbs < 40) {
       carbs = 40;
       int fatCal = ((targetCalories - (protein * 4) - (carbs * 4)) / 9).round();
       if (fatCal >= 30) fat = fatCal;
    }

    List<String> personalizedTips = _generateDeepTips(user, type, carbs, protein, fat, seed, highBmi);

    return DayPlan(
      type: type,
      title: title,
      calories: targetCalories.round(),
      protein: protein,
      fat: fat,
      carbs: carbs,
      description: desc,
      tips: personalizedTips,
    );
  }

  static List<String> _generateDeepTips(UserProfile user, DayType type, int dailyCarbs, int dailyProtein, int dailyFat, int seed, bool highBmi) {
     List<String> tips = [];
    final random = Random(seed);

    int waterMl = (user.weight * 35).round();
    String waterReason = "";
    if (type == DayType.training) { waterMl += 600; waterReason = "(+600мл тренировка)"; }
    else if (type == DayType.refeed) { waterMl += 1000; waterReason = "(+1000мл для углей)"; }
    else { waterReason = "(норма)"; }
    tips.add("💧 Вода: ${(waterMl/1000).toStringAsFixed(1)} л. $waterReason");

    if (highBmi) {
       tips.add("⚖️ Норма белка оптимизирована под ваш ИМТ для безопасности почек.");
    }

    if (type == DayType.training) {
      tips.add("🔥 Жиры (${dailyFat}г) держите умеренными.");
      tips.add(_carbSources[random.nextInt(_carbSources.length)]);
      tips.add(_proteinSources[random.nextInt(_proteinSources.length)]);
    } else if (type == DayType.rest) {
      tips.add("🥬 Углеводы (${dailyCarbs}г) лучше получать из овощей и круп.");
      tips.add(_veggieTips[random.nextInt(_veggieTips.length)]);
      tips.add(_fatSources[random.nextInt(_fatSources.length)]);
    } else if (type == DayType.refeed) {
      tips.add("🔄 Рефид — это 1-2 дня диетической поддержки, а не читдэй.");
      tips.add("🍝 Основной прирост калорий — за счет углеводов, белок держите стабильно.");
      tips.add("🥐 Жиры (${dailyFat}г) не разгоняйте, чтобы не выбить недельный баланс.");
      tips.add("📅 Удобно ставить рефид в день тяжелой тренировки или накануне — по самочувствию.");
      tips.add(_carbSources[random.nextInt(_carbSources.length)]);
    }
    
    return tips;
  }
}
