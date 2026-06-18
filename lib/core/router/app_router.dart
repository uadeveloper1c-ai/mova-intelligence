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

import '../../features/events/presentation/events_page.dart';
import '../../features/invoices/presentation/pages/recognize_page.dart';

import '../../features/work/presentation/work_page.dart';
import '../../features/modules/presentation/modules_page.dart';
import '../../features/messages/presentation/messages_page.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/production/production_service.dart';
import '../../features/production/presentation/new_production_request_page.dart';
import '../../features/production/presentation/production_page.dart';
import '../../features/production/presentation/production_template_editor_page.dart';
import '../../features/production/presentation/production_templates_page.dart';
import '../../features/sales/presentation/customer_order_details_page.dart';
import '../../features/sales/presentation/customer_order_page.dart';
import '../../features/sales/presentation/customer_orders_page.dart';

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

      if (state.matchedLocation.startsWith('/production') &&
          !auth.canAccessProduction) {
        return '/modules';
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
        builder: (context, state) => const AppScaffold(child: HomePage()),
      ),
      GoRoute(
        path: '/invoices',
        builder: (context, state) => const AppScaffold(child: InvoicesPage()),
      ),
      GoRoute(
        path: '/events',
        builder: (context, state) => const AppScaffold(child: EventsPage()),
      ),
      GoRoute(
        path: '/invoices/recognize',
        builder: (context, state) => const AppScaffold(child: RecognizePage()),
      ),
      GoRoute(
        path: '/approvals',
        builder: (context, state) => const AppScaffold(child: ApprovalsPage()),
      ),

      GoRoute(
        path: '/menu',
        builder: (context, state) => const AppScaffold(child: ProfilePage()),
      ),

      // 🔹 НОВАЯ ЗАЯВКА
      GoRoute(
        path: '/approvals/new',
        name: 'newPaymentRequest',
        builder: (context, state) => const AppScaffold(
          child: NewRequestPage(),
        ),
      ),

      GoRoute(
        path: '/work',
        builder: (context, state) => const AppScaffold(child: WorkPage()),
      ),

      GoRoute(
        path: '/modules',
        builder: (context, state) => const AppScaffold(child: ModulesPage()),
      ),
      GoRoute(
        path: '/modules/profile',
        builder: (context, state) => const AppScaffold(child: ProfilePage()),
      ),
      GoRoute(
        path: '/modules/communications/new',
        builder: (context, state) =>
            const AppScaffold(child: NotificationsPage()),
      ),
      GoRoute(
        path: '/modules/communications',
        builder: (context, state) => const AppScaffold(child: MessagesPage()),
      ),
      GoRoute(
        path: '/modules/notifications',
        builder: (context, state) =>
            const AppScaffold(child: NotificationsPage()),
      ),
      GoRoute(
        path: '/modules/messages',
        builder: (context, state) => const AppScaffold(child: MessagesPage()),
      ),

      // 🔹 ДЕТАЛИ ЗАЯВКИ ПО UID
      GoRoute(
        path: '/approvals/request/:uid',
        name: 'approvalRequestDetails',
        builder: (context, state) {
          final uid = state.pathParameters['uid']!;
          final allowActions = state.uri.queryParameters['actions'] == '1';
          return AppScaffold(
            child: PaymentRequestDetailsPage(
              uid: uid,
              allowActions: allowActions,
            ),
          );
        },
      ),

      GoRoute(
        path: '/tasks',
        builder: (context, state) => const AppScaffold(child: TasksPage()),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const AppScaffold(child: ReportsPage()),
      ),
      GoRoute(
        path: '/sales/customer-orders',
        builder: (context, state) =>
            const AppScaffold(child: CustomerOrdersPage()),
      ),
      GoRoute(
        path: '/sales/customer-orders/:uid',
        builder: (context, state) => AppScaffold(
          child: CustomerOrderDetailsPage(
            uid: state.pathParameters['uid'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/sales/customer-order/new',
        builder: (context, state) =>
            const AppScaffold(child: CustomerOrderPage()),
      ),
      GoRoute(
        path: '/production',
        builder: (context, state) => const AppScaffold(child: ProductionPage()),
      ),
      GoRoute(
        path: '/production/new',
        builder: (context, state) {
          final rawType = state.uri.queryParameters['type'] ?? '';
          ProductionRequestType? type;
          for (final value in ProductionRequestType.values) {
            if (value.code.toLowerCase() == rawType.toLowerCase()) {
              type = value;
              break;
            }
          }
          return AppScaffold(
            child: NewProductionRequestPage(initialType: type),
          );
        },
      ),
      GoRoute(
        path: '/production/templates',
        builder: (context, state) =>
            const AppScaffold(child: ProductionTemplatesPage()),
      ),
      GoRoute(
        path: '/production/templates/new',
        builder: (context, state) =>
            const AppScaffold(child: ProductionTemplateEditorPage()),
      ),
      GoRoute(
        path: '/production/templates/:uid',
        builder: (context, state) => AppScaffold(
          child: ProductionTemplateEditorPage(
            uid: state.pathParameters['uid'],
          ),
        ),
      ),
    ],
  );
}
