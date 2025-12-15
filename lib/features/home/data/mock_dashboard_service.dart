import 'dart:async';
import 'dashboard_counts.dart';
import 'i_dashboard_service.dart';

class MockDashboardService implements IDashboardService {
  @override
  Future<DashboardCounts> fetch() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return const DashboardCounts(
      approvals: 3,
      tasks: 7,
      invoicesToday: 2,
      expensesMonth: 15230.75,
    );
  }
}
