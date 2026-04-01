// lib/core/router/app_router.dart

import 'package:go_router/go_router.dart';

import '../../api/auth_provider.dart';
import '../../features/auth/login_page.dart';
import '../ui/app_scaffold.dart';

// страницы вкладок
import '../../features/home/presentation/home_page.dart';
import '../../features/invoices/presentation/pages/invoices_page.dart';
import '../../features/approvals/presentation/approvals_page.dart';
import '../../features/tasks/presentation/tasks_page.dart';
import '../../features/reports/presentation/reports_page.dart';

// страницы заявок
import '../../features/approvals/presentation/payment_request_details_page.dart';
import '../../features/approvals/presentation/new_request_page.dart';

import '../../features/menu/presentation/menu_page.dart';
import '../../features/events/presentation/events_page.dart';
import '../../features/invoices/presentation/pages/recognize_page.dart';

GoRouter createRouter(AuthProvider auth) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: auth,
    redirect: (context, state) {
      final loggedIn = auth.isLoggedIn;
      final loggingIn = state.matchedLocation == '/login';

      if (!loggedIn && !loggingIn) {
        return '/login';
      }

      if (loggedIn && loggingIn) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) =>
        const AppScaffold(child: HomePage()),
      ),
      GoRoute(
        path: '/invoices',
        builder: (context, state) =>
        const AppScaffold(child: InvoicesPage()),
      ),
      GoRoute(
        path: '/events',
        builder: (context, state) =>
        const AppScaffold(child: EventsPage()),
      ),
      GoRoute(
        path: '/invoices/recognize',
        builder: (context, state) => const AppScaffold(child: RecognizePage()),
      ),
      GoRoute(
        path: '/approvals',
        builder: (context, state) =>
        const AppScaffold(child: ApprovalsPage()),
      ),

      GoRoute(
        path: '/menu',
        builder: (context, state) => const AppScaffold(child: MenuPage()),
      ),

      // 🔹 НОВАЯ ЗАЯВКА
      GoRoute(
        path: '/approvals/new',
        name: 'newPaymentRequest',
        builder: (context, state) => const AppScaffold(
          child: NewRequestPage(),
        ),
      ),

      // 🔹 ДЕТАЛИ ЗАЯВКИ ПО UID
      GoRoute(
        path: '/approvals/request/:uid',
        name: 'approvalRequestDetails',
        builder: (context, state) {
          final uid = state.pathParameters['uid']!;
          return AppScaffold(
            child: PaymentRequestDetailsPage(
              uid: uid,
              allowActions: true,
            ),
          );
        },
      ),

      GoRoute(
        path: '/tasks',
        builder: (context, state) =>
        const AppScaffold(child: TasksPage()),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) =>
        const AppScaffold(child: ReportsPage()),
      ),
    ],
  );
}
