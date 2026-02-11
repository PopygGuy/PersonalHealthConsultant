import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum UserRole { admin, teacher, student }

class Faculty {
  final String id;
  final String name;
  Faculty({required this.id, required this.name});
  
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory Faculty.fromJson(Map<String, dynamic> json) => Faculty(id: json['id'], name: json['name']);
}

class Group {
  final String id;
  final String name;
  final String facultyId; 
  Group({required this.id, required this.name, required this.facultyId});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'facultyId': facultyId};
  factory Group.fromJson(Map<String, dynamic> json) => Group(id: json['id'], name: json['name'], facultyId: json['facultyId']);
}

class Norm {
  final String id;
  final String name;
  Norm({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory Norm.fromJson(Map<String, dynamic> json) => Norm(id: json['id'], name: json['name']);
}

class User {
  final String id;
  String login;
  String password;
  final UserRole role;
  String fullName;
  final String? faculty;
  final String? group;

  User({
    required this.id,
    required this.login,
    required this.password,
    required this.role,
    required this.fullName,
    this.faculty,
    this.group,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'login': login,
    'password': password,
    'role': role.index,
    'fullName': fullName,
    'faculty': faculty,
    'group': group,
  };

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      login: json['login'],
      password: json['password'],
      role: UserRole.values[json['role']],
      fullName: json['fullName'],
      faculty: json['faculty'],
      group: json['group'],
    );
  }
}

class Grade {
  final String id;
  final String studentId;
  final String studentName;
  final String teacherId;
  final String normId;
  final String normName;
  final int score;
  final DateTime date;
  final String? comment;
  final List<Map<String, dynamic>> history; 

  Grade({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.teacherId,
    required this.normId,
    required this.normName,
    required this.score,
    required this.date,
    this.comment,
    this.history = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'studentId': studentId,
    'studentName': studentName,
    'teacherId': teacherId,
    'normId': normId,
    'normName': normName,
    'score': score,
    'date': date.toIso8601String(),
    'comment': comment,
    'history': history,
  };

  factory Grade.fromJson(Map<String, dynamic> json) {
    return Grade(
      id: json['id'],
      studentId: json['studentId'],
      studentName: json['studentName'] ?? 'Студент',
      teacherId: json['teacherId'] ?? '',
      normId: json['normId'] ?? '',
      normName: json['normName'],
      score: json['score'],
      date: DateTime.parse(json['date']),
      comment: json['comment'],
      history: json['history'] != null 
          ? List<Map<String, dynamic>>.from(json['history']) 
          : [],
    );
  }
}

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  List<User> _users = [];
  List<Grade> _grades = [];
  List<Faculty> _faculties = [];
  List<Group> _groups = [];
  List<Norm> _norms = [];
  
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    
    // Users
    final usersString = prefs.getString('users');
    if (usersString != null) {
      final List<dynamic> decoded = jsonDecode(usersString);
      _users = decoded.map((e) => User.fromJson(e)).toList();
    } else {
      _users = [
        User(id: 'admin0', login: 'root', password: 'root', role: UserRole.admin, fullName: 'Администратор'),
        User(id: 'teacher1', login: 'teacher', password: '123', role: UserRole.teacher, fullName: 'Преподаватель Тест'),
      ];
      _saveUsers();
    }

    // Grades
    final gradesString = prefs.getString('grades');
    if (gradesString != null) {
      final List<dynamic> decoded = jsonDecode(gradesString);
      _grades = decoded.map((e) => Grade.fromJson(e)).toList();
    }

    // Faculties
    final facString = prefs.getString('faculties');
    if (facString != null) {
      final List<dynamic> decoded = jsonDecode(facString);
      _faculties = decoded.map((e) => Faculty.fromJson(e)).toList();
    } else {
      _initFacultiesAndGroups(); // Populate default structure
    }

    // Groups
    final grpString = prefs.getString('groups');
    if (grpString != null) {
      final List<dynamic> decoded = jsonDecode(grpString);
      _groups = decoded.map((e) => Group.fromJson(e)).toList();
    }
    // Note: If groups are missing but faculties were initialized by default, they are added in _initFacultiesAndGroups

    // Norms
    final normString = prefs.getString('norms');
    if (normString != null) {
      final List<dynamic> decoded = jsonDecode(normString);
      _norms = decoded.map((e) => Norm.fromJson(e)).toList();
    } else {
      _norms = [
        Norm(id: '101', name: 'Бег 30м'),
        Norm(id: '102', name: 'Бег 60м'),
        Norm(id: '103', name: 'Бег 100м'),
        Norm(id: '104', name: 'Челночный бег 3x10м'),
        Norm(id: '201', name: 'Бег 1000м'),
        Norm(id: '202', name: 'Бег 2000м'),
        Norm(id: '203', name: 'Бег 3000м'),
        Norm(id: '301', name: 'Подтягивание на высокой перекладине'),
        Norm(id: '302', name: 'Подтягивание на низкой перекладине'),
        Norm(id: '303', name: 'Сгибание и разгибание рук (отжимания)'),
        Norm(id: '304', name: 'Рывок гири 16кг'),
        Norm(id: '401', name: 'Наклон вперед (гибкость)'),
        Norm(id: '402', name: 'Поднимание туловища (пресс за 1 мин)'),
        Norm(id: '501', name: 'Прыжок в длину с места'),
        Norm(id: '502', name: 'Метание спортивного снаряда'),
        Norm(id: '601', name: 'Плавание 50м'),
        Norm(id: '602', name: 'Бег на лыжах 3км/5км'),
        Norm(id: '603', name: 'Стрельба из пневматической винтовки'),
      ];
      _saveNorms();
    }

    _isInitialized = true;
  }

  void _initFacultiesAndGroups() {
    // Structure: Faculty Name -> [List of Directions/Groups]
    final data = {
      "Финансово-экономический факультет": [
        "38.05.01 Экономическая безопасность",
        "38.05.02 Таможенное дело",
        "38.03.01 Экономика",
        "38.03.02 Менеджмент",
        "38.03.04 Государственное и муниципальное управление",
        "38.03.05 Бизнес-информатика",
        "43.03.01 Сервис"
      ],
      "Юридический факультет": [
        "40.03.01 Юриспруденция"
      ],
      "Факультет истории и международных отношений": [
        "46.03.01 История",
        "41.03.05 Международные отношения",
        "48.03.01 Теология",
        "44.03.05 ПО (История. Обществознание)",
        "44.03.01 ПО (История)"
      ],
      "Факультет педагогики и психологии": [
        "37.03.01 Психология",
        "39.03.01 Социология",
        "39.03.02 Социальная работа",
        "44.03.01 ПО (Начальное образование)",
        "44.03.01 ПО (Дошкольное образование)",
        "44.03.02 Психолого-педагогическое образование",
        "44.03.03 Специальное (дефектологическое) образование"
      ],
      "Факультет технологии и дизайна": [
        "44.03.05 ПО (Технология. БЖД)",
        "44.03.01 ПО (Технология)",
        "20.03.01 Техносферная безопасность",
        "44.03.04 Профессиональное обучение"
      ],
      "Факультет физической культуры": [
        "44.03.05 ПО (Физкультура. БЖД)",
        "44.03.01 ПО (Физическая культура)",
        "49.03.01 Физическая культура",
        "49.03.02 Физкультура для лиц с отклонениями"
      ],
      "Филологический факультет": [
        "42.03.02 Журналистика",
        "42.03.01 Реклама и связи с общественностью",
        "44.03.05 ПО (Русский язык. Литература)"
      ],
      "Факультет иностранных языков": [
        "45.03.02 Лингвистика",
        "44.03.05 ПО (Иностранный язык)"
      ],
      "Физико-математический факультет": [
        "01.03.02 Прикладная математика и информатика",
        "02.03.02 Фундаментальная информатика и ИТ",
        "03.03.02 Физика",
        "44.03.05 ПО (Математика. Информатика)",
        "44.03.05 ПО (Физика. Информатика)",
        "44.03.01 ПО (Информатика)"
      ],
      "Естественно-географический факультет": [
        "06.03.01 Биология",
        "05.03.06 Экология и природопользование",
        "05.03.02 География",
        "04.03.01 Химия",
        "21.03.02 Землеустройство и кадастры",
        "19.03.01 Биотехнология",
        "44.03.05 ПО (Биология. Химия)",
        "44.03.05 ПО (География. Экология)"
      ]
    };

    int fIndex = 1;
    int gIndex = 1;

    data.forEach((facName, directions) {
      final facId = "fac_$fIndex";
      _faculties.add(Faculty(id: facId, name: facName));
      
      for (var dir in directions) {
        _groups.add(Group(id: "grp_$gIndex", name: dir, facultyId: facId));
        gIndex++;
      }
      fIndex++;
    });

    _saveFaculties();
    _saveGroups();
  }

  Future<void> _saveUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('users', jsonEncode(_users.map((u) => u.toJson()).toList()));
  }

  Future<void> _saveGrades() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('grades', jsonEncode(_grades.map((g) => g.toJson()).toList()));
  }

  Future<void> _saveFaculties() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('faculties', jsonEncode(_faculties.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveGroups() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('groups', jsonEncode(_groups.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveNorms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('norms', jsonEncode(_norms.map((e) => e.toJson()).toList()));
  }

  String _normalize(String value) => value.trim().toLowerCase();

  String _cleanName(String value) => value.trim().replaceAll(RegExp(r'\s+'), ' ');

  void _validateEntityName(String value, {required String fieldName}) {
    final clean = _cleanName(value);
    if (clean.isEmpty) {
      throw Exception('$fieldName не может быть пустым');
    }
    if (clean.length < 3) {
      throw Exception('$fieldName должен содержать минимум 3 символа');
    }
    if (clean.length > 120) {
      throw Exception('$fieldName слишком длинный');
    }
  }

  bool isLoginTaken(String login, {String? excludeUserId}) {
    final normalized = _normalize(login);
    return _users.any(
      (u) => _normalize(u.login) == normalized && (excludeUserId == null || u.id != excludeUserId),
    );
  }

  bool isDuplicateTeacher({required String fullName, String? excludeUserId}) {
    final normalizedName = _normalize(fullName);
    return _users.any(
      (u) =>
          u.role == UserRole.teacher &&
          _normalize(u.fullName) == normalizedName &&
          (excludeUserId == null || u.id != excludeUserId),
    );
  }

  bool isDuplicateStudent({
    required String fullName,
    required String faculty,
    required String group,
    String? excludeUserId,
  }) {
    final normalizedName = _normalize(fullName);
    final normalizedFaculty = _normalize(faculty);
    final normalizedGroup = _normalize(group);

    return _users.any(
      (u) =>
          u.role == UserRole.student &&
          _normalize(u.fullName) == normalizedName &&
          _normalize(u.faculty ?? '') == normalizedFaculty &&
          _normalize(u.group ?? '') == normalizedGroup &&
          (excludeUserId == null || u.id != excludeUserId),
    );
  }

  bool isDuplicateFacultyName(String name, {String? excludeFacultyId}) {
    final normalized = _normalize(name);
    return _faculties.any(
      (f) => _normalize(f.name) == normalized && (excludeFacultyId == null || f.id != excludeFacultyId),
    );
  }

  bool isDuplicateGroupName(String name, {String? excludeGroupId}) {
    final normalized = _normalize(name);
    return _groups.any(
      (g) => _normalize(g.name) == normalized && (excludeGroupId == null || g.id != excludeGroupId),
    );
  }

  bool isDuplicateNormName(String name, {String? excludeNormId}) {
    final normalized = _normalize(name);
    return _norms.any(
      (n) => _normalize(n.name) == normalized && (excludeNormId == null || n.id != excludeNormId),
    );
  }

  User? login(String login, String password, {UserRole? role}) {
    try {
      return _users.firstWhere((u) => 
        u.login.toLowerCase() == login.toLowerCase() && 
        u.password == password &&
        (role == null || u.role == role)
      );
    } catch (e) {
      return null;
    }
  }

  User? getUserById(String id) {
    try {
      return _users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  // --- Norms ---
  List<Norm> getNorms() => _norms;

  Future<void> addNorm(String name) async {
    _validateEntityName(name, fieldName: 'Название норматива');
    final cleanName = _cleanName(name);
    if (isDuplicateNormName(cleanName)) {
      throw Exception('Норматив с таким названием уже существует');
    }
    _norms.add(Norm(id: DateTime.now().millisecondsSinceEpoch.toString(), name: cleanName));
    await _saveNorms();
  }

  Future<void> deleteNorm(String id) async {
    _norms.removeWhere((e) => e.id == id);
    await _saveNorms();
  }

  // --- Faculties ---
  List<Faculty> getFaculties() => _faculties;
  
  Future<void> addFaculty(String name) async {
    _validateEntityName(name, fieldName: 'Название факультета');
    final cleanName = _cleanName(name);
    if (isDuplicateFacultyName(cleanName)) {
      throw Exception('Факультет с таким названием уже существует');
    }
    _faculties.add(Faculty(id: DateTime.now().millisecondsSinceEpoch.toString(), name: cleanName));
    await _saveFaculties();
  }

  Future<void> deleteFaculty(String id) async {
    _faculties.removeWhere((e) => e.id == id);
    _groups.removeWhere((g) => g.facultyId == id);
    await _saveFaculties();
    await _saveGroups();
  }

  // --- Groups ---
  List<Group> getGroups() => _groups;
  List<Group> getGroupsByFaculty(String facultyId) => _groups.where((g) => g.facultyId == facultyId).toList();

  Future<void> addGroup(String name, String facultyId) async {
    _validateEntityName(name, fieldName: 'Название группы');
    final cleanName = _cleanName(name);
    if (isDuplicateGroupName(cleanName)) {
      throw Exception('Группа с таким названием уже существует');
    }
    _groups.add(Group(
      id: DateTime.now().millisecondsSinceEpoch.toString(), 
      name: cleanName, 
      facultyId: facultyId
    ));
    await _saveGroups();
  }

  Future<void> deleteGroup(String id) async {
    _groups.removeWhere((e) => e.id == id);
    await _saveGroups();
  }

  // --- Users ---
  List<User> getTeachers() => _users.where((u) => u.role == UserRole.teacher).toList();
  List<User> getStudents() => _users.where((u) => u.role == UserRole.student).toList();

  Future<void> addTeacher({required String fullName, required String login, required String password}) async {
    if (isLoginTaken(login)) {
      throw Exception('Пользователь с таким логином уже существует');
    }
    if (isDuplicateTeacher(fullName: fullName)) {
      throw Exception('Преподаватель с таким ФИО уже существует');
    }
    _users.add(User(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      login: login,
      password: password,
      role: UserRole.teacher,
      fullName: fullName,
    ));
    await _saveUsers();
  }

  Future<void> addStudent({
    required String fullName,
    required String faculty,
    required String group,
    required String login,
    required String password,
  }) async {
    if (isLoginTaken(login)) {
      throw Exception('Пользователь с таким логином уже существует');
    }
    if (isDuplicateStudent(fullName: fullName, faculty: faculty, group: group)) {
      throw Exception('Студент с таким ФИО, факультетом и группой уже существует');
    }
    _users.add(User(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      login: login,
      password: password,
      role: UserRole.student,
      fullName: fullName,
      faculty: faculty,
      group: group,
    ));
    await _saveUsers();
  }

  Future<void> updateUser({
    required String id,
    String? password,
    String? fullName,
    String? faculty,
    String? group,
  }) async {
    final index = _users.indexWhere((u) => u.id == id);
    if (index != -1) {
      final old = _users[index];
      _users[index] = User(
        id: old.id,
        login: old.login, // Login remains unchanged
        password: password ?? old.password,
        role: old.role,
        fullName: fullName ?? old.fullName,
        faculty: faculty ?? old.faculty,
        group: group ?? old.group,
      );
      await _saveUsers();
    }
  }

  Future<void> deleteUser(String id) async {
    _users.removeWhere((u) => u.id == id);
    await _saveUsers();
  }

  // --- Grades ---
  Future<void> addGrade({
    required String studentId,
    required String studentName,
    required String teacherId,
    required String normId,
    required String normName,
    required int score,
    String? comment,
  }) async {
    final index = _grades.indexWhere((g) => g.studentId == studentId && g.normId == normId);
    
    if (index != -1) {
      final oldGrade = _grades[index];
      final historyEntry = {
        'score': oldGrade.score,
        'date': oldGrade.date.toIso8601String(),
        'comment': oldGrade.comment,
        'teacherId': oldGrade.teacherId, 
      };

      final List<Map<String, dynamic>> newHistory = List.from(oldGrade.history)..add(historyEntry);

      _grades[index] = Grade(
        id: oldGrade.id,
        studentId: studentId,
        studentName: studentName,
        teacherId: teacherId,
        normId: normId,
        normName: normName,
        score: score, 
        date: DateTime.now(), 
        comment: comment, 
        history: newHistory,
      );
    } else {
      _grades.add(Grade(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        studentId: studentId,
        studentName: studentName,
        teacherId: teacherId,
        normId: normId,
        normName: normName,
        score: score,
        date: DateTime.now(),
        comment: comment,
        history: [],
      ));
    }
    await _saveGrades();
  }

  List<Grade> getGrades() => _grades;

  List<Grade> getGradesForStudent(String studentId) {
    return _grades.where((g) => g.studentId == studentId).toList();
  }
}
