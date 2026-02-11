import 'package:flutter/material.dart';
import '../../data/mock_database.dart';
import '../../services/session_service.dart';
import '../auth/login_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;
  final _db = DatabaseService();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Adaptive font size: small for phones (to fit text), larger for tablets
    final double navLabelSize = width < 380 ? 9.0 : (width < 600 ? 10.5 : 14.0);

    return Scaffold(
      // Removed global AppBar to allow per-tab SliverAppBar
      body: _buildBody(),
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

  // Updated to return CustomScrollView with Slivers
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

  Future<bool> _confirmDeleteAccount({required String displayName, required String roleLabel}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтверждение удаления'),
        content: Text('Вы точно хотите удалить $roleLabel "$displayName"?'),
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

  Future<bool> _confirmDeleteEntity({required String entityLabel, required String displayName}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтверждение удаления'),
        content: Text('Вы точно хотите удалить $entityLabel "$displayName"?'),
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

  String? _validateLogin(String? value, {String? excludeUserId}) {
    final login = value?.trim() ?? '';
    if (login.isEmpty) return 'Введите логин';
    if (login.length < 3) return 'Логин должен быть не короче 3 символов';
    if (login.length > 30) return 'Логин слишком длинный';
    final regex = RegExp(r'^[a-zA-Z0-9._-]+$');
    if (!regex.hasMatch(login)) {
      return 'Допустимы латинские буквы, цифры и . _ -';
    }
    if (_db.isLoginTaken(login, excludeUserId: excludeUserId)) {
      return 'Такой логин уже существует';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value?.trim() ?? '';
    if (password.isEmpty) return 'Введите пароль';
    if (password.length < 4) return 'Пароль должен быть не короче 4 символов';
    if (password.length > 64) return 'Пароль слишком длинный';
    return null;
  }

  String? _validateFullName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Введите ФИО';
    if (name.length < 5) return 'Укажите ФИО полностью';
    if (name.length > 120) return 'Слишком длинное ФИО';
    return null;
  }

  String? _validateEntityName(
    String? value, {
    required String fieldLabel,
    required bool Function(String) duplicateCheck,
  }) {
    final clean = (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) return 'Введите $fieldLabel';
    if (clean.length < 3) return '$fieldLabel должен содержать минимум 3 символа';
    if (clean.length > 120) return '$fieldLabel слишком длинный';
    if (duplicateCheck(clean)) return '$fieldLabel уже существует';
    return null;
  }

  // --- REUSABLE SLIVER HEADER ---
  Widget _buildSliverAppBar(String title, {List<Widget>? actions}) {
    return SliverAppBar.medium(
      title: Text(title),
      actions: actions,
    );
  }

  Widget _buildProfileTab() {
    final teachersCount = _db.getTeachers().length;
    final studentsCount = _db.getStudents().length;
    final facultiesCount = _db.getFaculties().length;
    final groupsCount = _db.getGroups().length;

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar("Профиль администратора"),
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
                        Chip(label: Text("Преподавателей: $teachersCount")),
                        Chip(label: Text("Студентов: $studentsCount")),
                        Chip(label: Text("Факультетов: $facultiesCount")),
                        Chip(label: Text("Групп: $groupsCount")),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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

  // --- REUSABLE SUMMARY BLOCK ---
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

  // --- REUSABLE EMPTY STATE ---
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

  // Space so FAB does not overlap last list item.
  Widget _buildFabBottomSpacer() {
    return const SliverToBoxAdapter(
      child: SizedBox(height: 96),
    );
  }

  // --- TAB 1: Teachers (Refactored) ---
  Widget _buildTeachersTab() {
    final teachers = _db.getTeachers();
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width > 900 ? 3 : (width > 600 ? 2 : 1);
    final isMobile = crossAxisCount == 1;

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar("Преподаватели"),
        _buildSummaryBlock(
          title: "Всего преподавателей",
          count: teachers.length.toString(),
          icon: Icons.school,
        ),
        if (teachers.isEmpty) 
          _buildEmptyState("Нет преподавателей. Добавьте первого!"),
        
        if (teachers.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: isMobile 
              ? SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildTeacherCard(teachers[index]),
                    childCount: teachers.length,
                  ),
                )
              :                   SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 200, // Fixed height instead of aspect ratio
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildTeacherCard(teachers[index]),
                      childCount: teachers.length,
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
      margin: const EdgeInsets.only(bottom: 12), // Add margin for list view
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showEditTeacherDialog(t),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                child: Text(t.login[0].toUpperCase()),
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
                    icon: Icon(
                      Icons.edit_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () => _showEditTeacherDialog(t),
                  ),
                  IconButton(
                    tooltip: "Удалить",
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      final shouldDelete = await _confirmDeleteAccount(
                        displayName: t.fullName,
                        roleLabel: 'преподавателя',
                      );
                      if (!shouldDelete) return;
                      _db.deleteUser(t.id);
                      setState(() {});
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

  // --- TAB 2: Students (Refactored) ---
  Widget _buildStudentsTab() {
    final students = _db.getStudents();
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width > 900 ? 3 : (width > 600 ? 2 : 1);
    final isMobile = crossAxisCount == 1;

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar("Студенты"),
        _buildSummaryBlock(
          title: "Всего студентов",
          count: students.length.toString(),
          icon: Icons.people,
          color: Theme.of(context).colorScheme.tertiaryContainer,
        ),
        if (students.isEmpty)
           _buildEmptyState("Список студентов пуст"),

        if (students.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: isMobile
              ? SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildStudentCard(students[index]),
                    childCount: students.length,
                  ),
                )
              :                   SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 220, // Fixed height instead of aspect ratio
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildStudentCard(students[index]),
                      childCount: students.length,
                    ),
                  ),
          ),
        _buildFabBottomSpacer(),
      ],
    );
  }

  Widget _buildStudentCard(User s) {
    return Card(
      elevation: 2,
      color: Theme.of(context).cardTheme.color,
      margin: const EdgeInsets.only(bottom: 12), // Add margin for list view
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showEditStudentDialog(s),
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      s.fullName, 
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis, 
                      style: Theme.of(context).textTheme.titleMedium
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (s.faculty != null) 
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest, 
                              borderRadius: BorderRadius.circular(6)
                            ),
                            child: Text(
                              s.faculty!, 
                              style: TextStyle(
                                fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600
                              )
                            ),
                          ),
                        if (s.group != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest, 
                              borderRadius: BorderRadius.circular(6)
                            ),
                            child: Text(
                              s.group!, 
                              style: TextStyle(
                                fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600
                              )
                            ),
                          ),
                      ],
                    )
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: "Редактировать",
                    icon: Icon(
                      Icons.edit_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () => _showEditStudentDialog(s),
                  ),
                  IconButton(
                    tooltip: "Удалить",
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      final shouldDelete = await _confirmDeleteAccount(
                        displayName: s.fullName,
                        roleLabel: 'студента',
                      );
                      if (!shouldDelete) return;
                      _db.deleteUser(s.id);
                      setState(() {});
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



  // --- Helpers for Adaptive Dialogs ---
  Future<void> _showResponsiveDialog({required String title, required Widget content, required VoidCallback onConfirm}) {
    return showDialog(
      context: context,
      builder: (ctx) {
        final w = MediaQuery.of(ctx).size.width;
        final dialogWidth = w >= 600 ? 560.0 : w * 0.92;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: dialogWidth),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    content,
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
                        const SizedBox(width: 8),
                        ElevatedButton(onPressed: onConfirm, child: const Text("Создать")),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddTeacherDialog() {
    final loginController = TextEditingController();
    final passController = TextEditingController();
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    _showResponsiveDialog(
      title: "Добавить преподавателя",
      content: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: loginController,
              decoration: const InputDecoration(labelText: "Логин"),
              validator: _validateLogin,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: passController,
              decoration: const InputDecoration(labelText: "Пароль"),
              validator: _validatePassword,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "ФИО"),
              validator: _validateFullName,
            ),
          ],
        ),
      ),
      onConfirm: () async {
        if (!(formKey.currentState?.validate() ?? false)) return;
        try {
          await _db.addTeacher(
            login: loginController.text.trim(),
            password: passController.text.trim(),
            fullName: nameController.text.trim(),
          );
          setState(() {});
          if (mounted) Navigator.pop(context);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
          );
        }
      },
    );
  }

  void _showEditTeacherDialog(User teacher) {
    final loginController = TextEditingController(text: teacher.login);
    final passController = TextEditingController(text: teacher.password);
    final nameController = TextEditingController(text: teacher.fullName);
    final formKey = GlobalKey<FormState>();
    
    _showResponsiveDialog(
      title: "Редактировать преподавателя",
      content: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: loginController, 
              decoration: const InputDecoration(labelText: "Логин (нельзя изменить)"),
              enabled: false,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: passController,
              decoration: const InputDecoration(labelText: "Новый пароль"),
              validator: _validatePassword,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "ФИО"),
              validator: (value) {
                final base = _validateFullName(value);
                if (base != null) return base;
                if (_db.isDuplicateTeacher(fullName: value!.trim(), excludeUserId: teacher.id)) {
                  return 'Преподаватель с таким ФИО уже существует';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      onConfirm: () async {
        if (!(formKey.currentState?.validate() ?? false)) return;
        await _db.updateUser(
          id: teacher.id,
          password: passController.text.trim(),
          fullName: nameController.text.trim(),
        );
        setState(() {});
        if (mounted) Navigator.pop(context);
      },
    );
  }

  void _showAddStudentDialog() {
    final loginController = TextEditingController();
    final passController = TextEditingController();
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? selectedFacultyId;
    String? selectedGroupId;
    
    final faculties = _db.getFaculties();
    List<Group> groups = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final w = MediaQuery.of(ctx).size.width;
          final dialogWidth = w >= 600 ? 560.0 : w * 0.92;

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: dialogWidth),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      Text("Добавить студента", style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: loginController, 
                        decoration: const InputDecoration(labelText: "Логин"),
                        style: Theme.of(context).textTheme.bodyLarge,
                        validator: _validateLogin,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passController, 
                        decoration: const InputDecoration(labelText: "Пароль"),
                        style: Theme.of(context).textTheme.bodyLarge,
                        validator: _validatePassword,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameController, 
                        decoration: const InputDecoration(labelText: "ФИО"),
                        style: Theme.of(context).textTheme.bodyLarge,
                        validator: _validateFullName,
                      ),
                      const SizedBox(height: 12),
                      
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: "Факультет"),
                        validator: (value) => value == null ? 'Выберите факультет' : null,
                        items: faculties.map((f) => DropdownMenuItem(
                          value: f.id, 
                          child: Text(
                            f.name, 
                            overflow: TextOverflow.visible, 
                            maxLines: 4,
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        )).toList(),
                        selectedItemBuilder: (context) {
                          return faculties.map<Widget>((f) {
                            return Text(
                              f.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            );
                          }).toList();
                        },
                        onChanged: (val) {
                          setStateDialog(() {
                            selectedFacultyId = val;
                            groups = _db.getGroupsByFaculty(val!);
                            selectedGroupId = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        key: ValueKey(selectedFacultyId),
                        decoration: const InputDecoration(labelText: "Группа"),
                        validator: (value) => value == null ? 'Выберите направление/группу' : null,
                        items: groups.map((g) => DropdownMenuItem(
                          value: g.id,
                          child: Text(
                            g.name,
                            overflow: TextOverflow.visible,
                            maxLines: 3,
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        )).toList(),
                        selectedItemBuilder: (context) {
                          return groups.map<Widget>((g) {
                            return Text(
                              g.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            );
                          }).toList();
                        },
                        onChanged: (val) => setStateDialog(() => selectedGroupId = val),
                        value: selectedGroupId,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              if (!(formKey.currentState?.validate() ?? false)) return;
                              final fName = faculties.firstWhere((f) => f.id == selectedFacultyId).name;
                              final gName = groups.firstWhere((g) => g.id == selectedGroupId).name;

                              if (_db.isDuplicateStudent(
                                fullName: nameController.text.trim(),
                                faculty: fName,
                                group: gName,
                              )) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Студент с такими данными уже существует")),
                                );
                                return;
                              }

                              try {
                                await _db.addStudent(
                                  login: loginController.text.trim(),
                                  password: passController.text.trim(),
                                  fullName: nameController.text.trim(),
                                  faculty: fName,
                                  group: gName,
                                );
                                setState(() {}); 
                                if (context.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                                );
                              }
                            },
                            child: const Text("Создать"),
                          ),
                        ],
                      ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  void _showEditStudentDialog(User student) {
    final loginController = TextEditingController(text: student.login);
    final passController = TextEditingController(text: student.password);
    final nameController = TextEditingController(text: student.fullName);
    final formKey = GlobalKey<FormState>();
    
    final faculties = _db.getFaculties();
    
    String? selectedFacultyId;
    String? selectedGroupId;

    try {
      if (student.faculty != null) {
        final f = faculties.firstWhere((f) => f.name == student.faculty);
        selectedFacultyId = f.id;
      }
    } catch (_) {}

    List<Group> groups = selectedFacultyId != null ? _db.getGroupsByFaculty(selectedFacultyId) : [];

    try {
      if (student.group != null && selectedFacultyId != null) {
        final g = groups.firstWhere((g) => g.name == student.group);
        selectedGroupId = g.id;
      }
    } catch (_) {}

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final w = MediaQuery.of(ctx).size.width;
          final dialogWidth = w >= 600 ? 560.0 : w * 0.92;

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: dialogWidth),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      Text("Редактировать студента", style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: loginController, 
                        decoration: const InputDecoration(labelText: "Логин (нельзя изменить)"),
                        enabled: false, 
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passController, 
                        decoration: const InputDecoration(labelText: "Новый пароль"),
                        style: Theme.of(context).textTheme.bodyLarge,
                        validator: _validatePassword,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameController, 
                        decoration: const InputDecoration(labelText: "ФИО"),
                        style: Theme.of(context).textTheme.bodyLarge,
                        validator: _validateFullName,
                      ),
                      const SizedBox(height: 12),
                      
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: "Факультет"),
                        value: selectedFacultyId,
                        validator: (value) => value == null ? 'Выберите факультет' : null,
                        items: faculties.map((f) => DropdownMenuItem(
                          value: f.id, 
                          child: Text(
                            f.name, 
                            overflow: TextOverflow.visible, 
                            maxLines: 4,
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        )).toList(),
                        selectedItemBuilder: (context) {
                          return faculties.map<Widget>((f) {
                            return Text(
                              f.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            );
                          }).toList();
                        },
                        onChanged: (val) {
                          setStateDialog(() {
                            selectedFacultyId = val;
                            groups = _db.getGroupsByFaculty(val!);
                            selectedGroupId = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        key: ValueKey(selectedFacultyId),
                        decoration: const InputDecoration(labelText: "Группа"),
                        value: selectedGroupId,
                        validator: (value) => value == null ? 'Выберите направление/группу' : null,
                        items: groups.map((g) => DropdownMenuItem(
                          value: g.id,
                          child: Text(
                            g.name,
                            overflow: TextOverflow.visible,
                            maxLines: 3,
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        )).toList(),
                        selectedItemBuilder: (context) {
                          return groups.map<Widget>((g) {
                            return Text(
                              g.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            );
                          }).toList();
                        },
                        onChanged: (val) => setStateDialog(() => selectedGroupId = val),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              if (!(formKey.currentState?.validate() ?? false)) return;
                              final fName = faculties.firstWhere((f) => f.id == selectedFacultyId).name;
                              final gName = groups.firstWhere((g) => g.id == selectedGroupId).name;

                              if (_db.isDuplicateStudent(
                                fullName: nameController.text.trim(),
                                faculty: fName,
                                group: gName,
                                excludeUserId: student.id,
                              )) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Студент с такими данными уже существует")),
                                );
                                return;
                              }

                              await _db.updateUser(
                                id: student.id,
                                password: passController.text.trim(),
                                fullName: nameController.text.trim(),
                                faculty: fName,
                                group: gName,
                              );
                              setState(() {}); 
                              if (context.mounted) Navigator.pop(ctx);
                            },
                            child: const Text("Сохранить"),
                          ),
                        ],
                      ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  // --- TAB 3: Faculties (Refactored) ---
  Widget _buildFacultiesTab() {
    final faculties = _db.getFaculties();
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar("Факультеты"),
        _buildSummaryBlock(title: "Всего факультетов", count: faculties.length.toString(), icon: Icons.domain),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final f = faculties[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: const Icon(Icons.business),
                    title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        final shouldDelete = await _confirmDeleteEntity(
                          entityLabel: 'факультет',
                          displayName: f.name,
                        );
                        if (!shouldDelete) return;
                        _db.deleteFaculty(f.id);
                        setState(() {});
                      },
                    ),
                  ),
                );
              },
              childCount: faculties.length,
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
    _showResponsiveDialog(
      title: "Добавить факультет",
      content: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: TextFormField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Название"),
          validator: (value) => _validateEntityName(
            value,
            fieldLabel: 'Название факультета',
            duplicateCheck: _db.isDuplicateFacultyName,
          ),
        ),
      ),
      onConfirm: () async {
        if (!(formKey.currentState?.validate() ?? false)) return;
        try {
          await _db.addFaculty(controller.text.trim());
          setState(() {});
          if (mounted) Navigator.pop(context);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
          );
        }
      },
    );
  }

  // --- TAB 4: Groups (Refactored) ---
  Widget _buildGroupsTab() {
    final groups = _db.getGroups();
    final faculties = _db.getFaculties(); // Get faculties for lookup

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar("Группы"),
        _buildSummaryBlock(title: "Всего групп", count: groups.length.toString(), icon: Icons.groups),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final g = groups[index];
                // Lookup faculty name
                final facultyName = faculties
                    .firstWhere((f) => f.id == g.facultyId, orElse: () => Faculty(id: '', name: 'Без факультета'))
                    .name;

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: const Icon(Icons.class_outlined),
                    title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(facultyName, style: Theme.of(context).textTheme.bodySmall), // Use Name instead of ID
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        final shouldDelete = await _confirmDeleteEntity(
                          entityLabel: 'группу',
                          displayName: g.name,
                        );
                        if (!shouldDelete) return;
                        _db.deleteGroup(g.id);
                        setState(() {});
                      },
                    ),
                  ),
                );
              },
              childCount: groups.length,
            ),
          ),
        ),
        _buildFabBottomSpacer(),
      ],
    );
  }

  void _showAddGroupDialog() {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? selectedFacultyId;
    final faculties = _db.getFaculties();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final w = MediaQuery.of(ctx).size.width;
          final dialogWidth = w >= 600 ? 560.0 : w * 0.92;

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: dialogWidth),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text("Добавить группу", style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: controller,
                          decoration: const InputDecoration(labelText: "Название группы"),
                          validator: (value) => _validateEntityName(
                            value,
                            fieldLabel: 'Название группы',
                            duplicateCheck: _db.isDuplicateGroupName,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: "Факультет"),
                          validator: (value) => value == null ? 'Выберите факультет' : null,
                          items: faculties.map((f) => DropdownMenuItem(
                            value: f.id,
                            child: Text(
                              f.name, 
                              style: Theme.of(context).textTheme.bodyMedium,
                              overflow: TextOverflow.visible,
                            ),
                          )).toList(),
                        selectedItemBuilder: (context) {
                          return faculties.map<Widget>((f) {
                            return Text(
                              f.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            );
                          }).toList();
                        },
                        onChanged: (val) => setStateDialog(() => selectedFacultyId = val),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () async {
                                if (!(formKey.currentState?.validate() ?? false)) return;
                                try {
                                  await _db.addGroup(controller.text.trim(), selectedFacultyId!);
                                  setState(() {});
                                  if (context.mounted) Navigator.pop(ctx);
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                                  );
                                }
                              },
                              child: const Text("Создать"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      ),
    );
  }
}