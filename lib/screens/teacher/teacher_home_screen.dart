import 'package:flutter/material.dart';
import '../../data/mock_database.dart';
import '../../widgets/responsive_wrapper.dart';
import '../auth/login_screen.dart';

class TeacherHomeScreen extends StatefulWidget {
  final User user;
  const TeacherHomeScreen({super.key, required this.user});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  int _currentIndex = 0;
  final _db = DatabaseService();

  // Filters State
  String? _filterFacultyId;
  String? _filterGroupId;
  String? _historyFilterFacultyId;
  String? _historyFilterGroupId;
  String? _historyFilterStudentId;
  String? _historyFilterNormId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Removed global AppBar
      body: _buildBody(),
      floatingActionButton: _buildFab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Студенты',
          ),
          NavigationDestination(
            icon: Icon(Icons.grade_outlined),
            selectedIcon: Icon(Icons.grade),
            label: 'Журнал',
          ),
          NavigationDestination(
            icon: Icon(Icons.rule_outlined),
            selectedIcon: Icon(Icons.rule),
            label: 'Нормативы',
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
  Widget _buildSliverAppBar(String title) {
    return SliverAppBar.medium(
      title: Text(title),
    );
  }

  Widget _buildProfileTab() {
    final myGradesCount = _db.getGrades().where((g) => g.teacherId == widget.user.id).length;
    final normsCount = _db.getNorms().length;
    final studentsCount = _db.getStudents().length;

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar("Профиль преподавателя"),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(widget.user.fullName.isNotEmpty ? widget.user.fullName[0].toUpperCase() : "П"),
                    ),
                    title: Text(widget.user.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
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
                        Chip(label: Text("Доступно нормативов: $normsCount")),
                        Chip(label: Text("Студентов: $studentsCount")),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  ),
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

  // --- Helper for Adaptive Dialog ---
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

  Future<bool> _confirmDeleteNorm(String normName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтверждение удаления'),
        content: Text('Вы точно хотите удалить норматив "$normName"?'),
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

  String? _validateNormName(String? value) {
    final clean = (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) return 'Введите название норматива';
    if (clean.length < 3) return 'Название норматива должно содержать минимум 3 символа';
    if (clean.length > 120) return 'Название норматива слишком длинное';
    if (_db.isDuplicateNormName(clean)) return 'Норматив с таким названием уже существует';
    return null;
  }

  // --- TAB 1: Students List (With Filters) ---
  Widget _buildStudentsTab() {
    final allStudents = _db.getStudents();
    final faculties = _db.getFaculties();
    final allGroups = _db.getGroups();
    
    List<User> filteredStudents = allStudents;
    
    if (_filterFacultyId != null) {
      final f = faculties.firstWhere((e) => e.id == _filterFacultyId, orElse: () => Faculty(id: '', name: ''));
      if (f.name.isNotEmpty) {
        filteredStudents = filteredStudents.where((s) => s.faculty == f.name).toList();
      }
    }

    if (_filterGroupId != null) {
       final groups = _db.getGroups();
       final g = groups.firstWhere((e) => e.id == _filterGroupId, orElse: () => Group(id: '', name: '', facultyId: ''));
       if (g.name.isNotEmpty) {
         filteredStudents = filteredStudents.where((s) => s.group == g.name).toList();
       }
    }

    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width > 900 ? 3 : (width > 600 ? 2 : 1);
    final isMobile = crossAxisCount == 1;

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar("Студенты"),
        
        // FILTERS (Tonal Container)
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
                  const Text("Фильтрация", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _filterFacultyId,
                    decoration: const InputDecoration(
                      labelText: "Факультет",
                      prefixIcon: Icon(Icons.domain_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text("Все факультеты")),
                      ...faculties.map((f) => DropdownMenuItem<String>(
                            value: f.id,
                            child: Text(f.name, overflow: TextOverflow.ellipsis, maxLines: 1),
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
                      labelText: "Направление / группа",
                      prefixIcon: Icon(Icons.groups_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text("Все направления")),
                      ...(_filterFacultyId == null
                              ? allGroups
                              : _db.getGroupsByFaculty(_filterFacultyId!))
                          .map((g) => DropdownMenuItem<String>(
                                value: g.id,
                                child: Text(g.name, overflow: TextOverflow.ellipsis, maxLines: 1),
                              )),
                    ],
                    onChanged: (value) => setState(() => _filterGroupId = value),
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
                    (context, index) {
                      final s = filteredStudents[index];
                      return _buildStudentCard(s);
                    },
                    childCount: filteredStudents.length,
                  ),
                )
              : SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                       crossAxisCount: crossAxisCount,
                       mainAxisSpacing: 12,
                       crossAxisSpacing: 12,
                       mainAxisExtent: 220, // Fixed height instead of aspect ratio
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                         final s = filteredStudents[index];
                         return _buildStudentCard(s);
                      },
                      childCount: filteredStudents.length,
                    ),
                ),
          ),
          
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)), // Space for FAB
      ],
    );
  }

  Widget _buildStudentCard(User s) {
    return Card(
      elevation: 2,
      color: Theme.of(context).cardTheme.color,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
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
                  const SizedBox(height: 4),
                  Text(
                    "${s.faculty ?? '-'} / ${s.group ?? '-'}", 
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: Theme.of(context).textTheme.bodySmall?.fontSize
                    )
                  ),
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
    return DefaultTabController(
      length: 2,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
           _buildSliverAppBar("Журнал оценок"),
           SliverToBoxAdapter(
             child: TabBar(
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
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
          children: [
            _buildNewGradeForm(),
            _buildGradesHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildNewGradeForm() {
    final students = _db.getStudents();
    final norms = _db.getNorms();
    final faculties = _db.getFaculties();
    final groups = _db.getGroups();

    if (students.isEmpty) return const Center(child: Text("Нет студентов для оценки"));
    if (norms.isEmpty) return const Center(child: Text("Сначала создайте нормативы во вкладке 'Нормативы'"));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ResponsiveWrapper(
        maxWidth: 500,
        child: Card( // Wrap form in a tonal card
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _GradeForm(
              students: students, 
              norms: norms, 
              faculties: faculties,
              groups: groups,
              teacherId: widget.user.id,
              onGradeAdded: () => setState(() {}),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradesHistory() {
    final grades = _db.getGrades(); 
    final myGrades = grades.where((g) => g.teacherId == widget.user.id).toList();
    final faculties = _db.getFaculties();
    final groups = _db.getGroups();
    final students = _db.getStudents();
    final norms = _db.getNorms();
    final studentsById = {for (final s in students) s.id: s};

    final selectedFacultyName = _historyFilterFacultyId == null
        ? null
        : faculties
            .firstWhere((f) => f.id == _historyFilterFacultyId, orElse: () => Faculty(id: '', name: ''))
            .name;

    final selectedGroupName = _historyFilterGroupId == null
        ? null
        : groups
            .firstWhere((g) => g.id == _historyFilterGroupId, orElse: () => Group(id: '', name: '', facultyId: ''))
            .name;

    final studentsForDropdown = students.where((s) {
      if (selectedFacultyName != null && s.faculty != selectedFacultyName) return false;
      if (selectedGroupName != null && s.group != selectedGroupName) return false;
      return true;
    }).toList();

    final filteredGrades = myGrades.where((g) {
      if (_historyFilterStudentId != null && g.studentId != _historyFilterStudentId) return false;
      if (_historyFilterNormId != null && g.normId != _historyFilterNormId) return false;

      final student = studentsById[g.studentId];
      if (selectedFacultyName != null && (student == null || student.faculty != selectedFacultyName)) {
        return false;
      }
      if (selectedGroupName != null && (student == null || student.group != selectedGroupName)) {
        return false;
      }
      return true;
    }).toList();

    if (myGrades.isEmpty) return const Center(child: Text("Вы еще не ставили оценок"));

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
                   DropdownButtonFormField<String>(
                     isExpanded: true,
                     value: _historyFilterFacultyId,
                     decoration: const InputDecoration(
                       labelText: "Факультет",
                       prefixIcon: Icon(Icons.domain_outlined),
                     ),
                     items: [
                       const DropdownMenuItem<String>(value: null, child: Text("Все факультеты")),
                       ...faculties.map((f) => DropdownMenuItem<String>(
                             value: f.id,
                             child: Text(f.name, overflow: TextOverflow.ellipsis, maxLines: 1),
                           )),
                     ],
                     onChanged: (value) {
                       setState(() {
                         _historyFilterFacultyId = value;
                         _historyFilterGroupId = null;
                         _historyFilterStudentId = null;
                       });
                     },
                   ),
                   const SizedBox(height: 12),
                   DropdownButtonFormField<String>(
                     isExpanded: true,
                     value: _historyFilterGroupId,
                     decoration: const InputDecoration(
                       labelText: "Направление / группа",
                       prefixIcon: Icon(Icons.groups_outlined),
                     ),
                     items: [
                       const DropdownMenuItem<String>(value: null, child: Text("Все направления")),
                       ...(_historyFilterFacultyId == null
                               ? groups
                               : _db.getGroupsByFaculty(_historyFilterFacultyId!))
                           .map((g) => DropdownMenuItem<String>(
                                 value: g.id,
                                 child: Text(g.name, overflow: TextOverflow.ellipsis, maxLines: 1),
                               )),
                     ],
                     onChanged: (value) {
                       setState(() {
                         _historyFilterGroupId = value;
                         _historyFilterStudentId = null;
                       });
                     },
                   ),
                   const SizedBox(height: 12),
                   DropdownButtonFormField<String>(
                     isExpanded: true,
                     value: _historyFilterStudentId,
                     decoration: const InputDecoration(
                       labelText: "Студент",
                       prefixIcon: Icon(Icons.person_outline),
                     ),
                     items: [
                       const DropdownMenuItem<String>(value: null, child: Text("Все студенты")),
                       ...studentsForDropdown.map((s) => DropdownMenuItem<String>(
                             value: s.id,
                             child: Text(s.fullName, overflow: TextOverflow.ellipsis, maxLines: 1),
                           )),
                     ],
                     onChanged: (value) => setState(() => _historyFilterStudentId = value),
                   ),
                   const SizedBox(height: 12),
                   DropdownButtonFormField<String>(
                     isExpanded: true,
                     value: _historyFilterNormId,
                     decoration: const InputDecoration(
                       labelText: "Норматив",
                       prefixIcon: Icon(Icons.rule_outlined),
                     ),
                     items: [
                       const DropdownMenuItem<String>(value: null, child: Text("Все нормативы")),
                       ...norms.map((n) => DropdownMenuItem<String>(
                             value: n.id,
                             child: Text(n.name, overflow: TextOverflow.ellipsis, maxLines: 1),
                           )),
                     ],
                     onChanged: (value) => setState(() => _historyFilterNormId = value),
                   ),
                 ],
               ),
             ),
           ),
         ),
         SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: filteredGrades.isEmpty
                ? SliverToBoxAdapter(
                    child: SizedBox(
                      height: 240,
                      child: Center(
                        child: Text(
                          "По выбранным фильтрам ничего не найдено",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  )
                : SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final g = filteredGrades[index];
                  final bool isEdited = g.history.isNotEmpty;
                  final theme = Theme.of(context);

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        leading: _getScoreIcon(g.score),
                        title: Text(g.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${g.normName} — ${g.date.toString().split(' ')[0]}"),
                        trailing: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                           decoration: BoxDecoration(
                             color: _getScoreColor(g.score).withOpacity(0.1),
                             borderRadius: BorderRadius.circular(20),
                           ),
                           child: Text(
                             "${g.score}", 
                             style: TextStyle(fontWeight: FontWeight.bold, color: _getScoreColor(g.score), fontSize: Theme.of(context).textTheme.titleMedium?.fontSize)
                           ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (g.comment != null && g.comment!.isNotEmpty)
                                   Container(
                                     padding: const EdgeInsets.all(12),
                                     decoration: BoxDecoration(
                                       color: theme.colorScheme.surfaceContainerHighest,
                                       borderRadius: BorderRadius.circular(12),
                                     ),
                                     child: Text(g.comment!),
                                   ),
                                
                                if (isEdited) ...[
                                  const SizedBox(height: 16),
                                  Text("История изменений:", style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant)),
                                  const SizedBox(height: 8),
                                  ...g.history.reversed.map((h) {
                                     final int hScore = h['score'];
                                     final String hDate = DateTime.parse(h['date']).toString().split(' ')[0];
                                     return Padding(
                                       padding: const EdgeInsets.only(bottom: 4.0),
                                       child: Row(
                                         children: [
                                           Icon(Icons.history, size: 14, color: theme.colorScheme.outline),
                                           const SizedBox(width: 8),
                                           Text(
                                             "Был балл: $hScore ($hDate)",
                                             style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: theme.textTheme.bodySmall?.fontSize),
                                           ),
                                         ],
                                       ),
                                     );
                                  }).toList(),
                                ]
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: filteredGrades.length,
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
    if (score >= 4) return const Icon(Icons.sentiment_satisfied_alt, color: Colors.green);
    if (score == 3) return const Icon(Icons.sentiment_neutral, color: Colors.orange);
    return const Icon(Icons.sentiment_dissatisfied, color: Colors.red);
  }

  // --- TAB 3: Norms Management ---
  Widget _buildNormsTab() {
    final norms = _db.getNorms();
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar("Нормативы"),
        if (norms.isEmpty) 
           const SliverFillRemaining(child: Center(child: Text("Список нормативов пуст"))),
        
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final n = norms[index];
                return Card(
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, shape: BoxShape.circle),
                      child: Icon(Icons.fitness_center, color: Theme.of(context).colorScheme.onPrimaryContainer, size: 20),
                    ),
                    title: Text(n.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                         final shouldDelete = await _confirmDeleteNorm(n.name);
                         if (!shouldDelete) return;
                         _db.deleteNorm(n.id);
                         setState(() {});
                      },
                    ),
                  ),
                );
              },
              childCount: norms.length,
            ),
          ),
        ),
      ],
    );
  }

  void _showAddNormDialog(BuildContext context) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    _showResponsiveDialog(
      title: "Добавить норматив",
      content: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: TextFormField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Название (бег, подтягивания...)"),
          validator: _validateNormName,
        ),
      ),
      onConfirm: () async {
        if (!(formKey.currentState?.validate() ?? false)) return;
        try {
          await _db.addNorm(controller.text.trim());
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
}

class _GradeForm extends StatefulWidget {
  final List<User> students;
  final List<Norm> norms;
  final List<Faculty> faculties;
  final List<Group> groups;
  final String teacherId;
  final VoidCallback onGradeAdded;

  const _GradeForm({
    required this.students, 
    required this.norms, 
    required this.faculties,
    required this.groups,
    required this.teacherId,
    required this.onGradeAdded,
  });

  @override
  State<_GradeForm> createState() => _GradeFormState();
}

class _GradeFormState extends State<_GradeForm> {
  String? _selectedFacultyId;
  String? _selectedGroupId;
  String? _selectedStudentId;
  String? _selectedNormId;
  int _score = 5;
  final _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final selectedFacultyName = _selectedFacultyId == null
        ? null
        : widget.faculties
            .firstWhere((f) => f.id == _selectedFacultyId, orElse: () => Faculty(id: '', name: ''))
            .name;
    final selectedGroupName = _selectedGroupId == null
        ? null
        : widget.groups
            .firstWhere((g) => g.id == _selectedGroupId, orElse: () => Group(id: '', name: '', facultyId: ''))
            .name;

    final filteredStudents = widget.students.where((s) {
      if (selectedFacultyName != null && s.faculty != selectedFacultyName) return false;
      if (selectedGroupName != null && s.group != selectedGroupName) return false;
      return true;
    }).toList();

    final groupsForFaculty = _selectedFacultyId == null
        ? widget.groups
        : widget.groups.where((g) => g.facultyId == _selectedFacultyId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: _selectedFacultyId,
          decoration: const InputDecoration(labelText: "Факультет", prefixIcon: Icon(Icons.domain_outlined)),
          items: [
            const DropdownMenuItem<String>(value: null, child: Text("Все факультеты")),
            ...widget.faculties.map((f) => DropdownMenuItem(
              value: f.id,
              child: Text(f.name, overflow: TextOverflow.ellipsis),
            )),
          ],
          onChanged: (v) => setState(() {
            _selectedFacultyId = v;
            _selectedGroupId = null;
            _selectedStudentId = null;
          }),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: _selectedGroupId,
          decoration: const InputDecoration(labelText: "Направление / группа", prefixIcon: Icon(Icons.groups_outlined)),
          items: [
            const DropdownMenuItem<String>(value: null, child: Text("Все направления")),
            ...groupsForFaculty.map((g) => DropdownMenuItem(
              value: g.id,
              child: Text(g.name, overflow: TextOverflow.ellipsis),
            )),
          ],
          onChanged: (v) => setState(() {
            _selectedGroupId = v;
            _selectedStudentId = null;
          }),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          isExpanded: true,
          decoration: const InputDecoration(labelText: "Студент", prefixIcon: Icon(Icons.person)),
          items: filteredStudents.map((s) => DropdownMenuItem(
            value: s.id,
            child: Text(s.fullName, overflow: TextOverflow.ellipsis),
          )).toList(),
          selectedItemBuilder: (context) {
            return filteredStudents.map<Widget>((s) {
              return Text(s.fullName, overflow: TextOverflow.ellipsis, maxLines: 1);
            }).toList();
          },
          onChanged: (v) => setState(() => _selectedStudentId = v),
        ),
        if (filteredStudents.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            "По выбранным фильтрам нет студентов",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: Theme.of(context).textTheme.bodySmall?.fontSize,
            ),
          ),
        ],
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          isExpanded: true,
          decoration: const InputDecoration(labelText: "Норматив", prefixIcon: Icon(Icons.rule)),
          items: widget.norms.map((n) => DropdownMenuItem(
            value: n.id,
            child: Text(
              n.name, 
              overflow: TextOverflow.visible, 
              maxLines: 2,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )).toList(),
          selectedItemBuilder: (context) {
            return widget.norms.map<Widget>((n) {
              return Text(n.name, overflow: TextOverflow.ellipsis, maxLines: 1);
            }).toList();
          },
          onChanged: (v) => setState(() => _selectedNormId = v),
        ),
        const SizedBox(height: 16),
        Text("Оценка:", style: TextStyle(fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize, fontWeight: FontWeight.bold)),
        Slider(
          value: _score.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          label: _score.toString(),
          onChanged: (v) => setState(() => _score = v.toInt()),
          activeColor: Theme.of(context).primaryColor,
        ),
        Center(child: Text("$_score ${_getScoreSuffix(_score)}", style: TextStyle(fontSize: Theme.of(context).textTheme.headlineMedium?.fontSize, fontWeight: FontWeight.bold))),
        const SizedBox(height: 16),
        TextField(
          controller: _commentController,
          decoration: const InputDecoration(labelText: "Комментарий (необязательно)"),
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

  void _submit() {
    if (_selectedStudentId == null || _selectedNormId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Выберите студента и норматив")));
      return;
    }
    
    final student = widget.students.firstWhere((s) => s.id == _selectedStudentId);
    final norm = widget.norms.firstWhere((n) => n.id == _selectedNormId);

    DatabaseService().addGrade(
      studentId: student.id,
      studentName: student.fullName,
      teacherId: widget.teacherId,
      normId: norm.id,
      normName: norm.name,
      score: _score,
      comment: _commentController.text,
    );

    widget.onGradeAdded();

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Оценка сохранена")));
    setState(() {
      _selectedStudentId = null;
      _selectedNormId = null;
      _score = 5;
      _commentController.clear();
    });
  }
}
