import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart'; // Import ApiService

class StepTrackerStats {
  final int dailyGoal;
  final double strideMeters;
  final bool isCustomStride;
  final int? profileHeightCm;
  final int stepsToday;
  final int totalSteps;
  final String currentDateKey;
  final int? baselineForToday;
  final int? lastSensorSteps;
  final Map<String, int> history;

  const StepTrackerStats({
    required this.dailyGoal,
    required this.strideMeters,
    required this.isCustomStride,
    required this.profileHeightCm,
    required this.stepsToday,
    required this.totalSteps,
    required this.currentDateKey,
    required this.baselineForToday,
    required this.lastSensorSteps,
    required this.history,
  });

  factory StepTrackerStats.initial({required String currentDateKey, int dailyGoal = 8000}) {
    return StepTrackerStats(
      dailyGoal: dailyGoal,
      strideMeters: StepTrackerService.defaultStrideMeters,
      isCustomStride: false,
      profileHeightCm: null,
      stepsToday: 0,
      totalSteps: 0,
      currentDateKey: currentDateKey,
      baselineForToday: null,
      lastSensorSteps: null,
      history: const {},
    );
  }

  StepTrackerStats copyWith({
    int? dailyGoal,
    double? strideMeters,
    bool? isCustomStride,
    int? profileHeightCm,
    bool clearProfileHeight = false,
    int? stepsToday,
    int? totalSteps,
    String? currentDateKey,
    int? baselineForToday,
    bool clearBaseline = false,
    int? lastSensorSteps,
    bool clearLastSensor = false,
    Map<String, int>? history,
  }) {
    return StepTrackerStats(
      dailyGoal: dailyGoal ?? this.dailyGoal,
      strideMeters: strideMeters ?? this.strideMeters,
      isCustomStride: isCustomStride ?? this.isCustomStride,
      profileHeightCm: clearProfileHeight ? null : (profileHeightCm ?? this.profileHeightCm),
      stepsToday: stepsToday ?? this.stepsToday,
      totalSteps: totalSteps ?? this.totalSteps,
      currentDateKey: currentDateKey ?? this.currentDateKey,
      baselineForToday: clearBaseline ? null : (baselineForToday ?? this.baselineForToday),
      lastSensorSteps: clearLastSensor ? null : (lastSensorSteps ?? this.lastSensorSteps),
      history: history ?? this.history,
    );
  }
}

abstract class StepTrackerStorage {
  Future<StepTrackerStats> load({
    required String userId,
    required String currentDateKey,
    int defaultGoal = 8000,
  });

  Future<void> save({
    required String userId,
    required StepTrackerStats stats,
  });
}

class SharedPrefsStepTrackerStorage implements StepTrackerStorage {
  const SharedPrefsStepTrackerStorage();

  @override
  Future<StepTrackerStats> load({
    required String userId,
    required String currentDateKey,
    int defaultGoal = 8000,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = userId;

    final dailyGoal = prefs.getInt('step_goal_noprefix_$uid') ?? defaultGoal; // Changed key slightly to avoid conflict if needed, or keep same? 
    // Actually, let's keep keys compatible if user switches storage strategies.
    // The ApiStepTrackerStorage uses 'step_date_$userId' etc.
    // Let's use same keys for compatibility where it makes sense.
    
    final customStride = prefs.getBool('step_stride_custom_$uid') ?? false;
    final savedStride = prefs.getDouble('step_stride_m_$uid');
    final profileHeightCm = prefs.getInt(StepTrackerService.profileHeightKey(uid));
    final strideMeters = customStride && savedStride != null
        ? StepTrackerService.sanitizeStrideMeters(savedStride)
        : StepTrackerService.estimateStrideMetersFromHeightCm(profileHeightCm);
    final totalSteps = prefs.getInt('step_total_$uid') ?? 0;
    final lastSensorSteps = prefs.getInt('step_last_sensor_$uid');

    final storedDate = prefs.getString('step_date_$uid') ?? currentDateKey;
    final storedBaseline = prefs.getInt('step_baseline_$uid');
    final storedToday = prefs.getInt('step_today_$uid') ?? 0;

    final historyRaw = prefs.getString('step_history_$uid');
    final history = _decodeHistory(historyRaw);

    if (storedDate == currentDateKey) {
      return StepTrackerStats(
        dailyGoal: dailyGoal,
        strideMeters: strideMeters,
        isCustomStride: customStride && savedStride != null,
        profileHeightCm: profileHeightCm,
        stepsToday: storedToday,
        totalSteps: totalSteps,
        currentDateKey: currentDateKey,
        baselineForToday: storedBaseline,
        lastSensorSteps: lastSensorSteps,
        history: history,
      );
    }

    return StepTrackerStats(
      dailyGoal: dailyGoal,
      strideMeters: strideMeters,
      isCustomStride: customStride && savedStride != null,
      profileHeightCm: profileHeightCm,
      stepsToday: 0,
      totalSteps: totalSteps,
      currentDateKey: currentDateKey,
      baselineForToday: null,
      lastSensorSteps: lastSensorSteps,
      history: history,
    );
  }

  @override
  Future<void> save({
    required String userId,
    required StepTrackerStats stats,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = userId;

    await prefs.setInt('step_goal_noprefix_$uid', stats.dailyGoal);
    await prefs.setBool('step_stride_custom_$uid', stats.isCustomStride);
    if (stats.isCustomStride) {
      await prefs.setDouble('step_stride_m_$uid', stats.strideMeters);
    } else {
      await prefs.remove('step_stride_m_$uid');
    }
    final profileHeightKey = StepTrackerService.profileHeightKey(uid);
    if (stats.profileHeightCm != null) {
      await prefs.setInt(profileHeightKey, stats.profileHeightCm!);
    } else {
      await prefs.remove(profileHeightKey);
    }
    await prefs.setInt('step_total_$uid', stats.totalSteps);
    await prefs.setString('step_date_$uid', stats.currentDateKey);
    await prefs.setInt('step_today_$uid', stats.stepsToday);
    if (stats.baselineForToday != null) {
      await prefs.setInt('step_baseline_$uid', stats.baselineForToday!);
    }
    if (stats.lastSensorSteps != null) {
      await prefs.setInt('step_last_sensor_$uid', stats.lastSensorSteps!);
    }
    await prefs.setString('step_history_$uid', jsonEncode(stats.history));
  }

  static Map<String, int> _decodeHistory(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return {};
    return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
  }
}

class ApiStepTrackerStorage implements StepTrackerStorage {
  final ApiService api;
  const ApiStepTrackerStorage({required this.api});

  @override
  Future<StepTrackerStats> load({
    required String userId,
    required String currentDateKey,
    int defaultGoal = 8000,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final localHeight = prefs.getInt(StepTrackerService.profileHeightKey(userId));
    
    // Load local parts (baseline, sensor diffs)
    final storedDate = prefs.getString('step_date_$userId') ?? currentDateKey;
    int? storedBaseline = prefs.getInt('step_baseline_$userId');
    int? storedLastSensor = prefs.getInt('step_last_sensor_$userId');
    
    // Reset baseline if date changed locally
    if (storedDate != currentDateKey) {
       storedBaseline = null;
    }

    try {
      final serverStats = await api.getSteps(currentDateKey);
      if (serverStats == null) {
        final autoStride = StepTrackerService.estimateStrideMetersFromHeightCm(localHeight);
        return StepTrackerStats(
          dailyGoal: defaultGoal,
          strideMeters: autoStride,
          isCustomStride: false,
          profileHeightCm: localHeight,
          stepsToday: 0,
          totalSteps: 0,
          currentDateKey: currentDateKey,
          baselineForToday: storedBaseline,
          lastSensorSteps: storedLastSensor,
          history: const {},
        );
      }

      final resolvedHeight = serverStats.heightCm ?? localHeight;
      final resolvedIsCustomStride = serverStats.isCustomStride;
      final resolvedStride = resolvedIsCustomStride
          ? StepTrackerService.sanitizeStrideMeters(serverStats.strideMeters)
          : StepTrackerService.estimateStrideMetersFromHeightCm(resolvedHeight);

      return StepTrackerStats(
        dailyGoal: serverStats.goal,
        strideMeters: resolvedStride,
        isCustomStride: resolvedIsCustomStride,
        profileHeightCm: resolvedHeight,
        stepsToday: serverStats.steps,
        totalSteps: 0, // Not synced from server yet, or could be
        currentDateKey: currentDateKey,
        baselineForToday: storedBaseline,
        lastSensorSteps: storedLastSensor,
        history: {}, // Could fetch history if needed
      );
    } catch (e) {
      print('StepTracker: Failed to load from API, using defaults. $e');
      final autoStride = StepTrackerService.estimateStrideMetersFromHeightCm(localHeight);
      return StepTrackerStats(
        dailyGoal: defaultGoal,
        strideMeters: autoStride,
        isCustomStride: false,
        profileHeightCm: localHeight,
        stepsToday: 0,
        totalSteps: 0,
        currentDateKey: currentDateKey,
        baselineForToday: storedBaseline,
        lastSensorSteps: storedLastSensor,
        history: const {},
      );
    }
  }

  @override
  Future<void> save({
    required String userId,
    required StepTrackerStats stats,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save local technical data
    await prefs.setString('step_date_$userId', stats.currentDateKey);
    if (stats.baselineForToday != null) {
      await prefs.setInt('step_baseline_$userId', stats.baselineForToday!);
    }
    if (stats.lastSensorSteps != null) {
      await prefs.setInt('step_last_sensor_$userId', stats.lastSensorSteps!);
    }
    final profileHeightKey = StepTrackerService.profileHeightKey(userId);
    if (stats.profileHeightCm != null) {
      await prefs.setInt(profileHeightKey, stats.profileHeightCm!);
    } else {
      await prefs.remove(profileHeightKey);
    }

    // Sync business data to API
    try {
      await api.updateSteps(
        date: stats.currentDateKey,
        steps: stats.stepsToday,
        goal: stats.dailyGoal,
        strideMeters: stats.strideMeters,
        heightCm: stats.profileHeightCm,
        isCustomStride: stats.isCustomStride,
      );
    } catch (e) {
      print('StepTracker: Failed to sync to API. $e');
    }
  }
}

class StepTrackerService {
  static const double defaultStrideMeters = 0.78;
  static const int defaultPointsPer100Steps = 5;

  const StepTrackerService();

  static double sanitizeStrideMeters(double? strideMeters) {
    final value = strideMeters ?? defaultStrideMeters;
    if (value.isNaN || value.isInfinite) return defaultStrideMeters;
    return value.clamp(0.40, 1.20).toDouble();
  }

  static String profileHeightKey(String userId) => 'student_height_cm_$userId';

  static bool isValidHeightCm(int? heightCm) {
    if (heightCm == null) return false;
    return heightCm >= 120 && heightCm <= 230;
  }

  static double estimateStrideMetersFromHeightCm(int? heightCm) {
    if (!isValidHeightCm(heightCm)) return defaultStrideMeters;
    final estimated = heightCm! * 0.415 / 100.0;
    return sanitizeStrideMeters(estimated);
  }

  StepTrackerStats applyStepEvent({
    required StepTrackerStats current,
    required int sensorSteps,
    required DateTime now,
  }) {
    final todayKey = dateKey(now);
    var activeDateKey = current.currentDateKey;
    int? baseline = current.baselineForToday;
    var stepsToday = current.stepsToday;
    var total = current.totalSteps;
    final history = Map<String, int>.from(current.history);

    if (activeDateKey != todayKey) {
      activeDateKey = todayKey;
      baseline = null;
      stepsToday = 0;
    }

    baseline ??= sensorSteps;
    if (sensorSteps < baseline) {
      baseline = sensorSteps;
    }

    stepsToday = (sensorSteps - baseline).clamp(0, 1000000).toInt();

    if (current.lastSensorSteps != null && sensorSteps >= current.lastSensorSteps!) {
      total += sensorSteps - current.lastSensorSteps!;
    }

    history[activeDateKey] = stepsToday;

    return current.copyWith(
      currentDateKey: activeDateKey,
      baselineForToday: baseline,
      stepsToday: stepsToday,
      totalSteps: total,
      lastSensorSteps: sensorSteps,
      history: history,
    );
  }

  String statusRu(String status) {
    switch (status.toLowerCase()) {
      case 'walking':
        return 'Ходьба';
      case 'stopped':
        return 'Покой';
      default:
        return 'Неизвестно';
    }
  }

  String dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String formatDate(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return key;
    return '${parts[2]}.${parts[1]}.${parts[0]}';
  }

  double kmFromSteps(int steps, {double strideMeters = defaultStrideMeters}) {
    if (steps <= 0) return 0;
    return (steps * sanitizeStrideMeters(strideMeters)) / 1000.0;
  }

  String formatKm(double km, {int fractionDigits = 2}) {
    return km.toStringAsFixed(fractionDigits).replaceAll('.', ',');
  }

  int healthPointsFromSteps(
    int steps, {
    int pointsPer100Steps = defaultPointsPer100Steps,
  }) {
    if (steps <= 0) return 0;
    return (steps ~/ 100) * pointsPer100Steps;
  }
}
