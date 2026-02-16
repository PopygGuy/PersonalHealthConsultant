import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  static const String _apiBaseUrlKey = 'api_base_url';
  static const String _apiBaseUrlDefine = String.fromEnvironment('API_BASE_URL');

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
    final savedBaseUrl = await _storage.read(key: _apiBaseUrlKey);
    final resolvedBaseUrl = _normalizeBaseUrl(
      _apiBaseUrlDefine.isNotEmpty
          ? _apiBaseUrlDefine
          : (savedBaseUrl?.isNotEmpty == true ? savedBaseUrl! : _defaultBaseUrl()),
    );

    _dio.options.baseUrl = resolvedBaseUrl;
    print("API Base URL: ${_dio.options.baseUrl}");
    _token = await _storage.read(key: _jwtTokenKey);
    // Ideally, validate token or fetch user profile here
  }

  Future<void> setBaseUrl(String rawBaseUrl) async {
    final normalized = _normalizeBaseUrl(rawBaseUrl);
    _dio.options.baseUrl = normalized;
    await _storage.write(key: _apiBaseUrlKey, value: normalized);
  }

  String _defaultBaseUrl() {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    if (Platform.isAndroid) {
      // Emulator default. On real devices set custom server URL in login screen.
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
      final response = await _dio.post('/token', data: {
        'username': username,
        'password': password,
      }, options: Options(contentType: Headers.formUrlEncodedContentType));

      if (response.statusCode == 200) {
        final data = response.data;
        _token = data['access_token'];
        await _storage.write(key: _jwtTokenKey, value: _token);

        // Map response to User object
        // The backend returns {access_token, token_type, role, id, full_name}
        final roleStr = data['role'] as String;
        UserRole role;
        if (roleStr == 'admin') role = UserRole.admin;
        else if (roleStr == 'teacher') role = UserRole.teacher;
        else role = UserRole.student;

        _currentUser = User(
          id: data['id'],
          login: username,
          password: '', // Don't store password
          role: role,
          fullName: data['full_name'],
          faculty: null, // Fetch if needed
          group: null, // Fetch if needed
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
    _token = null;
    _currentUser = null;
    await _storage.delete(key: _jwtTokenKey);
  }

  // Helper for authenticated requests
  Future<Response> get(String path) async {
    return _dio.get(path, options: Options(headers: {'Authorization': 'Bearer $_token'}));
  }

  Future<Response> post(String path, dynamic data) async {
    return _dio.post(path, data: data, options: Options(headers: {'Authorization': 'Bearer $_token'}));
  }

  Future<Response> delete(String path) async {
    return _dio.delete(path, options: Options(headers: {'Authorization': 'Bearer $_token'}));
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
    } catch (e) {
      print('createFaculty error: $e');
      return null;
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
      final path = facultyId != null ? '/groups?faculty_id=$facultyId' : '/groups';
      final response = await get(path);
      return (response.data as List).map((e) => Group.fromJson(e)).toList();
    } catch (e) {
      print('getGroups error: $e');
      return [];
    }
  }

  Future<Group> createGroup(String name, String facultyId) async {
    try {
      final response = await post('/groups', {'name': name, 'faculty_id': facultyId});
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
    } catch (e) {
      print('createUser error: $e');
      return null;
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
    } catch (e) {
      print('createNorm error: $e');
      return null;
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

  Future<List<Grade>> getGrades({String? studentId, String? normId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (studentId != null) queryParams['student_id'] = studentId;
      if (normId != null) queryParams['norm_id'] = normId;
      
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
    required int score,
    String? comment,
  }) async {
    try {
      final response = await post('/grades', {
        'student_id': studentId,
        'norm_id': normId,
        'score': score,
        'comment': comment,
      });
      return Grade.fromJson(response.data);
    } catch (e) {
      print('createGrade error: $e');
      return null;
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
