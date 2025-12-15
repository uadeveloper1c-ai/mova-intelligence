// lib/core/ui/app_scaffold.dart

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
    ('/invoices', Icons.receipt_long_outlined, 'Рахунки'),
    ('/approvals', Icons.verified_outlined, 'Погодження'),
    ('/tasks', Icons.checklist_outlined, 'Задачі'),
    ('/reports', Icons.bar_chart_outlined, 'Звіти'),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    final idx = _tabs.indexWhere((t) => loc.startsWith(t.$1));
    final selected = idx < 0 ? 0 : idx;

    return Scaffold(
      // Никакого AppBar — делаем свою верхнюю панель внутри body
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Верхняя панель: название вкладки + кнопка "Вийти"
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _tabs[selected].$3,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),

                    ),
                    const SizedBox(height: 2),
                    Text(
                      "v${AppVersion.version} (${AppVersion.buildNumber})",  // ← вот здесь
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout),
                      tooltip: 'Вийти',
                      onPressed: () async {
                        // логаут (внутри AuthProvider уже дергается unregisterDevice)
                        await context.read<AuthProvider>().logout();

                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // Контент конкретної вкладки
              Expanded(child: child),
            ],
          ),
        ),
      ),

      // Нижня навігація
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) => context.go(_tabs[i].$1),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(icon: Icon(t.$2), label: t.$3),
        ],
      ),
    );
  }
}
