import 'package:hive/hive.dart';

class OrgAccess {
  final String code;
  final String name;

  OrgAccess({
    required this.code,
    required this.name,
  });

  factory OrgAccess.fromJson(Map<String, dynamic> json) {
    return OrgAccess(
      code: json['Код']?.toString() ?? '',
      name: json['Наименование']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Код': code,
      'Наименование': name,
    };
  }
}

class SessionData {
  final String token;
  final String fullName;
  final bool canApprovePayments;
  final List<OrgAccess> orgs;

  /// UID елемента довідника "ПользователиМобильногоПриложения" (з /me)
  /// Може бути null для старих сесій або якщо бекенд його не віддав.
  final String? userUid;

  SessionData({
    required this.token,
    required this.fullName,
    required this.canApprovePayments,
    required this.orgs,
    this.userUid,
  });

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'fullName': fullName,
      'canApprovePayments': canApprovePayments,
      'orgs': orgs.map((o) => o.toJson()).toList(),
      if (userUid != null) 'userUid': userUid,
    };
  }
}

class SessionStore {
  static const String _boxName = 'mova_session';

  static Future<Box> _openBox() async {
    return Hive.openBox(_boxName);
  }

  static Future<void> saveSession(SessionData session) async {
    final box = await _openBox();
    await box.put('session', session.toJson());
  }

  static Future<SessionData?> loadSession() async {
    final box = await _openBox();
    final raw = box.get('session');
    if (raw == null || raw is! Map) {
      return null;
    }

    final map = Map<String, dynamic>.from(raw as Map);

    final orgsRaw = map['orgs'] as List<dynamic>? ?? const [];
    final orgs = orgsRaw
        .map((e) => OrgAccess.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return SessionData(
      token: map['token']?.toString() ?? '',
      fullName: map['fullName']?.toString() ?? '',
      canApprovePayments: map['canApprovePayments'] ?? false,
      orgs: orgs,
      // 🔹 uid збережений після /me
      userUid: map['userUid']?.toString(),
    );
  }

  static Future<void> clear() async {
    final box = await _openBox();
    await box.delete('session');
  }
}
