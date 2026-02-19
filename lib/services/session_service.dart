import '../models/user.dart';
import 'api_service.dart';

class SessionService {
  Future<void> clearSession() async {
    await ApiService().logout();
  }

  Future<void> initSession() async {
    await ApiService().init();
  }

  Future<User?> loadSessionUser() async {
    await initSession();
    return await ApiService().getMe();
  }
}
