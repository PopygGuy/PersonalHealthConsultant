import 'package:flutter/material.dart';
import '../../services/session_service.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import '../../models/user.dart';
import '../../models/faculty.dart';
import '../../models/group.dart';
import '../../models/user_role.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/app_theme_selector_card.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;
  final _api = ApiService();
  final TextEditingController _studentSearchController = TextEditingController();
  String _studentSearchQuery = '';
  String? _studentFilterFacultyId;
  String? _studentFilterGroupId;

  // Local state for data
  List<User> _teachers = [];
  List<User> _students = [];
  List<Faculty> _faculties = [];
  List<Group> _groups = [];
  bool _isLoading = true;
  bool _isRepairingCatalog = false;
  Map<String, dynamic>? _lastCatalogRepairReport;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final teachers = await _api.getUsers(role: 'teacher');
      final students = await _api.getUsers(role: 'student');
      final faculties = await _api.getFaculties();
      final groups = await _api.getGroups();

      setState(() {
        _teachers = teachers;
        _students = students;
        _faculties = faculties;
        _groups = groups;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _studentSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompactNav = width < 430;
    final double navLabelSize = width < 380 ? 8.5 : (width < 600 ? 10.0 : 14.0);

    return Scaffold(
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : _buildBody(),
      floatingActionButton: _buildFab(),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: navLabelSize, 
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
            );
          }),
        ),
        child: NavigationBar(
          height: isCompactNav ? 72 : null,
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.school_outlined),
              selectedIcon: const Icon(Icons.school),
              label: isCompactNav ? 'Препод.' : 'Преподаватели',
            ),
            const NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Студенты',
            ),
            NavigationDestination(
              icon: const Icon(Icons.domain_outlined),
              selectedIcon: const Icon(Icons.domain),
              label: isCompactNav ? 'Фак.' : 'Факультеты',
            ),
            const NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: 'Группы',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Профиль',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return switch (_currentIndex) {
      0 => _buildTeachersTab(),
      1 => _buildStudentsTab(),
      2 => _buildFacultiesTab(),
      3 => _buildGroupsTab(),
      4 => _buildProfileTab(),
      _ => const Center(child: Text("Ошибка")),
    };
  }

  Widget? _buildFab() {
    return switch (_currentIndex) {
      0 => FloatingActionButton(onPressed: _showAddTeacherDialog, child: const Icon(Icons.add)),
      1 => FloatingActionButton(onPressed: _showAddStudentDialog, child: const Icon(Icons.add)),
      2 => FloatingActionButton(onPressed: _showAddFacultyDialog, child: const Icon(Icons.add)),
      3 => FloatingActionButton(onPressed: _showAddGroupDialog, child: const Icon(Icons.add)),
      _ => null,
    };
  }

  Future<bool> _confirmDelete({required String title, required String content}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  String? _validateLogin(String? value) {
    final login = value?.trim() ?? '';
    if (login.isEmpty) return 'Введите логин';
    final loginRegex = RegExp(r'^[a-zA-Z0-9._]{3,32}$');
    if (!loginRegex.hasMatch(login)) {
      return 'Логин: 3-32 символа, латиница/цифры/._';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value?.trim() ?? '';
    if (password.isEmpty) return 'Введите пароль';
    if (password.length < 4) return 'Пароль должен быть не короче 4 символов';
    return null;
  }

  String? _validateFullName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Введите ФИО';
    return null;
  }

  String _normalizeFacultyName(String name) {
    return name
        .toLowerCase()
        .replaceAll('факультет', '')
        .replaceAll(RegExp(r'[\s\-_]+'), ' ')
        .trim();
  }

  List<Group> _groupsForFacultyId(String? facultyId) {
    if (facultyId == null || facultyId.isEmpty) return [];
    final direct = _groups.where((g) => g.facultyId == facultyId).toList();
    if (direct.isNotEmpty) return direct;

    // Fallback for duplicated faculty rows with same semantic name.
    final selected = _faculties.firstWhere(
      (f) => f.id == facultyId,
      orElse: () => Faculty(id: '', name: ''),
    );
    if (selected.id.isEmpty || selected.name.trim().isEmpty) return direct;

    final selectedNorm = _normalizeFacultyName(selected.name);
    if (selectedNorm.isEmpty) return direct;

    final sameSemanticFacultyIds = _faculties
        .where((f) => _normalizeFacultyName(f.name) == selectedNorm)
        .map((f) => f.id)
        .toSet();
    if (sameSemanticFacultyIds.isEmpty) return direct;

    return _groups.where((g) => sameSemanticFacultyIds.contains(g.facultyId)).toList();
  }

  // --- REUSABLE SLIVER HEADER ---
  Widget _buildSliverAppBar(
    String title, {
    List<Widget>? actions,
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
            child: Icon(icon, size: 18, color: theme.colorScheme.onPrimaryContainer),
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
      actions: actions,
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
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(
          "Профиль администратора",
          icon: Icons.admin_panel_settings_outlined,
          subtitle: "Управление пользователями и структурой обучения",
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.admin_panel_settings_outlined)),
                    title: const Text("Администратор", style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text("Управление пользователями и структурами"),
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
                        Chip(label: Text("Преподавателей: ${_teachers.length}")),
                        Chip(label: Text("Студентов: ${_students.length}")),
                        Chip(label: Text("Факультетов: ${_faculties.length}")),
                        Chip(label: Text("Групп: ${_groups.length}")),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const AppThemeSelectorCard(),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isRepairingCatalog
                      ? null
                      : () async {
                          setState(() => _isRepairingCatalog = true);
                          try {
                            final report = await _api.repairCatalog();
                            await _loadData();
                            if (!mounted) return;
                            setState(() => _lastCatalogRepairReport = report);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  report['message']?.toString() ??
                                      'Справочники восстановлены',
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString().replaceFirst('Exception: ', ''),
                                ),
                              ),
                            );
                          } finally {
                            if (mounted) {
                              setState(() => _isRepairingCatalog = false);
                            }
                          }
                        },
                  icon: _isRepairingCatalog
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_fix_high),
                  label: Text(
                    _isRepairingCatalog
                        ? "Восстанавливаю справочники..."
                        : "Починить справочники",
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    if (_lastCatalogRepairReport == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Сначала запустите "Починить справочники"',
                          ),
                        ),
                      );
                      return;
                    }
                    _showCatalogRepairReport(_lastCatalogRepairReport!);
                  },
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text("Показать отчёт"),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    await SessionService().clearSession();
                    if (!mounted) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
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

  void _showCatalogRepairReport(Map<String, dynamic> report) {
    final seed = report['seed'] is Map<String, dynamic>
        ? report['seed'] as Map<String, dynamic>
        : <String, dynamic>{};
    final dedupe = report['dedupe'] is Map<String, dynamic>
        ? report['dedupe'] as Map<String, dynamic>
        : <String, dynamic>{};

    final seedAddedFaculties = seed['added_faculties'] ?? 0;
    final seedAddedGroups = seed['added_groups'] ?? 0;
    final seedRelinkedGroups = seed['relinked_groups'] ?? 0;
    final seedAddedNorms = seed['added_norms'] ?? 0;
    final totalFaculties = seed['total_faculties'] ?? dedupe['total_faculties'] ?? _faculties.length;
    final totalGroups = seed['total_groups'] ?? _groups.length;
    final totalNorms = seed['total_norms'] ?? 0;

    final dedupeDeleted = dedupe['deleted_duplicate_faculties'] ?? 0;
    final dedupeRelinkedGroups = dedupe['relinked_groups'] ?? 0;
    final dedupeRelinkedUsers = dedupe['relinked_users'] ?? 0;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Отчёт по восстановлению"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report['message']?.toString() ??
                    'Справочники факультетов и групп восстановлены',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text("Seed:", style: Theme.of(context).textTheme.titleSmall),
              Text(" - Добавлено факультетов: $seedAddedFaculties"),
              Text(" - Добавлено групп: $seedAddedGroups"),
              Text(" - Перепривязано групп: $seedRelinkedGroups"),
              Text(" - Добавлено нормативов: $seedAddedNorms"),
              const SizedBox(height: 8),
              Text("Deduplicate:", style: Theme.of(context).textTheme.titleSmall),
              Text(" - Удалено дублей факультетов: $dedupeDeleted"),
              Text(" - Перепривязано групп: $dedupeRelinkedGroups"),
              Text(" - Перепривязано пользователей: $dedupeRelinkedUsers"),
              const SizedBox(height: 8),
              Text("Итоги:", style: Theme.of(context).textTheme.titleSmall),
              Text(" - Всего факультетов: $totalFaculties"),
              Text(" - Всего групп: $totalGroups"),
              Text(" - Всего нормативов: $totalNorms"),
            ],
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

  Widget _buildSummaryBlock({required String title, required String count, required IconData icon, Color? color}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final blockColor = color ?? colorScheme.surfaceContainerHighest;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: blockColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: colorScheme.primary, size: 32),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                  Text(count, style: theme.textTheme.headlineMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(message, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildFabBottomSpacer() {
    return const SliverToBoxAdapter(
      child: SizedBox(height: 96),
    );
  }

  Widget _buildTeachersTab() {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width > 900 ? 3 : (width > 600 ? 2 : 1);
    final isMobile = crossAxisCount == 1;

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(
          "Преподаватели",
          icon: Icons.school_outlined,
          subtitle: "Добавляйте, редактируйте и удаляйте учетные записи",
        ),
        _buildSummaryBlock(
          title: "Всего преподавателей",
          count: _teachers.length.toString(),
          icon: Icons.school,
        ),
        if (_teachers.isEmpty) 
          _buildEmptyState("Нет преподавателей. Добавьте первого!"),
        
        if (_teachers.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: isMobile 
              ? SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildTeacherCard(_teachers[index]),
                    childCount: _teachers.length,
                  ),
                )
              : SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 200,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildTeacherCard(_teachers[index]),
                    childCount: _teachers.length,
                  ),
                ),
          ),
        _buildFabBottomSpacer(),
      ],
    );
  }

  Widget _buildTeacherCard(User t) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            UserAvatar(
              displayName: t.fullName,
              seed: t.id.isNotEmpty ? t.id : t.login,
              role: UserRole.teacher,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(t.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    "Логин: ${t.login}",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: "Редактировать",
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showEditTeacherDialog(t),
                ),
                IconButton(
                  tooltip: "Удалить",
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    final confirmed = await _confirmDelete(
                      title: 'Удалить преподавателя?',
                      content: 'Вы точно хотите удалить преподавателя "${t.fullName}"?',
                    );
                    if (confirmed) {
                      await _api.deleteUser(t.id);
                      _loadData();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsTab() {
    final selectedFaculty = _studentFilterFacultyId == null
        ? null
        : _faculties.firstWhere(
            (f) => f.id == _studentFilterFacultyId,
            orElse: () => Faculty(id: '', name: ''),
          );
    final selectedGroup = _studentFilterGroupId == null
        ? null
        : _groups.firstWhere(
            (g) => g.id == _studentFilterGroupId,
            orElse: () => Group(id: '', name: '', facultyId: ''),
          );

    final selectedFacultyName = selectedFaculty?.name;
    final selectedGroupName = selectedGroup?.name;
    final search = _studentSearchQuery.trim().toLowerCase();
    final groupsForSelectedFaculty = _studentFilterFacultyId == null
        ? _groups
        : _groupsForFacultyId(_studentFilterFacultyId);

    final filteredStudents = _students.where((s) {
      if (_studentFilterFacultyId != null) {
        final byId = s.facultyId != null && s.facultyId == _studentFilterFacultyId;
        final byName = selectedFacultyName != null &&
            selectedFacultyName.isNotEmpty &&
            s.faculty != null &&
            s.faculty == selectedFacultyName;
        if (!byId && !byName) return false;
      }

      if (_studentFilterGroupId != null) {
        final byId = s.groupId != null && s.groupId == _studentFilterGroupId;
        final byName = selectedGroupName != null &&
            selectedGroupName.isNotEmpty &&
            s.group != null &&
            s.group == selectedGroupName;
        if (!byId && !byName) return false;
      }

      if (search.isNotEmpty) {
        final haystack = '${s.fullName} ${s.login} ${s.faculty ?? ''} ${s.group ?? ''}'.toLowerCase();
        if (!haystack.contains(search)) return false;
      }

      return true;
    }).toList();

    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width > 900 ? 3 : (width > 600 ? 2 : 1);
    final isMobile = crossAxisCount == 1;

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(
          "Студенты",
          icon: Icons.people_outline,
          subtitle: "Контроль состава групп и учебных направлений",
        ),
        _buildSummaryBlock(
          title: "Всего студентов",
          count: _students.length.toString(),
          icon: Icons.people,
          color: Theme.of(context).colorScheme.tertiaryContainer,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _studentFilterFacultyId,
                  decoration: const InputDecoration(
                    labelText: "Факультет",
                    prefixIcon: Icon(Icons.domain_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text("Все факультеты")),
                    ..._faculties.map(
                      (f) => DropdownMenuItem<String>(
                        value: f.id,
                        child: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _studentFilterFacultyId = value;
                      _studentFilterGroupId = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _studentFilterGroupId,
                  decoration: const InputDecoration(
                    labelText: "Группа",
                    prefixIcon: Icon(Icons.groups_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text("Все группы")),
                    ...groupsForSelectedFaculty.map(
                      (g) => DropdownMenuItem<String>(
                        value: g.id,
                        child: Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _studentFilterGroupId = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _studentSearchController,
                  onChanged: (value) => setState(() => _studentSearchQuery = value),
                  decoration: InputDecoration(
                    labelText: 'Поиск по ФИО, логину',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _studentSearchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _studentSearchController.clear();
                              setState(() => _studentSearchQuery = '');
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (filteredStudents.isEmpty)
           _buildEmptyState("Студенты не найдены"),
        if (filteredStudents.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: isMobile
              ? SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildStudentCard(filteredStudents[index]),
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
                    (context, index) => _buildStudentCard(filteredStudents[index]),
                    childCount: filteredStudents.length,
                  ),
                ),
          ),
        _buildFabBottomSpacer(),
      ],
    );
  }

  Widget _buildStudentCard(User s) {
    return Card(
      child: InkWell(
        onTap: () => _showEditStudentDialog(s),
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
                  children: [
                    Text(s.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                    Text(s.login, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: "Редактировать",
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _showEditStudentDialog(s),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                       final confirmed = await _confirmDelete(
                        title: 'Удалить студента?',
                        content: 'Вы точно хотите удалить студента "${s.fullName}"?',
                      );
                      if (confirmed) {
                        await _api.deleteUser(s.id);
                        _loadData();
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditTeacherDialog(User teacher) {
    final nameCtrl = TextEditingController(text: teacher.fullName);
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Редактировать преподавателя"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: teacher.login,
                enabled: false,
                decoration: const InputDecoration(labelText: "Логин"),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "ФИО"),
                validator: _validateFullName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passCtrl,
                decoration: const InputDecoration(
                  labelText: "Новый пароль (необязательно)",
                ),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return null;
                  if (value.length < 4) return 'Пароль должен быть не короче 4 символов';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final updated = await _api.updateUser(
                id: teacher.id,
                fullName: nameCtrl.text.trim(),
                password: passCtrl.text.trim().isEmpty ? null : passCtrl.text.trim(),
              );
              if (!mounted) return;
              if (updated == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Не удалось обновить преподавателя")),
                );
                return;
              }
              Navigator.pop(ctx);
              _loadData();
            },
            child: const Text("Сохранить"),
          ),
        ],
      ),
    );
  }

  void _showEditStudentDialog(User student) {
    final nameCtrl = TextEditingController(text: student.fullName);
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String? selectedFacultyId = student.facultyId;
    if (selectedFacultyId == null && student.faculty != null) {
      selectedFacultyId = _faculties
          .firstWhere((f) => f.name == student.faculty, orElse: () => Faculty(id: '', name: ''))
          .id;
      if (selectedFacultyId.isEmpty) selectedFacultyId = null;
    }

    String? selectedGroupId = student.groupId;
    if (selectedGroupId == null && student.group != null) {
      selectedGroupId = _groups
          .firstWhere((g) => g.name == student.group, orElse: () => Group(id: '', name: '', facultyId: ''))
          .id;
      if (selectedGroupId.isEmpty) selectedGroupId = null;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final groupsForFaculty = _groupsForFacultyId(selectedFacultyId);

          if (selectedGroupId != null && !groupsForFaculty.any((g) => g.id == selectedGroupId)) {
            selectedGroupId = null;
          }

          return AlertDialog(
            title: const Text("Редактировать студента"),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: student.login,
                      enabled: false,
                      decoration: const InputDecoration(labelText: "Логин"),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: "ФИО"),
                      validator: _validateFullName,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passCtrl,
                      decoration: const InputDecoration(
                        labelText: "Новый пароль (необязательно)",
                      ),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isEmpty) return null;
                        if (value.length < 4) return 'Пароль должен быть не короче 4 символов';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedFacultyId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: "Факультет"),
                      items: _faculties
                          .map(
                            (f) => DropdownMenuItem<String>(
                              value: f.id,
                              child: Text(
                                f.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setStateDialog(() {
                        selectedFacultyId = v;
                        selectedGroupId = null;
                      }),
                      validator: (v) => v == null ? 'Выберите факультет' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedGroupId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: "Группа"),
                      items: groupsForFaculty
                          .map(
                            (g) => DropdownMenuItem<String>(
                              value: g.id,
                              child: Text(
                                g.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setStateDialog(() => selectedGroupId = v),
                      validator: (v) => v == null ? 'Выберите группу' : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final updated = await _api.updateUser(
                    id: student.id,
                    fullName: nameCtrl.text.trim(),
                    password: passCtrl.text.trim().isEmpty ? null : passCtrl.text.trim(),
                    facultyId: selectedFacultyId,
                    groupId: selectedGroupId,
                  );
                  if (!mounted) return;
                  if (updated == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Не удалось обновить студента")),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  _loadData();
                },
                child: const Text("Сохранить"),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFacultiesTab() {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(
          "Факультеты",
          icon: Icons.domain_outlined,
          subtitle: "Структура вуза и направления подготовки",
        ),
        _buildSummaryBlock(title: "Всего факультетов", count: _faculties.length.toString(), icon: Icons.domain),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final f = _faculties[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: const Icon(Icons.business),
                    title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        final confirmed = await _confirmDelete(title: 'Удалить факультет?', content: 'Удалить ${f.name}?');
                        if (confirmed) {
                          try {
                            await _api.deleteFaculty(f.id);
                            await _loadData();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString().replaceFirst('Exception: ', ''),
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                );
              },
              childCount: _faculties.length,
            ),
          ),
        ),
        _buildFabBottomSpacer(),
      ],
    );
  }

  Widget _buildGroupsTab() {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(
          "Группы",
          icon: Icons.groups_outlined,
          subtitle: "Связка групп и факультетов",
        ),
        _buildSummaryBlock(title: "Всего групп", count: _groups.length.toString(), icon: Icons.groups),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final g = _groups[index];
                // Lookup faculty name
                final facultyName = _faculties
                    .firstWhere((f) => f.id == g.facultyId, orElse: () => Faculty(id: '', name: 'Без факультета'))
                    .name;

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: const Icon(Icons.class_outlined),
                    title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(facultyName, style: Theme.of(context).textTheme.bodySmall),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        final confirmed = await _confirmDelete(title: 'Удалить группу?', content: 'Удалить ${g.name}?');
                        if (confirmed) {
                          await _api.deleteGroup(g.id);
                          _loadData();
                        }
                      },
                    ),
                  ),
                );
              },
              childCount: _groups.length,
            ),
          ),
        ),
        _buildFabBottomSpacer(),
      ],
    );
  }

  void _showAddFacultyDialog() {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Добавить факультет"),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(labelText: "Название"),
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return 'Введите Название';
              final duplicateExists = _faculties.any(
                (f) => f.name.trim().toLowerCase() == value.toLowerCase(),
              );
              if (duplicateExists) {
                return 'Факультет с таким названием уже существует';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  await _api.createFaculty(controller.text.trim());
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

  void _showAddGroupDialog() {
    if (_faculties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала добавьте хотя бы один факультет')),
      );
      return;
    }

    final controller = TextEditingController();
    String? selectedFacultyId;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text("Добавить группу"),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: controller,
                    decoration: const InputDecoration(labelText: "Название"),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Введите Название';
                      final duplicateExists = _groups.any(
                        (g) => g.name.trim().toLowerCase() == value.toLowerCase(),
                      );
                      if (duplicateExists) {
                        return 'Группа с таким названием уже существует';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedFacultyId,
                    decoration: const InputDecoration(labelText: "Факультет"),
                    items: _faculties
                        .map(
                          (f) => DropdownMenuItem<String>(
                            value: f.id,
                            child: Text(
                              f.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setStateDialog(() => selectedFacultyId = v),
                    validator: (v) => v == null ? 'Выберите факультет' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await _api.createGroup(controller.text.trim(), selectedFacultyId!);
                    _loadData();
                    if (mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                    );
                  }
                }
              },
              child: const Text("Создать"),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTeacherDialog() {
    final loginCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Добавить преподавателя"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: loginCtrl, decoration: const InputDecoration(labelText: "Логин"), validator: _validateLogin),
              TextFormField(controller: passCtrl, decoration: const InputDecoration(labelText: "Пароль"), validator: _validatePassword),
              TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: "ФИО"), validator: _validateFullName),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  await _api.createUser(
                    login: loginCtrl.text.trim(),
                    password: passCtrl.text.trim(),
                    role: UserRole.teacher,
                    fullName: nameCtrl.text.trim(),
                  );
                  _loadData();
                  if (mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
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

  void _showAddStudentDialog() {
    final loginCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String? selectedFacultyId;
    String? selectedGroupId;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
           final groupsForFaculty = _groupsForFacultyId(selectedFacultyId);

           if (selectedGroupId != null && !groupsForFaculty.any((g) => g.id == selectedGroupId)) {
             selectedGroupId = null;
           }

           return AlertDialog(
            title: const Text("Добавить студента"),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(controller: loginCtrl, decoration: const InputDecoration(labelText: "Логин"), validator: _validateLogin),
                    TextFormField(controller: passCtrl, decoration: const InputDecoration(labelText: "Пароль"), validator: _validatePassword),
                    TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: "ФИО"), validator: _validateFullName),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedFacultyId,
                      decoration: const InputDecoration(labelText: "Факультет"),
                      items: _faculties
                          .map(
                            (f) => DropdownMenuItem<String>(
                              value: f.id,
                              child: Text(
                                f.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setStateDialog(() {
                        selectedFacultyId = v;
                        selectedGroupId = null;
                      }),
                      validator: (v) => v == null ? 'Выберите факультет' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedGroupId,
                      decoration: const InputDecoration(labelText: "Группа"),
                      items: groupsForFaculty
                          .map<DropdownMenuItem<String>>(
                            (g) => DropdownMenuItem<String>(
                              value: g.id,
                              child: Text(
                                g.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setStateDialog(() => selectedGroupId = v),
                      validator: (v) => v == null ? 'Выберите группу' : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    try {
                      await _api.createUser(
                        login: loginCtrl.text.trim(),
                        password: passCtrl.text.trim(),
                        role: UserRole.student,
                        fullName: nameCtrl.text.trim(),
                        facultyId: selectedFacultyId,
                        groupId: selectedGroupId,
                      );
                      _loadData();
                      if (mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                      );
                    }
                  }
                },
                child: const Text("Создать"),
              ),
            ],
          );
        }
      ),
    );
  }
}
