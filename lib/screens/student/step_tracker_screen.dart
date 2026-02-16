import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/step_tracker_service.dart';
import '../../models/user.dart';

class StepTrackerScreen extends StatefulWidget {
  final User user;
  final StepTrackerService? stepTrackerService;
  final StepTrackerStorage? stepTrackerStorage;

  const StepTrackerScreen({
    super.key,
    required this.user,
    this.stepTrackerService,
    this.stepTrackerStorage,
  });

  @override
  State<StepTrackerScreen> createState() => _StepTrackerScreenState();
}

class _StepTrackerScreenState extends State<StepTrackerScreen> {
  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<PedestrianStatus>? _statusSubscription;
  late final StepTrackerService _stepService;
  late final StepTrackerStorage _stepStorage;

  bool _permissionGranted = false;
  bool _stepSensorUnavailable = false;
  String _pedestrianStatus = 'Неизвестно';
  String? _statusHint;

  late StepTrackerStats _stats;

  @override
  void initState() {
    super.initState();
    _stepService = widget.stepTrackerService ?? const StepTrackerService();
    _stepStorage = widget.stepTrackerStorage ?? const SharedPrefsStepTrackerStorage();
    _stats = StepTrackerStats.initial(currentDateKey: _stepService.dateKey(DateTime.now()));
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
      _stepSensorUnavailable = false;
      _statusHint = null;
    });

    _stepSubscription = Pedometer.stepCountStream.listen(
      _onStepCount,
      onError: (error) {
        if (!mounted) return;
        _handleStepError(error);
      },
      cancelOnError: false,
    );

    _statusSubscription = Pedometer.pedestrianStatusStream.listen(
      (event) {
        if (!mounted) return;
        setState(() => _pedestrianStatus = _stepService.statusRu(event.status));
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _pedestrianStatus = _stepSensorUnavailable ? 'Недоступно' : 'Неизвестно';
        });
      },
      cancelOnError: false,
    );
  }

  void _handleStepError(Object error) {
    final message = error.toString();
    final isUnavailable = _isStepSensorUnavailable(message);
    if (isUnavailable) {
      _stepSubscription?.cancel();
      _statusSubscription?.cancel();
      setState(() {
        _stepSensorUnavailable = true;
        _pedestrianStatus = 'Недоступно';
        _statusHint =
            'На этом устройстве недоступен датчик шагов. В эмуляторе это ожидаемо — проверьте на реальном телефоне.';
      });
      return;
    }
    setState(() {
      _statusHint = 'Ошибка шагомера: $error';
    });
  }

  bool _isStepSensorUnavailable(String rawError) {
    final lower = rawError.toLowerCase();
    return lower.contains('stepcount not available') ||
        lower.contains('stepcount is not available') ||
        lower.contains('no sensor') ||
        lower.contains('not available on this device');
  }

  Future<void> _onStepCount(StepCount event) async {
    _stats = _stepService.applyStepEvent(
      current: _stats,
      sensorSteps: event.steps,
      now: DateTime.now(),
    );

    if (mounted) setState(() {});
    await _saveStoredStats();
  }

  Future<void> _loadStoredStats() async {
    _stats = await _stepStorage.load(
      userId: widget.user.id,
      currentDateKey: _stepService.dateKey(DateTime.now()),
    );
    if (mounted) setState(() {});
  }

  Future<void> _saveStoredStats() async {
    await _stepStorage.save(userId: widget.user.id, stats: _stats);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (_stats.stepsToday / _stats.dailyGoal).clamp(0.0, 1.0);
    final sortedDays = _stats.history.keys.toList()..sort((a, b) => b.compareTo(a));
    final recentDays = sortedDays.take(7).toList();
    final todayKm = _stepService.kmFromSteps(_stats.stepsToday, strideMeters: _stats.strideMeters);
    final totalKm = _stepService.kmFromSteps(_stats.totalSteps, strideMeters: _stats.strideMeters);
    final goalKm = _stepService.kmFromSteps(_stats.dailyGoal, strideMeters: _stats.strideMeters);
    final todayPoints = _stepService.healthPointsFromSteps(_stats.stepsToday);
    final totalPoints = _stepService.healthPointsFromSteps(_stats.totalSteps);
    final strideCm = (_stats.strideMeters * 100).round();
    final strideSource = _stats.isCustomStride
        ? 'ручная настройка'
        : (_stats.profileHeightCm != null
            ? 'авто по росту ${_stats.profileHeightCm} см'
            : 'значение по умолчанию');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Шагомер'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.tertiaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.directions_walk, color: theme.colorScheme.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Индивидуальный модуль активности',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _moduleChip(context, 'Шаги'),
                    _moduleChip(context, 'Дистанция (км)'),
                    _moduleChip(context, 'Баллы активности'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                        'Сегодня: ${_stats.stepsToday} шагов',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Дистанция сегодня: ${_stepService.formatKm(todayKm)} км',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _openStrideSettings,
                    icon: const Icon(Icons.straighten),
                    label: Text('Длина шага: $strideCm см'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Источник: $strideSource',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text('Цель: ${_stats.dailyGoal} шагов (${_stepService.formatKm(goalKm)} км)'),
                  const SizedBox(height: 8),
                  Text(
                    'Всего зафиксировано: ${_stats.totalSteps} шагов (${_stepService.formatKm(totalKm)} км)',
                  ),
                  const SizedBox(height: 8),
                  Text('Баллы активности: сегодня $todayPoints / всего $totalPoints'),
                  const SizedBox(height: 8),
                  Text('Статус: $_pedestrianStatus'),
                  if (_statusHint != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _statusHint!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    if (!_permissionGranted) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _requestPermissionAndStart,
                        icon: const Icon(Icons.security),
                        label: const Text('Запросить доступ'),
                      ),
                    ],
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
                    const Text('Пока нет данных по шагам и дистанции')
                  else
                    ...recentDays.map((day) {
                      final steps = _stats.history[day] ?? 0;
                      final km = _stepService.kmFromSteps(steps, strideMeters: _stats.strideMeters);
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today_outlined, size: 18),
                        title: Text(_stepService.formatDate(day)),
                        subtitle: Text('${_stepService.formatKm(km)} км'),
                        trailing: Text(
                          '$steps',
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

  Widget _moduleChip(BuildContext context, String label) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.75),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _openStrideSettings() async {
    final controller = TextEditingController(text: (_stats.strideMeters * 100).round().toString());
    final result = await showDialog<_StrideDialogResult>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Длина шага'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Введите длину шага в сантиметрах (40-120):'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Например: 78',
                  suffixText: 'см',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Используется для расчета дистанции в км.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, _StrideDialogResult.autoMode),
              child: const Text('Авто по росту'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                Navigator.pop(ctx, _StrideDialogResult.custom(parsed));
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );

    if (result == null) return;
    if (result.useAuto) {
      final autoStride = StepTrackerService.estimateStrideMetersFromHeightCm(_stats.profileHeightCm);
      setState(() {
        _stats = _stats.copyWith(
          strideMeters: autoStride,
          isCustomStride: false,
        );
      });
      await _saveStoredStats();
      return;
    }

    final customCm = result.customCm;
    if (customCm == null || customCm < 40 || customCm > 120) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Длина шага должна быть от 40 до 120 см')),
      );
      return;
    }

    final strideMeters = StepTrackerService.sanitizeStrideMeters(customCm / 100.0);
    setState(() {
      _stats = _stats.copyWith(
        strideMeters: strideMeters,
        isCustomStride: true,
      );
    });
    await _saveStoredStats();
  }

}

class _StrideDialogResult {
  final int? customCm;
  final bool useAuto;

  const _StrideDialogResult._({
    required this.customCm,
    required this.useAuto,
  });

  factory _StrideDialogResult.custom(int? cm) {
    return _StrideDialogResult._(customCm: cm, useAuto: false);
  }

  static const autoMode = _StrideDialogResult._(customCm: null, useAuto: true);
}
