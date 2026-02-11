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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Column
                  SizedBox(
                    width: 50,
                    child: Column(
                      children: [
                        Text(
                          "${date.day}",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isToday ? Theme.of(context).primaryColor : Colors.grey[800],
                          ),
                        ),
                        Text(
                          _getWeekdayName(date.weekday),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isToday ? Theme.of(context).primaryColor : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Content Card
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isToday ? Theme.of(context).primaryColor.withOpacity(0.5) : Colors.grey.shade200,
                          width: isToday ? 2 : 1,
                        ),
                        boxShadow: [
                          if (isToday)
                            BoxShadow(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(
                          dayPlan.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Row(
                            children: [
                              _buildMiniBadge("🔥 ${dayPlan.calories}"),
                              const SizedBox(width: 8),
                              _buildMiniBadge("🥩 ${dayPlan.protein}"),
                            ],
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getColorForType(dayPlan.type).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            dayPlan.type == DayType.training ? Icons.fitness_center : 
                            dayPlan.type == DayType.refeed ? Icons.restaurant : Icons.spa,
                            color: _getColorForType(dayPlan.type),
                            size: 20,
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

  Widget _buildMiniBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
    );
  }

  Color _getColorForType(DayType type) {
    switch (type) {
      case DayType.training: return Colors.blue;
      case DayType.rest: return Colors.green;
      case DayType.refeed: return Colors.orange;
    }
  }

  String _getWeekdayName(int weekday) {
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return days[weekday - 1];
  }

  DayPlan _getDayTypeForWeekday(DateTime date, DietPlan plan, UserProfile user) {
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
