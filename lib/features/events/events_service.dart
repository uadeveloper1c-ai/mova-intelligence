import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../api/api_client.dart';
import 'domain/event_item.dart';

class EventsService {
  final ApiClient _apiClient;
  EventsService(this._apiClient);

  Future<List<EventItem>> getEvents({
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    // ✅ твой эндпоинт
    final endpoint =
        '/events/get_list?limit=$limit&unreadOnly=${unreadOnly ? 1 : 0}';

    final http.Response r =
    await _apiClient.sendAuthorizedRequest('GET', endpoint);

    if (r.statusCode != 200) {
      throw Exception('HTTP ${r.statusCode}: ${r.body}');
    }

    final body = utf8.decode(r.bodyBytes);
    final data = jsonDecode(body);

    if (data is! List) {
      throw Exception('Очікувався список подій, отримав: $data');
    }

    return data
        .cast<Map<String, dynamic>>()
        .map(EventItem.fromJson)
        .toList();
  }

  Future<void> markRead(List<String> ids) async {
    if (ids.isEmpty) return;

    // ✅ твой эндпоинт
    final r = await _apiClient.sendAuthorizedRequest(
      'POST',
      '/events/mark_read',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'ids': ids}),
    );

    if (r.statusCode != 200) {
      throw Exception('HTTP ${r.statusCode}: ${r.body}');
    }
  }
}
