import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mova_intelligence_app/api/auth_provider.dart';
import 'package:mova_intelligence_app/core/app_version.dart';
import 'package:mova_intelligence_app/core/ui/app_background.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    ('/home', Icons.dashboard_outlined, 'Головна'),
    ('/work', Icons.verified_outlined, 'Робота'),
    ('/modules', Icons.menu_rounded, 'Модулі'),
  ];

  static const _desktopLinks = [
    ('/home', Icons.dashboard_outlined, 'Головна', 'Огляд системи'),
    ('/work', Icons.fact_check_outlined, 'Заявки', 'Погодження та оплати'),
    (
      '/modules/communications',
      Icons.forum_outlined,
      'Комунікації',
      'Діалоги та повідомлення',
    ),
    ('/events', Icons.notifications_none_rounded, 'Події', 'Важливі події'),
    (
      '/modules/profile',
      Icons.person_outline_rounded,
      'Профіль',
      'Користувач і налаштування',
    ),
    ('/modules', Icons.grid_view_rounded, 'Модулі', 'Всі розділи'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = cs.onSurface;
    final sub = theme.textTheme.bodyMedium?.color ??
        cs.onSurface.withValues(alpha: 0.7);
    final border = theme.dividerTheme.color ?? cs.outlineVariant;
    final surface = cs.surface;
    final accent = cs.primary;
    final isDark = theme.brightness == Brightness.dark;

    final accentSoft = isDark
        ? accent.withValues(alpha: 0.18)
        : accent.withValues(alpha: 0.12);

    final versionBorder = isDark
        ? accent.withValues(alpha: 0.24)
        : accent.withValues(alpha: 0.18);

    final loc = GoRouterState.of(context).uri.toString();
    final canAccessProduction =
        context.watch<AuthProvider>().canAccessProduction;

    int selected = 0;
    if (loc.startsWith('/work') || loc.startsWith('/approvals')) selected = 1;
    if (loc.startsWith('/modules')) selected = 2;

    final title = _tabs[selected].$3;
    final isDesktop = MediaQuery.sizeOf(context).width >= 1000;

    Future<void> logout() async {
      await context.read<AuthProvider>().logout();
      if (context.mounted) context.go('/login');
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: isDesktop
              ? Row(
                  children: [
                    _DesktopSidebar(
                      currentLocation: loc,
                      surface: surface,
                      border: border,
                      text: text,
                      sub: sub,
                      accent: accent,
                      accentSoft: accentSoft,
                      versionBorder: versionBorder,
                      isDark: isDark,
                      canAccessProduction: canAccessProduction,
                      onLogout: logout,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
                        child: Column(
                          children: [
                            _DesktopTopBar(
                              title: title,
                              surface: surface,
                              border: border,
                              text: text,
                              sub: sub,
                              accent: accent,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 12),
                            Expanded(child: child),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color:
                              surface.withValues(alpha: isDark ? 0.92 : 0.94),
                          border: Border.all(color: border),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: isDark ? 0.18 : 0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: text,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: accentSoft,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: versionBorder),
                              ),
                              child: Text(
                                'v${AppVersion.version} (${AppVersion.buildNumber})',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.logout_rounded, color: sub),
                              tooltip: 'Вийти',
                              onPressed: logout,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(child: child),
                  ],
                ),
        ),
      ),
      bottomNavigationBar: isDesktop
          ? null
          : Container(
              decoration: BoxDecoration(
                color: surface,
                border: Border(top: BorderSide(color: border)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: NavigationBar(
                selectedIndex: selected,
                onDestinationSelected: (i) => context.go(_tabs[i].$1),
                destinations: [
                  for (final t in _tabs)
                    NavigationDestination(
                      icon: Icon(t.$2, color: sub),
                      selectedIcon: Icon(t.$2, color: accent),
                      label: t.$3,
                    ),
                ],
              ),
            ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.currentLocation,
    required this.surface,
    required this.border,
    required this.text,
    required this.sub,
    required this.accent,
    required this.accentSoft,
    required this.versionBorder,
    required this.isDark,
    required this.canAccessProduction,
    required this.onLogout,
  });

  final String currentLocation;
  final Color surface;
  final Color border;
  final Color text;
  final Color sub;
  final Color accent;
  final Color accentSoft;
  final Color versionBorder;
  final bool isDark;
  final bool canAccessProduction;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 278,
      margin: const EdgeInsets.fromLTRB(16, 16, 0, 16),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: isDark ? 0.94 : 0.96),
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.07),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accentSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: versionBorder),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: OverflowBox(
                      maxWidth: 68,
                      maxHeight: 68,
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 68,
                        height: 68,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MOVA',
                        style: TextStyle(
                          color: text,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Intelligence',
                        style: TextStyle(
                          color: sub,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: accentSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: versionBorder),
              ),
              child: Text(
                'v${AppVersion.version} (${AppVersion.buildNumber})',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Divider(height: 1, color: border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
              children: [
                for (final item in AppScaffold._desktopLinks)
                  _DesktopNavTile(
                    path: item.$1,
                    icon: item.$2,
                    title: item.$3,
                    subtitle: item.$4,
                    selected: _isSelected(item.$1),
                    text: text,
                    sub: sub,
                    accent: accent,
                    border: border,
                    onTap: () => context.go(item.$1),
                  ),
                if (canAccessProduction)
                  _DesktopNavTile(
                    path: '/production',
                    icon: Icons.factory_outlined,
                    title: 'Виробництво',
                    subtitle: 'Сировина, розлив і склад',
                    selected: _isSelected('/production'),
                    text: text,
                    sub: sub,
                    accent: accent,
                    border: border,
                    onTap: () => context.go('/production'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: _DesktopLogoutButton(
              text: text,
              sub: sub,
              border: border,
              onTap: onLogout,
            ),
          ),
        ],
      ),
    );
  }

  bool _isSelected(String path) {
    if (path == '/work') {
      return currentLocation.startsWith('/work') ||
          currentLocation.startsWith('/approvals');
    }
    if (path == '/modules/communications') {
      return currentLocation.startsWith('/modules/communications') ||
          currentLocation.startsWith('/modules/messages');
    }
    if (path == '/modules/profile') {
      return currentLocation.startsWith('/modules/profile') ||
          currentLocation == '/menu';
    }
    if (path == '/modules') {
      return currentLocation == '/modules' ||
          currentLocation.startsWith('/modules/notifications');
    }
    return currentLocation.startsWith(path);
  }
}

class _DesktopNavTile extends StatelessWidget {
  const _DesktopNavTile({
    required this.path,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.text,
    required this.sub,
    required this.accent,
    required this.border,
    required this.onTap,
  });

  final String path;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final Color text;
  final Color sub;
  final Color accent;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color:
                selected ? accent.withValues(alpha: 0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.24)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.13)
                      : sub.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? accent.withValues(alpha: 0.22)
                        : border.withValues(alpha: 0.55),
                  ),
                ),
                child: Icon(icon, size: 19, color: selected ? accent : sub),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? accent : text,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: sub,
                        fontSize: 11.3,
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
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({
    required this.title,
    required this.surface,
    required this.border,
    required this.text,
    required this.sub,
    required this.accent,
    required this.isDark,
  });

  final String title;
  final Color surface;
  final Color border;
  final Color text;
  final Color sub;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: isDark ? 0.94 : 0.96),
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.space_dashboard_outlined, color: accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: text,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ),
          Text(
            'intelligence.mova.beer',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: sub,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopLogoutButton extends StatelessWidget {
  const _DesktopLogoutButton({
    required this.text,
    required this.sub,
    required this.border,
    required this.onTap,
  });

  final Color text;
  final Color sub;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(Icons.logout_rounded, color: sub, size: 19),
            const SizedBox(width: 9),
            Text(
              'Вийти',
              style: TextStyle(color: text, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
