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
  bool _canNotifyOwnSubdivision = false;
  bool _canNotifyOtherSubdivisions = false;
  bool _canNotifyUsers = false;
  bool _canNotifyAll = false;
  bool _canNotifyOwner = false;
  String? _defaultSubdivisionUid;
  int _avatarVersion = 0;
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

  bool get canNotifyOwnSubdivision => _canNotifyOwnSubdivision;
  bool get canNotifyOtherSubdivisions => _canNotifyOtherSubdivisions;
  bool get canNotifyUsers => _canNotifyUsers;
  bool get canNotifyAll => _canNotifyAll;
  bool get canNotifyOwner => _canNotifyOwner;
  String? get defaultSubdivisionUid => _defaultSubdivisionUid;
  int get avatarVersion => _avatarVersion;
  bool get canAccessNotifications =>
      _canNotifyOwnSubdivision ||
      _canNotifyOtherSubdivisions ||
      _canNotifyUsers ||
      _canNotifyAll ||
      _canNotifyOwner;

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

      final meMap = Map<String, dynamic>.from(me);

      // ✅ Прямой флаг с сервера
      _canApprovePayments = _parseBool(meMap['canApprovePayments']);
      _canNotifyOwnSubdivision = _parseBool(meMap['canNotifyOwnSubdivision']);
      _canNotifyOtherSubdivisions =
          _parseBool(meMap['canNotifyOtherSubdivisions']);
      _canNotifyUsers = _parseBool(meMap['canNotifyUsers']);
      _canNotifyAll = _parseBool(meMap['canNotifyAll']);
      _canNotifyOwner = _parseBool(meMap['canNotifyOwner']);
      _defaultSubdivisionUid = meMap['defaultSubdivisionUid']?.toString() ??
          meMap['defaultSubdivision']?.toString() ??
          meMap['defaultsubdivision']?.toString();

      final String? userUid = meMap['uid']?.toString();

      List<OrgAccess> orgs = [];
      List<SubdivisionAccess> subdivisions = [];
      try {
        final orgsJson = meMap['orgs'] as List<dynamic>? ?? const [];
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
        final subdivisionsJson =
            meMap['subdivisions'] as List<dynamic>? ?? const [];
        subdivisions = subdivisionsJson
            .map(
              (e) => SubdivisionAccess.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      } catch (e) {
        debugPrint('AuthProvider.loadUser: error parsing subdivisions: $e');
      }

      final hasSubdivisionName = (meMap['subdivisionName']
                  ?.toString()
                  .trim()
                  .isNotEmpty ??
              false) ||
          (meMap['name_subdivision']?.toString().trim().isNotEmpty ?? false) ||
          (meMap['subdivision_name']?.toString().trim().isNotEmpty ?? false) ||
          (meMap['Підрозділ']?.toString().trim().isNotEmpty ?? false) ||
          (meMap['Подразделение']?.toString().trim().isNotEmpty ?? false);

      if (!hasSubdivisionName && subdivisions.isNotEmpty) {
        SubdivisionAccess? subdivision;
        final defaultUid = _defaultSubdivisionUid?.trim() ?? '';

        if (defaultUid.isNotEmpty) {
          for (final item in subdivisions) {
            if (item.uid == defaultUid) {
              subdivision = item;
              break;
            }
          }
        }

        subdivision ??= subdivisions.length == 1 ? subdivisions.first : null;

        if (subdivision != null && subdivision.name.trim().isNotEmpty) {
          meMap['subdivisionName'] = subdivision.name;
        }
      }

      final user = UserModel.fromJson(meMap);
      currentUser = user;

      final session = SessionData(
        token: _apiClient.accessToken ?? '',
        fullName: user.name,
        canApprovePayments: canApprovePayments,
        orgs: orgs,
        subdivisions: subdivisions,
        defaultSubdivisionUid: _defaultSubdivisionUid,
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
        avatarUrl: '',
      );
      _canApprovePayments = false;
      _canNotifyOwnSubdivision = false;
      _canNotifyOtherSubdivisions = false;
      _canNotifyUsers = false;
      _canNotifyAll = false;
      _canNotifyOwner = false;
      _defaultSubdivisionUid = null;
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
    _canNotifyOwnSubdivision = false;
    _canNotifyOtherSubdivisions = false;
    _canNotifyUsers = false;
    _canNotifyAll = false;
    _canNotifyOwner = false;
    _defaultSubdivisionUid = null;
    lastError = null;

    notifyListeners();
  }

  Future<void> uploadAvatar({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final response =
        await _apiClient.uploadAvatar(bytes: bytes, mimeType: mimeType);
    final avatarUrl = response['avatarUrl']?.toString() ??
        response['avatar_url']?.toString() ??
        '';

    if (currentUser != null && avatarUrl.trim().isNotEmpty) {
      currentUser = currentUser!.copyWith(avatarUrl: avatarUrl.trim());
      notifyListeners();
    }

    _avatarVersion++;
    await loadUser();
  }
}
