import 'package:flutter/material.dart';
import '../../services/session_service.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import '../../models/user.dart';
import '../../models/faculty.dart';
import '../../models/group.dart';
import '../../models/user_role.dart';

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
    final double navLabelSize = width < 380 ? 9.0 : (width < 600 ? 10.5 : 14.0);

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
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school),
              label: 'Преподаватели',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Студенты',
            ),
            NavigationDestination(
              icon: Icon(Icons.domain_outlined),
              selectedIcon: Icon(Icons.domain),
              label: 'Факультеты',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: 'Группы',
            ),
            NavigationDestination(
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
    if (login.length < 3) return 'Логин должен быть не короче 3 символов';
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

  String? _validateNotEmpty(String? value, String label) {
    if (value == null || value.trim().isEmpty) return 'Введите $label';
    return null;
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
                FilledButton.icon(
                  onPressed: () async {
                    await SessionService().clearSession();
                    await _api.logout();
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
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              child: Text(t.login.isNotEmpty ? t.login[0].toUpperCase() : "?"),
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
        : _groups.where((g) => g.facultyId == _studentFilterFacultyId).toList();

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
        onTap: () {}, // No edit for now
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                child: Text(s.fullName.isNotEmpty ? s.fullName[0] : "?"),
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
        ),
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
                          await _api.deleteFaculty(f.id);
                          _loadData();
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
            validator: (v) => _validateNotEmpty(v, 'Название'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _api.createFaculty(controller.text.trim());
                _loadData();
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text("Создать"),
          ),
        ],
      ),
    );
  }

  void _showAddGroupDialog() {
    final controller = TextEditingController();
    String? selectedFacultyId;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text("Добавить группу"),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: controller,
                  decoration: const InputDecoration(labelText: "Название"),
                  validator: (v) => _validateNotEmpty(v, 'Название'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedFacultyId,
                  decoration: const InputDecoration(labelText: "Факультет"),
                  items: _faculties.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))).toList(),
                  onChanged: (v) => setStateDialog(() => selectedFacultyId = v),
                  validator: (v) => v == null ? 'Выберите факультет' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  await _api.createGroup(controller.text.trim(), selectedFacultyId!);
                  _loadData();
                  if (mounted) Navigator.pop(ctx);
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
                await _api.createUser(
                  login: loginCtrl.text.trim(),
                  password: passCtrl.text.trim(),
                  role: UserRole.teacher,
                  fullName: nameCtrl.text.trim(),
                );
                _loadData();
                if (mounted) Navigator.pop(ctx);
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
           final filteredGroups = selectedFacultyId != null 
              ? _groups.where((g) => g.facultyId == selectedFacultyId).toList()
              : <Group>[];
           
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
                      value: selectedFacultyId,
                      decoration: const InputDecoration(labelText: "Факультет"),
                      items: _faculties.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))).toList(),
                      onChanged: (v) => setStateDialog(() {
                        selectedFacultyId = v;
                        selectedGroupId = null;
                      }),
                      validator: (v) => v == null ? 'Выберите факультет' : null,
                    ),
                    const SizedBox(height: 12),
                     DropdownButtonFormField<String>(
                      value: selectedGroupId,
                      decoration: const InputDecoration(labelText: "Группа"),
                      items: filteredGroups.map<DropdownMenuItem<String>>((g) => DropdownMenuItem(value: g.id, child: Text(g.name))).toList(),
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
