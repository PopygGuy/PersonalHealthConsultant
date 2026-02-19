import 'user_role.dart';

class User {
  final String id;
  String login;
  final UserRole role;
  String fullName;
  
  final String? facultyId;
  final String? groupId;
  
  // Names (optional, populated if available)
  final String? faculty;
  final String? group;

  User({
    required this.id,
    required this.login,
    required this.role,
    required this.fullName,
    this.facultyId,
    this.groupId,
    this.faculty,
    this.group,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'login': login,
    'role': role.index,
    'fullName': fullName,
    'faculty_id': facultyId,
    'group_id': groupId,
    'faculty': faculty,
    'group': group,
  };

  factory User.fromJson(Map<String, dynamic> json) {
    UserRole role;
    if (json['role'] is int) {
      role = UserRole.values[json['role']];
    } else {
      final roleStr = json['role'] as String;
      if (roleStr == 'admin') role = UserRole.admin;
      else if (roleStr == 'teacher') role = UserRole.teacher;
      else role = UserRole.student;
    }

    return User(
      id: json['id'],
      login: json['login'],
      role: role,
      fullName: json['full_name'] ?? json['fullName'],
      facultyId: json['faculty_id'],
      groupId: json['group_id'],
      faculty: json['faculty'],
      group: json['group'],
    );
  }
}
