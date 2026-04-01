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
  bool _canApprovePayments = false;
  String? lastError;

  bool get isLoggedIn => currentUser != null;

  bool get canApprovePayments {
    final u = currentUser;
    if (u == null) return false;

    // 1) Прямой серверный флаг из /me
    if (_canApprovePayments) return true;

    // 2) Если в UserModel есть поле canApprovePayments — используем его
    try {
      final v = (u as dynamic).canApprovePayments;
      if (v is bool) return v;
    } catch (_) {
      // ignore
    }

    // 3) Fallback по ролям
    final roles = u.roles.map((e) => e.toLowerCase().trim()).toList();
    return roles.contains('approver') ||
        roles.contains('approve_payments') ||
        roles.contains('payments_approver') ||
        roles.contains('утверждает') ||
        roles.contains('затверджує');
  }

  String get approvalsTitle =>
      canApprovePayments ? 'На погодженні' : 'Мої заявки';

  bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;

    final s = value.toString().trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  Future<void> loadUser() async {
    try {
      final me = await _apiClient.getMe();
      debugPrint('AuthProvider.loadUser: /me = $me');

      if (me == null) return;

      final user = UserModel.fromJson(me);
      currentUser = user;

      // ✅ Прямой флаг с сервера
      _canApprovePayments = _parseBool(me['canApprovePayments']);

      final String? userUid = me['uid']?.toString();

      List<OrgAccess> orgs = [];
      List<SubdivisionAccess> subdivisions = [];
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

      try {
        final subdivisionsJson = me['subdivisions'] as List<dynamic>? ?? const [];
        subdivisions = subdivisionsJson
            .map(
              (e) => SubdivisionAccess.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .where((e) => e.uid.isNotEmpty)
            .toList();
      } catch (e) {
        debugPrint('AuthProvider.loadUser: error parsing subdivisions: $e');
      }

      final session = SessionData(
        token: _apiClient.accessToken ?? '',
        fullName: user.name,
        canApprovePayments: canApprovePayments,
        orgs: orgs,
        subdivisions: subdivisions,
        userUid: userUid,
      );
      await SessionStore.saveSession(session);

      notifyListeners();
    } catch (e) {
      debugPrint('AuthProvider.loadUser: error $e');
    }
  }

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

      // Временный пользователь до /me
      currentUser = UserModel(
        uid: login,
        name: login,
        roles: const [],
      );
      _canApprovePayments = false;
      notifyListeners();

      // Подтягиваем реальные данные
      await loadUser();

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
    _canApprovePayments = false;
    lastError = null;

    notifyListeners();
  }
}