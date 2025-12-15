import 'package:dio/dio.dart';
import 'dashboard_counts.dart';
import 'i_dashboard_service.dart';

class HttpDashboardService implements IDashboardService {
  final Dio _dio;
  final String baseUrl;
  HttpDashboardService(this._dio, {required this.baseUrl});

  @override
  Future<DashboardCounts> fetch() async {
    final res = await _dio.get('$baseUrl/api/dashboard');
    return DashboardCounts.fromJson(res.data as Map<String, dynamic>);
  }
}
