import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mova_intelligence_app/api/auth_provider.dart';
import 'package:mova_intelligence_app/core/ui/app_background.dart';
import 'package:mova_intelligence_app/core/app_version.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    ('/home', Icons.dashboard_outlined, 'Головна'),
    ('/approvals', Icons.verified_outlined, 'Заявки'),
    ('/menu', Icons.menu_rounded, 'Меню'),
  ];

  static const _bg = Color(0xFF0E1A2B);
  static const _panel = Color(0xFF1A2A40);
  static const _border = Color(0xFF2A3B52);
  static const _text = Color(0xFFF3F7FB);
  static const _sub = Color(0xFFB7C4D1);
  static const _accent = Color(0xFF22D3EE);

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();

    int selected = 0;
    if (loc.startsWith('/approvals')) selected = 1;
    if (loc.startsWith('/menu')) selected = 2;

    final title = _tabs[selected].$3;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _panel.withValues(alpha: 0.94),
                    border: Border.all(color: _border),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 14,
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
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _text,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _bg.withValues(alpha: 0.42),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _border),
                        ),
                        child: Text(
                          'v${AppVersion.version} (${AppVersion.buildNumber})',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _sub,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.logout_rounded),
                        tooltip: 'Вийти',
                        color: _text,
                        onPressed: () async {
                          await context.read<AuthProvider>().logout();
                          if (context.mounted) context.go('/login');
                        },
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
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: const NavigationBarThemeData(
            backgroundColor: _panel,
            indicatorColor: Color(0x2422D3EE),
            elevation: 0,
            height: 72,
            labelTextStyle: WidgetStatePropertyAll(
              TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            iconTheme: WidgetStatePropertyAll(
              IconThemeData(size: 24),
            ),
          ),
        ),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _border)),
          ),
          child: NavigationBar(
            selectedIndex: selected,
            onDestinationSelected: (i) => context.go(_tabs[i].$1),
            destinations: [
              for (final t in _tabs)
                NavigationDestination(
                  icon: Icon(t.$2, color: _sub),
                  selectedIcon: Icon(t.$2, color: _accent),
                  label: t.$3,
                ),
            ],
          ),
        ),
      ),
    );
  }
}