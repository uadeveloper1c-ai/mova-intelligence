import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'api/api_client.dart';
import 'api/auth_provider.dart';
import 'api/push_service.dart';
import 'core/app_version.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_themes.dart';
import 'core/theme/theme_controller.dart';
import 'features/approvals/approvals_service.dart';
import 'features/events/events_service.dart';
import 'features/notifications/notifications_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && defaultTargetPlatform != TargetPlatform.windows) {
    await Firebase.initializeApp();
  }
  await Hive.initFlutter();
  await AppVersion.init();

  final apiClient = ApiClient();
  await apiClient.init();

  final themeController = ThemeController();
  await themeController.load();

  final pushService = PushService(apiClient: apiClient);
  await pushService.init();

  final auth = AuthProvider(
    apiClient: apiClient,
    pushService: pushService,
  );

  final GoRouter router = createRouter(auth);

  pushService.onApprovalPush = ({
    required String type,
    required String requestUid,
    String? orgUid,
  }) {
    debugPrint(
        'Approval push: type=$type requestUid=$requestUid orgUid=$orgUid');

    pushService.clearSystemNotifications();
    router.pushNamed(
      'approvalRequestDetails',
      pathParameters: {'uid': requestUid},
      queryParameters: const {'actions': '1'},
    );
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<ThemeController>.value(value: themeController),
        Provider<ApiClient>.value(value: apiClient),
        Provider<PushService>.value(value: pushService),
        Provider<EventsService>(create: (_) => EventsService(apiClient)),
        Provider<ApprovalsService>(create: (_) => ApprovalsService(apiClient)),
        Provider<NotificationsService>(
          create: (_) => NotificationsService(apiClient),
        ),
      ],
      child: MyApp(router: router),
    ),
  );

  () async {
    await auth.loadUser();
    if (auth.isLoggedIn) {
      await pushService.clearSystemNotifications();
      await pushService.registerCurrentDevice();

      final pendingId = pushService.initialApprovalRequestId;
      if (pendingId != null && pendingId.isNotEmpty) {
        debugPrint('main: pending approval request $pendingId, navigating now');
        await pushService.clearSystemNotifications();
        router.pushNamed(
          'approvalRequestDetails',
          pathParameters: {'uid': pendingId},
          queryParameters: const {'actions': '1'},
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
    final themeController = context.watch<ThemeController>();

    return MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      themeMode: themeController.themeMode,
      theme: AppThemes.lightTheme(),
      darkTheme: AppThemes.darkTheme(),
      locale: const Locale('uk', 'UA'),
      supportedLocales: const [
        Locale('uk', 'UA'),
        Locale('ru', 'UA'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
