class EventItem {
  final String id;
  final DateTime createdAt;
  final String type;
  final String title;
  final String text;
  final bool read;
  final Map<String, dynamic> payload;

  EventItem({
    required this.id,
    required this.createdAt,
    required this.type,
    required this.title,
    required this.text,
    required this.read,
    required this.payload,
  });

  factory EventItem.fromJson(Map<String, dynamic> json) {
    return EventItem(
      id: json['id']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      type: json['type']?.toString() ?? 'system',
      title: json['title']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      read: json['read'] == true,
      payload: (json['payload'] is Map)
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : <String, dynamic>{},
    );
  }
}
