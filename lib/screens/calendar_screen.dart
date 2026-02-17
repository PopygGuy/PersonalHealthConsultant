import 'package:flutter/material.dart';
import '../services/health_engine.dart';
import '../models/user_profile.dart';

import '../widgets/responsive_wrapper.dart';

class CalendarScreen extends StatelessWidget {
  final DietPlan plan;
  final UserProfile user;

  const CalendarScreen({super.key, required this.plan, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final ui = width < 360 ? 0.92 : (width < 600 ? 1.0 : 1.12);
    final dateColWidth = width < 360 ? 44.0 : (width < 600 ? 50.0 : 60.0);
    return Scaffold(
      appBar: AppBar(title: const Text('Календарь питания (14 дней)')),
      body: ResponsiveWrapper(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: 14,
          itemBuilder: (context, index) {
            final date = DateTime.now().add(Duration(days: index));
            final dayPlan = _getDayTypeForWeekday(date, plan, user);
            final isToday = index == 0;

            return Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 16 * ui, vertical: 8 * ui),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Column
                  SizedBox(
                    width: dateColWidth,
                    child: Column(
                      children: [
                        Text(
                          "${date.day}",
                          style: TextStyle(
                            fontSize: 20 * ui,
                            fontWeight: FontWeight.bold,
                            color: isToday
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          _getWeekdayName(date.weekday),
                          style: TextStyle(
                            fontSize: 12 * ui,
                            fontWeight: FontWeight.bold,
                            color: isToday
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12 * ui),

                  // Content Card
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? theme.colorScheme.surfaceContainer
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isToday
                              ? theme.colorScheme.primary.withOpacity(0.55)
                              : theme.colorScheme.outlineVariant
                                  .withOpacity(0.75),
                          width: isToday ? 2 : 1,
                        ),
                        boxShadow: [
                          if (isToday)
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(
                                isDark ? 0.22 : 0.10,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16 * ui, vertical: 8 * ui),
                        title: Text(
                          dayPlan.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                            fontSize: 18 * ui,
                          ),
                        ),
                        isThreeLine: dayPlan.type == DayType.refeed,
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (dayPlan.type == DayType.refeed) ...[
                                _buildMiniBadge(context, "🔄 Поддержка", ui),
                                const SizedBox(height: 6),
                              ],
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _buildMiniBadge(
                                      context, "🔥 ${dayPlan.calories}", ui),
                                  _buildMiniBadge(
                                      context, "🥩 ${dayPlan.protein}", ui),
                                  _buildMiniBadge(
                                      context, "🥑 ${dayPlan.fat}", ui),
                                  _buildMiniBadge(
                                      context, "🍚 ${dayPlan.carbs}", ui),
                                ],
                              ),
                            ],
                          ),
                        ),
                        trailing: Container(
                          padding: EdgeInsets.all(8 * ui),
                          decoration: BoxDecoration(
                            color: _getColorForType(dayPlan.type).withOpacity(
                              isDark ? 0.18 : 0.12,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            dayPlan.type == DayType.training
                                ? Icons.fitness_center
                                : dayPlan.type == DayType.refeed
                                    ? Icons.restaurant
                                    : Icons.spa,
                            color: _getColorForType(dayPlan.type),
                            size: 20 * ui,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMiniBadge(BuildContext context, String text, [double ui = 1.0]) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * ui, vertical: 2 * ui),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.7)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12 * ui,
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getColorForType(DayType type) {
    switch (type) {
      case DayType.training:
        return Colors.blue;
      case DayType.rest:
        return Colors.green;
      case DayType.refeed:
        return Colors.orange;
    }
  }

  String _getWeekdayName(int weekday) {
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return days[weekday - 1];
  }

  DayPlan _getDayTypeForWeekday(
      DateTime date, DietPlan plan, UserProfile user) {
    // Logic:
    // If Active/Gain -> More Training days (e.g. Mon, Wed, Fri)
    // If Sedentary/Lose -> Less Training days (e.g. Mon, Thu)
    // Refeed usually on Sunday or heavy training day

    int day = date.weekday; // 1 = Mon, 7 = Sun

    // Simple Pattern Logic
    if (user.goal == HealthGoal.gainMuscle) {
      // Mon, Wed, Fri, Sat = Training
      if ([1, 3, 5, 6].contains(day)) return plan.trainingDay;
      if (day == 7) return plan.refeedDay; // Sunday Refeed
      return plan.restDay;
    } else if (user.activityLevel == ActivityLevel.sedentary) {
      // Mon, Thu = Training
      if ([1, 4].contains(day)) return plan.trainingDay;
      if (day == 6) return plan.refeedDay; // Saturday Refeed
      return plan.restDay;
    } else {
      // Standard: Mon, Wed, Fri
      if ([1, 3, 5].contains(day)) return plan.trainingDay;
      if (day == 6) return plan.refeedDay;
      return plan.restDay;
    }
  }
}
