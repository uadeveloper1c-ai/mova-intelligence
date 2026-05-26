import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../api/api_client.dart';
import '../../../api/avatar_cache_store.dart';
import '../../../api/auth_provider.dart';
import '../../../core/theme/theme_controller.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _uploading = false;
  Uint8List? _localAvatarPreview;
  String? _loadedCacheForUid;

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
    final userUid = auth.currentUser?.uid.trim() ?? '';

    try {
      setState(() {
        _uploading = true;
        _localAvatarPreview = bytes;
      });
      if (userUid.isNotEmpty) {
        await AvatarCacheStore.save(userUid, bytes);
      }
      await auth.uploadAvatar(bytes: bytes, mimeType: mimeType);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _localAvatarPreview = null;
      });
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
      builder: (context) => _PresetAvatarSheet(avatarAssets: _presetAvatars),
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

  Future<void> _openAvatarPreview({
    required String name,
    required String avatarUrl,
    Uint8List? imageBytes,
  }) async {
    if ((imageBytes == null || imageBytes.isEmpty) && avatarUrl.isEmpty) {
      return;
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'avatar-preview',
      barrierColor: Colors.black.withValues(alpha: 0.82),
      pageBuilder: (_, __, ___) => _AvatarPreviewScreen(
        name: name,
        avatarUrl: avatarUrl,
        imageBytes: imageBytes,
      ),
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: child,
        );
      },
    );
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

  Future<void> _ensureCachedAvatarLoaded(String userUid) async {
    if (userUid.isEmpty ||
        _loadedCacheForUid == userUid ||
        _localAvatarPreview != null) {
      return;
    }

    final cached = await AvatarCacheStore.load(userUid);
    if (!mounted) return;
    if (cached == null || cached.isEmpty) {
      _loadedCacheForUid = userUid;
      return;
    }

    setState(() {
      _loadedCacheForUid = userUid;
      _localAvatarPreview = cached;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = cs.onSurface;
    final sub = theme.textTheme.bodyMedium?.color ??
        cs.onSurface.withValues(alpha: 0.7);
    final api = context.read<ApiClient>();
    final themeController = context.watch<ThemeController>();
    final userUid = user?.uid.trim() ?? '';

    final rawAvatarUrl = user?.avatarUrl.trim() ?? '';
    String avatarUrl = '';
    if (rawAvatarUrl.isNotEmpty) {
      avatarUrl = api.resolveUrl(rawAvatarUrl);
      avatarUrl = avatarUrl.contains('?')
          ? '$avatarUrl&v=${auth.avatarVersion}'
          : '$avatarUrl?v=${auth.avatarVersion}';
    }

    if (userUid.isNotEmpty) {
      _ensureCachedAvatarLoaded(userUid);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        Text(
          'Профіль',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Особиста інформація, аватар та налаштування застосунку.',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: sub,
          ),
        ),
        const SizedBox(height: 18),
        _Panel(
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _openAvatarPreview(
                      name: user?.name ?? 'Користувач',
                      avatarUrl: avatarUrl,
                      imageBytes: _localAvatarPreview,
                    ),
                    child: _ProfileAvatar(
                      name: user?.name ?? 'Користувач',
                      avatarUrl: avatarUrl,
                      imageBytes: _localAvatarPreview,
                      radius: 36,
                    ),
                  ),
                  const SizedBox(width: 16),
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
                          user?.subdivisionName.trim().isNotEmpty == true
                              ? user!.subdivisionName
                              : 'Підрозділ не вказано',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: sub,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _uploading ? null : _showAvatarOptions,
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_camera_outlined),
                  label:
                      Text(_uploading ? 'Завантаження...' : 'Змінити аватар'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Організаційна інформація',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: text,
                ),
              ),
              const SizedBox(height: 12),
              _InfoRow(
                label: 'Відділ',
                value: user?.subdivisionName.trim().isNotEmpty == true
                    ? user!.subdivisionName
                    : 'Не вказано',
              ),
              const SizedBox(height: 10),
              _InfoRow(
                label: 'Керівник',
                value: user?.managerName.trim().isNotEmpty == true
                    ? user!.managerName
                    : 'Не вказано',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Тема оформлення',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: text,
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
        ),
      ],
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
              alpha: theme.brightness == Brightness.dark ? 0.18 : 0.07,
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.colorScheme.onSurface;
    final sub = theme.textTheme.bodyMedium?.color ??
        theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: sub,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 36 + bottomInset),
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
                  child: _AvatarCircle(
                    radius: 34,
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
    this.imageBytes,
    this.radius = 28,
  });

  final String name;
  final String avatarUrl;
  final Uint8List? imageBytes;
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

    if (imageBytes != null && imageBytes!.isNotEmpty) {
      return _AvatarCircle(
        radius: radius,
        child: Image.memory(
          imageBytes!,
          fit: BoxFit.cover,
        ),
      );
    }

    if (avatarUrl.isEmpty) return fallback;

    return _AvatarCircle(
      radius: radius,
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
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.radius,
    required this.child,
  });

  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.42 : 0.8),
      ),
      child: ClipOval(
        child: child,
      ),
    );
  }
}

class _AvatarPreviewScreen extends StatelessWidget {
  const _AvatarPreviewScreen({
    required this.name,
    required this.avatarUrl,
    this.imageBytes,
  });

  final String name;
  final String avatarUrl;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final api = context.read<ApiClient>();
    final token = api.accessToken;

    Widget image;
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      image = Image.memory(
        imageBytes!,
        fit: BoxFit.contain,
      );
    } else {
      image = Image.network(
        avatarUrl,
        fit: BoxFit.contain,
        headers: {
          if ((token ?? '').isNotEmpty) 'Authorization': 'Bearer $token',
        },
        errorBuilder: (_, __, ___) => Center(
          child: Text(
            'Не вдалося відкрити аватар',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.transparent),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white,
                      ),
                      Expanded(
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Center(child: image),
                    ),
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
