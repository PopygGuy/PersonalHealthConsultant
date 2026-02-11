import 'package:flutter/material.dart';
import '../services/health_engine.dart';
import '../models/user_profile.dart';
import 'calendar_screen.dart';

import '../widgets/responsive_wrapper.dart';

class ResultScreen extends StatelessWidget {
  final DietPlan plan;
  final UserProfile user;

  const ResultScreen({super.key, required this.plan, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ваш план питания'),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_month),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CalendarScreen(plan: plan, user: user),
                  ),
                );
              },
            ),
          ],
          bottom: TabBar(
            indicatorColor: theme.primaryColor,
            labelColor: theme.primaryColor,
            unselectedLabelColor: Colors.grey[700], // Darker grey for better visibility
            labelStyle: const TextStyle(fontWeight: FontWeight.bold), // Bold for selected
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600), // Semi-bold for unselected
            tabs: const [
              Tab(text: 'Тренировка'),
              Tab(text: 'Отдых'),
              Tab(text: 'Рефид'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDayPage(context, plan.trainingDay, Colors.blue),
            _buildDayPage(context, plan.restDay, Colors.green),
            _buildDayPage(context, plan.refeedDay, Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildDayPage(BuildContext context, DayPlan day, Color accentColor) {
    // We stick to the theme for structure, but use accentColor for specific highlighting logic
    // However, to be "Unified", we should probably use the Theme's primary color or neutral styles
    // But the user liked the distinction. I will keep the accent colors but ensure shapes match theme.
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: ResponsiveWrapper(
        maxWidth: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              color: accentColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      day.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: accentColor, 
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${day.calories}",
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.grey[800],
                        height: 1.0,
                      ),
                    ),
                    Text(
                      "ккал",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      day.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[700], height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Macros Row
            const Text("Баланс БЖУ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildMacroCard(context, "Белки", "${day.protein}г", Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _buildMacroCard(context, "Жиры", "${day.fat}г", Colors.orange)),
                const SizedBox(width: 12),
                Expanded(child: _buildMacroCard(context, "Углеводы", "${day.carbs}г", Colors.green)),
              ],
            ),
            
            const SizedBox(height: 32),
            _buildAdviceSection(context, day, accentColor),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroCard(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdviceSection(BuildContext context, DayPlan day, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tips_and_updates_outlined, color: color),
            const SizedBox(width: 8),
            const Text("Советы дня", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        ...day.tips.map((tip) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.check_circle, color: color.withOpacity(0.8), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(tip, style: const TextStyle(fontSize: 14, height: 1.4))),
            ],
          ),
        )).toList(),
      ],
    );
  }
}
