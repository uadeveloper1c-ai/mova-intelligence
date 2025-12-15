import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MOVA')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tile(
            context,
            icon: Icons.document_scanner_outlined,
            title: 'Новая заявка на расход ДС',
            subtitle: 'PDF / Фото → поля',
            onTap: () => context.push('/recognize'),
          ),
          const SizedBox(height: 12),
          _tile(
            context,
            icon: Icons.history,
            title: 'История',
            subtitle: 'Последние согласования',
            onTap: () => context.push('/history'),
          ),
          const SizedBox(height: 12),
          _tile(
            context,
            icon: Icons.settings_outlined,
            title: 'Настройки',
            subtitle: 'URL, токен, язык',
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }

  Widget _tile(
      BuildContext ctx, {
        required IconData icon,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
      }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 28),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
