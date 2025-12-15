// lib/api/user_model.dart

class UserModel {
  final String uid;
  final String name;
  final List<String> roles;

  UserModel({
    required this.uid,
    required this.name,
    required this.roles,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // uid: подстрахуемся по имени ключа и типу
    final uid =
            json['uid']?.toString() ??               // старое поле
            json['UID']?.toString() ??               // на всякий
            '';

    // name: тоже максимально мягко
    final name =
        json['name']?.toString() ??
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

    return UserModel(
      uid: uid,
      name: name,
      roles: roles,
    );
  }

  bool get canApprovePayments =>
      roles.contains("Approver") ||
          roles.contains("Boss") ||
          roles.contains("Owner");
}
