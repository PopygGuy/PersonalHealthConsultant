import 'package:flutter/material.dart';
import '../services/health_engine.dart';
import '../models/user_profile.dart';
import 'calendar_screen.dart';

import '../widgets/responsive_wrapper.dart';

class ResultScreen extends StatelessWidget {
  final DietPlan plan;
  final UserProfile user;

  const ResultScreen({super.key, required this.plan, required this.user});

  double _uiScale(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 360) return 0.92;
    if (width < 600) return 1.0;
    if (width < 900) return 1.08;
    return 1.15;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final ui = _uiScale(context);
    final compactTabs = width < 390;
    final selectedTabColor =
        isDark ? const Color(0xFF4DA3FF) : theme.colorScheme.primary;
    final unselectedTabColor = isDark
        ? theme.colorScheme.onSurface.withOpacity(0.78)
        : theme.colorScheme.onSurfaceVariant;

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
                    builder: (context) =>
                        CalendarScreen(plan: plan, user: user),
                  ),
                );
              },
            ),
          ],
          bottom: TabBar(
            isScrollable: compactTabs,
            indicatorColor: selectedTabColor,
            labelColor: selectedTabColor,
            unselectedLabelColor: unselectedTabColor,
            labelStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14 * ui,
            ),
            unselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13 * ui,
            ),
            tabs: [
              const Tab(text: 'Тренировка'),
              const Tab(text: 'Отдых'),
              Tab(text: compactTabs ? 'Рефид' : 'Рефид (поддержка)'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDayPage(context, plan.trainingDay, Colors.blue, ui),
            _buildDayPage(context, plan.restDay, Colors.green, ui),
            _buildDayPage(context, plan.refeedDay, Colors.orange, ui),
          ],
        ),
      ),
    );
  }

  Widget _buildDayPage(
    BuildContext context,
    DayPlan day,
    Color accentColor,
    double ui,
  ) {
    // We stick to the theme for structure, but use accentColor for specific highlighting logic
    // However, to be "Unified", we should probably use the Theme's primary color or neutral styles
    // But the user liked the distinction. I will keep the accent colors but ensure shapes match theme.
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0 * ui),
      child: ResponsiveWrapper(
        maxWidth: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24 * ui),
              ),
              color: isDark
                  ? Color.alphaBlend(accentColor.withOpacity(0.20),
                      theme.colorScheme.surfaceContainerHighest)
                  : accentColor.withOpacity(0.10),
              child: Padding(
                padding: EdgeInsets.all(24.0 * ui),
                child: Column(
                  children: [
                    Text(
                      day.title,
                      style: TextStyle(
                        fontSize: 24 * ui,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8 * ui),
                    Text(
                      "${day.calories}",
                      style: TextStyle(
                        fontSize: 48 * ui,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      "ккал",
                      style: TextStyle(
                        fontSize: 16 * ui,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 16 * ui),
                    Text(
                      day.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14 * ui,
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24 * ui),

            // Macros Row
            Text(
              "Баланс БЖУ",
              style: TextStyle(
                fontSize: 18 * ui,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 16 * ui),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 360;
                if (isCompact) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildMacroCard(
                              context,
                              "Белки",
                              "${day.protein}г",
                              Colors.blue,
                              ui,
                            ),
                          ),
                          SizedBox(width: 10 * ui),
                          Expanded(
                            child: _buildMacroCard(
                              context,
                              "Жиры",
                              "${day.fat}г",
                              Colors.orange,
                              ui,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10 * ui),
                      _buildMacroCard(
                        context,
                        "Углеводы",
                        "${day.carbs}г",
                        Colors.green,
                        ui,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: _buildMacroCard(
                        context,
                        "Белки",
                        "${day.protein}г",
                        Colors.blue,
                        ui,
                      ),
                    ),
                    SizedBox(width: 12 * ui),
                    Expanded(
                      child: _buildMacroCard(
                        context,
                        "Жиры",
                        "${day.fat}г",
                        Colors.orange,
                        ui,
                      ),
                    ),
                    SizedBox(width: 12 * ui),
                    Expanded(
                      child: _buildMacroCard(
                        context,
                        "Углеводы",
                        "${day.carbs}г",
                        Colors.green,
                        ui,
                      ),
                    ),
                  ],
                );
              },
            ),

            SizedBox(height: 32 * ui),
            _buildAdviceSection(context, day, accentColor, ui),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroCard(
    BuildContext context,
    String label,
    String value,
    Color color,
    double ui,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16 * ui, horizontal: 8 * ui),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16 * ui),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.65)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20 * ui,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4 * ui),
          Text(
            label,
            style: TextStyle(
              fontSize: 12 * ui,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdviceSection(
    BuildContext context,
    DayPlan day,
    Color color,
    double ui,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tips_and_updates_outlined, color: color, size: 22 * ui),
            SizedBox(width: 8 * ui),
            Text(
              "Советы дня",
              style: TextStyle(
                fontSize: 18 * ui,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        SizedBox(height: 16 * ui),
        ...day.tips
            .map((tip) => Container(
                  margin: EdgeInsets.only(bottom: 12 * ui),
                  padding: EdgeInsets.all(16 * ui),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16 * ui),
                    border: Border.all(
                        color:
                            theme.colorScheme.outlineVariant.withOpacity(0.65)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 2 * ui),
                        child: Icon(
                          Icons.check_circle,
                          color: color.withOpacity(0.8),
                          size: 20 * ui,
                        ),
                      ),
                      SizedBox(width: 12 * ui),
                      Expanded(
                        child: Text(
                          tip,
                          style: TextStyle(
                            fontSize: 14 * ui,
                            height: 1.4,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ],
    );
  }
}
