// lib/api/api_client.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  ApiClient._internal();

  String? _accessToken;
  String? get accessToken => _accessToken;
  bool _isRefreshing = false;
  final List<Function> _pendingRequests = [];

  String? lastLoginError;

  /// БАЗОВЫЙ URL API 1С
  final String baseUrl = "https://intelligence.mova.beer/hs/api";

  // === загрузка токенов при запуске
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString("access_token");
  }

  // === сохранить токены
  Future<void> _saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("access_token", access);
    await prefs.setString("refresh_token", refresh);
    _accessToken = access;
  }

  // === очистить токены (при logout)
  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("access_token");
    await prefs.remove("refresh_token");
    _accessToken = null;
  }

  // === логин
  Future<bool> login(String login, String password) async {
    lastLoginError = null;
    try {
      final url = Uri.parse("$baseUrl/login");

      final r = await http
          .post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"login": login, "password": password}),
      )
          .timeout(const Duration(seconds: 15));

      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        await _saveTokens(data["access_token"], data["refresh_token"]);
        return true;
      } else {
        if (r.statusCode == 401) {
          // невірний логін/пароль або відмова в доступі
          lastLoginError = 'Невірний логін або пароль, або немає доступу';
        } else {
          lastLoginError =
          'Помилка логіна (HTTP ${r.statusCode})'; // без html-тіла
        }
        return false;
      }
    } on TimeoutException {
      lastLoginError = 'Таймаут запиту при логіні';
      return false;
    } catch (e) {
      lastLoginError = 'Внутрішня помилка логіна: $e';
      return false;
    }
  }


  // === refresh
  Future<bool> _refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refresh = prefs.getString("refresh_token");
    if (refresh == null) return false;

    try {
      final url = Uri.parse("$baseUrl/refresh");

      final r = await http
          .post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"refresh_token": refresh}),
      )
          .timeout(const Duration(seconds: 15));

      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        await _saveTokens(data["access_token"], data["refresh_token"]);
        return true;
      }

      return false;
    } catch (e) {
      print('REFRESH EXCEPTION: $e');
      return false;
    }
  }

  // === универсальный запрос с авто-refresh
  Future<http.Response> sendAuthorizedRequest(
      String method,
      String endpoint, {
        Map<String, String>? headers,
        Object? body,
      }) async {
    final url = Uri.parse("$baseUrl$endpoint");

    Future<http.Response> makeRequest() async {
      final hdr = <String, String>{
        "Content-Type": "application/json",
        if (_accessToken != null) "Authorization": "Bearer $_accessToken",
        if (headers != null) ...headers,
      };

      switch (method.toUpperCase()) {
        case "GET":
          return http.get(url, headers: hdr);
        case "POST":
          return http.post(url, headers: hdr, body: body);
        case "PUT":
          return http.put(url, headers: hdr, body: body);
        case "DELETE":
          return http.delete(url, headers: hdr);
        default:
          throw Exception("Unknown HTTP method: $method");
      }
    }

    var response = await makeRequest();

    if (response.statusCode != 401) {
      return response;
    }

    // если кто-то уже обновляет токен – встаём в очередь
    if (_isRefreshing) {
      final completer = Completer<http.Response>();
      _pendingRequests.add(() async {
        completer.complete(await makeRequest());
      });
      return completer.future;
    }

    _isRefreshing = true;
    final ok = await _refreshToken();
    _isRefreshing = false;

    if (!ok) {
      throw Exception("Refresh token expired – нужно логиниться заново");
    }

    for (final fn in _pendingRequests) {
      fn();
    }
    _pendingRequests.clear();

    return await makeRequest();
  }

  // === me
  Future<Map<String, dynamic>?> getMe() async {
    try {
      final r = await sendAuthorizedRequest("GET", "/me");
      if (r.statusCode == 200) {
        return jsonDecode(r.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('GetMe error: $e');
    }
    return null;
  }

  /// Надіслати заявку на оплату в 1С (/sendInvoice)
  Future<Map<String, dynamic>> sendInvoice({
    required String supplierName,
    required double amount,
    required String purpose,
    String? number,
    String? desiredDateIso, // yyyy-MM-dd
    String? orgCode,
    String? vendorCode,
    bool urgent = false,
  }) async {
    final Map<String, dynamic> body = {
      // 1С чекає ці ключі - віддамо хоча б порожні рядки
      'org_code': orgCode ?? '',
      'vendor_code': vendorCode ?? '',
      'vendor_name': supplierName,
      'amount': amount.toString(), // 1С сама зробить Число(...)
      'purpose': purpose,
      'urgent': urgent,
      if (desiredDateIso != null && desiredDateIso.isNotEmpty)
        'desired_date': desiredDateIso, // "2025-02-01"
      if (number != null && number.isNotEmpty) 'invoice_number': number,
    };

    final r = await sendAuthorizedRequest(
      'POST',
      '/sendInvoice',
      body: jsonEncode(body),
    );

    if (r.statusCode >= 200 && r.statusCode < 300) {
      return jsonDecode(r.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Помилка надсилання заявки: ${r.statusCode} ${r.body}',
      );
    }
  }


  // === регистрация устройства для пушей
  Future<void> registerDevice({
    required String deviceId,
    required String pushToken,
    required String platform,
    required String appVersion,
  }) async {
    final body = jsonEncode({
      "deviceId": deviceId,
      "pushToken": pushToken,
      "platform": platform,
      "appVersion": appVersion,
    });

    final r = await sendAuthorizedRequest(
      "POST",
      "/devices/register",
      body: body,
    );

    print('registerDevice: ${r.statusCode} ${r.body}');
  }

  // === снятие устройства с регистрации
  Future<void> unregisterDevice({required String deviceId}) async {
    final body = jsonEncode({"deviceId": deviceId});

    final r = await sendAuthorizedRequest(
      "POST",
      "/devices/unregister",
      body: body,
    );

    print('unregisterDevice: ${r.statusCode} ${r.body}');
  }
}
