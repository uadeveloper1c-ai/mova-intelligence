import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'api/api_client.dart';
import 'api/auth_provider.dart';
import 'api/push_service.dart';
import 'core/router/app_router.dart';
import 'core/app_version.dart';
import 'features/approvals/approvals_service.dart';
import 'features/events/events_service.dart';

final ValueNotifier<int> approvalsRefreshNotifier = ValueNotifier<int>(0);
final GlobalKey<ScaffoldMessengerState> rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await Hive.initFlutter();
  await AppVersion.init();

  final apiClient = ApiClient();
  await apiClient.init();

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
    debugPrint('Approval push: type=$type requestUid=$requestUid orgUid=$orgUid');

    router.pushNamed(
      'approvalRequestDetails',
      pathParameters: {'uid': requestUid},
    );
  };

  pushService.onDataRefreshNeeded = () {
    approvalsRefreshNotifier.value++;
    debugPrint('approvalsRefreshNotifier -> ${approvalsRefreshNotifier.value}');
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        Provider<ApiClient>.value(value: apiClient),
        Provider<PushService>.value(value: pushService),
        Provider<EventsService>(create: (_) => EventsService(apiClient)),
        Provider<ApprovalsService>(create: (_) => ApprovalsService(apiClient)),
      ],
      child: MyApp(router: router),
    ),
  );

  await pushService.init();

  () async {
    await auth.loadUser();
    if (auth.isLoggedIn) {
      await pushService.registerCurrentDevice();

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
      scaffoldMessengerKey: rootMessengerKey,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: _movaDarkTheme(),
      theme: _movaDarkTheme(),
    );
  }
}

ThemeData _movaDarkTheme() {
  const bg = Color(0xFF14263D);
  const panel = Color(0xFF20344F);
  const panelSoft = Color(0xFF2A4366);
  const border = Color(0xFF3A506B);
  const text = Color(0xFFF3F7FB);
  const sub = Color(0xFF9FB3C8);
  const cyan = Color(0xFF38E1FF);

  final base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: bg,
    colorScheme: base.colorScheme.copyWith(
      brightness: Brightness.dark,
      primary: cyan,
      secondary: cyan,
      surface: panel,
      onSurface: text,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: text,
      displayColor: text,
    ),
    cardTheme: const CardThemeData(
      color: panel,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: border),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: border,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: cyan,
        foregroundColor: Colors.black,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: text,
        side: const BorderSide(color: border),
        backgroundColor: panelSoft.withValues(alpha: 0.35),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: cyan,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: panelSoft.withValues(alpha: 0.82),
      hintStyle: const TextStyle(color: sub),
      labelStyle: const TextStyle(color: sub),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: cyan),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFF97373)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFF97373)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: panelSoft.withValues(alpha: 0.45),
      selectedColor: cyan.withValues(alpha: 0.18),
      side: const BorderSide(color: border),
      labelStyle: const TextStyle(color: text, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: text,
      centerTitle: false,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: panel,
      contentTextStyle: const TextStyle(color: text),
      actionTextColor: cyan,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}