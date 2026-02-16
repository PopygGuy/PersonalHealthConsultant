import 'package:flutter_test/flutter_test.dart';
import 'package:personal_health_consultant/services/step_tracker_service.dart';

void main() {
  group('StepTrackerService.applyStepEvent', () {
    const service = StepTrackerService();

    test('initializes baseline and calculates today steps', () {
      final initial = StepTrackerStats.initial(currentDateKey: '2026-02-12');

      final updated = service.applyStepEvent(
        current: initial,
        sensorSteps: 1200,
        now: DateTime(2026, 2, 12, 9),
      );

      expect(updated.baselineForToday, 1200);
      expect(updated.stepsToday, 0);
      expect(updated.totalSteps, 0);
      expect(updated.lastSensorSteps, 1200);
      expect(updated.history['2026-02-12'], 0);
    });

    test('increments totals when sensor count increases', () {
      final current = StepTrackerStats(
        dailyGoal: 8000,
        strideMeters: StepTrackerService.defaultStrideMeters,
        isCustomStride: false,
        profileHeightCm: null,
        stepsToday: 0,
        totalSteps: 500,
        currentDateKey: '2026-02-12',
        baselineForToday: 1200,
        lastSensorSteps: 1200,
        history: const {'2026-02-12': 0},
      );

      final updated = service.applyStepEvent(
        current: current,
        sensorSteps: 1500,
        now: DateTime(2026, 2, 12, 10),
      );

      expect(updated.stepsToday, 300);
      expect(updated.totalSteps, 800);
      expect(updated.lastSensorSteps, 1500);
      expect(updated.history['2026-02-12'], 300);
    });

    test('resets baseline on new day and starts from zero', () {
      final current = StepTrackerStats(
        dailyGoal: 8000,
        strideMeters: StepTrackerService.defaultStrideMeters,
        isCustomStride: false,
        profileHeightCm: null,
        stepsToday: 400,
        totalSteps: 1000,
        currentDateKey: '2026-02-12',
        baselineForToday: 1000,
        lastSensorSteps: 1400,
        history: const {'2026-02-12': 400},
      );

      final updated = service.applyStepEvent(
        current: current,
        sensorSteps: 2000,
        now: DateTime(2026, 2, 13, 8),
      );

      expect(updated.currentDateKey, '2026-02-13');
      expect(updated.baselineForToday, 2000);
      expect(updated.stepsToday, 0);
      expect(updated.totalSteps, 1600);
      expect(updated.history['2026-02-13'], 0);
    });

    test('handles sensor reset without negative values', () {
      final current = StepTrackerStats(
        dailyGoal: 8000,
        strideMeters: StepTrackerService.defaultStrideMeters,
        isCustomStride: false,
        profileHeightCm: null,
        stepsToday: 300,
        totalSteps: 1300,
        currentDateKey: '2026-02-12',
        baselineForToday: 1200,
        lastSensorSteps: 1500,
        history: const {'2026-02-12': 300},
      );

      final updated = service.applyStepEvent(
        current: current,
        sensorSteps: 20,
        now: DateTime(2026, 2, 12, 18),
      );

      expect(updated.baselineForToday, 20);
      expect(updated.stepsToday, 0);
      expect(updated.totalSteps, 1300);
      expect(updated.lastSensorSteps, 20);
      expect(updated.history['2026-02-12'], 0);
    });
  });

  group('StepTrackerService metrics helpers', () {
    const service = StepTrackerService();

    test('converts steps to kilometers', () {
      final km = service.kmFromSteps(5000);
      expect(km, closeTo(3.9, 0.0001));
      expect(service.formatKm(km), '3,90');
    });

    test('sanitizes invalid stride values', () {
      expect(StepTrackerService.sanitizeStrideMeters(null), StepTrackerService.defaultStrideMeters);
      expect(StepTrackerService.sanitizeStrideMeters(0.2), 0.40);
      expect(StepTrackerService.sanitizeStrideMeters(2.0), 1.20);
    });

    test('calculates health points from steps', () {
      expect(service.healthPointsFromSteps(0), 0);
      expect(service.healthPointsFromSteps(99), 0);
      expect(service.healthPointsFromSteps(100), 5);
      expect(service.healthPointsFromSteps(2450), 120);
    });

    test('estimates stride from height', () {
      final stride = StepTrackerService.estimateStrideMetersFromHeightCm(180);
      expect(stride, closeTo(0.747, 0.0001));
      expect(StepTrackerService.estimateStrideMetersFromHeightCm(null), StepTrackerService.defaultStrideMeters);
    });
  });
}
