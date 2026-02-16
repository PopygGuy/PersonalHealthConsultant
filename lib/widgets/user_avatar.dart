import 'package:flutter/material.dart';

import '../models/user_role.dart';

class UserAvatar extends StatelessWidget {
  final String displayName;
  final String seed;
  final UserRole? role;
  final double radius;

  const UserAvatar({
    super.key,
    required this.displayName,
    required this.seed,
    this.role,
    this.radius = 20,
  });

  int _stableHash(String value) {
    var hash = 0;
    for (final code in value.codeUnits) {
      hash = ((hash * 31) + code) & 0x7fffffff;
    }
    return hash;
  }

  IconData _roleIcon(UserRole? role) {
    switch (role) {
      case UserRole.teacher:
        return Icons.school;
      case UserRole.student:
        return Icons.person;
      case UserRole.admin:
        return Icons.admin_panel_settings;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedSeed = seed.trim().isEmpty ? displayName : seed;
    final hash = _stableHash(normalizedSeed);
    final hue = (hash % 360).toDouble();

    final bg = HSLColor.fromAHSL(1, hue, 0.55, 0.80).toColor();
    final fg = HSLColor.fromAHSL(1, hue, 0.75, 0.20).toColor();
    final badgeBg = HSLColor.fromAHSL(1, (hue + 30) % 360, 0.60, 0.45).toColor();

    final trimmed = displayName.trim();
    final initial = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: bg,
            foregroundColor: fg,
            child: Text(
              initial,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.85,
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: radius * 0.70,
              height: radius * 0.70,
              decoration: BoxDecoration(
                color: badgeBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 1.5,
                ),
              ),
              child: Icon(
                _roleIcon(role),
                color: Colors.white,
                size: radius * 0.40,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
