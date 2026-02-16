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
    
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180.0,
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
                  child: Icon(
                    Icons.monitor_heart, 
                    size: 80, 
                    color: Colors.white.withOpacity(0.3)
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_graph, color: theme.colorScheme.onSecondaryContainer),
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
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _featureChip(theme, 'Калории'),
                        _featureChip(theme, 'БЖУ'),
                        _featureChip(theme, 'План на 14 дней'),
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
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionTitle("Пол"),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildGenderCard(Gender.male, "Мужской", Icons.male)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildGenderCard(Gender.female, "Женский", Icons.female)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildSectionTitle("Параметры тела"),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInput(
                            controller: _ageController,
                            label: "Возраст",
                            suffix: "лет",
                            icon: Icons.cake,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Введите возраст';
                              int? val = int.tryParse(v);
                              if (val == null || val < 17 || val > 50) return '17-50 лет';
                              return null;
                            }
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInput(
                            controller: _weightController,
                            label: "Вес",
                            suffix: "кг",
                            icon: Icons.scale,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Введите вес';
                              double? val = double.tryParse(v);
                              if (val == null || val < 20 || val > 300) return '20-300 кг';
                              return null;
                            }
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInput(
                      controller: _heightController,
                      label: "Рост",
                      suffix: "см",
                      icon: Icons.height,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Введите рост';
                        double? val = double.tryParse(v);
                        if (val == null || val < 90 || val > 250) return '90-250 см';
                        return null;
                      }
                    ),

                    const SizedBox(height: 24),
                    _buildSectionTitle("Активность"),
                    const SizedBox(height: 12),
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
                            overflow: TextOverflow.visible, // Allow wrap
                            maxLines: 2,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _activityLevel = v!),
                    ),

                    const SizedBox(height: 24),
                    _buildSectionTitle("Цель"),
                    const SizedBox(height: 12),
                    SegmentedButton<HealthGoal>(
                      segments: const [
                        ButtonSegment(
                          value: HealthGoal.loseWeight,
                          label: FittedBox(child: Text("Похудеть", maxLines: 1)),
                          icon: Icon(Icons.arrow_downward),
                        ),
                        ButtonSegment(
                          value: HealthGoal.maintain,
                          label: FittedBox(child: Text("Норма", maxLines: 1)),
                          icon: Icon(Icons.balance),
                        ),
                        ButtonSegment(
                          value: HealthGoal.gainMuscle,
                          label: FittedBox(child: Text("Набрать", maxLines: 1)),
                          icon: Icon(Icons.fitness_center),
                        ),
                      ],
                      selected: {_goal},
                      onSelectionChanged: (Set<HealthGoal> newSelection) {
                        setState(() {
                          _goal = newSelection.first;
                        });
                      },
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.resolveWith<Color>(
                          (Set<MaterialState> states) {
                            if (states.contains(MaterialState.selected)) {
                              return theme.primaryColor;
                            }
                            // Slightly lighter background for unselected segments for visibility
                            return theme.brightness == Brightness.dark 
                              ? theme.cardColor 
                              : Colors.transparent;
                          },
                        ),
                        foregroundColor: MaterialStateProperty.resolveWith<Color>(
                          (Set<MaterialState> states) {
                            if (states.contains(MaterialState.selected)) {
                              return theme.colorScheme.onPrimary;
                            }
                            return theme.colorScheme.onSurface;
                          },
                        ),
                        side: MaterialStateProperty.all(
                          BorderSide(color: theme.dividerColor.withOpacity(0.2)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _calculate,
                      child: const Text("Рассчитать план"),
                    ),
                    const SizedBox(height: 20),
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
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        suffixStyle: TextStyle(
          fontSize: 16, 
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurfaceVariant
        ),
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      validator: validator,
    );
  }

  Widget _buildGenderCard(Gender gender, String label, IconData icon) {
    final isSelected = _gender == gender;
    final theme = Theme.of(context);
    final color = isSelected ? theme.primaryColor : theme.colorScheme.onSurfaceVariant;
    
    return InkWell(
      onTap: () => setState(() => _gender = gender),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor.withOpacity(0.15) : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.primaryColor : theme.dividerColor.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureChip(ThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.8),
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

  String _getActivityLabel(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary: return "Сидячий (без тренировок)";
      case ActivityLevel.light: return "Легкая (1-3 тренировки в неделю)";
      case ActivityLevel.moderate: return "Средняя (3-5 тренировок в неделю)";
      case ActivityLevel.active: return "Высокая (6-7 тренировок в неделю)";
      case ActivityLevel.veryActive: return "Экстремальная (2 тренировки в день / тяжелый труд)";
    }
  }
}
