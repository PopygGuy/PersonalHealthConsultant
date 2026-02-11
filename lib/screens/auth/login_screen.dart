import 'package:flutter/material.dart';
import '../../data/mock_database.dart';
import '../admin/admin_home_screen.dart';
import '../teacher/teacher_home_screen.dart';
import '../student/student_dashboard.dart';

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
  
  // Default selection
  UserRole _selectedRole = UserRole.student;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1)); // Imitation

    final user = DatabaseService().login(
      _loginController.text, 
      _passwordController.text,
      _selectedRole
    );

    setState(() => _isLoading = false);

    if (user != null) {
      if (!mounted) return;
      Widget nextScreen;
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
          content: Text('Неверный логин, пароль или роль'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.health_and_safety,
                          size: 64,
                          color: Theme.of(context).primaryColor,
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
                        'Ваш персональный консультант по здоровью',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 32),

                      // Adaptive Role Selector
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth > 600) {
                            return SegmentedButton<UserRole>(
                              segments: const [
                                ButtonSegment(value: UserRole.admin, label: Text('Админ'), icon: Icon(Icons.admin_panel_settings_outlined)),
                                ButtonSegment(value: UserRole.teacher, label: Text('Преподаватель'), icon: Icon(Icons.school_outlined)),
                                ButtonSegment(value: UserRole.student, label: Text('Студент'), icon: Icon(Icons.person_outline)),
                              ],
                              selected: {_selectedRole},
                              onSelectionChanged: (Set<UserRole> newSelection) => setState(() => _selectedRole = newSelection.first),
                            );
                          } else {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildRoleTile(UserRole.admin, 'Администратор', Icons.admin_panel_settings_outlined),
                                const SizedBox(height: 8),
                                _buildRoleTile(UserRole.teacher, 'Преподаватель', Icons.school_outlined),
                                const SizedBox(height: 8),
                                _buildRoleTile(UserRole.student, 'Студент', Icons.person_outline),
                              ],
                            );
                          }
                        },
                      ),
                      
                      const SizedBox(height: 24),

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
                                        child: const Text('Войти'),
                                      ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Hint text
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                        ),
                        child: Text(
                          _getHintText(),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: Theme.of(context).textTheme.bodySmall?.fontSize, color: Theme.of(context).colorScheme.onSurfaceVariant),
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

  Widget _buildRoleTile(UserRole role, String label, IconData icon) {
    final isSelected = _selectedRole == role;
    final colorScheme = Theme.of(context).colorScheme;
    
    return InkWell(
      onTap: () => setState(() => _selectedRole = role),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? colorScheme.onPrimary : colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: colorScheme.onPrimary, size: 20),
          ],
        ),
      ),
    );
  }

  String _getHintText() {
    switch (_selectedRole) {
      case UserRole.admin:
        return "Демо: root / root";
      case UserRole.teacher:
        return "Демо: teacher / 123";
      case UserRole.student:
        return "Вход по данным, выданным преподавателем";
    }
  }
}
