import '../models/user.dart';
import 'api_service.dart';

class SessionService {
  Future<void> saveSession(User user) async {
    // No-op: Session is managed by JWT token in ApiService
  }

  Future<void> clearSession() async {
    await ApiService().logout();
  }

  Future<User?> loadSessionUser() async {
    // Ensure API service is initialized (token loaded)
    await ApiService().init();
    return await ApiService().getMe();
  }
}
