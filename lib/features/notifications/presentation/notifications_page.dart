import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../api/api_client.dart';
import '../../../api/auth_provider.dart';
import '../notifications_service.dart';

enum _NotificationAudience {
  subdivision,
  userList,
  all,
}

enum _MessageImportance {
  normal,
  high,
  urgent,
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _avatarSessionStamp = '';

  bool _loading = true;
  bool _sending = false;
  String? _loadError;

  _NotificationAudience? _audience;

  List<NotifyUserOption> _users = const [];
  List<NotifySubdivisionOption> _subdivisions = const [];

  final Set<String> _selectedUserUids = <String>{};
  String? _selectedSubdivisionUid;
  _MessageImportance _importance = _MessageImportance.normal;

  @override
  void initState() {
    super.initState();
    _refreshAvatarStamp();
    _loadData();
  }

  void _refreshAvatarStamp() {
    _avatarSessionStamp = DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  bool _canPickUsers(AuthProvider auth) {
    return auth.canNotifyUsers ||
        auth.canNotifyOwnSubdivision ||
        auth.canNotifyOtherSubdivisions ||
        auth.canNotifyAll;
  }

  List<_NotificationAudience> _allowedAudiences(AuthProvider auth) {
    final items = <_NotificationAudience>[];
    if (auth.canNotifyOwnSubdivision ||
        auth.canNotifyOtherSubdivisions ||
        auth.canNotifyAll) {
      items.add(_NotificationAudience.subdivision);
    }
    if (_canPickUsers(auth)) {
      items.add(_NotificationAudience.userList);
    }
    if (auth.canNotifyAll) {
      items.add(_NotificationAudience.all);
    }
    return items;
  }

  void _ensureAudience(AuthProvider auth) {
    final allowed = _allowedAudiences(auth);
    if (allowed.isEmpty) {
      _audience = null;
      return;
    }
    if (_audience == null || !allowed.contains(_audience)) {
      _audience = allowed.first;
    }
  }

  void _ensureDefaultSubdivision(AuthProvider auth) {
    if (_subdivisions.isEmpty) {
      _selectedSubdivisionUid = null;
      return;
    }

    if ((_selectedSubdivisionUid ?? '').isNotEmpty &&
        _subdivisions.any((e) => e.uid == _selectedSubdivisionUid)) {
      return;
    }

    final defaultUid = auth.defaultSubdivisionUid;
    if ((defaultUid ?? '').isNotEmpty &&
        _subdivisions.any((e) => e.uid == defaultUid)) {
      _selectedSubdivisionUid = defaultUid;
      return;
    }

    if (_subdivisions.length == 1) {
      _selectedSubdivisionUid = _subdivisions.first.uid;
    }
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();

    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final service = context.read<NotificationsService>();
      List<NotifyUserOption> users = const [];
      List<NotifySubdivisionOption> subdivisions = const [];

      if (_canPickUsers(auth)) {
        users = await service.getUsers();
      }

      if (auth.canNotifyOwnSubdivision ||
          auth.canNotifyOtherSubdivisions ||
          auth.canNotifyAll) {
        subdivisions = await service.getSubdivisions();
      }

      if (!mounted) return;
      setState(() {
        _users = users;
        _subdivisions = subdivisions;
        _refreshAvatarStamp();
        _ensureAudience(auth);
        _ensureDefaultSubdivision(auth);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  String? get _selectedSubdivisionName {
    final uid = _selectedSubdivisionUid;
    if (uid == null || uid.isEmpty) return null;
    for (final subdivision in _subdivisions) {
      if (subdivision.uid == uid) return subdivision.name;
    }
    return null;
  }

  List<NotifyUserOption> get _selectedUsersPreview {
    if (_selectedUserUids.isEmpty) return const [];
    final result = <NotifyUserOption>[];
    for (final user in _users) {
      if (_selectedUserUids.contains(user.uid)) {
        result.add(user);
      }
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  bool get _canSend {
    final audience = _audience;
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (audience == null || title.isEmpty || body.isEmpty || _sending) {
      return false;
    }

    switch (audience) {
      case _NotificationAudience.subdivision:
        return (_selectedSubdivisionUid ?? '').isNotEmpty;
      case _NotificationAudience.userList:
        return _selectedUserUids.isNotEmpty;
      case _NotificationAudience.all:
        return true;
    }
  }

  String _audienceLabel(_NotificationAudience audience) {
    switch (audience) {
      case _NotificationAudience.subdivision:
        return 'Підрозділу';
      case _NotificationAudience.userList:
        return 'Користувачам';
      case _NotificationAudience.all:
        return 'Усім';
    }
  }

  String _importanceLabel(_MessageImportance importance) {
    switch (importance) {
      case _MessageImportance.normal:
        return 'Звичайне';
      case _MessageImportance.high:
        return 'Важливе';
      case _MessageImportance.urgent:
        return 'Термінове';
    }
  }

  Future<void> _pickMultipleUsers() async {
    setState(_refreshAvatarStamp);
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => _UserPickerSheet(
        users: _users,
        initiallySelected: _selectedUserUids,
        avatarCacheBuster: _avatarSessionStamp,
      ),
    );

    if (!mounted || selected == null) return;
    setState(() {
      _selectedUserUids
        ..clear()
        ..addAll(selected);
    });
  }

  Future<void> _pickSubdivision() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => _SubdivisionPickerSheet(
        subdivisions: _subdivisions,
        selectedUid: _selectedSubdivisionUid,
      ),
    );

    if (!mounted || selected == null) return;
    setState(() {
      _selectedSubdivisionUid = selected;
    });
  }

  Future<void> _send() async {
    final audience = _audience;
    if (!_canSend || audience == null) return;

    setState(() {
      _sending = true;
    });

    try {
      final service = context.read<NotificationsService>();

      late final NotificationTargetType targetType;
      late final NotificationImportance importance;
      String? targetUid;
      List<String>? targetUids;

      switch (audience) {
        case _NotificationAudience.subdivision:
          targetType = NotificationTargetType.subdivision;
          targetUid = _selectedSubdivisionUid;
          break;
        case _NotificationAudience.userList:
          targetType = NotificationTargetType.userList;
          targetUids = _selectedUserUids.toList();
          break;
        case _NotificationAudience.all:
          targetType = NotificationTargetType.all;
          break;
      }

      switch (_importance) {
        case _MessageImportance.normal:
          importance = NotificationImportance.normal;
          break;
        case _MessageImportance.high:
          importance = NotificationImportance.high;
          break;
        case _MessageImportance.urgent:
          importance = NotificationImportance.urgent;
          break;
      }

      final result = await service.createCommunication(
        targetType: targetType,
        targetUid: targetUid,
        targetUids: targetUids,
        importance: importance,
        title: _titleController.text,
        body: _bodyController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.recipients > 0
                ? 'Комунікацію створено для ${result.recipients} учасників'
                : 'Комунікацію створено',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося надіслати: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = cs.onSurface;
    final sub = theme.textTheme.bodyMedium?.color ??
        cs.onSurface.withValues(alpha: 0.72);
    final border = theme.dividerTheme.color ?? cs.outlineVariant;
    final panel = cs.surface;
    final canCreateCommunication = auth.canNotifyOwnSubdivision ||
        auth.canNotifyOtherSubdivisions ||
        auth.canNotifyUsers ||
        auth.canNotifyAll;

    _ensureAudience(auth);

    if (!canCreateCommunication) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, color: cs.primary, size: 34),
                const SizedBox(height: 12),
                Text(
                  'Немає доступу до комунікацій',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Цей модуль прихований для користувачів без прав на створення комунікацій.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: sub,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, color: cs.primary, size: 34),
                const SizedBox(height: 12),
                Text(
                  'Не вдалося завантажити дані',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: sub,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Спробувати ще раз'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: [
          Text(
            'Нова комунікація',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Створіть нову тему для користувачів, підрозділу або всієї компанії.',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: sub,
            ),
          ),
          const SizedBox(height: 18),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Кому',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: text,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<_NotificationAudience>(
                  initialValue: _audience,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Тип отримувача',
                  ),
                  items: _allowedAudiences(auth)
                      .map(
                        (audience) => DropdownMenuItem<_NotificationAudience>(
                          value: audience,
                          child: Text(_audienceLabel(audience)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _audience = value;
                    });
                  },
                ),
                if (_audience == _NotificationAudience.subdivision ||
                    _audience == _NotificationAudience.userList)
                  const SizedBox(height: 12),
                if (_audience == _NotificationAudience.subdivision)
                  _PickerTile(
                    label: 'Підрозділ',
                    value: _selectedSubdivisionName ?? 'Обрати підрозділ',
                    onTap: _pickSubdivision,
                  ),
                if (_audience == _NotificationAudience.userList)
                  _PickerTile(
                    label: 'Одержувачі',
                    value: _selectedUserUids.isEmpty
                        ? 'Обрати користувачів'
                        : 'Обрано: ${_selectedUserUids.length}',
                    onTap: _pickMultipleUsers,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_audience != null)
            _RecipientsPanel(
              audience: _audience,
              selectedUsers: _selectedUsersPreview,
              selectedSubdivisionName: _selectedSubdivisionName,
              includeChildren: true,
              avatarCacheBuster: _avatarSessionStamp,
            ),
          const SizedBox(height: 14),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Стартове повідомлення',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: text,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Важливість',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: sub,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<_MessageImportance>(
                  segments: [
                    for (final importance in _MessageImportance.values)
                      ButtonSegment<_MessageImportance>(
                        value: importance,
                        label: Text(_importanceLabel(importance)),
                      ),
                  ],
                  selected: {_importance},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    setState(() {
                      _importance = selection.first;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Заголовок',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bodyController,
                  onChanged: (_) => setState(() {}),
                  minLines: 5,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Текст повідомлення',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _canSend ? _send : null,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(_sending ? 'Надсилання...' : 'Надіслати'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.dividerTheme.color ?? theme.colorScheme.outlineVariant;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.16 : 0.06,
            ),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.colorScheme.onSurface;
    final sub = theme.textTheme.bodyMedium?.color ??
        theme.colorScheme.onSurface.withValues(alpha: 0.72);
    final border = theme.dividerTheme.color ?? theme.colorScheme.outlineVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: sub,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: sub),
          ],
        ),
      ),
    );
  }
}

class _RecipientsPanel extends StatelessWidget {
  const _RecipientsPanel({
    required this.audience,
    required this.selectedUsers,
    required this.selectedSubdivisionName,
    required this.includeChildren,
    required this.avatarCacheBuster,
  });

  final _NotificationAudience? audience;
  final List<NotifyUserOption> selectedUsers;
  final String? selectedSubdivisionName;
  final bool includeChildren;
  final String avatarCacheBuster;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.colorScheme.onSurface;
    final sub = theme.textTheme.bodyMedium?.color ??
        theme.colorScheme.onSurface.withValues(alpha: 0.72);

    String title = 'Обрані отримувачі';
    String? caption;

    switch (audience) {
      case _NotificationAudience.userList:
        caption = selectedUsers.isEmpty
            ? null
            : '${selectedUsers.length} користувачів';
        break;
      case _NotificationAudience.subdivision:
        title = 'Куди надсилаємо';
        caption = selectedSubdivisionName == null
            ? null
            : includeChildren
                ? '$selectedSubdivisionName та дочірні'
                : selectedSubdivisionName;
        break;
      case _NotificationAudience.all:
        title = 'Куди надсилаємо';
        caption = 'Усі активні користувачі';
        break;
      case null:
        break;
    }

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: text,
                  ),
                ),
              ),
            ],
          ),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(
              caption,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: sub,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (audience == _NotificationAudience.userList)
            if (selectedUsers.isEmpty)
              Text(
                'Після вибору тут буде видно, кому саме піде розсилка.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: sub,
                  height: 1.35,
                ),
              )
            else
              ...selectedUsers.map(
                (user) => _RecipientLine(
                  title: user.name,
                  subtitle: user.subdivisionPath,
                  avatarUrl: user.avatarUrl,
                  labels: user.labels,
                  avatarCacheBuster: avatarCacheBuster,
                ),
              ),
          if (audience == _NotificationAudience.subdivision)
            _RecipientLine(
              title: selectedSubdivisionName ?? 'Підрозділ ще не обрано',
              subtitle: 'Автоматично з урахуванням дочірніх',
            ),
          if (audience == _NotificationAudience.all)
            const _RecipientLine(
              title: 'Усі активні користувачі',
              subtitle: 'Окрім технічного та самого відправника',
            ),
        ],
      ),
    );
  }
}

class _RecipientLine extends StatelessWidget {
  const _RecipientLine({
    required this.title,
    this.subtitle,
    this.avatarUrl,
    this.labels = const [],
    this.avatarCacheBuster,
  });

  final String title;
  final String? subtitle;
  final String? avatarUrl;
  final List<String> labels;
  final String? avatarCacheBuster;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.colorScheme.onSurface;
    final sub = theme.textTheme.bodyMedium?.color ??
        theme.colorScheme.onSurface.withValues(alpha: 0.72);
    final border = theme.dividerTheme.color ?? theme.colorScheme.outlineVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          _UserAvatar(
            name: title,
            avatarUrl: avatarUrl,
            cacheBuster: avatarCacheBuster,
            radius: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (labels.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _RoleBadge(label: labels.first),
                    ],
                  ],
                ),
                if ((subtitle ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: sub,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    Color bg = cs.primaryContainer.withValues(alpha: 0.85);
    Color fg = cs.onPrimaryContainer;

    if (label == 'Власник') {
      bg = cs.tertiaryContainer.withValues(alpha: 0.9);
      fg = cs.onTertiaryContainer;
    } else if (label == 'CFO') {
      bg = cs.secondaryContainer.withValues(alpha: 0.9);
      fg = cs.onSecondaryContainer;
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

class _UserPickerSheet extends StatefulWidget {
  const _UserPickerSheet({
    required this.users,
    required this.initiallySelected,
    required this.avatarCacheBuster,
  });

  final List<NotifyUserOption> users;
  final Set<String> initiallySelected;
  final String avatarCacheBuster;

  @override
  State<_UserPickerSheet> createState() => _UserPickerSheetState();
}

class _UserPickerSheetState extends State<_UserPickerSheet> {
  final _searchController = TextEditingController();
  late final Set<String> _selected = {...widget.initiallySelected};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, List<NotifyUserOption>> get _groupedUsers {
    final query = _searchController.text.trim().toLowerCase();
    final Map<String, List<NotifyUserOption>> grouped = {};

    for (final user in widget.users) {
      final haystack = '${user.name} ${user.subdivisionPath}'.toLowerCase();
      if (query.isNotEmpty && !haystack.contains(query)) continue;

      grouped.putIfAbsent(user.subdivisionPath, () => []).add(user);
    }

    final sortedKeys = grouped.keys.toList()..sort();
    final result = <String, List<NotifyUserOption>>{};
    for (final key in sortedKeys) {
      final users = grouped[key]!..sort((a, b) => a.name.compareTo(b.name));
      result[key] = users;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = _groupedUsers;
    final totalVisible = grouped.values.fold<int>(
      0,
      (sum, users) => sum + users.length,
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Оберіть користувачів',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  child: const Text('Готово'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Пошук користувача або підрозділу',
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: grouped.isEmpty
                  ? const Center(child: Text('Нічого не знайдено'))
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        _UsersOverviewTile(totalVisible: totalVisible),
                        const SizedBox(height: 12),
                        for (final entry in grouped.entries) ...[
                          _UserGroupSection(
                            title: entry.key,
                            count: entry.value.length,
                            children: [
                              for (var i = 0; i < entry.value.length; i++)
                                _UserPickerRow(
                                  user: entry.value[i],
                                  selected:
                                      _selected.contains(entry.value[i].uid),
                                  showDivider: i != entry.value.length - 1,
                                  avatarCacheBuster: widget.avatarCacheBuster,
                                  onTap: () {
                                    setState(() {
                                      if (_selected
                                          .contains(entry.value[i].uid)) {
                                        _selected.remove(entry.value[i].uid);
                                      } else {
                                        _selected.add(entry.value[i].uid);
                                      }
                                    });
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
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

class _UsersOverviewTile extends StatelessWidget {
  const _UsersOverviewTile({required this.totalVisible});

  final int totalVisible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.dividerTheme.color ?? theme.colorScheme.outlineVariant;
    final panel = theme.colorScheme.surfaceContainerHighest
        .withValues(alpha: theme.brightness == Brightness.dark ? 0.22 : 0.75);
    final sub = theme.textTheme.bodyMedium?.color ??
        theme.colorScheme.onSurface.withValues(alpha: 0.72);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.groups_2_outlined,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Усі користувачі',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '$totalVisible',
            style: theme.textTheme.labelLarge?.copyWith(
              color: sub,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right_rounded,
            color: sub,
          ),
        ],
      ),
    );
  }
}

class _UserGroupSection extends StatelessWidget {
  const _UserGroupSection({
    required this.title,
    required this.count,
    required this.children,
  });

  final String title;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.dividerTheme.color ?? theme.colorScheme.outlineVariant;
    final panel = theme.colorScheme.surfaceContainerHighest
        .withValues(alpha: theme.brightness == Brightness.dark ? 0.14 : 0.42);
    final sub = theme.textTheme.bodyMedium?.color ??
        theme.colorScheme.onSurface.withValues(alpha: 0.72);

    return Container(
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '$count користувач${_userCountSuffix(count)}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: sub,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.expand_less_rounded,
                  size: 18,
                  color: sub,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

class _UserPickerRow extends StatelessWidget {
  const _UserPickerRow({
    required this.user,
    required this.selected,
    required this.showDivider,
    required this.avatarCacheBuster,
    required this.onTap,
  });

  final NotifyUserOption user;
  final bool selected;
  final bool showDivider;
  final String avatarCacheBuster;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = theme.textTheme.bodyMedium?.color ??
        theme.colorScheme.onSurface.withValues(alpha: 0.72);
    final selectedBg = theme.colorScheme.primary.withValues(alpha: 0.08);

    return Material(
      color: selected ? selectedBg : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  _UserAvatar(
                    name: user.name,
                    avatarUrl: user.avatarUrl,
                    cacheBuster: avatarCacheBuster,
                    radius: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                user.name,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (user.labels.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              _RoleBadge(label: user.labels.first),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user.subdivisionName.isEmpty
                              ? 'Без підрозділу'
                              : user.subdivisionName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: sub,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected ? theme.colorScheme.primary : sub,
                  ),
                ],
              ),
            ),
            if (showDivider)
              const Padding(
                padding: EdgeInsets.only(left: 70),
                child: Divider(height: 1),
              ),
          ],
        ),
      ),
    );
  }
}

String _userCountSuffix(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  if (mod10 == 1 && mod100 != 11) return '';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'і';
  return 'ів';
}

class _SubdivisionPickerSheet extends StatefulWidget {
  const _SubdivisionPickerSheet({
    required this.subdivisions,
    required this.selectedUid,
  });

  final List<NotifySubdivisionOption> subdivisions;
  final String? selectedUid;

  @override
  State<_SubdivisionPickerSheet> createState() =>
      _SubdivisionPickerSheetState();
}

class _SubdivisionPickerSheetState extends State<_SubdivisionPickerSheet> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<NotifySubdivisionOption> get _items {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.subdivisions;
    return widget.subdivisions
        .where((e) => e.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Оберіть підрозділ',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Пошук підрозділу',
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: _items.isEmpty
                  ? const Center(child: Text('Нічого не знайдено'))
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final item in _items)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.name),
                            trailing: widget.selectedUid == item.uid
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    color: theme.colorScheme.primary,
                                  )
                                : const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.of(context).pop(item.uid),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({
    required this.name,
    this.avatarUrl,
    this.cacheBuster,
    this.radius = 18,
  });

  final String name;
  final String? avatarUrl;
  final String? cacheBuster;
  final double radius;

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final api = context.read<ApiClient>();
    final rawUrl = (avatarUrl ?? '').trim();
    final resolvedBaseUrl = rawUrl.isEmpty ? '' : api.resolveUrl(rawUrl);
    final resolvedUrl = resolvedBaseUrl.isEmpty
        ? ''
        : resolvedBaseUrl.contains('?')
            ? '$resolvedBaseUrl&v=${cacheBuster ?? '1'}'
            : '$resolvedBaseUrl?v=${cacheBuster ?? '1'}';
    final token = api.accessToken;

    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
      child: Text(
        _initials,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    if (resolvedUrl.isEmpty) {
      return fallback;
    }

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.42 : 0.8),
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
