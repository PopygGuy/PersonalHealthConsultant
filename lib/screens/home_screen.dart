import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/health_engine.dart';
import 'result_screen.dart';

import '../widgets/responsive_wrapper.dart';

class HomeScreen extends StatefulWidget {
  final UserProfile? initialUser; // Optional: if editing existing profile

  const HomeScreen({super.key, this.initialUser});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  // State
  Gender _gender = Gender.male;
  ActivityLevel _activityLevel = ActivityLevel.sedentary;
  HealthGoal _goal = HealthGoal.maintain;

  double _uiScale(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 360) return 0.92;
    if (width < 600) return 1.0;
    if (width < 900) return 1.08;
    return 1.16;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialUser != null) {
      // Pre-fill if needed
    }
  }

  void _calculate() {
    if (_formKey.currentState!.validate()) {
      final user = UserProfile(
        age: int.parse(_ageController.text),
        weight: double.parse(_weightController.text),
        height: double.parse(_heightController.text),
        gender: _gender,
        activityLevel: _activityLevel,
        goal: _goal,
      );

      final plan = HealthEngine.generatePlan(user);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(plan: plan, user: user),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ui = _uiScale(context);
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 390;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180.0 * ui,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                "Калькулятор здоровья",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.primaryColor,
                      theme.colorScheme.secondary,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(Icons.monitor_heart,
                      size: 80, color: Colors.white.withOpacity(0.3)),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16 * ui, 16 * ui, 16 * ui, 0),
              child: Container(
                padding: EdgeInsets.all(16 * ui),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_graph,
                            color: theme.colorScheme.onSecondaryContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Персональный модуль расчета плана',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8 * ui),
                    Wrap(
                      spacing: 8 * ui,
                      runSpacing: 8 * ui,
                      children: [
                        _featureChip(theme, 'Калории', ui),
                        _featureChip(theme, 'БЖУ', ui),
                        _featureChip(theme, 'План на 14 дней', ui),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ResponsiveWrapper(
              maxWidth: 600, // Limit form width
              child: Padding(
                padding: EdgeInsets.all(20.0 * ui),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionTitle("Пол"),
                      SizedBox(height: 12 * ui),
                      Row(
                        children: [
                          Expanded(
                              child: _buildGenderCard(
                                  Gender.male, "Мужской", Icons.male)),
                          SizedBox(width: 12 * ui),
                          Expanded(
                              child: _buildGenderCard(
                                  Gender.female, "Женский", Icons.female)),
                        ],
                      ),
                      SizedBox(height: 24 * ui),
                      _buildSectionTitle("Параметры тела"),
                      SizedBox(height: 12 * ui),
                      if (isCompact)
                        Column(
                          children: [
                            _buildInput(
                                controller: _ageController,
                                label: "Возраст",
                                suffix: "лет",
                                icon: Icons.cake,
                                validator: (v) {
                                  if (v == null || v.isEmpty)
                                    return 'Введите возраст';
                                  int? val = int.tryParse(v);
                                  if (val == null || val < 17 || val > 50)
                                    return '17-50 лет';
                                  return null;
                                }),
                            SizedBox(height: 12 * ui),
                            _buildInput(
                                controller: _weightController,
                                label: "Вес",
                                suffix: "кг",
                                icon: Icons.scale,
                                validator: (v) {
                                  if (v == null || v.isEmpty)
                                    return 'Введите вес';
                                  double? val = double.tryParse(v);
                                  if (val == null || val < 20 || val > 300)
                                    return '20-300 кг';
                                  return null;
                                }),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: _buildInput(
                                  controller: _ageController,
                                  label: "Возраст",
                                  suffix: "лет",
                                  icon: Icons.cake,
                                  validator: (v) {
                                    if (v == null || v.isEmpty)
                                      return 'Введите возраст';
                                    int? val = int.tryParse(v);
                                    if (val == null || val < 17 || val > 50)
                                      return '17-50 лет';
                                    return null;
                                  }),
                            ),
                            SizedBox(width: 12 * ui),
                            Expanded(
                              child: _buildInput(
                                  controller: _weightController,
                                  label: "Вес",
                                  suffix: "кг",
                                  icon: Icons.scale,
                                  validator: (v) {
                                    if (v == null || v.isEmpty)
                                      return 'Введите вес';
                                    double? val = double.tryParse(v);
                                    if (val == null || val < 20 || val > 300)
                                      return '20-300 кг';
                                    return null;
                                  }),
                            ),
                          ],
                        ),
                      SizedBox(height: 12 * ui),
                      _buildInput(
                          controller: _heightController,
                          label: "Рост",
                          suffix: "см",
                          icon: Icons.height,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Введите рост';
                            double? val = double.tryParse(v);
                            if (val == null || val < 90 || val > 250)
                              return '90-250 см';
                            return null;
                          }),
                      SizedBox(height: 24 * ui),
                      _buildSectionTitle("Активность"),
                      SizedBox(height: 12 * ui),
                      DropdownButtonFormField<ActivityLevel>(
                        value: _activityLevel,
                        isExpanded: true, // Prevent overflow
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.directions_run),
                          labelText: 'Уровень активности',
                        ),
                        items: ActivityLevel.values.map((level) {
                          return DropdownMenuItem(
                            value: level,
                            child: Text(
                              _getActivityLabel(level),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              style: TextStyle(fontSize: 14 * ui),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _activityLevel = v!),
                        selectedItemBuilder: (context) {
                          return ActivityLevel.values.map((level) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _getActivityLabel(level),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14 * ui),
                              ),
                            );
                          }).toList();
                        },
                      ),
                      SizedBox(height: 24 * ui),
                      _buildSectionTitle("Цель"),
                      SizedBox(height: 12 * ui),
                      SegmentedButton<HealthGoal>(
                        showSelectedIcon: !isCompact,
                        segments: [
                          ButtonSegment(
                            value: HealthGoal.loseWeight,
                            label: FittedBox(
                                child: Text("Похудеть",
                                    maxLines: 1,
                                    style: TextStyle(fontSize: 14 * ui))),
                            icon: Icon(Icons.arrow_downward, size: 18 * ui),
                          ),
                          ButtonSegment(
                            value: HealthGoal.maintain,
                            label: FittedBox(
                                child: Text("Норма",
                                    maxLines: 1,
                                    style: TextStyle(fontSize: 14 * ui))),
                            icon: Icon(Icons.balance, size: 18 * ui),
                          ),
                          ButtonSegment(
                            value: HealthGoal.gainMuscle,
                            label: FittedBox(
                                child: Text("Набрать",
                                    maxLines: 1,
                                    style: TextStyle(fontSize: 14 * ui))),
                            icon: Icon(Icons.fitness_center, size: 18 * ui),
                          ),
                        ],
                        selected: {_goal},
                        expandedInsets: EdgeInsets.zero,
                        onSelectionChanged: (Set<HealthGoal> newSelection) {
                          setState(() {
                            _goal = newSelection.first;
                          });
                        },
                        style: ButtonStyle(
                          backgroundColor:
                              MaterialStateProperty.resolveWith<Color>(
                            (Set<MaterialState> states) {
                              if (states.contains(MaterialState.selected)) {
                                return theme.colorScheme.primaryContainer;
                              }
                              return theme.colorScheme.surfaceContainerHigh;
                            },
                          ),
                          foregroundColor:
                              MaterialStateProperty.resolveWith<Color>(
                            (Set<MaterialState> states) {
                              if (states.contains(MaterialState.selected)) {
                                return theme.colorScheme.onPrimaryContainer;
                              }
                              return theme.colorScheme.onSurfaceVariant;
                            },
                          ),
                          side: MaterialStateProperty.all(
                            BorderSide(
                              color: theme.colorScheme.outlineVariant
                                  .withOpacity(0.7),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 32 * ui),
                      ElevatedButton(
                        onPressed: _calculate,
                        child: const Text("Рассчитать план"),
                      ),
                      SizedBox(height: 20 * ui),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final ui = _uiScale(context);
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12 * ui,
          vertical: 14 * ui,
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(
          theme.brightness == Brightness.dark ? 0.30 : 0.55,
        ),
        suffixText: suffix,
        suffixStyle: TextStyle(
            fontSize: 16 * ui,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface),
        prefixIcon: Icon(icon, size: 20 * ui, color: theme.colorScheme.primary),
      ),
      validator: validator,
    );
  }

  Widget _buildGenderCard(Gender gender, String label, IconData icon) {
    final isSelected = _gender == gender;
    final theme = Theme.of(context);
    final ui = _uiScale(context);
    final color =
        isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface;

    return InkWell(
      onTap: () => setState(() => _gender = gender),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16 * ui),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withOpacity(0.42)
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withOpacity(0.75),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32 * ui, color: color),
            SizedBox(height: 4 * ui),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 16 * ui,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureChip(ThemeData theme, String label, double ui) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * ui, vertical: 6 * ui),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(
          theme.brightness == Brightness.dark ? 0.38 : 0.88,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.55),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: (theme.textTheme.bodySmall?.fontSize ?? 12) * ui,
        ),
      ),
    );
  }

  String _getActivityLabel(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return "Сидячий (без тренировок)";
      case ActivityLevel.light:
        return "Легкая (1-3 тренировки в неделю)";
      case ActivityLevel.moderate:
        return "Средняя (3-5 тренировок в неделю)";
      case ActivityLevel.active:
        return "Высокая (6-7 тренировок в неделю)";
      case ActivityLevel.veryActive:
        return "Экстремальная (2 тренировки в день / тяжелый труд)";
    }
  }
}
