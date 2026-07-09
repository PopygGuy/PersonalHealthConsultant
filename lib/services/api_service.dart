import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/user_role.dart';
import '../models/faculty.dart';
import '../models/group.dart';
import '../models/norm.dart';
import '../models/grade.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String _jwtTokenKey = 'jwt_token';
  static const String _apiBaseUrlDefine =
      String.fromEnvironment('API_BASE_URL');

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://127.0.0.1:8000',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _token;
  User? _currentUser;

  User? get currentUser => _currentUser;
  String get baseUrl => _dio.options.baseUrl;

  Future<void> init() async {
    final resolvedBaseUrl = _normalizeBaseUrl(
      _apiBaseUrlDefine.isNotEmpty
          ? _apiBaseUrlDefine
          : _defaultBaseUrl(),
    );

    _dio.options.baseUrl = resolvedBaseUrl;
    print("API Base URL: ${_dio.options.baseUrl}");
    _token = await _readStoredToken();
    // Ideally, validate token or fetch user profile here
  }

  Future<String?> _readStoredToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_jwtTokenKey);
    }
    try {
      return await _storage.read(key: _jwtTokenKey);
    } catch (e) {
      print('Token read error: $e');
      return null;
    }
  }

  Future<void> _persistToken(String token) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_jwtTokenKey, token);
      return;
    }
    try {
      await _storage.write(key: _jwtTokenKey, value: token);
    } catch (e) {
      // Do not fail login if token persistence fails.
      print('Token persist error: $e');
    }
  }

  Future<void> _clearStoredToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_jwtTokenKey);
      return;
    }
    try {
      await _storage.delete(key: _jwtTokenKey);
    } catch (e) {
      print('Token delete error: $e');
    }
  }

  String _defaultBaseUrl() {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    if (Platform.isAndroid) {
      // Emulator default for local development.
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  String _normalizeBaseUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return _defaultBaseUrl();
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }

    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) {
      return _defaultBaseUrl();
    }

    final withPort = uri.hasPort ? uri : uri.replace(port: 8000);
    var normalized = withPort.toString();
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  Future<User?> getMe() async {
    if (_token == null || _token!.trim().isEmpty) {
      return null;
    }
    try {
      final response = await get('/users/me');
      if (response.statusCode == 200) {
        _currentUser = User.fromJson(response.data);
        return _currentUser;
      }
    } catch (e) {
      print('getMe error: $e');
    }
    return null;
  }

  Future<User?> login(String username, String password) async {
    try {
      final response = await _dio.post('/token',
          data: {
            'username': username,
            'password': password,
          },
          options: Options(contentType: Headers.formUrlEncodedContentType));

      if (response.statusCode == 200) {
        final data = response.data;
        _token = data['access_token'];
        await _persistToken(_token!);
        // Immediately fetch full profile (with faculty/group ids and names).
        final me = await getMe();
        if (me != null) {
          return me;
        }

        // Fallback to token payload mapping if /users/me is unavailable.
        final roleStr = data['role'] as String;
        UserRole role;
        if (roleStr == 'admin') {
          role = UserRole.admin;
        } else if (roleStr == 'teacher') {
          role = UserRole.teacher;
        } else {
          role = UserRole.student;
        }

        _currentUser = User(
          id: data['id'],
          login: username,
          role: role,
          fullName: data['full_name'],
          facultyId: data['faculty_id'],
          groupId: data['group_id'],
          faculty: data['faculty'],
          group: data['group'],
        );
        return _currentUser;
      }
    } catch (e) {
      print('Login error: $e');
      return null;
    }
    return null;
  }

  Future<void> logout() async {
    if (_token != null) {
      try {
        await post('/auth/logout', {});
      } catch (e) {
        print('logout audit error: $e');
      }
    }
    _token = null;
    _currentUser = null;
    await _clearStoredToken();
  }

  // Helper for authenticated requests
  Future<Response> get(String path) async {
    final headers = <String, dynamic>{};
    if (_token != null && _token!.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return _dio.get(path, options: Options(headers: headers));
  }

  Future<Response> post(String path, dynamic data) async {
    final headers = <String, dynamic>{};
    if (_token != null && _token!.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return _dio.post(path, data: data, options: Options(headers: headers));
  }

  Future<Response> put(String path, dynamic data) async {
    final headers = <String, dynamic>{};
    if (_token != null && _token!.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return _dio.put(path, data: data, options: Options(headers: headers));
  }

  Future<Response> delete(String path) async {
    final headers = <String, dynamic>{};
    if (_token != null && _token!.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return _dio.delete(path, options: Options(headers: headers));
  }

  // --- Admin API ---
  Future<List<Faculty>> getFaculties() async {
    try {
      final response = await get('/faculties');
      return (response.data as List).map((e) => Faculty.fromJson(e)).toList();
    } catch (e) {
      print('getFaculties error: $e');
      return [];
    }
  }

  Future<Faculty?> createFaculty(String name) async {
    try {
      final response = await post('/faculties', {'name': name});
      return Faculty.fromJson(response.data);
    } on DioException catch (e) {
      final detail = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['detail']?.toString() ??
              'Ошибка создания факультета')
          : 'Ошибка создания факультета';
      throw Exception(detail);
    } catch (e) {
      print('createFaculty error: $e');
      throw Exception('Ошибка создания факультета');
    }
  }

  Future<bool> deleteFaculty(String id) async {
    try {
      await delete('/faculties/$id');
      return true;
    } catch (e) {
      print('deleteFaculty error: $e');
      return false;
    }
  }

  Future<List<Group>> getGroups({String? facultyId}) async {
    try {
      final path =
          facultyId != null ? '/groups?faculty_id=$facultyId' : '/groups';
      final response = await get(path);
      return (response.data as List).map((e) => Group.fromJson(e)).toList();
    } catch (e) {
      print('getGroups error: $e');
      return [];
    }
  }

  Future<Group> createGroup(String name, String facultyId) async {
    try {
      final response =
          await post('/groups', {'name': name, 'faculty_id': facultyId});
      return Group.fromJson(response.data);
    } on DioException catch (e) {
      final detail = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['detail']?.toString() ?? 'Ошибка создания группы')
          : 'Ошибка создания группы';
      throw Exception(detail);
    } catch (e) {
      print('createGroup error: $e');
      throw Exception('Ошибка создания группы');
    }
  }

  Future<bool> deleteGroup(String id) async {
    try {
      await delete('/groups/$id');
      return true;
    } catch (e) {
      print('deleteGroup error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> repairCatalog() async {
    try {
      final response = await post('/admin/maintenance/repair-catalog', {});
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const {
        'ok': true,
        'message': 'Справочники восстановлены',
      };
    } on DioException catch (e) {
      final detail = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['detail']?.toString() ??
              'Ошибка восстановления справочников')
          : 'Ошибка восстановления справочников';
      throw Exception(detail);
    } catch (e) {
      print('repairCatalog error: $e');
      throw Exception('Ошибка восстановления справочников');
    }
  }

  Future<List<User>> getUsers({String? role}) async {
    try {
      final path = role != null ? '/users?role=$role' : '/users';
      final response = await get(path);
      return (response.data as List).map((e) => User.fromJson(e)).toList();
    } catch (e) {
      print('getUsers error: $e');
      return [];
    }
  }

  Future<User?> createUser({
    required String login,
    required String password,
    required UserRole role,
    required String fullName,
    String? facultyId,
    String? groupId,
  }) async {
    try {
      final response = await post('/users', {
        'login': login,
        'password': password,
        'role': role.toString().split('.').last,
        'full_name': fullName,
        'faculty_id': facultyId,
        'group_id': groupId,
      });
      return User.fromJson(response.data);
    } on DioException catch (e) {
      final detail = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['detail']?.toString() ??
              'Ошибка создания пользователя')
          : 'Ошибка создания пользователя';
      throw Exception(detail);
    } catch (e) {
      print('createUser error: $e');
      throw Exception('Ошибка создания пользователя');
    }
  }

  Future<bool> deleteUser(String id) async {
    try {
      await delete('/users/$id');
      return true;
    } catch (e) {
      print('deleteUser error: $e');
      return false;
    }
  }

  Future<User?> updateUser({
    required String id,
    String? fullName,
    String? password,
    String? facultyId,
    String? groupId,
  }) async {
    try {
      final response = await put('/users/$id', {
        'full_name': fullName,
        'password': password,
        'faculty_id': facultyId,
        'group_id': groupId,
      });
      return User.fromJson(response.data);
    } on DioException catch (e) {
      print('updateUser error: ${e.response?.data ?? e.message}');
      return null;
    } catch (e) {
      print('updateUser error: $e');
      return null;
    }
  }

  // --- Norms and Grades API (Future Use) ---
  Future<List<Norm>> getNorms() async {
    try {
      final response = await get('/norms');
      return (response.data as List).map((e) => Norm.fromJson(e)).toList();
    } catch (e) {
      print('getNorms error: $e');
      return [];
    }
  }

  Future<Norm?> createNorm(String name) async {
    try {
      final response = await post('/norms', {'name': name});
      return Norm.fromJson(response.data);
    } on DioException catch (e) {
      final detail = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['detail']?.toString() ??
              'Ошибка создания норматива')
          : 'Ошибка создания норматива';
      throw Exception(detail);
    } catch (e) {
      print('createNorm error: $e');
      throw Exception('Ошибка создания норматива');
    }
  }

  Future<bool> deleteNorm(String id) async {
    try {
      await delete('/norms/$id');
      return true;
    } catch (e) {
      print('deleteNorm error: $e');
      return false;
    }
  }

  Future<Norm?> updateNormStatus(String id, bool isActive) async {
    try {
      final response =
          await put('/norms/$id/status', {'is_active': isActive});
      return Norm.fromJson(response.data);
    } on DioException catch (e) {
      final detail = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['detail']?.toString() ??
              'Ошибка изменения статуса норматива')
          : 'Ошибка изменения статуса норматива';
      throw Exception(detail);
    } catch (e) {
      print('updateNormStatus error: $e');
      throw Exception('Ошибка изменения статуса норматива');
    }
  }

  Future<List<Grade>> getGrades({
    String? studentId,
    String? normId,
    String? academicYear,
    int? course,
    int? semester,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (studentId != null) queryParams['student_id'] = studentId;
      if (normId != null) queryParams['norm_id'] = normId;
      if (academicYear != null && academicYear.trim().isNotEmpty) {
        queryParams['academic_year'] = academicYear.trim();
      }
      if (course != null) queryParams['course'] = course.toString();
      if (semester != null) queryParams['semester'] = semester.toString();

      final queryString = Uri(queryParameters: queryParams).query;
      final path = queryString.isNotEmpty ? '/grades?$queryString' : '/grades';

      final response = await get(path);
      return (response.data as List).map((e) => Grade.fromJson(e)).toList();
    } catch (e) {
      print('getGrades error: $e');
      return [];
    }
  }

  Future<Grade?> createGrade({
    required String studentId,
    required String normId,
    required String academicYear,
    required int course,
    required int semester,
    required int score,
    String? comment,
  }) async {
    try {
      final response = await post('/grades', {
        'student_id': studentId,
        'norm_id': normId,
        'academic_year': academicYear,
        'course': course,
        'semester': semester,
        'score': score,
        'comment': comment,
      });
      return Grade.fromJson(response.data);
    } on DioException catch (e) {
      final detail = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['detail']?.toString() ??
              'Ошибка выставления оценки')
          : 'Ошибка выставления оценки';
      throw Exception(detail);
    } catch (e) {
      print('createGrade error: $e');
      throw Exception('Ошибка выставления оценки');
    }
  }

  // --- Step Tracker API ---
  Future<StepStats?> getSteps(String date) async {
    try {
      final response = await get('/steps/$date');
      return StepStats.fromJson(response.data);
    } catch (e) {
      print('getSteps error: $e');
      return null;
    }
  }

  Future<StepStats?> updateSteps({
    required String date,
    required int steps,
    required int goal,
    required double strideMeters,
    int? heightCm,
    required bool isCustomStride,
  }) async {
    try {
      final response = await post('/steps', {
        'date': date,
        'steps': steps,
        'goal': goal,
        'stride_meters': strideMeters,
        'height_cm': heightCm,
        'is_custom_stride': isCustomStride,
      });
      return StepStats.fromJson(response.data);
    } catch (e) {
      print('updateSteps error: $e');
      return null;
    }
  }
}

class StepStats {
  final String id;
  final String userId;
  final String date;
  final int steps;
  final int goal;
  final double strideMeters;
  final int? heightCm;
  final bool isCustomStride;

  StepStats({
    required this.id,
    required this.userId,
    required this.date,
    required this.steps,
    required this.goal,
    required this.strideMeters,
    this.heightCm,
    required this.isCustomStride,
  });

  factory StepStats.fromJson(Map<String, dynamic> json) {
    return StepStats(
      id: json['id'],
      userId: json['user_id'],
      date: json['date'],
      steps: json['steps'],
      goal: json['goal'],
      strideMeters: (json['stride_meters'] as num).toDouble(),
      heightCm: json['height_cm'],
      isCustomStride: json['is_custom_stride'],
    );
  }
}
