import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../admin/admin_home_screen.dart';
import '../teacher/teacher_home_screen.dart';
import '../student/student_dashboard.dart';
import '../../models/user_role.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    final user = await ApiService().login(
      _loginController.text, 
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (user != null) {
      if (!mounted) return;
      Widget nextScreen = const Scaffold(body: Center(child: Text('Ошибка роли'))); // Default
      
      switch (user.role) {
        case UserRole.admin:
          nextScreen = const AdminHomeScreen();
          break;
        case UserRole.teacher:
          nextScreen = TeacherHomeScreen(user: user);
          break;
        case UserRole.student:
          nextScreen = StudentDashboard(user: user);
          break;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => nextScreen),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Неверный логин или пароль, либо ошибка соединения'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // Remove hardcoded background color to allow theme adaptation
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo / Icon
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark
                              ? theme.colorScheme.primaryContainer.withOpacity(0.28)
                              : theme.colorScheme.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? theme.colorScheme.primary.withOpacity(0.55)
                                : theme.colorScheme.primary.withOpacity(0.20),
                          ),
                          boxShadow: isDark
                              ? [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withOpacity(0.20),
                                    blurRadius: 18,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          Icons.fact_check_outlined,
                          size: 64,
                          color: isDark
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Вход в систему',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Платформа оценки нормативов студентов\nи развития физической формы',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? theme.colorScheme.onSurface.withOpacity(0.90)
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),

                      Card(
                        elevation: 4, 
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _loginController,
                                  decoration: const InputDecoration(
                                    labelText: 'Логин',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: (value) =>
                                      value?.isEmpty ?? true ? 'Введите логин' : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Пароль',
                                    prefixIcon: Icon(Icons.lock_outline),
                                  ),
                                  validator: (value) =>
                                      value?.isEmpty ?? true ? 'Введите пароль' : null,
                                ),
                                const SizedBox(height: 24),
                                _isLoading
                                    ? const CircularProgressIndicator()
                                    : ElevatedButton(
                                        onPressed: _login,
                                        child: const Text('Войти в систему'),
                                      ),
                              ],
                            ),
                          ),
                        ),
                      ),
              
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

}
