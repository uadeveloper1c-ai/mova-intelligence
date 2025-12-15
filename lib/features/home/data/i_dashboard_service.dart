import 'dashboard_counts.dart';

abstract class IDashboardService {
  Future<DashboardCounts> fetch();
}
