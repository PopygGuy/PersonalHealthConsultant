import 'package:flutter/material.dart';
import '../../services/session_service.dart';
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
  bool _isServerLoading = true;
  String _serverUrl = '';

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
  }

  Future<void> _loadServerUrl() async {
    await ApiService().init();
    if (!mounted) return;
    setState(() {
      _serverUrl = ApiService().baseUrl;
      _isServerLoading = false;
    });
  }

  Future<void> _showServerSettingsDialog() async {
    final controller = TextEditingController(text: _serverUrl);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Адрес сервера'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'API URL',
                hintText: 'Например: 192.168.1.42:8000',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Для реального Android-устройства укажите IP вашего ноутбука в Wi-Fi сети.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              await ApiService().setBaseUrl(controller.text);
              if (!mounted) return;
              setState(() => _serverUrl = ApiService().baseUrl);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Сервер обновлен: ${ApiService().baseUrl}')),
              );
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    // Use ApiService for login instead of DatabaseService
    final user = await ApiService().login(
      _loginController.text, 
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (user != null) {
      await SessionService().saveSession(user);
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
                          Icons.fact_check_outlined,
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
                        'Платформа оценки нормативов студентов\nи развития физической формы',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
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
                      const SizedBox(height: 24),
                      Card(
                        elevation: 0,
                        child: ListTile(
                          leading: const Icon(Icons.dns_outlined),
                          title: const Text('Сервер API'),
                          subtitle: Text(
                            _isServerLoading ? 'Загрузка...' : _serverUrl,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: TextButton(
                            onPressed: _isServerLoading ? null : _showServerSettingsDialog,
                            child: const Text('Изменить'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Hint text
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                        ),
                        child: Text(
                          "Тестовый доступ: администратор root / root, преподаватель teacher / 123",
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

}
