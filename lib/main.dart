import 'dart:async';
import 'dart:ui';

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
import 'features/production/production_service.dart';
import 'features/sales/sales_service.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exceptionAsString()}');
      debugPrint('${details.stack}');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('PlatformDispatcher error: $error');
      debugPrint('$stack');
      return true;
    };

    await _startupStep('Hive.initFlutter', Hive.initFlutter);
    await _startupStep('AppVersion.init', AppVersion.init);

    final apiClient = ApiClient();
    await _startupStep('ApiClient.init', apiClient.init);

    final themeController = ThemeController();
    await _startupStep('ThemeController.load', themeController.load);

    final pushService = PushService(apiClient: apiClient);

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
          Provider<ApprovalsService>(
              create: (_) => ApprovalsService(apiClient)),
          Provider<NotificationsService>(
            create: (_) => NotificationsService(apiClient),
          ),
          Provider<ProductionService>(
              create: (_) => ProductionService(apiClient)),
          Provider<SalesService>(create: (_) => SalesService(apiClient)),
        ],
        child: MyApp(router: router),
      ),
    );

    unawaited(_afterFirstFrameStartup(
      auth: auth,
      pushService: pushService,
      router: router,
    ));
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error');
    debugPrint('$stack');
  });
}

Future<void> _afterFirstFrameStartup({
  required AuthProvider auth,
  required PushService pushService,
  required GoRouter router,
}) async {
  await WidgetsBinding.instance.endOfFrame;

  var pushReady = false;
  if (!kIsWeb && defaultTargetPlatform != TargetPlatform.windows) {
    pushReady = await _startupStep(
      'Firebase.initializeApp',
      Firebase.initializeApp,
      timeout: const Duration(seconds: 8),
    );
    if (pushReady) {
      pushReady = await _startupStep(
        'PushService.init',
        pushService.init,
        timeout: const Duration(seconds: 8),
      );
    }
  }

  await _startupStep('AuthProvider.loadUser', auth.loadUser);
  if (auth.isLoggedIn) {
    if (pushReady) {
      await _startupStep(
        'PushService.clearSystemNotifications',
        pushService.clearSystemNotifications,
      );
      await _startupStep(
        'PushService.registerCurrentDevice',
        pushService.registerCurrentDevice,
        timeout: const Duration(seconds: 8),
      );
    }

    final pendingId = pushService.initialApprovalRequestId;
    if (pendingId != null && pendingId.isNotEmpty) {
      debugPrint('main: pending approval request $pendingId, navigating now');
      if (pushReady) {
        await _startupStep(
          'PushService.clearSystemNotifications.beforeNavigation',
          pushService.clearSystemNotifications,
        );
      }
      router.pushNamed(
        'approvalRequestDetails',
        pathParameters: {'uid': pendingId},
        queryParameters: const {'actions': '1'},
      );
      pushService.initialApprovalRequestId = null;
    }
  }
}

Future<bool> _startupStep(
  String name,
  Future<void> Function() action, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  try {
    debugPrint('Startup[$name]: begin');
    await action().timeout(timeout);
    debugPrint('Startup[$name]: ok');
    return true;
  } catch (e, stack) {
    debugPrint('Startup[$name]: failed: $e');
    debugPrint('$stack');
    return false;
  }
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
