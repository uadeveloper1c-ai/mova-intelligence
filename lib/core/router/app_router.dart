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
        path: '/approvals',
        builder: (context, state) =>
        const AppScaffold(child: ApprovalsPage()),
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
            child: PaymentRequestDetailsPage(requestId: uid),
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
