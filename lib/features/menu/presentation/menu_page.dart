import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../api/api_client.dart';
import '../../../api/auth_provider.dart';
import '../../../core/theme/theme_controller.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = cs.onSurface;
    final sub = theme.textTheme.bodyMedium?.color ??
        cs.onSurface.withValues(alpha: 0.7);
    final border = theme.dividerTheme.color ?? cs.outlineVariant;
    final panel = cs.surface;
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      children: [
        Text(
          'Розділи MOVA Intelligence',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Швидкий доступ до основних модулів системи.',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: sub,
          ),
        ),
        const SizedBox(height: 16),
        const _ProfileCard(),
        const SizedBox(height: 14),
        _MenuCard(
          title: 'Події',
          subtitle: 'Історія дій, пуші, статуси та зміни в системі',
          icon: Icons.notifications_none_rounded,
          accent: const Color(0xFF2F80ED),
          onTap: () => context.push('/events'),
        ),
        const SizedBox(height: 12),
        _MenuCard(
          title: 'Комунікації',
          subtitle: auth.canAccessNotifications
              ? 'Діалоги, повідомлення та нові теми для команди'
              : 'Вхідні робочі діалоги та повідомлення',
          icon: Icons.forum_outlined,
          accent: const Color(0xFF14B8A6),
          onTap: () => context.push('/modules/communications'),
        ),
        const SizedBox(height: 12),
        const _MenuCard(
          title: 'План робіт на сьогодні',
          subtitle: 'По відділах, виробництво, склад, логістика',
          icon: Icons.factory_outlined,
          accent: Color(0xFFF59E0B),
          isComingSoon: true,
        ),
        const SizedBox(height: 12),
        const _MenuCard(
          title: 'Старший зміни',
          subtitle: 'Хто відповідальний сьогодні по відділу',
          icon: Icons.badge_outlined,
          accent: Color(0xFF8B5CF6),
          isComingSoon: true,
        ),
        const SizedBox(height: 12),
        _MenuCard(
          title: 'Задачі',
          subtitle: 'Список задач та статуси виконання',
          icon: Icons.checklist_rounded,
          accent: const Color(0xFF22C55E),
          onTap: () => context.push('/tasks'),
        ),
        const SizedBox(height: 12),
        _MenuCard(
          title: 'Звіти',
          subtitle: 'Аналітика, показники та огляд для керівника',
          icon: Icons.bar_chart_rounded,
          accent: const Color(0xFF10B981),
          onTap: () => context.push('/reports'),
        ),
        const SizedBox(height: 12),
        _MenuCard(
          title: 'Розпізнати документ (OCR)',
          subtitle: 'Фото або галерея → створити заявку',
          icon: Icons.document_scanner_outlined,
          accent: const Color(0xFF3AAFA9),
          onTap: () => context.push('/invoices/recognize'),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: panel.withValues(alpha: isDark ? 0.92 : 0.94),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Text(
            'Перемикач теми вже підключений. Далі можна спокійно переводити екран нової заявки, список і деталі на Theme.of(context), без жорстко забитих кольорів.',
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.35,
              color: sub,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatefulWidget {
  const _ProfileCard();

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  bool _uploading = false;
  static const List<String> _presetAvatars = [
    'assets/avatars/avatar_01.png',
    'assets/avatars/avatar_02.png',
    'assets/avatars/avatar_03.png',
    'assets/avatars/avatar_04.png',
    'assets/avatars/avatar_05.png',
    'assets/avatars/avatar_06.png',
    'assets/avatars/avatar_07.png',
    'assets/avatars/avatar_08.png',
    'assets/avatars/avatar_09.png',
    'assets/avatars/avatar_10.png',
    'assets/avatars/avatar_11.png',
    'assets/avatars/avatar_12.png',
    'assets/avatars/avatar_13.png',
    'assets/avatars/avatar_14.png',
    'assets/avatars/avatar_15.png',
    'assets/avatars/avatar_16.png',
  ];

  Future<void> _uploadAvatarBytes({
    required Uint8List bytes,
    required String mimeType,
    required String successMessage,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();

    try {
      setState(() => _uploading = true);
      await auth.uploadAvatar(
        bytes: bytes,
        mimeType: mimeType,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Не вдалося оновити аватар: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (file == null || !mounted) return;

      final path = file.path.toLowerCase();
      final mimeType = path.endsWith('.png') ? 'image/png' : 'image/jpeg';
      final bytes = await File(file.path).readAsBytes();
      await _uploadAvatarBytes(
        bytes: bytes,
        mimeType: mimeType,
        successMessage: 'Аватар оновлено',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося обрати фото: $e')),
      );
    }
  }

  Future<void> _pickPresetAvatar() async {
    final selectedAsset = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => _PresetAvatarSheet(
        avatarAssets: _presetAvatars,
      ),
    );

    if (!mounted || selectedAsset == null || selectedAsset.isEmpty) return;

    final bytes = await rootBundle.load(selectedAsset);
    await _uploadAvatarBytes(
      bytes: bytes.buffer.asUint8List(),
      mimeType: 'image/png',
      successMessage: 'Аватар обрано',
    );
  }

  Future<void> _showAvatarOptions() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Оберіть аватар',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Обрати з галереї'),
                  onTap: () => Navigator.of(context).pop('gallery'),
                ),
                ListTile(
                  leading: const Icon(Icons.grid_view_rounded),
                  title: const Text('Обрати з колекції'),
                  onTap: () => Navigator.of(context).pop('preset'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    if (selected == 'gallery') {
      await _pickAndUploadAvatar();
    } else if (selected == 'preset') {
      await _pickPresetAvatar();
    }
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Світла';
      case ThemeMode.dark:
        return 'Темна';
      case ThemeMode.system:
        return 'Системна';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final theme = Theme.of(context);
    final themeController = context.watch<ThemeController>();
    final cs = theme.colorScheme;
    final text = cs.onSurface;
    final sub = theme.textTheme.bodyMedium?.color ??
        cs.onSurface.withValues(alpha: 0.7);
    final border = theme.dividerTheme.color ?? cs.outlineVariant;
    final api = context.read<ApiClient>();

    final rawAvatarUrl = user?.avatarUrl.trim() ?? '';
    final avatarUrl = rawAvatarUrl.isEmpty
        ? ''
        : (rawAvatarUrl.startsWith('http')
            ? rawAvatarUrl
            : '${api.baseUrl}$rawAvatarUrl');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.18 : 0.07,
            ),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ProfileAvatar(
                name: user?.name ?? 'Користувач',
                avatarUrl: avatarUrl,
                radius: 30,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name.trim().isNotEmpty == true
                          ? user!.name
                          : 'Користувач',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (user?.subdivisionName.trim().isNotEmpty ?? false)
                          ? user!.subdivisionName
                          : 'Профіль',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: sub,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _uploading ? null : _showAvatarOptions,
                icon: _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_camera_outlined),
                label: Text(_uploading ? 'Завантаження' : 'Аватар'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Тема оформлення',
            style: theme.textTheme.titleSmall?.copyWith(
              color: text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Оберіть вигляд застосунку MOVA Intelligence.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: sub,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_rounded),
                label: Text('Світла'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_rounded),
                label: Text('Темна'),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.settings_suggest_rounded),
                label: Text('Системна'),
              ),
            ],
            selected: {themeController.themeMode},
            onSelectionChanged: (selection) {
              themeController.setThemeMode(selection.first);
            },
          ),
          const SizedBox(height: 10),
          Text(
            'Зараз: ${_themeLabel(themeController.themeMode)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: sub,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetAvatarSheet extends StatelessWidget {
  const _PresetAvatarSheet({
    required this.avatarAssets,
  });

  final List<String> avatarAssets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Колекція аватарів',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Оберіть один із готових варіантів.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              itemCount: avatarAssets.length,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final asset = avatarAssets[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => Navigator.of(context).pop(asset),
                  child: ClipOval(
                    child: Image.asset(
                      asset,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.name,
    required this.avatarUrl,
    this.radius = 28,
  });

  final String name;
  final String avatarUrl;
  final double radius;

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
    final token = api.accessToken;

    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
      child: Text(
        _initials,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    if (avatarUrl.isEmpty) return fallback;

    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Image.network(
          avatarUrl,
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

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.onTap,
    this.isComingSoon = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final bool isComingSoon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = cs.onSurface;
    final sub = theme.textTheme.bodyMedium?.color ??
        cs.onSurface.withValues(alpha: 0.7);
    final border = theme.dividerTheme.color ?? cs.outlineVariant;
    final panel = cs.surface;
    final disabled = theme.brightness == Brightness.dark
        ? const Color(0xFF72839A)
        : const Color(0xFF94A3B8);

    final enabled = !isComingSoon && onTap != null;
    final iconColor = enabled ? accent : disabled;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: enabled ? onTap : null,
      child: Ink(
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.18 : 0.07,
              ),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.20),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 26,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: enabled ? text : sub,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (isComingSoon) const _SoonBadge(),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: enabled ? sub : disabled,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                enabled
                    ? Icons.chevron_right_rounded
                    : Icons.lock_outline_rounded,
                color: enabled ? sub : disabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoonBadge extends StatelessWidget {
  const _SoonBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.dividerTheme.color ?? theme.colorScheme.outlineVariant;
    final panel = theme.colorScheme.surface;
    final sub = theme.textTheme.bodyMedium?.color ??
        theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        'Скоро',
        style: TextStyle(
          color: sub,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
