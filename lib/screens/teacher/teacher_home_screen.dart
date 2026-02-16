import 'package:flutter/material.dart';
import '../../services/session_service.dart';
import '../../services/api_service.dart';
import '../../widgets/responsive_wrapper.dart';
import '../auth/login_screen.dart';
import '../../models/user.dart';
import '../../models/faculty.dart';
import '../../models/group.dart';
import '../../models/norm.dart';
import '../../models/grade.dart';
import '../../models/user_role.dart';

class TeacherHomeScreen extends StatefulWidget {
  final User user;
  const TeacherHomeScreen({super.key, required this.user});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  int _currentIndex = 0;
  final _api = ApiService();

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
  String? _historyFilterFacultyId;
  String? _historyFilterGroupId;
  String? _historyFilterStudentId;
  String? _historyFilterNormId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final students = await _api.getUsers(role: 'student');
      final faculties = await _api.getFaculties();
      final groups = await _api.getGroups();
      final norms = await _api.getNorms();
      final grades = await _api.getGrades(); // Get all grades for now, or filter by teacher if backend supports it

      setState(() {
        _students = students;
        _faculties = faculties;
        _groups = groups;
        _norms = norms;
        _grades = grades;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _buildBody(),
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
    final myGradesCount = _grades.where((g) => g.teacherId == widget.user.id).length;
    final normsCount = _norms.length;
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
                  onPressed: () async {
                    await SessionService().clearSession();
                    await _api.logout();
                    if (!mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
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
       // Assuming faculty name in User matches Faculty name
       final f = _faculties.firstWhere((e) => e.id == _filterFacultyId, orElse: () => Faculty(id: '', name: ''));
       if (f.name.isNotEmpty) {
         filteredStudents = filteredStudents.where((s) => s.faculty == f.name).toList();
       }
    }

    // Filter by Group
    if (_filterGroupId != null) {
       final g = _groups.firstWhere((e) => e.id == _filterGroupId, orElse: () => Group(id: '', name: '', facultyId: ''));
       if (g.name.isNotEmpty) {
         filteredStudents = filteredStudents.where((s) => s.group == g.name).toList();
       }
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
                      ..._faculties.map((f) => DropdownMenuItem<String>(
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
                              ? _groups
                              : _groups.where((g) => g.facultyId == _filterFacultyId))
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
            CircleAvatar(
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
           _buildSliverAppBar(
             "Журнал оценок",
             icon: Icons.grade_outlined,
             subtitle: "Выставление баллов и просмотр истории",
           ),
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
    if (_students.isEmpty) return const Center(child: Text("Нет студентов для оценки"));
    if (_norms.isEmpty) return const Center(child: Text("Сначала создайте нормативы во вкладке 'Нормативы'"));

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
              norms: _norms, 
              faculties: _faculties,
              groups: _groups,
              teacherId: widget.user.id,
              onGradeAdded: _loadData, // Reload data after adding grade
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradesHistory() {
    final myGrades = _grades.where((g) => g.teacherId == widget.user.id).toList();
    final studentsById = {for (final s in _students) s.id: s};
    final normsById = {for (final n in _norms) n.id: n};

    final selectedFacultyName = _historyFilterFacultyId == null
        ? null
        : _faculties.firstWhere((f) => f.id == _historyFilterFacultyId, orElse: () => Faculty(id: '', name: '')).name;

    final selectedGroupName = _historyFilterGroupId == null
        ? null
        : _groups.firstWhere((g) => g.id == _historyFilterGroupId, orElse: () => Group(id: '', name: '', facultyId: '')).name;

    final studentsForDropdown = _students.where((s) {
      if (selectedFacultyName != null && s.faculty != selectedFacultyName) return false;
      if (selectedGroupName != null && s.group != selectedGroupName) return false;
      return true;
    }).toList();

    final filteredGrades = myGrades.where((g) {
      if (_historyFilterStudentId != null && g.studentId != _historyFilterStudentId) return false;
      if (_historyFilterNormId != null && g.normId != _historyFilterNormId) return false;

      final student = studentsById[g.studentId];
      if (selectedFacultyName != null && (student == null || student.faculty != selectedFacultyName)) return false;
      if (selectedGroupName != null && (student == null || student.group != selectedGroupName)) return false;
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
                     decoration: const InputDecoration(labelText: "Факультет", prefixIcon: Icon(Icons.domain_outlined)),
                     items: [
                       const DropdownMenuItem<String>(value: null, child: Text("Все факультеты")),
                       ..._faculties.map((f) => DropdownMenuItem<String>(value: f.id, child: Text(f.name, overflow: TextOverflow.ellipsis))),
                     ],
                     onChanged: (value) => setState(() {
                         _historyFilterFacultyId = value;
                         _historyFilterGroupId = null;
                         _historyFilterStudentId = null;
                     }),
                   ),
                   const SizedBox(height: 12),
                   DropdownButtonFormField<String>(
                     isExpanded: true,
                     value: _historyFilterGroupId,
                     decoration: const InputDecoration(labelText: "Направление / группа", prefixIcon: Icon(Icons.groups_outlined)),
                     items: [
                       const DropdownMenuItem<String>(value: null, child: Text("Все направления")),
                       ...(_historyFilterFacultyId == null ? _groups : _groups.where((g) => g.facultyId == _historyFilterFacultyId))
                           .map((g) => DropdownMenuItem<String>(value: g.id, child: Text(g.name, overflow: TextOverflow.ellipsis))),
                     ],
                     onChanged: (value) => setState(() {
                         _historyFilterGroupId = value;
                         _historyFilterStudentId = null;
                     }),
                   ),
                   const SizedBox(height: 12),
                   DropdownButtonFormField<String>(
                     isExpanded: true,
                     value: _historyFilterStudentId,
                     decoration: const InputDecoration(labelText: "Студент", prefixIcon: Icon(Icons.person_outline)),
                     items: [
                       const DropdownMenuItem<String>(value: null, child: Text("Все студенты")),
                       ...studentsForDropdown.map((s) => DropdownMenuItem<String>(value: s.id, child: Text(s.fullName, overflow: TextOverflow.ellipsis))),
                     ],
                     onChanged: (value) => setState(() => _historyFilterStudentId = value),
                   ),
                   const SizedBox(height: 12),
                   DropdownButtonFormField<String>(
                     isExpanded: true,
                     value: _historyFilterNormId,
                     decoration: const InputDecoration(labelText: "Норматив", prefixIcon: Icon(Icons.rule_outlined)),
                     items: [
                       const DropdownMenuItem<String>(value: null, child: Text("Все нормативы")),
                       ..._norms.map((n) => DropdownMenuItem<String>(value: n.id, child: Text(n.name, overflow: TextOverflow.ellipsis))),
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
                      child: Center(child: Text("По выбранным фильтрам ничего не найдено", style: Theme.of(context).textTheme.bodyMedium)),
                    ),
                  )
                : SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final g = filteredGrades[index];
                  final bool isEdited = g.history.isNotEmpty;
                  final theme = Theme.of(context);
                  
                  final studentName = studentsById[g.studentId]?.fullName ?? 'Неизвестный студент';
                  final normName = normsById[g.normId]?.name ?? 'Неизвестный норматив';

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5))),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        leading: _getScoreIcon(g.score),
                        title: Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("$normName — ${g.date.toString().split(' ')[0]}"),
                        trailing: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                           decoration: BoxDecoration(color: _getScoreColor(g.score).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                           child: Text("${g.score}", style: TextStyle(fontWeight: FontWeight.bold, color: _getScoreColor(g.score), fontSize: Theme.of(context).textTheme.titleMedium?.fontSize)),
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
                                     decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
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
                                           Text("Был балл: $hScore ($hDate)", style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: theme.textTheme.bodySmall?.fontSize)),
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
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(
          "Нормативы",
          icon: Icons.rule_outlined,
          subtitle: "Актуальный перечень нормативов для оценки",
        ),
        if (_norms.isEmpty) 
           const SliverFillRemaining(child: Center(child: Text("Список нормативов пуст"))),
        
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final n = _norms[index];
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
                         await _api.deleteNorm(n.id);
                         _loadData();
                      },
                    ),
                  ),
                );
              },
              childCount: _norms.length,
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Удалить')),
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
            validator: (v) => v == null || v.isEmpty ? 'Введите название' : null,
          ),
        ),
        actions: [
           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
           ElevatedButton(
             onPressed: () async {
               if (formKey.currentState!.validate()) {
                 await _api.createNorm(controller.text.trim());
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
            ...widget.faculties.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name, overflow: TextOverflow.ellipsis))),
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
            ...groupsForFaculty.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name, overflow: TextOverflow.ellipsis))),
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
          items: filteredStudents.map((s) => DropdownMenuItem(value: s.id, child: Text(s.fullName, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setState(() => _selectedStudentId = v),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          isExpanded: true,
          decoration: const InputDecoration(labelText: "Норматив", prefixIcon: Icon(Icons.rule)),
          items: widget.norms.map((n) => DropdownMenuItem(value: n.id, child: Text(n.name, overflow: TextOverflow.ellipsis))).toList(),
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

  void _submit() async {
    if (_selectedStudentId == null || _selectedNormId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Выберите студента и норматив")));
      return;
    }
    
    await ApiService().createGrade(
      studentId: _selectedStudentId!,
      normId: _selectedNormId!,
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
