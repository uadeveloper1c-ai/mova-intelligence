// lib/api/auth_provider.dart
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'push_service.dart';
import 'user_model.dart';
import 'package:mova_intelligence_app/features/auth/session_store.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required ApiClient apiClient,
    required PushService pushService,
  })  : _apiClient = apiClient,
        _pushService = pushService;

  final ApiClient _apiClient;
  final PushService _pushService;

  UserModel? currentUser;
  bool isLoading = false;
  String? lastError;

  bool get isLoggedIn => currentUser != null;

  /// Подтянуть пользователя по /me (используем для уточнения данных и orgs),
  /// но НЕ ломаем логин, если здесь что-то пойдёт не так.
  Future<void> loadUser() async {
    try {
      final me = await _apiClient.getMe();
      debugPrint('AuthProvider.loadUser: /me = $me');

      if (me == null) {
        return;
      }

      // Парсим пользователя
      final user = UserModel.fromJson(me);
      currentUser = user;

      // UID користувача мобільного додатку з /me
      final String? userUid = me['uid']?.toString();

      // orgs
      List<OrgAccess> orgs = [];
      try {
        final orgsJson = me['orgs'] as List<dynamic>? ?? const [];
        orgs = orgsJson
            .map(
              (e) => OrgAccess.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
            .toList();
      } catch (e) {
        debugPrint('AuthProvider.loadUser: error parsing orgs: $e');
      }

      // Сесія для заявок
      final session = SessionData(
        token: _apiClient.accessToken ?? '',
        fullName: user.name,
        canApprovePayments: user.canApprovePayments,
        orgs: orgs,
        userUid: userUid, // 🔹 ТУТ важное место
      );
      await SessionStore.saveSession(session);

      notifyListeners();
    } catch (e) {
      debugPrint('AuthProvider.loadUser: error $e');
    }
  }

  /// Логин:
  /// 1) /login — если ок → СРАЗУ считаем пользователя залогиненным
  /// 2) в фоне дергаем /me, чтобы подтянуть роли, orgs и т.п.
  Future<bool> login(String login, String password) async {
    isLoading = true;
    lastError = null;
    notifyListeners();

    try {
      final ok = await _apiClient.login(login, password);
      debugPrint('AuthProvider.login: apiClient.login = $ok');

      if (!ok) {
        lastError = _apiClient.lastLoginError ?? 'Помилка логіна';
        return false;
      }

      // ===== КРИТИЧЕСКИЙ МОМЕНТ =====
      // Считаем, что пользователь залогинен, даже если /me потом ляжет.
      currentUser = UserModel(
        uid: login,          // временно используем логин
        name: login,
        roles: const [],     // позже подтянем из /me
      );
      notifyListeners();     // чтобы GoRouter увидел loggedIn = true

      // В фоне подтянем реальные данные и orgs
      // (НЕ ждём, чтобы не ломать логин)
      loadUser();

      // Регистрируем устройство для push (ошибка здесь логин не ломает)
      try {
        await _pushService.registerCurrentDevice();
      } catch (e) {
        debugPrint('AuthProvider.login: registerCurrentDevice error: $e');
      }

      return true;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _pushService.unregisterCurrentDevice();
    } catch (e) {
      debugPrint('AuthProvider.logout: unregisterCurrentDevice error: $e');
    }

    await _apiClient.clearTokens();
    await SessionStore.clear();

    currentUser = null;
    notifyListeners();
  }
}
