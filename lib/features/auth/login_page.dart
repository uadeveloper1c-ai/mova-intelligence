// lib/features/auth/login_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/auth_provider.dart';
import '../../api/api_client.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _loginCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Вхід в MOVA')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _loginCtrl,
                decoration: const InputDecoration(labelText: 'Логін'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passCtrl,
                decoration: const InputDecoration(labelText: 'Пароль'),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              auth.isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: () async {
                  final ok = await auth.login(
                    _loginCtrl.text.trim(),
                    _passCtrl.text,
                  );

                  if (!ok && mounted) {
                    final err = ApiClient().lastLoginError ?? 'Помилка логіна';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(err),
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }

                  // если ok – redirect обработает GoRouter сам
                },
                child: const Text('Увійти'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
