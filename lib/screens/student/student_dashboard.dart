import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../home_screen.dart'; // Reuse health calculator
import '../../services/training_advisor.dart';
import '../../services/session_service.dart';
import '../../services/step_tracker_service.dart';
import '../../services/api_service.dart';
import '../../widgets/responsive_wrapper.dart';
import '../auth/login_screen.dart'; // Import for logout
import 'step_tracker_screen.dart';
import '../../models/user.dart';
import '../../models/grade.dart';
import '../../models/norm.dart';
import '../../models/user_role.dart';
import '../../models/faculty.dart';
import '../../models/group.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/app_theme_selector_card.dart';

class StudentDashboard extends StatefulWidget {
  final User user;
  const StudentDashboard({super.key, required this.user});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0;
  final _api = ApiService();
  final _stepService = const StepTrackerService();
  late final StepTrackerStorage _stepStorage; // Use late initialization
  late User _currentUser;

  // Data State
  List<Grade> _grades = [];
  List<Norm> _norms = [];
  List<Faculty> _faculties = [];
  List<Group> _groups = [];
  bool _isLoading = true;
  String? _journalFilterNormId;
  String? _journalFilterAcademicYear;
  int? _journalFilterCourse;
  int? _journalFilterSemester;

  String? _selectedMood;
  String? _moodAdvice;
  StepTrackerStats? _stepSummary;
  bool _stepSummaryLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _stepStorage = ApiStepTrackerStorage(api: _api);
    _loadCurrentUser();
    _loadData();
    _loadMoodStateForToday();
    _loadStepSummary();
  }

  Future<void> _loadCurrentUser() async {
    final me = await _api.getMe();
    if (!mounted || me == null) return;
    setState(() => _currentUser = me);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final grades = await _api.getGrades(studentId: widget.user.id);
      final norms = await _api.getNorms();
      final faculties = await _api.getFaculties();
      final groups = await _api.getGroups();

      setState(() {
        _grades = grades;
        _norms = norms;
        _faculties = faculties;
        _groups = groups;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  // Helper to get norm name by ID
  String _getNormName(String normId) {
    return _norms
        .firstWhere((n) => n.id == normId,
            orElse: () => Norm(id: '', name: 'Неизвестный норматив'))
        .name;
  }

  String _defaultAcademicYear() {
    final now = DateTime.now();
    final startYear = now.month >= 9 ? now.year : now.year - 1;
    return '$startYear/${startYear + 1}';
  }

  List<String> _academicYearOptions() {
    final now = DateTime.now();
    final currentStartYear = now.month >= 9 ? now.year : now.year - 1;
    final years = <String>{
      ...List<String>.generate(6, (i) {
        final start = currentStartYear - 2 + i;
        return '$start/${start + 1}';
      }),
      ..._grades.map((g) => g.academicYear.trim()).where((y) => y.isNotEmpty),
    }.toList();
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
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

  void _onDestinationSelected(int index) {
    setState(() => _currentIndex = index);
    if (index == 0) {
      _loadStepSummary();
      _loadData(); // Refresh grades on dashboard
    } else if (index == 1) {
      _loadData(); // Refresh grades on journal
    }
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildJournalTab();
      case 2:
        return _buildStepsTab();
      case 3:
        return _buildHealthTab();
      case 4:
        return _buildProfileTab();
      default:
        return const Center(child: Text("Ошибка"));
    }
  }

  Widget _buildSliverAppBar(
    String title, {
    IconData icon = Icons.dashboard_outlined,
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final subtitleFontSize = width < 360 ? 14.0 : (width < 600 ? 16.0 : 18.0);
    return SliverAppBar.medium(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon,
                size: 18, color: theme.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      bottom: subtitle == null
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  child: Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: subtitleFontSize,
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // --- TAB 1: Dashboard (Summary) ---
  Widget _buildDashboardTab() {
    final recentGrades = [..._grades]..sort((a, b) => b.date.compareTo(a.date));
    final topRecentGrades = recentGrades.take(3).toList();
    double avgScore = 0;
    if (_grades.isNotEmpty) {
      avgScore =
          _grades.map((g) => g.score).reduce((a, b) => a + b) / _grades.length;
    }

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(
          "Привет, ${_currentUser.fullName.split(' ')[0]}!",
          icon: Icons.dashboard_outlined,
          subtitle: "Главная сводка по нормативам и активности",
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
                          title: "Средний балл (нормативы)",
                          value:
                              avgScore > 0 ? avgScore.toStringAsFixed(1) : "-",
                          icon: Icons.school,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          title: "Сдано нормативов",
                          value: _grades.length.toString(),
                          icon: Icons.task_alt,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryCard(
                    context,
                    title: "Прогресс по нормативам",
                    icon: Icons.military_tech_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _grades.isEmpty
                              ? "Пока нет оценок. После первой оценки здесь будет видна динамика прогресса."
                              : "Основной фокус: результаты сдачи нормативов и рост баллов.",
                        ),
                        const SizedBox(height: 10),
                        if (topRecentGrades.isNotEmpty)
                          ...topRecentGrades.map(
                            (g) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Text(
                                    "${g.score}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _getScoreColor(g.score),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _getNormName(g.normId),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _onDestinationSelected(1),
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text("Открыть журнал"),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStepsSummaryCard(context),
                  const SizedBox(height: 16),

                  // Additional wellbeing module
                  _buildSummaryCard(
                    context,
                    title: "Дополнительно: самочувствие",
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Совет на сегодня (${_selectedMood ?? '-'})",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
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
    final filteredGrades = _grades.where((g) {
      if (_journalFilterNormId != null && g.normId != _journalFilterNormId)
        return false;
      if (_journalFilterAcademicYear != null &&
          (g.academicYear.isEmpty ? _defaultAcademicYear() : g.academicYear) !=
              _journalFilterAcademicYear) {
        return false;
      }
      if (_journalFilterCourse != null && g.course != _journalFilterCourse)
        return false;
      if (_journalFilterSemester != null &&
          g.semester != _journalFilterSemester) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(
          "Журнал успеваемости",
          icon: Icons.school_outlined,
          subtitle: "Ваши оценки и рекомендации по нормативам",
        ),
        if (_grades.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text("Пока нет оценок")),
          )
        else
          SliverToBoxAdapter(
            child: ResponsiveWrapper(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _journalFilterNormId,
                      decoration: const InputDecoration(
                        labelText: "Норматив",
                        prefixIcon: Icon(Icons.rule_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text("Все нормативы"),
                        ),
                        ..._norms.map(
                          (n) => DropdownMenuItem<String>(
                            value: n.id,
                            child: Text(
                              n.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _journalFilterNormId = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _journalFilterAcademicYear,
                      decoration: const InputDecoration(
                        labelText: "Учебный год",
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text("Все учебные годы"),
                        ),
                        ..._academicYearOptions().map(
                          (y) => DropdownMenuItem<String>(
                            value: y,
                            child: Text(y),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _journalFilterAcademicYear = value),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            value: _journalFilterCourse,
                            decoration: const InputDecoration(
                              labelText: "Курс",
                              prefixIcon: Icon(Icons.school_outlined),
                            ),
                            items: const [
                              DropdownMenuItem<int>(
                                  value: null, child: Text("Все курсы")),
                              DropdownMenuItem<int>(
                                  value: 1, child: Text("1 курс")),
                              DropdownMenuItem<int>(
                                  value: 2, child: Text("2 курс")),
                              DropdownMenuItem<int>(
                                  value: 3, child: Text("3 курс")),
                              DropdownMenuItem<int>(
                                  value: 4, child: Text("4 курс")),
                              DropdownMenuItem<int>(
                                  value: 5, child: Text("5 курс")),
                              DropdownMenuItem<int>(
                                  value: 6, child: Text("6 курс")),
                            ],
                            onChanged: (value) =>
                                setState(() => _journalFilterCourse = value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            value: _journalFilterSemester,
                            decoration: const InputDecoration(
                              labelText: "Семестр",
                              prefixIcon: Icon(Icons.event_note_outlined),
                            ),
                            items: const [
                              DropdownMenuItem<int>(
                                  value: null, child: Text("Все семестры")),
                              DropdownMenuItem<int>(
                                  value: 1, child: Text("1 семестр")),
                              DropdownMenuItem<int>(
                                  value: 2, child: Text("2 семестр")),
                            ],
                            onChanged: (value) =>
                                setState(() => _journalFilterSemester = value),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (filteredGrades.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text("По выбранным фильтрам нет оценок")),
          )
        else
          SliverToBoxAdapter(
            child: ResponsiveWrapper(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: filteredGrades.length,
                separatorBuilder: (c, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final g = filteredGrades[index];
                  final normName = _getNormName(g.normId);
                  final advice =
                      TrainingAdvisor.getAdviceForNorm(normName, g.score);

                  return Card(
                    child: ExpansionTile(
                      shape: const Border(),
                      leading: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
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
                      title: Text(normName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        "${(g.academicYear.isEmpty ? _defaultAcademicYear() : g.academicYear)} • ${g.course} курс / ${g.semester} семестр — ${g.date.toString().split(' ')[0]}",
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
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
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
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
                              Icon(Icons.info_outline,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  advice,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStepsTab() {
    return StepTrackerScreen(
      user: _currentUser,
      stepTrackerStorage: _stepStorage, // Pass the API storage
    );
  }

  Widget _buildHealthTab() {
    return HomeScreen(initialUser: null);
  }

  Widget _buildProfileTab() {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(
          "Профиль",
          icon: Icons.person_outline,
          subtitle: "Личные данные и настройки аккаунта",
        ),
        SliverToBoxAdapter(
          child: ResponsiveWrapper(
            child: ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    children: [
                      UserAvatar(
                        displayName: _currentUser.fullName,
                        seed: _currentUser.id.isNotEmpty
                            ? _currentUser.id
                            : _currentUser.login,
                        role: UserRole.student,
                        radius: 40,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _currentUser.fullName,
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Chip(
                        label: Text(_currentUser.role == UserRole.student
                            ? "Студент"
                            : "Пользователь"),
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                _buildProfileItem(
                    Icons.school, "Факультет", _resolveFacultyName()),
                _buildProfileItem(Icons.class_, "Группа", _resolveGroupName()),
                _buildProfileItem(Icons.login, "Логин", _currentUser.login),
                const Divider(height: 32),
                const AppThemeSelectorCard(),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text("Приватность"),
                  subtitle:
                      const Text("Данные о самочувствии видны только вам"),
                ),
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.red),
                  title:
                      const Text("Выйти", style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    await SessionService().clearSession();
                    if (!mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context,
      {required String title,
      required IconData icon,
      required Color color,
      required Widget content}) {
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
                Text(title,
                    style:
                        TextStyle(fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildStepsSummaryCard(BuildContext context) {
    final stats = _stepSummary;
    if (_stepSummaryLoading || stats == null) {
      return _buildSummaryCard(
        context,
        title: "Активность сегодня",
        icon: Icons.directions_walk,
        color: Theme.of(context).colorScheme.primary,
        content: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(),
        ),
      );
    }

    final km = _stepService.kmFromSteps(
      stats.stepsToday,
      strideMeters: stats.strideMeters,
    );
    final points = _stepService.healthPointsFromSteps(stats.stepsToday);
    final progress = (stats.stepsToday / stats.dailyGoal).clamp(0.0, 1.0);
    final progressPercent = (progress * 100).round();

    return _buildSummaryCard(
      context,
      title: "Активность сегодня",
      icon: Icons.directions_walk,
      color: Theme.of(context).colorScheme.primary,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Шаги: ${stats.stepsToday}"),
          const SizedBox(height: 4),
          Text("Дистанция: ${_stepService.formatKm(km)} км"),
          const SizedBox(height: 4),
          Text("Баллы: $points"),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 6),
          Text(
              "Прогресс цели: $progressPercent% (${stats.stepsToday}/${stats.dailyGoal})"),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _onDestinationSelected(2),
              icon: const Icon(Icons.arrow_forward),
              label: const Text("Открыть шагомер"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context,
      {required String title,
      required String value,
      required IconData icon,
      required Color color}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
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

  String _resolveFacultyName() {
    if (_currentUser.faculty != null &&
        _currentUser.faculty!.trim().isNotEmpty) {
      return _currentUser.faculty!;
    }
    final facultyId = _currentUser.facultyId;
    if (facultyId == null || facultyId.isEmpty) return 'Не указан';
    final faculty =
        _faculties.where((f) => f.id == facultyId).cast<Faculty?>().firstWhere(
              (f) => f != null,
              orElse: () => null,
            );
    return faculty?.name ?? 'Не указан';
  }

  String _resolveGroupName() {
    if (_currentUser.group != null && _currentUser.group!.trim().isNotEmpty) {
      return _currentUser.group!;
    }
    final groupId = _currentUser.groupId;
    if (groupId == null || groupId.isEmpty) return 'Не указана';
    final group =
        _groups.where((g) => g.id == groupId).cast<Group?>().firstWhere(
              (g) => g != null,
              orElse: () => null,
            );
    return group?.name ?? 'Не указана';
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

  Future<void> _loadStepSummary() async {
    setState(() => _stepSummaryLoading = true);
    final stats = await _stepStorage.load(
      userId: widget.user.id,
      currentDateKey: _stepService.dateKey(DateTime.now()),
    );
    if (!mounted) return;
    setState(() {
      _stepSummary = stats;
      _stepSummaryLoading = false;
    });
  }
}
