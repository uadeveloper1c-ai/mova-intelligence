// lib/main.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart'; // 🔹 ДОБАВИТЬ

import 'api/api_client.dart';
import 'api/auth_provider.dart';
import 'api/push_service.dart';
import 'core/router/app_router.dart';
import 'core/app_version.dart';
import 'features/approvals/approvals_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Инициализируем Firebase
  await Firebase.initializeApp();

  // 🔹 1.5. Инициализируем Hive (для SessionStore / orgs / сессии)
  await Hive.initFlutter();

  // 2. Версия приложения
  await AppVersion.init();

  // 3. Клиент API
  final apiClient = ApiClient();
  await apiClient.init();

  /// 4. Push-сервис (пока без init)
  final pushService = PushService(apiClient: apiClient);

// 5. Auth-провайдер
  final auth = AuthProvider(
    apiClient: apiClient,
    pushService: pushService,
  );

// 6. Роутер
  final GoRouter router = createRouter(auth);

// 6.1. Привязываем навигацию по пушу к роутеру
  pushService.onApprovalPush = ({
    required String type,
    required String requestUid,
    String? orgUid,
  }) {
    debugPrint(
      'Approval push: type=$type requestUid=$requestUid orgUid=$orgUid',
    );

    router.pushNamed(
      'approvalRequestDetails',
      pathParameters: {
        'uid': requestUid,
      },
    );
  };

// 7. UI
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        Provider<ApiClient>.value(value: apiClient),
        Provider<PushService>.value(value: pushService),
        Provider<ApprovalsService>(
          create: (_) => ApprovalsService(apiClient),
        ),
      ],
      child: MyApp(router: router),
    ),
  );

// 8. Всё "тяжёлое" после старта UI

// инициализация пушей
  pushService.init();

// авто-логин + регистрация устройства + повторное открытие заявки после логина
  () async {
    await auth.loadUser();
    if (auth.isLoggedIn) {
      await pushService.registerCurrentDevice();

      // если пуш пришёл ДО логина — открываем заявку сейчас
      final pendingId = pushService.initialApprovalRequestId;
      if (pendingId != null && pendingId.isNotEmpty) {
        debugPrint('main: pending approval request $pendingId, navigating now');
        router.pushNamed(
          'approvalRequestDetails',
          pathParameters: {'uid': pendingId},
        );
        pushService.initialApprovalRequestId = null;
      }
    }
  }();
}

class MyApp extends StatelessWidget {
  final GoRouter router;
  const MyApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
