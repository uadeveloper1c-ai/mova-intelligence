import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../api/api_client.dart';
import '../../../api/auth_provider.dart';
import '../../notifications/notifications_service.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  static const _pollInterval = Duration(seconds: 2);

  Timer? _pollTimer;
  bool _loading = true;
  String? _error;
  List<NotificationInboxItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await context.read<NotificationsService>().getInbox();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Не вдалося завантажити комунікації');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!mounted) return;
      _loadSilently();
    });
  }

  Future<void> _loadSilently() async {
    if (_loading) return;

    try {
      final items = await context.read<NotificationsService>().getInbox();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Не вдалося завантажити комунікації');
    }
  }

  Future<void> _openMessage(NotificationInboxItem item) async {
    if (!item.read) {
      _setReadLocal(item.groupUid);
      try {
        await context.read<NotificationsService>().markRead([item.groupUid]);
      } catch (_) {
        // keep optimistic UI
      }
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => _MessageThreadSheet(item: item),
    );
  }

  void _setReadLocal(String groupUid) {
    final index = _items.indexWhere((e) => e.groupUid == groupUid);
    if (index < 0) return;
    final item = _items[index];
    if (item.read) return;

    final updated = NotificationInboxItem(
      groupUid: item.groupUid,
      title: item.title,
      body: item.body,
      importance: item.importance,
      sentAt: item.sentAt,
      readAt: DateTime.now(),
      read: true,
      senderUid: item.senderUid,
      senderName: item.senderName,
      senderAvatarUrl: item.senderAvatarUrl,
      unreadCount: 0,
      participantsCount: item.participantsCount,
      isFinished: item.isFinished,
      canReply: item.canReply,
      canFinish: item.canFinish,
      canHide: item.canHide,
    );

    setState(() {
      _items = [..._items]..[index] = updated;
      _items.sort((a, b) {
        if (a.read != b.read) return a.read ? 1 : -1;
        final aSent = a.sentAt;
        final bSent = b.sentAt;
        if (aSent == null && bSent == null) return 0;
        if (aSent == null) return 1;
        if (bSent == null) return -1;
        return bSent.compareTo(aSent);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = cs.onSurface;
    final sub = theme.textTheme.bodyMedium?.color ??
        cs.onSurface.withValues(alpha: 0.72);
    final auth = context.watch<AuthProvider>();
    final canCreateCommunication = auth.canNotifyOwnSubdivision ||
        auth.canNotifyOtherSubdivisions ||
        auth.canNotifyUsers ||
        auth.canNotifyAll;
    final unreadItems = _items.where((e) => !e.read).toList(growable: false);
    final readItems = _items.where((e) => e.read).toList(growable: false);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: [
          Text(
            'Комунікації',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Робочі діалоги, відповіді та нові теми для команди.',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: sub,
            ),
          ),
          const SizedBox(height: 16),
          if (canCreateCommunication) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final created =
                      await context.push<bool>('/modules/communications/new');
                  if (!mounted || created != true) return;
                  await _load();
                },
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('Нова комунікація'),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ...[
            _StateCard(
              icon: Icons.cloud_off_rounded,
              title: 'Не вдалося завантажити комунікації',
              subtitle: _error!,
              actionLabel: 'Спробувати ще раз',
              onPressed: _load,
            ),
          ] else if (!_loading && _items.isEmpty) ...[
            const _StateCard(
              icon: Icons.mark_email_read_outlined,
              title: 'Комунікацій поки немає',
              subtitle: 'Нові теми та відповіді з’являться тут.',
            ),
          ] else ...[
            if (unreadItems.isNotEmpty) ...[
              const _SectionLabel('Потребують уваги'),
              const SizedBox(height: 10),
              for (var i = 0; i < unreadItems.length; i++) ...[
                _MessageListTile(
                  item: unreadItems[i],
                  onTap: () => _openMessage(unreadItems[i]),
                ),
                if (i != unreadItems.length - 1) const SizedBox(height: 10),
              ],
              if (readItems.isNotEmpty) const SizedBox(height: 18),
            ],
            if (readItems.isNotEmpty) ...[
              const _SectionLabel('Переглянуті теми'),
              const SizedBox(height: 10),
              for (var i = 0; i < readItems.length; i++) ...[
                _MessageListTile(
                  item: readItems[i],
                  onTap: () => _openMessage(readItems[i]),
                ),
                if (i != readItems.length - 1) const SizedBox(height: 10),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.92),
      ),
    );
  }
}

class _MessageListTile extends StatelessWidget {
  const _MessageListTile({
    required this.item,
    required this.onTap,
  });

  final NotificationInboxItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = cs.onSurface;
    final sub = theme.textTheme.bodyMedium?.color ??
        cs.onSurface.withValues(alpha: 0.72);
    final accent = _communicationAccent(theme, item.importance, !item.read);
    final cardBg = theme.brightness == Brightness.dark
        ? const Color(0xFF16263A)
        : cs.surface;
    final frameColor = theme.brightness == Brightness.dark
        ? const Color(0xFF47D7E5)
        : const Color(0xFF14B8C8);
    final sentAt = item.sentAt;
    final sentLabel = sentAt == null
        ? ''
        : '${sentAt.day.toString().padLeft(2, '0')}.${sentAt.month.toString().padLeft(2, '0')} ${sentAt.hour.toString().padLeft(2, '0')}:${sentAt.minute.toString().padLeft(2, '0')}';

    const radius = BorderRadius.all(Radius.circular(20));

    return Material(
      color: cardBg,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: frameColor.withValues(alpha: 0.9), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.18 : 0.08,
              ),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        _SenderAvatar(
                          name: item.senderName.isEmpty
                              ? 'MOVA'
                              : item.senderName,
                          avatarUrl: item.senderAvatarUrl,
                        ),
                        if (!item.read)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.surface,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  item.title.isEmpty
                                      ? 'Без назви теми'
                                      : item.title,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: text,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                    height: 1.08,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              _ImportanceBadge(importance: item.importance),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.senderName.isEmpty
                                ? 'Системне повідомлення'
                                : item.senderName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: accent.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: sub,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.only(left: 62),
                  child: Text(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: text.withValues(alpha: 0.96),
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  margin: const EdgeInsets.only(left: 62),
                  height: 1,
                  color: frameColor.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 62),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Text(
                          item.read ? 'Переглянуто' : 'Потребує уваги',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: !item.read ? accent : sub,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (sentLabel.isNotEmpty)
                        Text(
                          sentLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: sub,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SenderAvatar extends StatelessWidget {
  const _SenderAvatar({
    required this.name,
    required this.avatarUrl,
  });

  final String name;
  final String avatarUrl;

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final api = context.read<ApiClient>();
    final resolvedUrl =
        avatarUrl.trim().isEmpty ? '' : api.resolveUrl(avatarUrl.trim());
    final token = api.accessToken;

    final fallback = CircleAvatar(
      radius: 24,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
      child: Text(
        _initials,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    if (resolvedUrl.isEmpty) return fallback;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: ClipOval(
        child: Image.network(
          resolvedUrl,
          fit: BoxFit.cover,
          headers: {
            if ((token ?? '').isNotEmpty) 'Authorization': 'Bearer $token',
          },
          errorBuilder: (_, __, ___) => fallback,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return fallback;
          },
        ),
      ),
    );
  }
}

class _ImportanceBadge extends StatelessWidget {
  const _ImportanceBadge({required this.importance});

  final NotificationImportance importance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    late final String label;
    late final Color bg;
    late final Color fg;

    switch (importance) {
      case NotificationImportance.normal:
        label = 'Звичайне';
        bg = cs.secondaryContainer.withValues(alpha: 0.72);
        fg = cs.onSecondaryContainer;
        break;
      case NotificationImportance.high:
        label = 'Важливе';
        bg = cs.primaryContainer.withValues(alpha: 0.78);
        fg = cs.onPrimaryContainer;
        break;
      case NotificationImportance.urgent:
        label = 'Термінове';
        bg = cs.errorContainer.withValues(alpha: 0.82);
        fg = cs.onErrorContainer;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MessageThreadSheet extends StatefulWidget {
  const _MessageThreadSheet({required this.item});

  final NotificationInboxItem item;

  @override
  State<_MessageThreadSheet> createState() => _MessageThreadSheetState();
}

class _MessageThreadSheetState extends State<_MessageThreadSheet> {
  static const _pollInterval = Duration(seconds: 2);

  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _pollTimer;

  bool _loading = true;
  bool _sending = false;
  bool _finishing = false;
  bool _hiding = false;
  String? _error;

  late String _title = widget.item.title;
  late NotificationImportance _importance = widget.item.importance;
  late bool _isFinished = widget.item.isFinished;
  late bool _canReply = widget.item.canReply;
  late bool _canFinish = widget.item.canFinish;
  late bool _canHide = widget.item.canHide;
  int _participantsCount = 0;
  List<_ThreadMessage> _messages = const [];

  @override
  void initState() {
    super.initState();
    _loadThread();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadThread() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await context
          .read<NotificationsService>()
          .getThread(widget.item.groupUid);
      final dialog = _asMap(data['dialog']);
      final messagesRaw = data['messages'];
      final messages = messagesRaw is List
          ? messagesRaw
              .map((e) => _ThreadMessage.fromJson(_asMap(e)))
              .toList(growable: false)
          : const <_ThreadMessage>[];

      if (!mounted) return;
      setState(() {
        _title = _readString(dialog, const ['title']).isEmpty
            ? widget.item.title
            : _readString(dialog, const ['title']);
        _importance = _parseThreadImportance(
          _readString(dialog, const ['importance']),
        );
        _participantsCount = _readInt(dialog, const ['participantsCount']);
        _isFinished = _readBool(dialog, const ['isFinished']);
        _canReply = _readBool(dialog, const ['canReply'], defaultValue: true);
        _canFinish = _readBool(dialog, const ['canFinish']);
        _canHide = _readBool(dialog, const ['canHide'], defaultValue: true);
        _messages = messages;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _threadErrorText(e);
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!mounted || _loading || _sending || _finishing || _hiding) return;
      _refreshThreadSilently();
    });
  }

  Future<void> _refreshThreadSilently() async {
    try {
      final data = await context
          .read<NotificationsService>()
          .getThread(widget.item.groupUid);
      final dialog = _asMap(data['dialog']);
      final messagesRaw = data['messages'];
      final messages = messagesRaw is List
          ? messagesRaw
              .map((e) => _ThreadMessage.fromJson(_asMap(e)))
              .toList(growable: false)
          : const <_ThreadMessage>[];

      if (!mounted) return;
      final hadMessages = _messages.length;
      setState(() {
        _title = _readString(dialog, const ['title']).isEmpty
            ? widget.item.title
            : _readString(dialog, const ['title']);
        _importance = _parseThreadImportance(
          _readString(dialog, const ['importance']),
        );
        _participantsCount = _readInt(dialog, const ['participantsCount']);
        _isFinished = _readBool(dialog, const ['isFinished']);
        _canReply = _readBool(dialog, const ['canReply'], defaultValue: true);
        _canFinish = _readBool(dialog, const ['canFinish']);
        _canHide = _readBool(dialog, const ['canHide'], defaultValue: true);
        _messages = messages;
        _error = null;
      });
      if (messages.length > hadMessages) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (_) {
      // Keep current UI state during background polling.
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _sending || !_canReply || _isFinished) return;

    setState(() => _sending = true);
    try {
      await context.read<NotificationsService>().reply(
            dialogUid: widget.item.groupUid,
            text: text,
          );
      _replyController.clear();
      await _loadThread();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не вдалося надіслати відповідь')),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _finishDialog() async {
    if (_finishing || !_canFinish) return;
    setState(() => _finishing = true);
    try {
      await context.read<NotificationsService>().finish(widget.item.groupUid);
      if (!mounted) return;
      setState(() {
        _isFinished = true;
        _canReply = false;
        _canFinish = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Діалог завершено')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не вдалося завершити діалог')),
      );
    } finally {
      if (mounted) {
        setState(() => _finishing = false);
      }
    }
  }

  Future<void> _hideDialog() async {
    if (_hiding || !_canHide) return;
    setState(() => _hiding = true);
    try {
      await context.read<NotificationsService>().hide(widget.item.groupUid);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Тему приховано')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не вдалося приховати тему')),
      );
    } finally {
      if (mounted) {
        setState(() => _hiding = false);
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.colorScheme.onSurface;
    final sub = theme.textTheme.bodyMedium?.color ??
        theme.colorScheme.onSurface.withValues(alpha: 0.72);
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final safeBottom = mediaQuery.padding.bottom;

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 12 + safeBottom + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _title.isEmpty ? 'Комунікація' : _title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ImportanceBadge(importance: _importance),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _participantsCount > 0
                  ? '$_participantsCount учасників'
                  : 'Тема команди',
              style: theme.textTheme.bodySmall?.copyWith(
                color: sub,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_isFinished) ...[
              const SizedBox(height: 8),
              Text(
                'Діалог завершено. Історія доступна тільки для перегляду.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: sub,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                    onPressed: _loadThread,
                                    child: const Text('Спробувати ще раз'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _messages.isEmpty
                            ? Center(
                                child: Text(
                                  'У темі поки немає повідомлень',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: sub,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(12),
                                itemCount: _messages.length,
                                itemBuilder: (context, index) {
                                  return _ThreadMessageBubble(
                                    message: _messages[index],
                                  );
                                },
                              ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: theme.dividerTheme.color ??
                      theme.colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                children: [
                  if (_canHide || _canFinish)
                    Row(
                      children: [
                        if (_canHide)
                          TextButton(
                            onPressed: _hiding ? null : _hideDialog,
                            child: Text(_hiding ? 'Ховаємо...' : 'Приховати'),
                          ),
                        const Spacer(),
                        if (_canFinish)
                          TextButton(
                            onPressed: _finishing ? null : _finishDialog,
                            child: Text(
                              _finishing ? 'Завершуємо...' : 'Завершити',
                            ),
                          ),
                      ],
                    ),
                  if (_canReply && !_isFinished) ...[
                    if (_canHide || _canFinish) const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _replyController,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.newline,
                            decoration: const InputDecoration(
                              hintText: 'Напишіть відповідь',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: _sending ? null : _sendReply,
                          child: Text(_sending ? '...' : 'Надіслати'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadMessage {
  const _ThreadMessage({
    required this.authorName,
    required this.authorAvatarUrl,
    required this.text,
    required this.sentAt,
    required this.isMine,
    required this.isSystem,
  });

  final String authorName;
  final String authorAvatarUrl;
  final String text;
  final DateTime? sentAt;
  final bool isMine;
  final bool isSystem;

  factory _ThreadMessage.fromJson(Map<String, dynamic> json) {
    return _ThreadMessage(
      authorName: _readString(json, const ['authorName']),
      authorAvatarUrl: _readString(json, const ['authorAvatarUrl']),
      text: _readString(json, const ['text']),
      sentAt: _tryParseThreadDateTime(_readString(json, const ['sentAt'])),
      isMine: _readBool(json, const ['isMine']),
      isSystem: _readBool(json, const ['isSystem']),
    );
  }
}

class _ThreadMessageBubble extends StatelessWidget {
  const _ThreadMessageBubble({required this.message});

  final _ThreadMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final align =
        message.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final rowAlign =
        message.isMine ? MainAxisAlignment.end : MainAxisAlignment.start;
    final bg = message.isMine
        ? cs.primaryContainer.withValues(alpha: 0.82)
        : cs.surface;
    final fg = message.isMine ? cs.onPrimaryContainer : cs.onSurface;
    final sentAt = message.sentAt;
    final sentLabel = sentAt == null
        ? ''
        : '${sentAt.day.toString().padLeft(2, '0')}.${sentAt.month.toString().padLeft(2, '0')} ${sentAt.hour.toString().padLeft(2, '0')}:${sentAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (!message.isMine && message.authorName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 4),
              child: Text(
                message.authorName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: rowAlign,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!message.isMine) ...[
                _SenderAvatar(
                  name:
                      message.authorName.isEmpty ? 'MOVA' : message.authorName,
                  avatarUrl: message.authorAvatarUrl,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: align,
                    children: [
                      Text(
                        message.text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: fg,
                          height: 1.35,
                          fontWeight: message.isSystem
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (sentLabel.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          sentLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: fg.withValues(alpha: 0.72),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

String _readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

int _readInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}

bool _readBool(
  Map<String, dynamic> json,
  List<String> keys, {
  bool defaultValue = false,
}) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) return value;
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text == 'true') return true;
    if (text == 'false') return false;
  }
  return defaultValue;
}

DateTime? _tryParseThreadDateTime(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

NotificationImportance _parseThreadImportance(String value) {
  switch (value.trim().toLowerCase()) {
    case 'high':
      return NotificationImportance.high;
    case 'urgent':
      return NotificationImportance.urgent;
    default:
      return NotificationImportance.normal;
  }
}

Color _communicationAccent(
  ThemeData theme,
  NotificationImportance importance,
  bool highlight,
) {
  final cs = theme.colorScheme;
  switch (importance) {
    case NotificationImportance.normal:
      return highlight ? cs.primary : cs.secondary;
    case NotificationImportance.high:
      return cs.primary;
    case NotificationImportance.urgent:
      return cs.error;
  }
}

String _threadErrorText(Object error) {
  final text = error.toString();
  if (text.contains('HTTP 400')) {
    return 'Не вдалося відкрити тему. Сервер не прийняв параметри діалогу.';
  }
  if (text.contains('HTTP 403')) {
    return 'Не вдалося відкрити тему. Немає доступу до цього діалогу.';
  }
  if (text.contains('HTTP 404')) {
    return 'Не вдалося відкрити тему. Діалог не знайдено на сервері.';
  }
  return 'Не вдалося відкрити тему.\n$text';
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.dividerTheme.color ?? theme.colorScheme.outlineVariant;
    final text = theme.colorScheme.onSurface;
    final sub = theme.textTheme.bodyMedium?.color ??
        theme.colorScheme.onSurface.withValues(alpha: 0.72);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: sub,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onPressed != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
