import 'package:flutter/material.dart';

import '../services/app_theme_service.dart';

class AppThemeSelectorCard extends StatelessWidget {
  const AppThemeSelectorCard({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AppThemeService();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: service.themeModeNotifier,
          builder: (context, mode, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Тема приложения',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Изменение применяется для всех ролей и экранов',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Системная'),
                      selected: mode == ThemeMode.system,
                      onSelected: (_) => service.setThemeMode(ThemeMode.system),
                    ),
                    ChoiceChip(
                      label: const Text('Светлая'),
                      selected: mode == ThemeMode.light,
                      onSelected: (_) => service.setThemeMode(ThemeMode.light),
                    ),
                    ChoiceChip(
                      label: const Text('Тёмная'),
                      selected: mode == ThemeMode.dark,
                      onSelected: (_) => service.setThemeMode(ThemeMode.dark),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
