import 'dart:convert';

import '../../api/api_client.dart';

enum NotificationTargetType {
  userList,
  subdivision,
  all,
}

enum NotificationImportance {
  normal,
  high,
  urgent,
}

String notificationTargetTypeToBackend(NotificationTargetType type) {
  switch (type) {
    case NotificationTargetType.userList:
      return 'user_list';
    case NotificationTargetType.subdivision:
      return 'subdivision';
    case NotificationTargetType.all:
      return 'all';
  }
}

String notificationImportanceToBackend(NotificationImportance importance) {
  switch (importance) {
    case NotificationImportance.normal:
      return 'normal';
    case NotificationImportance.high:
      return 'high';
    case NotificationImportance.urgent:
      return 'urgent';
  }
}

class NotifyUserOption {
  final String uid;
  final String name;
  final String subdivisionUid;
  final String subdivisionName;
  final String parentSubdivisionUid;
  final String parentSubdivisionName;
  final String avatarUrl;
  final List<String> labels;

  const NotifyUserOption({
    required this.uid,
    required this.name,
    this.subdivisionUid = '',
    this.subdivisionName = '',
    this.parentSubdivisionUid = '',
    this.parentSubdivisionName = '',
    this.avatarUrl = '',
    this.labels = const [],
  });

  factory NotifyUserOption.fromJson(Map<String, dynamic> json) {
    return NotifyUserOption(
      uid: _firstJsonString(json, const ['uid', 'id', 'Ссылка']),
      name: _firstJsonString(json, const ['name', 'Наименование']),
      subdivisionUid: _firstJsonString(json, const [
        'uid_subdivision',
        'subdivisionUid',
        'ПодразделениеСсылка',
      ]),
      subdivisionName: _firstJsonString(json, const [
        'name_subdivision',
        'subdivisionName',
        'ПодразделениеНаименование',
      ]),
      parentSubdivisionUid: _firstJsonString(json, const [
        'parent_subdivision_uid',
        'parentSubdivisionUid',
      ]),
      parentSubdivisionName: _firstJsonString(json, const [
        'parent_subdivision_name',
        'parentSubdivisionName',
      ]),
      avatarUrl: _firstJsonString(json, const ['avatarUrl', 'avatar_url']),
      labels: _parseStringList(json['labels']),
    );
  }

  String get subdivisionPath {
    if (parentSubdivisionName.isNotEmpty && subdivisionName.isNotEmpty) {
      return '$parentSubdivisionName / $subdivisionName';
    }
    if (subdivisionName.isNotEmpty) return subdivisionName;
    return 'Без підрозділу';
  }
}

List<String> _parseStringList(dynamic value) {
  if (value is List) {
    return value
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return const [];
  return [text];
}

int _userLabelPriority(NotifyUserOption user) {
  if (user.labels.contains('Власник')) return 0;
  if (user.labels.contains('CFO')) return 1;
  if (user.labels.contains('Керівник підрозділу')) return 2;
  return 3;
}

class NotifySubdivisionOption {
  final String uid;
  final String name;

  const NotifySubdivisionOption({
    required this.uid,
    required this.name,
  });

  factory NotifySubdivisionOption.fromJson(Map<String, dynamic> json) {
    return NotifySubdivisionOption(
      uid: _firstJsonString(json, const ['uid', 'id', 'Ссылка']),
      name: _firstJsonString(json, const ['name', 'Наименование']),
    );
  }
}

class NotifySendResult {
  final bool success;
  final String targetType;
  final int recipients;
  final int sent;
  final String dialogUid;

  const NotifySendResult({
    required this.success,
    required this.targetType,
    required this.recipients,
    required this.sent,
    required this.dialogUid,
  });

  factory NotifySendResult.fromJson(Map<String, dynamic> json) {
    final recipients = _parseJsonInt(json['recipients']) != 0
        ? _parseJsonInt(json['recipients'])
        : _parseJsonInt(json['participantsCount']);
    final sent = _parseJsonInt(json['sent']) != 0
        ? _parseJsonInt(json['sent'])
        : recipients;

    return NotifySendResult(
      success: json['success'] == true,
      targetType:
          _firstJsonString(json, const ['targetType', 'type', 'dialogType']),
      recipients: recipients,
      sent: sent,
      dialogUid: _firstJsonString(json, const ['dialogUid', 'groupUid']),
    );
  }
}

class NotificationInboxItem {
  final String groupUid;
  final String title;
  final String body;
  final NotificationImportance importance;
  final DateTime? sentAt;
  final DateTime? readAt;
  final bool read;
  final String senderUid;
  final String senderName;
  final String senderAvatarUrl;
  final int unreadCount;
  final int participantsCount;
  final bool isFinished;
  final bool canReply;
  final bool canFinish;
  final bool canHide;

  const NotificationInboxItem({
    required this.groupUid,
    required this.title,
    required this.body,
    required this.importance,
    required this.sentAt,
    required this.readAt,
    required this.read,
    required this.senderUid,
    required this.senderName,
    required this.senderAvatarUrl,
    required this.unreadCount,
    required this.participantsCount,
    required this.isFinished,
    required this.canReply,
    required this.canFinish,
    required this.canHide,
  });

  factory NotificationInboxItem.fromJson(Map<String, dynamic> json) {
    final readAt = _tryParseDateTime(
      _firstJsonString(json, const ['readAt', 'read_at']),
    );
    final unreadCount = _parseJsonInt(json['unreadCount']);
    final hasUnreadCounter = json.containsKey('unreadCount');
    final participantsCount = _parseJsonInt(json['participantsCount']);
    return NotificationInboxItem(
      groupUid: _firstJsonString(
        json,
        const ['dialogUid', 'groupUid', 'dialog_uid', 'group_uid'],
      ),
      title: _firstJsonString(json, const ['title', 'Заголовок']),
      body: _firstJsonString(
        json,
        const ['lastMessageText', 'body', 'text', 'Текст'],
      ),
      importance: _parseImportance(
        _firstJsonString(json, const ['importance', 'priority']),
      ),
      sentAt: _tryParseDateTime(
        _firstJsonString(
          json,
          const ['lastMessageAt', 'sentAt', 'createdAt', 'sent_at'],
        ),
      ),
      readAt: readAt,
      read: hasUnreadCounter
          ? unreadCount == 0
          : json['read'] == true || readAt != null,
      senderUid: _firstJsonString(
        json,
        const ['authorUid', 'senderUid', 'author_uid', 'sender_uid'],
      ),
      senderName: _firstJsonString(
        json,
        const ['authorName', 'senderName', 'author_name', 'sender_name'],
      ),
      senderAvatarUrl: _firstJsonString(
        json,
        const [
          'authorAvatarUrl',
          'senderAvatarUrl',
          'author_avatar_url',
          'sender_avatar_url',
        ],
      ),
      unreadCount: unreadCount,
      participantsCount: participantsCount,
      isFinished: json['isFinished'] == true,
      canReply: json['canReply'] != false,
      canFinish: json['canFinish'] == true,
      canHide: json['canHide'] != false,
    );
  }
}

String _firstJsonString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;

    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }

  return '';
}

int _parseJsonInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _tryParseDateTime(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

NotificationImportance _parseImportance(String value) {
  switch (value.trim().toLowerCase()) {
    case 'high':
      return NotificationImportance.high;
    case 'urgent':
      return NotificationImportance.urgent;
    default:
      return NotificationImportance.normal;
  }
}

class NotificationsService {
  final ApiClient _apiClient;

  NotificationsService(this._apiClient);

  dynamic _decodeJsonResponse(String body) => jsonDecode(body);

  bool _isHttp404(Object error) => error.toString().contains('HTTP 404');

  Future<dynamic> _getJson(String endpoint) async {
    final r = await _apiClient.sendAuthorizedRequest('GET', endpoint);
    final body = utf8.decode(r.bodyBytes);

    if (r.statusCode != 200) {
      throw Exception('HTTP ${r.statusCode}: $body');
    }

    return _decodeJsonResponse(body);
  }

  Future<dynamic> _postJson(String endpoint, Map<String, dynamic> body) async {
    final r = await _apiClient.sendAuthorizedRequest(
      'POST',
      endpoint,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final responseBody = utf8.decode(r.bodyBytes);

    if (r.statusCode != 200) {
      throw Exception('HTTP ${r.statusCode}: $responseBody');
    }

    return _decodeJsonResponse(responseBody);
  }

  Future<List<NotifyUserOption>> getUsers() async {
    dynamic data;
    try {
      data = await _getJson('/communications/users');
    } catch (e) {
      if (_isHttp404(e)) return const [];
      rethrow;
    }
    if (data is! List) {
      throw Exception('Очікувався список користувачів, отримав: $data');
    }

    final users = data
        .map((e) =>
            NotifyUserOption.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((e) => e.uid.isNotEmpty && e.name.isNotEmpty)
        .toList();

    users.sort((a, b) {
      final bySubdivision = a.subdivisionPath
          .toLowerCase()
          .compareTo(b.subdivisionPath.toLowerCase());
      if (bySubdivision != 0) return bySubdivision;
      final byRole = _userLabelPriority(a).compareTo(_userLabelPriority(b));
      if (byRole != 0) return byRole;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return users;
  }

  Future<List<NotifySubdivisionOption>> getSubdivisions() async {
    dynamic data;
    try {
      data = await _getJson('/communications/subdivisions');
    } catch (e) {
      if (_isHttp404(e)) return const [];
      rethrow;
    }
    if (data is! List) {
      throw Exception('Очікувався список підрозділів, отримав: $data');
    }

    final subdivisions = data
        .map((e) => NotifySubdivisionOption.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .where((e) => e.uid.isNotEmpty && e.name.isNotEmpty)
        .toList();

    subdivisions.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return subdivisions;
  }

  Future<NotifySendResult> createCommunication({
    required NotificationTargetType targetType,
    String? targetUid,
    List<String>? targetUids,
    NotificationImportance importance = NotificationImportance.normal,
    required String title,
    required String body,
  }) async {
    final payload = <String, dynamic>{
      'targetType': notificationTargetTypeToBackend(targetType),
      'importance': notificationImportanceToBackend(importance),
      'title': title.trim(),
      'body': body.trim(),
    };

    if (targetType == NotificationTargetType.subdivision) {
      payload['targetUid'] = targetUid?.trim() ?? '';
    }

    if (targetType == NotificationTargetType.userList) {
      payload['targetUids'] = (targetUids ?? [])
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final data = await _postJson('/communications/create', payload);
    if (data is! Map) {
      throw Exception(
          'Очікувався результат створення комунікації, отримав: $data');
    }

    return NotifySendResult.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<NotificationInboxItem>> getInbox() async {
    dynamic data;
    try {
      data = await _getJson('/communications/inbox');
    } catch (e) {
      if (_isHttp404(e)) return const [];
      rethrow;
    }
    if (data is! List) {
      throw Exception('Очікувався список комунікацій, отримав: $data');
    }

    final items = data
        .map((e) => NotificationInboxItem.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .where((e) =>
            e.groupUid.isNotEmpty && (e.title.isNotEmpty || e.body.isNotEmpty))
        .toList();

    items.sort((a, b) {
      if (a.read != b.read) {
        return a.read ? 1 : -1;
      }
      final aSent = a.sentAt;
      final bSent = b.sentAt;
      if (aSent == null && bSent == null) return 0;
      if (aSent == null) return 1;
      if (bSent == null) return -1;
      return bSent.compareTo(aSent);
    });

    return items;
  }

  Future<void> markRead(List<String> groupUids) async {
    final ids =
        groupUids.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (ids.isEmpty) return;

    await _postJson('/communications/mark_read', {
      'dialogUids': ids,
    });
  }

  Future<Map<String, dynamic>> getThread(String dialogUid) async {
    final data = await _getJson('/communications/thread?dialogUid=$dialogUid');
    if (data is! Map) {
      throw Exception('Очікувався діалог комунікації, отримав: $data');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<void> reply({
    required String dialogUid,
    required String text,
  }) async {
    await _postJson('/communications/reply', {
      'dialogUid': dialogUid.trim(),
      'text': text.trim(),
    });
  }

  Future<void> finish(String dialogUid) async {
    await _postJson('/communications/finish', {
      'dialogUid': dialogUid.trim(),
    });
  }

  Future<void> hide(String dialogUid) async {
    await _postJson('/communications/hide', {
      'dialogUid': dialogUid.trim(),
    });
  }
}
