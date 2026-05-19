import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/session_service.dart';
import '../../services/api_service.dart';
import '../../widgets/responsive_wrapper.dart';
import '../auth/login_screen.dart';
import '../../models/user.dart';
import '../../models/user_role.dart';
import '../../models/faculty.dart';
import '../../models/group.dart';
import '../../models/norm.dart';
import '../../models/grade.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/app_theme_selector_card.dart';

class TeacherHomeScreen extends StatefulWidget {
  final User user;
  const TeacherHomeScreen({super.key, required this.user});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

String _studentSearchText(User student) {
  return student.fullName.trim().toLowerCase();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final _api = ApiService();
  late final TabController _journalTabController;

  // Data State
  List<User> _students = [];
  List<Faculty> _faculties = [];
  List<Group> _groups = [];
  List<Norm> _norms = [];
  List<Grade> _grades = [];
  bool _isLoading = true;

  // Filters State
  String? _filterFacultyId;
  String? _filterGroupId;
  String _studentSearchQuery = '';
  String? _historyFilterFacultyId;
  String? _historyFilterGroupId;
  String? _historyFilterStudentId;
  String? _historyFilterNormId;
  String? _historyFilterAcademicYear;
  int? _historyFilterCourse;
  int? _historyFilterSemester;
  String _historySearchQuery = '';
  final TextEditingController _historySearchController = TextEditingController();
  DateTime? _journalVisibleFrom;
  bool _showOnlyActiveNorms = true;

  Widget _filterLabel(String text) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
            letterSpacing: 0.2,
          ) ??
          TextStyle(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
    );
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
  void initState() {
    super.initState();
    _journalTabController = TabController(length: 2, vsync: this);
    _loadHistoryPreferences();
    _loadData();
  }

  @override
  void dispose() {
    _journalTabController.dispose();
    _historySearchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistoryPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getString('teacher_journal_visible_from_${widget.user.id}');
    if (raw == null || raw.isEmpty) return;
    final parsed = DateTime.tryParse(raw);
    if (!mounted || parsed == null) return;
    setState(() => _journalVisibleFrom = parsed);
  }

  Future<void> _saveHistoryPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'teacher_journal_visible_from_${widget.user.id}';
    if (_journalVisibleFrom == null) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, _journalVisibleFrom!.toIso8601String());
  }

  Future<void> _clearJournalVisualOnly() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить журнал визуально?'),
        content: const Text(
          'Будут скрыты старые записи, а оценки студентов в базе останутся без изменений.\n\n'
          'Показываться будут записи только за последний месяц. Продолжить?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Уверены'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() {
      _journalVisibleFrom = DateTime.now().subtract(const Duration(days: 30));
    });
    await _saveHistoryPreferences();
  }

  Future<void> _resetJournalVisibility() async {
    setState(() => _journalVisibleFrom = null);
    await _saveHistoryPreferences();
  }

  Future<void> _loadData({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => _isLoading = true);
    }
    try {
      final students = await _api.getUsers(role: 'student');
      final faculties = await _api.getFaculties();
      final groups = await _api.getGroups();
      final norms = await _api.getNorms();
      final grades = await _api.getGrades();

      setState(() {
        _students = students;
        _faculties = faculties;
        _groups = groups;
        _norms = norms;
        _grades = grades;
        if (showLoader) _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      if (showLoader) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompactNav = width < 420;
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      floatingActionButton: _buildFab(),
      bottomNavigationBar: NavigationBar(
        height: isCompactNav ? 72 : null,
        labelBehavior: isCompactNav
            ? NavigationDestinationLabelBehavior.onlyShowSelected
            : NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: isCompactNav ? 'Студ.' : 'Студенты',
          ),
          NavigationDestination(
            icon: const Icon(Icons.grade_outlined),
            selectedIcon: const Icon(Icons.grade),
            label: 'Журнал',
          ),
          NavigationDestination(
            icon: const Icon(Icons.rule_outlined),
            selectedIcon: const Icon(Icons.rule),
            label: isCompactNav ? 'Норм.' : 'Нормативы',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }

  bool _matchesFaculty(
      User student, String? selectedFacultyId, String? selectedFacultyName) {
    if (selectedFacultyId == null) return true;
    if (student.facultyId != null && student.facultyId == selectedFacultyId)
      return true;
    if (selectedFacultyName != null &&
        selectedFacultyName.isNotEmpty &&
        student.faculty != null &&
        student.faculty == selectedFacultyName) {
      return true;
    }
    return false;
  }

  bool _matchesGroup(
      User student, String? selectedGroupId, String? selectedGroupName) {
    if (selectedGroupId == null) return true;
    if (student.groupId != null && student.groupId == selectedGroupId)
      return true;
    if (selectedGroupName != null &&
        selectedGroupName.isNotEmpty &&
        student.group != null &&
        student.group == selectedGroupName) {
      return true;
    }
    return false;
  }

  String _resolveFacultyName(User student) {
    if (student.faculty != null && student.faculty!.trim().isNotEmpty)
      return student.faculty!;
    if (student.facultyId != null) {
      final faculty = _faculties.firstWhere(
        (f) => f.id == student.facultyId,
        orElse: () => Faculty(id: '', name: ''),
      );
      if (faculty.name.isNotEmpty) return faculty.name;
    }
    return '-';
  }

  String _resolveGroupName(User student) {
    if (student.group != null && student.group!.trim().isNotEmpty)
      return student.group!;
    if (student.groupId != null) {
      final group = _groups.firstWhere(
        (g) => g.id == student.groupId,
        orElse: () => Group(id: '', name: '', facultyId: ''),
      );
      if (group.name.isNotEmpty) return group.name;
    }
    return '-';
  }

  Widget _buildBody() {
    return switch (_currentIndex) {
      0 => _buildStudentsTab(),
      1 => _buildGradeJournalTab(),
      2 => _buildNormsTab(),
      3 => _buildProfileTab(),
      _ => const Center(child: Text("Ошибка")),
    };
  }

  Widget? _buildFab() {
    if (_currentIndex == 2) {
      return FloatingActionButton(
        onPressed: () => _showAddNormDialog(context),
        child: const Icon(Icons.add),
      );
    }
    return null;
  }

  // --- REUSABLE HEADER ---
  Widget _buildSliverAppBar(
    String title, {
    IconData icon = Icons.dashboard_outlined,
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final subtitleFontSize = width < 360 ? 12.0 : (width < 600 ? 14.0 : 16.0);
    final subtitleHeight = width < 360 ? 76.0 : 72.0;
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
              preferredSize: Size.fromHeight(subtitleHeight),
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

  Widget _buildProfileTab() {
    final myGradesCount =
        _grades.where((g) => g.teacherId == widget.user.id).length;
    final studentsCount = _students.length;

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(
          "Профиль преподавателя",
          icon: Icons.person_outline,
          subtitle: "Контроль оценок и работа с нормативами",
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: ListTile(
                    leading: UserAvatar(
                      displayName: widget.user.fullName,
                      seed: widget.user.id.isNotEmpty
                          ? widget.user.id
                          : widget.user.login,
                      role: UserRole.teacher,
                      radius: 18,
                    ),
                    title: Text(widget.user.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text("Логин: ${widget.user.login}"),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text("Оценок выставлено: $myGradesCount")),
                        Chip(label: Text("Студентов: $studentsCount")),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const AppThemeSelectorCard(),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    await SessionService().clearSession();
                    if (!mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text("Выйти"),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- TAB 1: Students List (With Filters) ---
  Widget _buildStudentsTab() {
    List<User> filteredStudents = _students;

    // Filter by Faculty
    if (_filterFacultyId != null) {
      final f = _faculties.firstWhere((e) => e.id == _filterFacultyId,
          orElse: () => Faculty(id: '', name: ''));
      filteredStudents = filteredStudents
          .where((s) => _matchesFaculty(s, _filterFacultyId, f.name))
          .toList();
    }

    // Filter by Group
    if (_filterGroupId != null) {
      final g = _groups.firstWhere((e) => e.id == _filterGroupId,
          orElse: () => Group(id: '', name: '', facultyId: ''));
      filteredStudents = filteredStudents
          .where((s) => _matchesGroup(s, _filterGroupId, g.name))
          .toList();
    }

    final studentQuery = _studentSearchQuery.trim().toLowerCase();
    if (studentQuery.isNotEmpty) {
      filteredStudents = filteredStudents.where((s) {
        final fullName = s.fullName.toLowerCase();
        return fullName.contains(studentQuery);
      }).toList();
      filteredStudents.sort((a, b) {
        final aName = a.fullName.toLowerCase();
        final bName = b.fullName.toLowerCase();

        int rank(User u) {
          final name = u.fullName.toLowerCase();
          if (name.startsWith(studentQuery)) return 0;
          if (name.contains(studentQuery)) return 1;
          return 9;
        }

        final r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        return aName.compareTo(bName);
      });
    }

    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width > 900 ? 3 : (width > 600 ? 2 : 1);
    final isMobile = crossAxisCount == 1;

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(
          "Студенты",
          icon: Icons.people_outline,
          subtitle: "Список и фильтрация студентов по факультетам и группам",
        ),

        // FILTERS
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Фильтрация",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _filterLabel("Факультет"),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _filterFacultyId,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.domain_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text("Все факультеты")),
                      ..._faculties.map((f) => DropdownMenuItem<String>(
                            value: f.id,
                            child: Text(f.name,
                                overflow: TextOverflow.ellipsis, maxLines: 1),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterFacultyId = value;
                        _filterGroupId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _filterGroupId,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.groups_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text("Все направления")),
                      ...(_filterFacultyId == null
                              ? _groups
                              : _groups.where(
                                  (g) => g.facultyId == _filterFacultyId))
                          .map((g) => DropdownMenuItem<String>(
                                value: g.id,
                                child: Text(g.name,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1),
                              )),
                    ],
                    onChanged: (value) =>
                        setState(() => _filterGroupId = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) =>
                        setState(() => _studentSearchQuery = value),
                    decoration: const InputDecoration(
                      labelText: "Поиск студентов по ФИО",
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // LIST
        if (filteredStudents.isEmpty)
          const SliverFillRemaining(
            child: Center(child: Text("Студенты не найдены")),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: isMobile
                ? SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildStudentCard(filteredStudents[index]),
                      childCount: filteredStudents.length,
                    ),
                  )
                : SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 220,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildStudentCard(filteredStudents[index]),
                      childCount: filteredStudents.length,
                    ),
                  ),
          ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }

  Widget _buildStudentCard(User s) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            UserAvatar(
              displayName: s.fullName,
              seed: s.id.isNotEmpty ? s.id : s.login,
              role: UserRole.student,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(s.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text("${_resolveFacultyName(s)} / ${_resolveGroupName(s)}",
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize:
                              Theme.of(context).textTheme.bodySmall?.fontSize)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 2: Grade Journal ---
  Widget _buildGradeJournalTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedTabColor =
        isDark ? const Color(0xFF4DA3FF) : theme.colorScheme.primary;
    final unselectedTabColor = isDark
        ? theme.colorScheme.onSurface.withOpacity(0.78)
        : theme.colorScheme.onSurfaceVariant;
    return NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(
            "Журнал оценок",
            icon: Icons.grade_outlined,
            subtitle: "Выставление баллов и просмотр истории",
          ),
          SliverToBoxAdapter(
            child: TabBar(
              controller: _journalTabController,
              indicatorColor: selectedTabColor,
              labelColor: selectedTabColor,
              unselectedLabelColor: unselectedTabColor,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: "Новая оценка"),
                Tab(text: "История"),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _journalTabController,
          children: [
            _buildNewGradeForm(),
            _buildGradesHistory(),
          ],
        ),
    );
  }

  Widget _buildNewGradeForm() {
    final activeNorms = _norms.where((n) => n.isActive).toList();
    if (_students.isEmpty)
      return const Center(child: Text("Нет студентов для оценки"));
    if (activeNorms.isEmpty)
      return const Center(
          child:
              Text("Нет активных нормативов. Разблокируйте их во вкладке 'Нормативы'"));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ResponsiveWrapper(
        maxWidth: 500,
        child: Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _GradeForm(
              students: _students,
              norms: activeNorms,
              faculties: _faculties,
              groups: _groups,
              grades: _grades,
              teacherId: widget.user.id,
              onGradeAdded: () => _loadData(showLoader: false),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradesHistory() {
    final myGrades =
        _grades.where((g) => g.teacherId == widget.user.id).toList();
    final studentsById = {for (final s in _students) s.id: s};
    final normsById = {for (final n in _norms) n.id: n};

    final selectedFacultyName = _historyFilterFacultyId == null
        ? null
        : _faculties
            .firstWhere((f) => f.id == _historyFilterFacultyId,
                orElse: () => Faculty(id: '', name: ''))
            .name;

    final selectedGroupName = _historyFilterGroupId == null
        ? null
        : _groups
            .firstWhere((g) => g.id == _historyFilterGroupId,
                orElse: () => Group(id: '', name: '', facultyId: ''))
            .name;

    final studentsForDropdown = _students.where((s) {
      if (!_matchesFaculty(s, _historyFilterFacultyId, selectedFacultyName))
        return false;
      if (!_matchesGroup(s, _historyFilterGroupId, selectedGroupName))
        return false;
      return true;
    }).toList();

    final filteredGrades = myGrades.where((g) {
      if (_historyFilterStudentId != null &&
          g.studentId != _historyFilterStudentId) return false;
      if (_historyFilterNormId != null && g.normId != _historyFilterNormId)
        return false;
      if (_historyFilterAcademicYear != null &&
          (g.academicYear.isEmpty ? _defaultAcademicYear() : g.academicYear) !=
              _historyFilterAcademicYear) {
        return false;
      }
      if (_historyFilterCourse != null && g.course != _historyFilterCourse)
        return false;
      if (_historyFilterSemester != null &&
          g.semester != _historyFilterSemester) return false;
      if (_journalVisibleFrom != null && g.date.isBefore(_journalVisibleFrom!))
        return false;

      final student = studentsById[g.studentId];
      if (student == null) return false;
      if (!_matchesFaculty(
          student, _historyFilterFacultyId, selectedFacultyName)) return false;
      if (!_matchesGroup(student, _historyFilterGroupId, selectedGroupName))
        return false;

      final query = _historySearchQuery.trim().toLowerCase();
      if (query.isNotEmpty) {
        if (!_studentSearchText(student).contains(query)) return false;
      }
      return true;
    }).toList();

    final query = _historySearchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      int rank(Grade g) {
        final student = studentsById[g.studentId];
        if (student == null) return 9;
        final studentSearchText = _studentSearchText(student);
        if (studentSearchText.startsWith(query)) return 0;
        if (studentSearchText.contains(query)) return 1;
        return 9;
      }

      filteredGrades.sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        return b.date.compareTo(a.date);
      });
    } else {
      filteredGrades.sort((a, b) => b.date.compareTo(a.date));
    }
    final displayItems = _buildGradeDisplayItems(filteredGrades);

    if (myGrades.isEmpty)
      return const Center(child: Text("Вы еще не ставили оценок"));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _historySearchController,
                    onChanged: (value) =>
                        setState(() => _historySearchQuery = value),
                    decoration: const InputDecoration(
                      labelText: "Поиск по ФИО студента",
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    initiallyExpanded: _historyFilterFacultyId != null ||
                        _historyFilterGroupId != null ||
                        _historyFilterStudentId != null ||
                        _historyFilterNormId != null ||
                        _historyFilterAcademicYear != null ||
                        _historyFilterCourse != null ||
                        _historyFilterSemester != null,
                    leading: const Icon(Icons.tune),
                    title: const Text("Фильтры"),
                    subtitle: Text(
                      "Факультет, группа, студент, норматив, год, курс, семестр",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    children: [
                  _filterLabel("Факультет"),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _historyFilterFacultyId,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.domain_outlined)),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text("Все факультеты")),
                      ..._faculties.map(
                        (f) => DropdownMenuItem<String>(
                          value: f.id,
                          child: Text(
                            f.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _historyFilterFacultyId = value;
                      _historyFilterGroupId = null;
                      _historyFilterStudentId = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  _filterLabel("Направление / группа"),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _historyFilterGroupId,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.groups_outlined)),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text("Все направления")),
                      ...(_historyFilterFacultyId == null
                              ? _groups
                              : _groups.where((g) =>
                                  g.facultyId == _historyFilterFacultyId))
                          .map(
                        (g) => DropdownMenuItem<String>(
                          value: g.id,
                          child: Text(
                            g.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _historyFilterGroupId = value;
                      _historyFilterStudentId = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  _filterLabel("Студент"),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _historyFilterStudentId,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_outline)),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text("Все студенты")),
                      ...studentsForDropdown.map(
                        (s) => DropdownMenuItem<String>(
                          value: s.id,
                          child: Text(
                            s.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _historyFilterStudentId = value),
                  ),
                  const SizedBox(height: 12),
                  _filterLabel("Норматив"),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _historyFilterNormId,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.rule_outlined)),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text("Все нормативы")),
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
                        setState(() => _historyFilterNormId = value),
                  ),
                  const SizedBox(height: 12),
                  _filterLabel("Учебный год"),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _historyFilterAcademicYear,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.calendar_today_outlined)),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text("Все учебные годы")),
                      ..._academicYearOptions().map(
                        (y) => DropdownMenuItem<String>(
                          value: y,
                          child: Text(y),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _historyFilterAcademicYear = value),
                  ),
                  const SizedBox(height: 12),
                  _filterLabel("Курс"),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: _historyFilterCourse,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.school_outlined)),
                    items: const [
                      DropdownMenuItem<int>(
                          value: null, child: Text("Все курсы")),
                      DropdownMenuItem<int>(value: 1, child: Text("1 курс")),
                      DropdownMenuItem<int>(value: 2, child: Text("2 курс")),
                      DropdownMenuItem<int>(value: 3, child: Text("3 курс")),
                      DropdownMenuItem<int>(value: 4, child: Text("4 курс")),
                      DropdownMenuItem<int>(value: 5, child: Text("5 курс")),
                      DropdownMenuItem<int>(value: 6, child: Text("6 курс")),
                    ],
                    onChanged: (value) =>
                        setState(() => _historyFilterCourse = value),
                  ),
                  const SizedBox(height: 12),
                  _filterLabel("Семестр"),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: _historyFilterSemester,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.event_note_outlined)),
                    items: const [
                      DropdownMenuItem<int>(
                          value: null, child: Text("Все семестры")),
                      DropdownMenuItem<int>(value: 1, child: Text("1 семестр")),
                      DropdownMenuItem<int>(value: 2, child: Text("2 семестр")),
                    ],
                    onChanged: (value) =>
                        setState(() => _historyFilterSemester = value),
                  ),
                  const SizedBox(height: 4),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _journalVisibleFrom == null
                              ? _clearJournalVisualOnly
                              : _resetJournalVisibility,
                          icon: Icon(
                            _journalVisibleFrom == null
                                ? Icons.cleaning_services_outlined
                                : Icons.restore_outlined,
                          ),
                          label: Text(
                            _journalVisibleFrom == null
                                ? "Очистить журнал (визуально)"
                                : "Показать весь журнал",
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_journalVisibleFrom != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      "Показываются записи с ${_journalVisibleFrom!.toString().split(' ')[0]}",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: displayItems.isEmpty
              ? SliverToBoxAdapter(
                  child: SizedBox(
                    height: 240,
                    child: Center(
                        child: Text("По выбранным фильтрам ничего не найдено",
                            style: Theme.of(context).textTheme.bodyMedium)),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = displayItems[index];
                      final g = item.current;
                      final bool isEdited = item.historyEntries.isNotEmpty;
                      final theme = Theme.of(context);

                      final studentName = studentsById[g.studentId]?.fullName ??
                          'Неизвестный студент';
                      final normName =
                          normsById[g.normId]?.name ?? 'Неизвестный норматив';

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                                color: theme.colorScheme.outlineVariant
                                    .withOpacity(0.5))),
                        child: Theme(
                          data: Theme.of(context)
                              .copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            leading: _getScoreIcon(g.score),
                            title: Text(studentName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              "$normName • ${(g.academicYear.isEmpty ? _defaultAcademicYear() : g.academicYear)} • ${g.course} курс / ${g.semester} семестр — ${g.date.toString().split(' ')[0]}",
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color:
                                      _getScoreColor(g.score).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text("${g.score}",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _getScoreColor(g.score),
                                      fontSize: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.fontSize)),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    ..._buildScoreSummaryChips(
                                      currentScore: g.score,
                                      entries: item.historyEntries,
                                      theme: theme,
                                    ),
                                    if (item.historyEntries.isNotEmpty)
                                      const SizedBox(height: 12),
                                    if (g.comment != null &&
                                        g.comment!.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                            color: theme.colorScheme
                                                .surfaceContainerHighest,
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        child: Text(g.comment!),
                                      ),
                                    if (isEdited) ...[
                                      const SizedBox(height: 16),
                                      Text("История изменений:",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme
                                                  .onSurfaceVariant)),
                                      const SizedBox(height: 8),
                                      ..._buildHistoryTimeline(
                                        currentScore: g.score,
                                        entries: item.historyEntries,
                                        theme: theme,
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: displayItems.length,
                  ),
                ),
        ),
      ],
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 4) return Colors.green;
    if (score == 3) return Colors.orange;
    return Colors.red;
  }

  Icon _getScoreIcon(int score) {
    if (score >= 4)
      return const Icon(Icons.sentiment_satisfied_alt, color: Colors.green);
    if (score == 3)
      return const Icon(Icons.sentiment_neutral, color: Colors.orange);
    return const Icon(Icons.sentiment_dissatisfied, color: Colors.red);
  }

  List<_HistoryEntry> _normalizeHistoryEntries(Grade grade) {
    final entries = <_HistoryEntry>[];
    for (final raw in grade.history) {
      final scoreRaw = raw['score'];
      final dateRaw = raw['date'];
      final parsedScore = scoreRaw is num
          ? scoreRaw.toInt()
          : int.tryParse(scoreRaw?.toString() ?? '');
      final parsed = DateTime.tryParse(dateRaw?.toString() ?? '');
      if (parsedScore == null || parsed == null) continue;
      // Skip pseudo-history points equal to current grade state at same timestamp.
      final sameScore = parsedScore == grade.score;
      final sameMoment = parsed.toUtc().toIso8601String() ==
          grade.date.toUtc().toIso8601String();
      if (sameScore && sameMoment) continue;
      entries.add(_HistoryEntry(score: parsedScore, date: parsed));
    }

    return _dedupeAndSortHistory(entries);
  }

  List<_GradeDisplayItem> _buildGradeDisplayItems(List<Grade> grades) {
    final grouped = <String, List<Grade>>{};
    for (final g in grades) {
      final key =
          '${g.studentId}_${g.normId}_${g.academicYear}_${g.course}_${g.semester}';
      grouped.putIfAbsent(key, () => <Grade>[]).add(g);
    }

    final result = <_GradeDisplayItem>[];
    for (final bucket in grouped.values) {
      bucket.sort((a, b) => b.date.compareTo(a.date));
      final current = bucket.first;
      final history = <_HistoryEntry>[
        ..._normalizeHistoryEntries(current),
        ...bucket
            .skip(1)
            .map((old) => _HistoryEntry(score: old.score, date: old.date)),
      ];

      result.add(
        _GradeDisplayItem(
          current: current,
          historyEntries: _dedupeAndSortHistory(history),
        ),
      );
    }

    result.sort((a, b) => b.current.date.compareTo(a.current.date));
    return result;
  }

  List<_HistoryEntry> _dedupeAndSortHistory(List<_HistoryEntry> entries) {
    final unique = <String, _HistoryEntry>{};
    for (final e in entries) {
      unique['${e.score}_${e.date.toUtc().toIso8601String()}'] = e;
    }
    final result = unique.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  List<Widget> _buildHistoryTimeline({
    required int currentScore,
    required List<_HistoryEntry> entries,
    required ThemeData theme,
  }) {
    final widgets = <Widget>[];
    var newerScore = currentScore;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final delta = newerScore - entry.score;
      final isUp = delta > 0;
      final isDown = delta < 0;
      final Color accent = isUp
          ? Colors.green
          : (isDown ? Colors.red : theme.colorScheme.outline);
      final IconData trendIcon = isUp
          ? Icons.trending_up
          : (isDown ? Icons.trending_down : Icons.trending_flat);

      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              Icon(trendIcon, size: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Был балл: ${entry.score} (${entry.date.toString().split(' ')[0]})",
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: theme.textTheme.bodySmall?.fontSize,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      newerScore = entry.score;
    }

    return widgets;
  }

  List<Widget> _buildScoreSummaryChips({
    required int currentScore,
    required List<_HistoryEntry> entries,
    required ThemeData theme,
  }) {
    final chips = <Widget>[
      _summaryChip(
        label: "Текущий балл: $currentScore",
        fg: _getScoreColor(currentScore),
        bg: _getScoreColor(currentScore).withOpacity(0.12),
      ),
    ];

    if (entries.isNotEmpty) {
      final latestPrevious = entries
          .firstWhere(
            (e) => e.score != currentScore,
            orElse: () => entries.first,
          )
          .score;
      final delta = currentScore - latestPrevious;
      final deltaText = delta > 0
          ? "Изменение: +$delta"
          : (delta < 0 ? "Изменение: $delta" : "Изменение: 0");
      final deltaColor = delta > 0
          ? Colors.green
          : (delta < 0 ? Colors.red : theme.colorScheme.outline);
      chips.add(
        _summaryChip(
          label: deltaText,
          fg: deltaColor,
          bg: deltaColor.withOpacity(0.12),
        ),
      );
    }

    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips,
      ),
    ];
  }

  Widget _summaryChip({
    required String label,
    required Color fg,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  // --- TAB 3: Norms Management ---
  Widget _buildNormsTab() {
    final visibleNorms = _showOnlyActiveNorms
        ? _norms.where((n) => n.isActive).toList()
        : _norms.where((n) => !n.isActive).toList();
    final activeCount = _norms.where((n) => n.isActive).length;
    final blockedCount = _norms.length - activeCount;

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(
          "Нормативы",
          icon: Icons.rule_outlined,
          subtitle: "Актуальный перечень нормативов для оценки",
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  label: Text("Доступные ($activeCount)"),
                  selected: _showOnlyActiveNorms,
                  onSelected: (_) => setState(() => _showOnlyActiveNorms = true),
                ),
                ChoiceChip(
                  label: Text("Недоступные ($blockedCount)"),
                  selected: !_showOnlyActiveNorms,
                  onSelected: (_) => setState(() => _showOnlyActiveNorms = false),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              _showOnlyActiveNorms
                  ? "Показаны: доступные"
                  : "Показаны: недоступные",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),
        if (_norms.isEmpty)
          const SliverFillRemaining(
              child: Center(child: Text("Список нормативов пуст"))),
        if (_norms.isNotEmpty && visibleNorms.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Text(
                _showOnlyActiveNorms
                    ? "Нет доступных нормативов"
                    : "Нет недоступных нормативов",
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final n = visibleNorms[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              shape: BoxShape.circle),
                          child: Icon(Icons.fitness_center,
                              color:
                                  Theme.of(context).colorScheme.onPrimaryContainer,
                              size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                                softWrap: true,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                n.isActive ? "Активен" : "Заблокирован",
                                style: TextStyle(
                                  color: n.isActive
                                      ? Colors.green
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip:
                                  n.isActive ? "Заблокировать" : "Разблокировать",
                              icon: Icon(
                                n.isActive ? Icons.lock_outline : Icons.lock_open,
                                color: n.isActive
                                    ? Theme.of(context).colorScheme.onSurfaceVariant
                                    : Colors.green,
                              ),
                              onPressed: () async {
                                try {
                                  await _api.updateNormStatus(n.id, !n.isActive);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        !n.isActive
                                            ? 'Норматив "${n.name}" разблокирован'
                                            : 'Норматив "${n.name}" заблокирован',
                                      ),
                                    ),
                                  );
                                  _loadData(showLoader: false);
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Ошибка: $e")),
                                  );
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () async {
                                final shouldDelete = await _confirmDeleteNorm(n.name);
                                if (!shouldDelete) return;
                                await _api.deleteNorm(n.id);
                                _loadData(showLoader: false);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: visibleNorms.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 88),
        ),
      ],
    );
  }

  Future<bool> _confirmDeleteNorm(String normName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтверждение удаления'),
        content: Text('Вы точно хотите удалить норматив "$normName"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Удалить')),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _showAddNormDialog(BuildContext context) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Добавить норматив"),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(labelText: "Название"),
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return 'Введите название';
              final duplicateExists = _norms.any(
                (n) => n.name.trim().toLowerCase() == value.toLowerCase(),
              );
              if (duplicateExists) {
                return 'Норматив с таким названием уже существует';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  await _api.createNorm(controller.text.trim());
                  _loadData();
                  if (mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text(e.toString().replaceFirst('Exception: ', '')),
                    ),
                  );
                }
              }
            },
            child: const Text("Создать"),
          ),
        ],
      ),
    );
  }
}

class _HistoryEntry {
  final int score;
  final DateTime date;

  const _HistoryEntry({
    required this.score,
    required this.date,
  });
}

class _GradeDisplayItem {
  final Grade current;
  final List<_HistoryEntry> historyEntries;

  const _GradeDisplayItem({
    required this.current,
    required this.historyEntries,
  });
}

class _GradeForm extends StatefulWidget {
  final List<User> students;
  final List<Norm> norms;
  final List<Faculty> faculties;
  final List<Group> groups;
  final List<Grade> grades;
  final String teacherId;
  final Future<void> Function() onGradeAdded;

  const _GradeForm({
    required this.students,
    required this.norms,
    required this.faculties,
    required this.groups,
    required this.grades,
    required this.teacherId,
    required this.onGradeAdded,
  });

  @override
  State<_GradeForm> createState() => _GradeFormState();
}

class _GradeFormState extends State<_GradeForm>
    with AutomaticKeepAliveClientMixin<_GradeForm> {
  String? _selectedFacultyId;
  String? _selectedGroupId;
  String? _selectedStudentId;
  String? _selectedNormId;
  String _studentSearchQuery = '';
  final TextEditingController _studentSearchController = TextEditingController();
  late String _selectedAcademicYear;
  final List<String> _customAcademicYears = <String>[];
  int _selectedCourse = 1;
  int _selectedSemester = 1;
  int _score = 5;
  String? _existingGradeHint;
  final _commentController = TextEditingController();

  Widget _filterLabel(String text) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
            letterSpacing: 0.2,
          ) ??
          TextStyle(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
    );
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
      ..._customAcademicYears,
    }.toList();
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  String get _customYearsStorageKey =>
      'teacher_custom_academic_years_${widget.teacherId}';

  Future<void> _loadCustomAcademicYears() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_customYearsStorageKey) ?? const [];
    if (!mounted) return;
    setState(() {
      _customAcademicYears
        ..clear()
        ..addAll(stored.where(_isValidAcademicYear));
      final options = _academicYearOptions();
      if (!options.contains(_selectedAcademicYear)) {
        _selectedAcademicYear = _defaultAcademicYear();
      }
    });
  }

  Future<void> _saveCustomAcademicYears() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_customYearsStorageKey, _customAcademicYears);
  }

  bool _isValidAcademicYear(String value) {
    final match = RegExp(r'^(\d{4})/(\d{4})$').firstMatch(value);
    if (match == null) return false;
    final start = int.tryParse(match.group(1)!);
    final end = int.tryParse(match.group(2)!);
    if (start == null || end == null) return false;
    return end == start + 1;
  }

  Future<void> _addAcademicYear() async {
    final controller = TextEditingController(text: _defaultAcademicYear());
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Добавить учебный год"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Например: 2027/2028",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Отмена"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text("Добавить"),
          ),
        ],
      ),
    );
    if (!mounted || result == null) return;
    if (!_isValidAcademicYear(result)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Формат: YYYY/YYYY+1, например 2027/2028"),
        ),
      );
      return;
    }
    setState(() {
      if (!_customAcademicYears.contains(result)) {
        _customAcademicYears.add(result);
      }
      _selectedAcademicYear = result;
    });
    await _saveCustomAcademicYears();
  }

  Future<void> _removeAcademicYear(String year) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Удалить учебный год?"),
        content: Text("Удалить из пользовательского списка: $year"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Отмена"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Удалить"),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _customAcademicYears.remove(year);
      if (_selectedAcademicYear == year) {
        _selectedAcademicYear = _defaultAcademicYear();
      }
    });
    await _saveCustomAcademicYears();
  }

  Future<void> _manageAcademicYears() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Пользовательские учебные годы"),
        content: SizedBox(
          width: 420,
          child: _customAcademicYears.isEmpty
              ? const Text("Список пуст. Добавьте год через кнопку +")
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _customAcademicYears.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final year = _customAcademicYears[index];
                    return ListTile(
                      dense: true,
                      title: Text(year),
                      trailing: IconButton(
                        tooltip: "Удалить",
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _removeAcademicYear(year);
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Закрыть"),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedAcademicYear = _defaultAcademicYear();
    _loadCustomAcademicYears();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _studentSearchController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Grade? _latestGradeForSelection() {
    if (_selectedStudentId == null || _selectedNormId == null) return null;

    final matches = widget.grades
        .where((g) =>
            g.studentId == _selectedStudentId && g.normId == _selectedNormId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return matches.isEmpty ? null : matches.first;
  }

  void _applyExistingGradeIfAny() {
    final latestGrade = _latestGradeForSelection();
    if (latestGrade == null) {
      _existingGradeHint = null;
      return;
    }

    final academicYear = latestGrade.academicYear.trim().isEmpty
        ? _defaultAcademicYear()
        : latestGrade.academicYear.trim();

    if (!_customAcademicYears.contains(academicYear) &&
        !_academicYearOptions().contains(academicYear)) {
      _customAcademicYears.add(academicYear);
      _saveCustomAcademicYears();
    }

    _selectedAcademicYear = academicYear;
    _selectedCourse = latestGrade.course;
    _selectedSemester = latestGrade.semester;
    _score = latestGrade.score;
    _commentController.text = latestGrade.comment ?? '';
    _existingGradeHint =
        'Найден уже проставленный результат: $academicYear, ${latestGrade.course} курс, ${latestGrade.semester} семестр, ${latestGrade.score} ${_getScoreSuffix(latestGrade.score)}. Можно только повысить балл.';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final selectedFacultyName = _selectedFacultyId == null
        ? null
        : widget.faculties
            .firstWhere((f) => f.id == _selectedFacultyId,
                orElse: () => Faculty(id: '', name: ''))
            .name;
    final selectedGroupName = _selectedGroupId == null
        ? null
        : widget.groups
            .firstWhere((g) => g.id == _selectedGroupId,
                orElse: () => Group(id: '', name: '', facultyId: ''))
            .name;

    final studentQuery = _studentSearchQuery.trim().toLowerCase();
    final filteredStudents = widget.students.where((s) {
      final facultyMatched = _selectedFacultyId == null
          ? true
          : ((s.facultyId != null && s.facultyId == _selectedFacultyId) ||
              (selectedFacultyName != null &&
                  selectedFacultyName.isNotEmpty &&
                  s.faculty == selectedFacultyName));
      final groupMatched = _selectedGroupId == null
          ? true
          : ((s.groupId != null && s.groupId == _selectedGroupId) ||
              (selectedGroupName != null &&
                  selectedGroupName.isNotEmpty &&
                  s.group == selectedGroupName));
      if (!facultyMatched) return false;
      if (!groupMatched) return false;
      if (studentQuery.isNotEmpty &&
          !_studentSearchText(s).contains(studentQuery)) return false;
      return true;
    }).toList();

    final groupsForFaculty = _selectedFacultyId == null
        ? widget.groups
        : widget.groups
            .where((g) => g.facultyId == _selectedFacultyId)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _studentSearchController,
          onChanged: (value) => setState(() {
            _studentSearchQuery = value;
            final nextQuery = value.trim().toLowerCase();
            if (_selectedStudentId != null) {
              final stillVisible = widget.students.any((s) {
                final facultyMatched = _selectedFacultyId == null
                    ? true
                    : ((s.facultyId != null &&
                            s.facultyId == _selectedFacultyId) ||
                        (selectedFacultyName != null &&
                            selectedFacultyName.isNotEmpty &&
                            s.faculty == selectedFacultyName));
                final groupMatched = _selectedGroupId == null
                    ? true
                    : ((s.groupId != null && s.groupId == _selectedGroupId) ||
                        (selectedGroupName != null &&
                            selectedGroupName.isNotEmpty &&
                            s.group == selectedGroupName));
                return s.id == _selectedStudentId &&
                    facultyMatched &&
                    groupMatched &&
                    (nextQuery.isEmpty ||
                        _studentSearchText(s).contains(nextQuery));
              });
              if (!stillVisible) {
                _selectedStudentId = null;
                _existingGradeHint = null;
              }
            }
          }),
          decoration: const InputDecoration(
            labelText: "Поиск студента по ФИО",
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          initiallyExpanded: _selectedFacultyId != null || _selectedGroupId != null,
          leading: const Icon(Icons.tune),
          title: const Text("Фильтры"),
          subtitle: Text(
            "Факультет и группа",
            style: Theme.of(context).textTheme.bodySmall,
          ),
          children: [
            _filterLabel("Факультет"),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedFacultyId,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.domain_outlined)),
              items: [
                const DropdownMenuItem<String>(
                    value: null, child: Text("Все факультеты")),
                ...widget.faculties.map(
                  (f) => DropdownMenuItem(
                    value: f.id,
                    child: Text(
                      f.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (v) => setState(() {
                _selectedFacultyId = v;
                _selectedGroupId = null;
                _selectedStudentId = null;
                _existingGradeHint = null;
              }),
            ),
            const SizedBox(height: 12),
            _filterLabel("Направление / группа"),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedGroupId,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.groups_outlined)),
              items: [
                const DropdownMenuItem<String>(
                    value: null, child: Text("Все направления")),
                ...groupsForFaculty.map(
                  (g) => DropdownMenuItem(
                    value: g.id,
                    child: Text(
                      g.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (v) => setState(() {
                _selectedGroupId = v;
                _selectedStudentId = null;
                _existingGradeHint = null;
              }),
            ),
            const SizedBox(height: 4),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: filteredStudents.any((s) => s.id == _selectedStudentId)
              ? _selectedStudentId
              : null,
          decoration: const InputDecoration(
            labelText: "Студент",
            helperText: "В списке показаны студенты по введенному ФИО",
            prefixIcon: Icon(Icons.person),
          ),
          items: filteredStudents
              .map(
                (s) => DropdownMenuItem(
                  value: s.id,
                  child: Text(
                    s.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() {
            _selectedStudentId = v;
            _applyExistingGradeIfAny();
          }),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: widget.norms.any((n) => n.id == _selectedNormId)
              ? _selectedNormId
              : null,
          decoration: const InputDecoration(
              labelText: "Норматив", prefixIcon: Icon(Icons.rule)),
          items: widget.norms
              .map(
                (n) => DropdownMenuItem(
                  value: n.id,
                  child: Text(
                    n.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() {
            _selectedNormId = v;
            _applyExistingGradeIfAny();
          }),
        ),
        if (_existingGradeHint != null) ...[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _existingGradeHint!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: _selectedAcademicYear,
          decoration: InputDecoration(
            labelText: "Учебный год",
            prefixIcon: const Icon(Icons.calendar_today_outlined),
            suffixIcon: SizedBox(
              width: 88,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: "Добавить учебный год",
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _addAcademicYear,
                  ),
                  IconButton(
                    tooltip: "Управление списком годов",
                    icon: const Icon(Icons.edit_calendar_outlined),
                    onPressed: _manageAcademicYears,
                  ),
                ],
              ),
            ),
          ),
          items: _academicYearOptions()
              .map(
                (y) => DropdownMenuItem(
                  value: y,
                  child: Text(y),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => _selectedAcademicYear = v);
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                value: _selectedCourse,
                decoration: const InputDecoration(
                  labelText: "Курс",
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text("1 курс")),
                  DropdownMenuItem(value: 2, child: Text("2 курс")),
                  DropdownMenuItem(value: 3, child: Text("3 курс")),
                  DropdownMenuItem(value: 4, child: Text("4 курс")),
                  DropdownMenuItem(value: 5, child: Text("5 курс")),
                  DropdownMenuItem(value: 6, child: Text("6 курс")),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _selectedCourse = v);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                value: _selectedSemester,
                decoration: const InputDecoration(
                  labelText: "Семестр",
                  prefixIcon: Icon(Icons.event_note_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text("1 семестр")),
                  DropdownMenuItem(value: 2, child: Text("2 семестр")),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _selectedSemester = v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text("Оценка:",
            style: TextStyle(
                fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize,
                fontWeight: FontWeight.bold)),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveTrackColor: Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withOpacity(0.35),
            thumbColor: Theme.of(context).colorScheme.primary,
            overlayColor:
                Theme.of(context).colorScheme.primary.withOpacity(0.18),
            valueIndicatorColor: Theme.of(context).colorScheme.primaryContainer,
            valueIndicatorTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
            trackHeight: 4.0,
          ),
          child: Slider(
            value: _score.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: _score.toString(),
            onChanged: (v) => setState(() => _score = v.toInt()),
          ),
        ),
        Center(
            child: Text("$_score ${_getScoreSuffix(_score)}",
                style: TextStyle(
                    fontSize:
                        Theme.of(context).textTheme.headlineMedium?.fontSize,
                    fontWeight: FontWeight.bold))),
        const SizedBox(height: 16),
        TextField(
          controller: _commentController,
          decoration:
              const InputDecoration(labelText: "Комментарий (необязательно)"),
          maxLines: 2,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _submit,
          child: const Text("Поставить оценку"),
        ),
      ],
    );
  }

  String _getScoreSuffix(int score) {
    if (score == 1) return "балл";
    if (score >= 2 && score <= 4) return "балла";
    return "баллов";
  }

  Future<void> _submit() async {
    if (_selectedStudentId == null || _selectedNormId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Выберите студента и норматив")));
      return;
    }

    try {
      await ApiService().createGrade(
        studentId: _selectedStudentId!,
        normId: _selectedNormId!,
        academicYear: _selectedAcademicYear,
        course: _selectedCourse,
        semester: _selectedSemester,
        score: _score,
        comment: _commentController.text,
      );

      await widget.onGradeAdded();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Оценка сохранена")));
      setState(() => _applyExistingGradeIfAny());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }
}
