import 'package:hive/hive.dart';

class DeliveryMethod {
  final String code;
  final String name;

  DeliveryMethod({
    required this.code,
    required this.name,
  });

  factory DeliveryMethod.fromJson(Map<String, dynamic> json) {
    return DeliveryMethod(
      code: json['Код']?.toString() ?? json['code']?.toString() ?? '',
      name: json['Наименование']?.toString() ?? json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Код': code,
      'Наименование': name,
    };
  }
}

class OrgAccess {
  final String code;
  final String name;
  final List<DeliveryMethod> deliveryMethods;
  final String? defaultDeliveryMethod;

  OrgAccess({
    required this.code,
    required this.name,
    this.deliveryMethods = const [],
    this.defaultDeliveryMethod,
  });

  factory OrgAccess.fromJson(Map<String, dynamic> json) {
    final methodsRaw =
        json['СпособыДоставки'] ??
            json['deliveryMethods'] ??
            const [];

    final List<DeliveryMethod> methods = [];

    if (methodsRaw is List) {
      for (final item in methodsRaw) {
        if (item is Map) {
          methods.add(
            DeliveryMethod.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    return OrgAccess(
      code: json['Код']?.toString() ??
          json['code']?.toString() ??
          '',
      name: json['Наименование']?.toString() ??
          json['name']?.toString() ??
          '',
      deliveryMethods: methods,
      defaultDeliveryMethod:
      json['ОсновнойСпособДоставки']?.toString() ??
          json['defaultDeliveryMethod']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Код': code,
      'Наименование': name,
      'СпособыДоставки': deliveryMethods.map((e) => e.toJson()).toList(),
      if (defaultDeliveryMethod != null)
        'ОсновнойСпособДоставки': defaultDeliveryMethod,
    };
  }
}



class SubdivisionAccess {
  final String uid;
  final String name;

  SubdivisionAccess({
    required this.uid,
    required this.name,
  });

  factory SubdivisionAccess.fromJson(Map<String, dynamic> json) {
    return SubdivisionAccess(
      uid: json['Ссылка']?.toString() ??
          json['uid']?.toString() ??
          json['id']?.toString() ??
          '',
      name: json['Наименование']?.toString() ??
          json['name']?.toString() ??
          '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Ссылка': uid,
      'Наименование': name,
    };
  }
}

class SessionData {
  final String token;
  final String fullName;
  final bool canApprovePayments;
  final List<OrgAccess> orgs;
  final List<SubdivisionAccess> subdivisions;

  /// UID елемента довідника "ПользователиМобильногоПриложения" (з /me)
  /// Може бути null для старих сесій або якщо бекенд його не віддав.
  final String? userUid;

  SessionData({
    required this.token,
    required this.fullName,
    required this.canApprovePayments,
    required this.orgs,
    this.subdivisions = const [],
    this.userUid,
  });

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'fullName': fullName,
      'canApprovePayments': canApprovePayments,
      'orgs': orgs.map((o) => o.toJson()).toList(),
      'subdivisions': subdivisions.map((s) => s.toJson()).toList(),
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

    final map = Map<String, dynamic>.from(raw);

    final orgsRaw = map['orgs'] as List<dynamic>? ?? const [];
    final orgs = orgsRaw
        .map((e) => OrgAccess.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final subdivisionsRaw = map['subdivisions'] as List<dynamic>? ?? const [];
    final subdivisions = subdivisionsRaw
        .map((e) => SubdivisionAccess.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return SessionData(
      token: map['token']?.toString() ?? '',
      fullName: map['fullName']?.toString() ?? '',
      canApprovePayments: map['canApprovePayments'] == true,
      orgs: orgs,
      subdivisions: subdivisions,
      userUid: map['userUid']?.toString(),
    );
  }

  static Future<void> clear() async {
    final box = await _openBox();
    await box.delete('session');
  }
}