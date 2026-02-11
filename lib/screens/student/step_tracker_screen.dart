import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/mock_database.dart';

class StepTrackerScreen extends StatefulWidget {
  final User user;
  const StepTrackerScreen({super.key, required this.user});

  @override
  State<StepTrackerScreen> createState() => _StepTrackerScreenState();
}

class _StepTrackerScreenState extends State<StepTrackerScreen> {
  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<PedestrianStatus>? _statusSubscription;

  bool _permissionGranted = false;
  String _pedestrianStatus = 'Неизвестно';
  String? _statusHint;

  int _stepsToday = 0;
  int _totalSteps = 0;
  int _dailyGoal = 8000;

  String _currentDateKey = _dateKey(DateTime.now());
  int? _baselineForToday;
  int? _lastSensorSteps;

  // Simple per-day history map: yyyy-MM-dd -> steps
  Map<String, int> _history = {};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadStoredStats();
    await _requestPermissionAndStart();
  }

  Future<void> _requestPermissionAndStart() async {
    final status = await Permission.activityRecognition.request();
    if (!mounted) return;

    if (!status.isGranted) {
      setState(() {
        _permissionGranted = false;
        _statusHint = 'Разрешите доступ к физической активности для работы шагомера.';
      });
      return;
    }

    setState(() {
      _permissionGranted = true;
      _statusHint = null;
    });

    _stepSubscription = Pedometer.stepCountStream.listen(
      _onStepCount,
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _statusHint = 'Ошибка шагомера: $error';
        });
      },
      cancelOnError: false,
    );

    _statusSubscription = Pedometer.pedestrianStatusStream.listen(
      (event) {
        if (!mounted) return;
        setState(() => _pedestrianStatus = _statusRu(event.status));
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _pedestrianStatus = 'Неизвестно');
      },
      cancelOnError: false,
    );
  }

  Future<void> _onStepCount(StepCount event) async {
    final now = DateTime.now();
    final todayKey = _dateKey(now);
    final sensorSteps = event.steps;

    // If day changed, reset daily baseline.
    if (_currentDateKey != todayKey) {
      _currentDateKey = todayKey;
      _baselineForToday = null;
      _stepsToday = 0;
    }

    _baselineForToday ??= sensorSteps;

    // Sensor may reset (e.g. reboot), adapt baseline safely.
    if (sensorSteps < (_baselineForToday ?? 0)) {
      _baselineForToday = sensorSteps;
    }

    final todaySteps = (sensorSteps - (_baselineForToday ?? sensorSteps)).clamp(0, 1000000).toInt();

    int total = _totalSteps;
    if (_lastSensorSteps != null && sensorSteps >= _lastSensorSteps!) {
      total += (sensorSteps - _lastSensorSteps!).toInt();
    }
    _lastSensorSteps = sensorSteps;

    _stepsToday = todaySteps;
    _totalSteps = total;
    _history[_currentDateKey] = _stepsToday;

    if (mounted) setState(() {});
    await _saveStoredStats();
  }

  Future<void> _loadStoredStats() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = widget.user.id;

    _dailyGoal = prefs.getInt('step_goal_$uid') ?? 8000;
    _totalSteps = prefs.getInt('step_total_$uid') ?? 0;
    _lastSensorSteps = prefs.getInt('step_last_sensor_$uid');

    final storedDate = prefs.getString('step_date_$uid') ?? _currentDateKey;
    final baseline = prefs.getInt('step_baseline_$uid');
    final today = prefs.getInt('step_today_$uid') ?? 0;

    // Keep daily values only for same date.
    if (storedDate == _currentDateKey) {
      _baselineForToday = baseline;
      _stepsToday = today;
    } else {
      _baselineForToday = null;
      _stepsToday = 0;
    }

    final historyRaw = prefs.getString('step_history_$uid');
    if (historyRaw != null && historyRaw.isNotEmpty) {
      final decoded = jsonDecode(historyRaw) as Map<String, dynamic>;
      _history = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    }
  }

  Future<void> _saveStoredStats() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = widget.user.id;

    await prefs.setInt('step_goal_$uid', _dailyGoal);
    await prefs.setInt('step_total_$uid', _totalSteps);
    await prefs.setString('step_date_$uid', _currentDateKey);
    await prefs.setInt('step_today_$uid', _stepsToday);
    if (_baselineForToday != null) {
      await prefs.setInt('step_baseline_$uid', _baselineForToday!);
    }
    if (_lastSensorSteps != null) {
      await prefs.setInt('step_last_sensor_$uid', _lastSensorSteps!);
    }
    await prefs.setString('step_history_$uid', jsonEncode(_history));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (_stepsToday / _dailyGoal).clamp(0.0, 1.0);
    final sortedDays = _history.keys.toList()..sort((a, b) => b.compareTo(a));
    final recentDays = sortedDays.take(7).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Шагомер')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.directions_walk, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Сегодня: $_stepsToday шагов',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text('Цель: $_dailyGoal шагов'),
                  const SizedBox(height: 8),
                  Text('Всего зафиксировано: $_totalSteps'),
                  const SizedBox(height: 8),
                  Text('Статус: $_pedestrianStatus'),
                  if (!_permissionGranted || _statusHint != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _statusHint ?? 'Нет разрешения на отслеживание шагов',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _requestPermissionAndStart,
                      icon: const Icon(Icons.security),
                      label: const Text('Запросить доступ'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Статистика за 7 дней',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (recentDays.isEmpty)
                    const Text('Пока нет данных по шагам')
                  else
                    ...recentDays.map((day) {
                      final value = _history[day] ?? 0;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today_outlined, size: 18),
                        title: Text(_formatDate(day)),
                        trailing: Text(
                          '$value',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _statusRu(String status) {
    switch (status.toLowerCase()) {
      case 'walking':
        return 'Ходьба';
      case 'stopped':
        return 'Покой';
      default:
        return 'Неизвестно';
    }
  }

  static String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _formatDate(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return key;
    return '${parts[2]}.${parts[1]}.${parts[0]}';
  }
}
