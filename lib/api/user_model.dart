// lib/api/user_model.dart

class UserModel {
  final String uid;
  final String name;
  final String subdivisionName;
  final String managerName;
  final List<String> roles;
  final bool canNotifyOwnSubdivision;
  final bool canNotifyOtherSubdivisions;
  final bool canNotifyUsers;
  final bool canNotifyAll;
  final bool canNotifyOwner;
  final String defaultSubdivisionUid;
  final String avatarUrl;

  UserModel({
    required this.uid,
    required this.name,
    this.subdivisionName = '',
    this.managerName = '',
    required this.roles,
    this.canNotifyOwnSubdivision = false,
    this.canNotifyOtherSubdivisions = false,
    this.canNotifyUsers = false,
    this.canNotifyAll = false,
    this.canNotifyOwner = false,
    this.defaultSubdivisionUid = '',
    this.avatarUrl = '',
  });

  UserModel copyWith({
    String? uid,
    String? name,
    String? subdivisionName,
    String? managerName,
    List<String>? roles,
    bool? canNotifyOwnSubdivision,
    bool? canNotifyOtherSubdivisions,
    bool? canNotifyUsers,
    bool? canNotifyAll,
    bool? canNotifyOwner,
    String? defaultSubdivisionUid,
    String? avatarUrl,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      subdivisionName: subdivisionName ?? this.subdivisionName,
      managerName: managerName ?? this.managerName,
      roles: roles ?? this.roles,
      canNotifyOwnSubdivision:
          canNotifyOwnSubdivision ?? this.canNotifyOwnSubdivision,
      canNotifyOtherSubdivisions:
          canNotifyOtherSubdivisions ?? this.canNotifyOtherSubdivisions,
      canNotifyUsers: canNotifyUsers ?? this.canNotifyUsers,
      canNotifyAll: canNotifyAll ?? this.canNotifyAll,
      canNotifyOwner: canNotifyOwner ?? this.canNotifyOwner,
      defaultSubdivisionUid:
          defaultSubdivisionUid ?? this.defaultSubdivisionUid,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // uid: подстрахуемся по имени ключа и типу
    final uid = json['uid']?.toString() ?? // старое поле
        json['UID']?.toString() ?? // на всякий
        '';

    // name: тоже максимально мягко
    final name = json['name']?.toString() ??
        json['Name']?.toString() ??
        json['Наименование']?.toString() ??
        '';

    // roles: берём массив ЛЮБОГО типа и вытягиваем строки
    final rawRoles = json['roles'];
    final List<String> roles = [];

    if (rawRoles is List) {
      for (final r in rawRoles) {
        if (r is String) {
          roles.add(r);
        } else if (r is Map) {
          // если вдруг вернёшь объекты вида { "Код": "Approver" }
          if (r['code'] != null) {
            roles.add(r['code'].toString());
          } else if (r['Код'] != null) {
            roles.add(r['Код'].toString());
          } else {
            roles.add(r.toString());
          }
        } else {
          roles.add(r.toString());
        }
      }
    }

    bool parseBool(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is num) return value != 0;

      final s = value.toString().trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }

    return UserModel(
      uid: uid,
      name: name,
      subdivisionName: json['subdivisionName']?.toString() ??
          json['name_subdivision']?.toString() ??
          json['subdivision_name']?.toString() ??
          json['Підрозділ']?.toString() ??
          json['Подразделение']?.toString() ??
          '',
      managerName: json['managerName']?.toString() ??
          json['headName']?.toString() ??
          json['bossName']?.toString() ??
          json['supervisorName']?.toString() ??
          json['name_manager']?.toString() ??
          json['name_head']?.toString() ??
          json['name_boss']?.toString() ??
          json['Керівник']?.toString() ??
          json['Руководитель']?.toString() ??
          '',
      roles: roles,
      canNotifyOwnSubdivision: parseBool(json['canNotifyOwnSubdivision']),
      canNotifyOtherSubdivisions: parseBool(json['canNotifyOtherSubdivisions']),
      canNotifyUsers: parseBool(json['canNotifyUsers']),
      canNotifyAll: parseBool(json['canNotifyAll']),
      canNotifyOwner: parseBool(json['canNotifyOwner']),
      defaultSubdivisionUid: json['defaultSubdivisionUid']?.toString() ??
          json['defaultSubdivision']?.toString() ??
          json['defaultsubdivision']?.toString() ??
          '',
      avatarUrl:
          json['avatarUrl']?.toString() ?? json['avatar_url']?.toString() ?? '',
    );
  }

  bool get canApprovePayments =>
      roles.contains("Approver") ||
      roles.contains("Boss") ||
      roles.contains("Owner");

  bool get canAccessNotifications =>
      canNotifyOwnSubdivision ||
      canNotifyOtherSubdivisions ||
      canNotifyUsers ||
      canNotifyAll ||
      canNotifyOwner;
}
