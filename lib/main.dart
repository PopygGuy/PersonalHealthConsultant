import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'data/mock_database.dart'; // DatabaseService
import 'screens/admin/admin_home_screen.dart';
import 'screens/student/student_dashboard.dart';
import 'screens/teacher/teacher_home_screen.dart';
import 'services/session_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  double _lerpByWidth({
    required double width,
    required double minWidth,
    required double maxWidth,
    required double minValue,
    required double maxValue,
  }) {
    final t = ((width - minWidth) / (maxWidth - minWidth)).clamp(0.0, 1.0);
    return minValue + (maxValue - minValue) * t;
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final width = MediaQuery.sizeOf(context).width;

        // Плавный рост в диапазоне: телефон -> большой планшет/desktop
        final bodyMediumSize = _lerpByWidth(
          width: width,
          minWidth: 360,
          maxWidth: 1200,
          minValue: 16, // Increased from 15
          maxValue: 19, // Increased from 18
        );

        final bodyLargeSize = _lerpByWidth(
          width: width,
          minWidth: 360,
          maxWidth: 1200,
          minValue: 18, // Increased from 17
          maxValue: 21, // Increased from 20
        );

        final titleSize = _lerpByWidth(
          width: width,
          minWidth: 360,
          maxWidth: 1200,
          minValue: 24, // Increased from 22
          maxValue: 30, // Increased from 28
        );

        return MaterialApp(
          title: 'Health Consultant',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.light, // Force Light Theme per user request
          
          // --- LIGHT THEME ---
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1A73E8), // Academic Blue (Primary)
              brightness: Brightness.light,
              surface: const Color(0xFFF9FAFB), // Clean, airy background
              primary: const Color(0xFF1A73E8), 
              secondary: const Color(0xFF009688), // Health Teal (Secondary)
              tertiary: const Color(0xFF5F6368), // Neutral Grey
            ),
            scaffoldBackgroundColor: const Color(0xFFF9FAFB),
            
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF202124),
              elevation: 0,
              centerTitle: true,
              iconTheme: IconThemeData(color: Color(0xFF5F6368)),
            ),

            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200, width: 1), // Subtle border
              ),
              color: Colors.white,
              margin: const EdgeInsets.symmetric(vertical: 8),
            ),

            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.teal, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              labelStyle: TextStyle(fontSize: bodyMediumSize, color: Colors.grey[600]),
              floatingLabelStyle: TextStyle(fontSize: bodyMediumSize, color: Colors.teal),
            ),

            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              elevation: 5,
              titleTextStyle: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold, color: Colors.black87),
            ),

            textTheme: TextTheme(
              headlineMedium: TextStyle(fontSize: titleSize + 4, fontWeight: FontWeight.bold, color: Colors.black87),
              titleLarge: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold, color: Colors.black87),
              titleMedium: TextStyle(fontSize: bodyLargeSize, fontWeight: FontWeight.w600, color: Colors.black87),
              bodyLarge: TextStyle(fontSize: bodyLargeSize, color: Colors.black87),
              bodyMedium: TextStyle(fontSize: bodyMediumSize, color: Colors.black87),
              labelLarge: TextStyle(fontSize: bodyMediumSize, fontWeight: FontWeight.bold),
            ),
          ),

          // --- DARK THEME ---
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF8AB4F8), // Lighter Blue for Dark Mode
              brightness: Brightness.dark,
              surface: const Color(0xFF1E1E1E),
              onSurface: const Color(0xFFE8EAED),
              primary: const Color(0xFF8AB4F8),
              secondary: const Color(0xFF4DB6AC), // Lighter Teal
              tertiary: const Color(0xFF9AA0A6),
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1E1E),
              foregroundColor: Color(0xFFE8EAED),
              elevation: 0,
              centerTitle: true,
            ),

            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              color: const Color(0xFF2C2C2C),
              margin: const EdgeInsets.symmetric(vertical: 8),
            ),

            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF2C2C2C),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade600),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade600),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.tealAccent, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              labelStyle: TextStyle(fontSize: bodyMediumSize, color: const Color(0xFFB0B0B0)), 
              floatingLabelStyle: TextStyle(fontSize: bodyMediumSize, color: Colors.tealAccent),
              hintStyle: TextStyle(color: Colors.grey.shade500),
            ),

            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: const Color(0xFF2C2C2C),
              elevation: 5,
              titleTextStyle: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold, color: Colors.white),
              contentTextStyle: TextStyle(fontSize: bodyMediumSize, color: const Color(0xFFE0E0E0)),
            ),

            textTheme: TextTheme(
              headlineMedium: TextStyle(fontSize: titleSize + 4, fontWeight: FontWeight.bold, color: Colors.white),
              titleLarge: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold, color: Colors.white),
              titleMedium: TextStyle(fontSize: bodyLargeSize, fontWeight: FontWeight.w600, color: const Color(0xFFEEEEEE)),
              bodyLarge: TextStyle(fontSize: bodyLargeSize, color: const Color(0xFFE0E0E0)),
              bodyMedium: TextStyle(fontSize: bodyMediumSize, color: const Color(0xFFD0D0D0)), 
              bodySmall: TextStyle(fontSize: bodyMediumSize - 1.5, color: const Color(0xFFB0B0B0)),
              labelLarge: TextStyle(fontSize: bodyMediumSize, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            
            iconTheme: const IconThemeData(color: Color(0xFFE0E0E0)),
          ),
          
          home: const _SessionGate(),
        );
      },
    );
  }
}

class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  late final Future<User?> _sessionUserFuture;

  @override
  void initState() {
    super.initState();
    _sessionUserFuture = SessionService().loadSessionUser();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User?>(
      future: _sessionUserFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        switch (user.role) {
          case UserRole.admin:
            return const AdminHomeScreen();
          case UserRole.teacher:
            return TeacherHomeScreen(user: user);
          case UserRole.student:
            return StudentDashboard(user: user);
        }
      },
    );
  }
}
