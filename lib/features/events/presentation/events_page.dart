// lib/features/events/presentation/events_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../domain/event_item.dart';
import '../events_service.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  bool _loading = true;
  String? _error;
  List<EventItem> _items = [];
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = context.read<EventsService>();
      final items = await service.getEvents(limit: 80, unreadOnly: _unreadOnly);

      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Не вдалося завантажити події');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'approval_new':
        return Icons.verified_outlined;
      case 'approval_approved':
        return Icons.check_circle_outline;
      case 'approval_rejected':
        return Icons.cancel_outlined;
      case 'approval_topaid':
        return Icons.payments_outlined;
      case 'telegram_order_new':
        return Icons.shopping_bag_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  // ✅ локально помечаем как прочитанное, без перезагрузки списка
  void _setReadLocal(String id) {
    final idx = _items.indexWhere((x) => x.id == id);
    if (idx < 0) return;

    final e = _items[idx];

    if (e.read) return;

    // ⚠️ если у EventItem другие поля — поправь этот конструктор под себя
    final updated = EventItem(
      id: e.id,
      type: e.type,
      title: e.title,
      text: e.text,
      read: true,
      payload: e.payload,
      createdAt: e.createdAt,
      // если есть date/createdAt — добавь сюда
    );

    setState(() {
      _items = [..._items]..[idx] = updated;
    });
  }

  Future<void> _markReadIfNeeded(EventItem e) async {
    if (e.read) return;

    // мгновенно обновим UI (ощущается быстрее)
    _setReadLocal(e.id);

    try {
      await context.read<EventsService>().markRead([e.id]);
    } catch (_) {
      // если не удалось — можно откатить read назад, но для MVP ок оставить
    }

    // если включен фильтр "только непрочитанные" — уберем событие из списка
    if (_unreadOnly) {
      setState(() {
        _items = _items.where((x) => x.id != e.id).toList();
      });
    }
  }

  Future<void> _openEvent(EventItem e) async {
    await _markReadIfNeeded(e);

    final payload = e.payload;

    // заявка
    final reqUid = payload['request_uid']?.toString();
    if (reqUid != null && reqUid.isNotEmpty) {
      if (!mounted) return;
      context.push('/approvals/request/$reqUid');
      return;
    }

    // заказ (пока заглушка)
    final orderUid = payload['order_uid']?.toString();
    if (orderUid != null && orderUid.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Замовлення $orderUid (екран ще в роботі)')),
      );
      return;
    }

    // просто детали
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(e.title),
        content: Text(e.text),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Події',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilterChip(
                  label: const Text('Лише непрочитані'),
                  selected: _unreadOnly,
                  onSelected: (v) {
                    setState(() => _unreadOnly = v);
                    _load();
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_loading) const LinearProgressIndicator(),

            if (_error != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),

            const SizedBox(height: 10),

            if (!_loading && _error == null && _items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Center(child: Text('Поки немає подій')),
              ),

            for (final e in _items)
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ListTile(
                  leading: Icon(
                    _iconForType(e.type),
                    size: 30,
                    color: e.read ? Colors.black45 : Colors.deepPurple,
                  ),
                  title: Text(
                    e.title,
                    style: TextStyle(
                      fontWeight: e.read ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(e.text),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openEvent(e),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
