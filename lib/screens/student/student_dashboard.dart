import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/mock_database.dart';
import '../home_screen.dart'; // Reuse health calculator
import '../../services/training_advisor.dart';
import '../../services/session_service.dart';
import '../../widgets/responsive_wrapper.dart';
import '../auth/login_screen.dart'; // Import for logout
import 'step_tracker_screen.dart';

class StudentDashboard extends StatefulWidget {
  final User user;
  const StudentDashboard({super.key, required this.user});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0;
  final _db = DatabaseService();
  String? _selectedMood;
  String? _moodAdvice;

  @override
  void initState() {
    super.initState();
    _loadMoodStateForToday();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Главная',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Журнал',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Шагомер',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: 'Здоровье',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0: return _buildDashboardTab();
      case 1: return _buildJournalTab();
      case 2: return _buildStepsTab();
      case 3: return _buildHealthTab();
      case 4: return _buildProfileTab();
      default: return const Center(child: Text("Ошибка"));
    }
  }

  // --- TAB 1: Dashboard (Summary) ---
  Widget _buildDashboardTab() {
    final grades = _db.getGradesForStudent(widget.user.id);
    double avgScore = 0;
    if (grades.isNotEmpty) {
      avgScore = grades.map((g) => g.score).reduce((a, b) => a + b) / grades.length;
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar.medium(
          title: Text("Привет, ${widget.user.fullName.split(' ')[0]}!"), // First name only
          centerTitle: false,
        ),
        SliverToBoxAdapter(
          child: ResponsiveWrapper(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Academic Summary
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          title: "Средний балл",
                          value: avgScore > 0 ? avgScore.toStringAsFixed(1) : "-",
                          icon: Icons.school,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          title: "Сдано нормативов",
                          value: grades.length.toString(),
                          icon: Icons.task_alt,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Health Check-in
                  _buildSummaryCard(
                    context,
                    title: "Самочувствие",
                    icon: Icons.favorite,
                    color: Theme.of(context).colorScheme.secondary,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Как вы себя чувствуете сегодня?"),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ActionChip(
                              label: const Text("Отлично"),
                              onPressed: () => _onMoodSelected("Отлично"),
                            ),
                            ActionChip(
                              label: const Text("Нормально"),
                              onPressed: () => _onMoodSelected("Нормально"),
                            ),
                            ActionChip(
                              label: const Text("Устал"),
                              onPressed: () => _onMoodSelected("Устал"),
                            ),
                          ],
                        ),
                        if (_moodAdvice != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Совет на сегодня (${_selectedMood ?? '-'})",
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(_moodAdvice!),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- TAB 2: Journal (Grades) ---
  Widget _buildJournalTab() {
    final grades = _db.getGradesForStudent(widget.user.id);

    return Scaffold(
      appBar: AppBar(title: const Text("Журнал успеваемости")),
      body: grades.isEmpty 
          ? _buildEmptyState("Пока нет оценок", Icons.assignment_outlined)
          : ResponsiveWrapper(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: grades.length,
                separatorBuilder: (c, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final g = grades[index];
                  final advice = TrainingAdvisor.getAdviceForNorm(g.normName, g.score);
                  
                  return Card(
                    child: ExpansionTile(
                      shape: const Border(), // Remove default borders
                      leading: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _getScoreColor(g.score).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${g.score}",
                          style: TextStyle(
                            color: _getScoreColor(g.score),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      title: Text(g.normName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        g.date.toString().split(' ')[0], 
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        if (g.comment != null && g.comment!.isNotEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(g.comment!),
                            ),
                          ),
                        if (advice != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  advice, 
                                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)
                                ),
                              ),
                            ],
                          )
                        ]
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildStepsTab() {
    return StepTrackerScreen(user: widget.user);
  }

  // --- TAB 3: Health (Calculator) ---
  Widget _buildHealthTab() {
    return HomeScreen(initialUser: null); // Reusing the calculator screen
  }

  // --- TAB 4: Profile ---
  Widget _buildProfileTab() {
    return Scaffold(
      appBar: AppBar(title: const Text("Профиль")),
      body: ResponsiveWrapper(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      widget.user.fullName[0], 
                      style: TextStyle(fontSize: 32, color: Theme.of(context).colorScheme.onPrimaryContainer)
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.user.fullName,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(widget.user.role == UserRole.student ? "Студент" : "Пользователь"),
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildProfileItem(Icons.school, "Факультет", widget.user.faculty ?? "Не указан"),
            _buildProfileItem(Icons.class_, "Группа", widget.user.group ?? "Не указана"),
            _buildProfileItem(Icons.login, "Логин", widget.user.login),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text("Приватность"),
              subtitle: const Text("Данные о самочувствии видны только вам"),
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text("Выйти", style: TextStyle(color: Colors.red)),
              onTap: () async {
                await SessionService().clearSession();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- Helpers ---

  Widget _buildSummaryCard(BuildContext context, {
    required String title, 
    required IconData icon, 
    required Color color, 
    required Widget content
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, {
    required String title, 
    required String value, 
    required IconData icon, 
    required Color color
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label, style: Theme.of(context).textTheme.bodySmall),
      subtitle: Text(value, style: const TextStyle(fontSize: 16)),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 4) return Colors.green;
    if (score == 3) return Colors.orange;
    return Colors.red;
  }

  void _onMoodSelected(String mood) {
    final advice = _getDailyMoodAdvice(mood);
    setState(() {
      _selectedMood = mood;
      _moodAdvice = advice;
    });
    _saveMoodStateForToday(mood: mood, advice: advice);
  }

  String _getDailyMoodAdvice(String mood) {
    final adviceMap = <String, List<String>>{
      "Отлично": [
        "Сохраните темп: добавьте 20-30 минут легкой активности и пейте воду небольшими порциями в течение дня.",
        "Отличный день для прогресса: выполните разминку 7-10 минут и закрепите результат короткой вечерней прогулкой.",
        "Используйте высокий ресурс: выберите одно приоритетное учебное задание и закройте его до конца дня.",
        "Поддержите состояние: следите за осанкой и делайте 2-3 коротких перерыва на растяжку.",
      ],
      "Нормально": [
        "Чтобы повысить тонус, сделайте 5 минут дыхательной разминки и 10-15 минут ходьбы в комфортном темпе.",
        "Добавьте энергии: не пропускайте прием пищи и выберите сбалансированный перекус с белком и сложными углеводами.",
        "Снизьте утомление: работайте циклами по 25-30 минут с короткими перерывами по 3-5 минут.",
        "Поддержите концентрацию: уменьшите экранную нагрузку вечером и постарайтесь лечь спать немного раньше.",
      ],
      "Устал": [
        "Сегодня приоритет - восстановление: снизьте нагрузку, добавьте теплую воду и спокойную прогулку 10-20 минут.",
        "Чтобы уменьшить усталость, сделайте мягкую растяжку 5-7 минут и ограничьте интенсивную активность до завтра.",
        "Сфокусируйтесь на отдыхе: выполните одно важное дело и оставьте время на восстановление и сон не менее 7-8 часов.",
        "При утомлении помогает режим: легкий ужин, меньше кофеина вечером и короткая релаксация перед сном.",
      ],
    };

    final options = adviceMap[mood] ?? adviceMap["Нормально"]!;
    final today = DateTime.now();
    final dayOfYear = today.difference(DateTime(today.year, 1, 1)).inDays + 1;
    final moodSeed = mood.codeUnits.fold<int>(0, (sum, c) => sum + c);
    final index = (dayOfYear + moodSeed) % options.length;
    return options[index];
  }

  String _todayKeyPrefix() {
    final today = DateTime.now();
    final date =
        "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    return "student_mood_${widget.user.id}_$date";
  }

  Future<void> _saveMoodStateForToday({
    required String mood,
    required String advice,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final keyPrefix = _todayKeyPrefix();
    await prefs.setString("${keyPrefix}_value", mood);
    await prefs.setString("${keyPrefix}_advice", advice);
  }

  Future<void> _loadMoodStateForToday() async {
    final prefs = await SharedPreferences.getInstance();
    final keyPrefix = _todayKeyPrefix();
    final savedMood = prefs.getString("${keyPrefix}_value");
    final savedAdvice = prefs.getString("${keyPrefix}_advice");

    if (!mounted) return;
    setState(() {
      _selectedMood = savedMood;
      _moodAdvice = savedAdvice;
    });
  }
}
