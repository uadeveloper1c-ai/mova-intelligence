import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  ApiClient._internal();

  final http.Client _httpClient = http.Client();

  String? _accessToken;
  String? get accessToken => _accessToken;

  bool _isRefreshing = false;

  // очередь ожидающих запросов во время refresh
  final List<Future<void> Function()> _pendingRequests = [];

  String? lastLoginError;

  /// БАЗОВЫЙ URL API 1С
  final String baseUrl = "https://intelligence.mova.beer/hs/api";

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString("access_token");
  }

  Future<void> _saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("access_token", access);
    await prefs.setString("refresh_token", refresh);
    _accessToken = access;
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("access_token");
    await prefs.remove("refresh_token");
    _accessToken = null;
  }

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
          lastLoginError = 'Невірний логін або пароль, або немає доступу';
        } else {
          lastLoginError = 'Помилка логіна (HTTP ${r.statusCode})';
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
      // ignore: avoid_print
      print('REFRESH EXCEPTION: $e');
      return false;
    }
  }

  Future<http.Response> sendAuthorizedRequest(
      String method,
      String endpoint, {
        Map<String, String>? headers,
        Object? body,
      }) async {
    final url = Uri.parse("$baseUrl$endpoint");

    Future<http.Response> makeRequest() async {
      final hdr = <String, String>{
        // ставим JSON по умолчанию, но не ломаем, если передали свой
        if (headers == null || !headers.containsKey("Content-Type"))
          "Content-Type": "application/json",
        if (_accessToken != null) "Authorization": "Bearer $_accessToken",
        if (headers != null) ...headers,
      };

      switch (method.toUpperCase()) {
        case "GET":
          return _httpClient.get(url, headers: hdr);
        case "POST":
          return _httpClient.post(url, headers: hdr, body: body);
        case "PUT":
          return _httpClient.put(url, headers: hdr, body: body);
        case "DELETE":
          return _httpClient.delete(url, headers: hdr);
        default:
          throw Exception("Unknown HTTP method: $method");
      }
    }

    var response = await makeRequest();

    if (response.statusCode != 401) return response;

    // если refresh уже идёт — ждём и повторяем запрос после него
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

    // запускаем ожидающих
    for (final fn in _pendingRequests) {
      await fn();
    }
    _pendingRequests.clear();

    return await makeRequest();
  }

  /// RAW (multipart/stream) с Bearer и авто-refresh
  ///
  /// Важно: BaseRequest нельзя переиспользовать. Поэтому сюда передаём builder,
  /// который создаёт НОВЫЙ request каждый раз.
  Future<http.StreamedResponse> sendAuthorizedRaw(
      http.BaseRequest Function() requestBuilder,
      ) async {
    http.BaseRequest req = requestBuilder();

    if (_accessToken != null) {
      req.headers["Authorization"] = "Bearer $_accessToken";
    }

    http.StreamedResponse resp = await _httpClient.send(req);

    if (resp.statusCode != 401) return resp;

    if (_isRefreshing) {
      final completer = Completer<http.StreamedResponse>();
      _pendingRequests.add(() async {
        final r2 = requestBuilder();
        if (_accessToken != null) {
          r2.headers["Authorization"] = "Bearer $_accessToken";
        }
        completer.complete(await _httpClient.send(r2));
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
      await fn();
    }
    _pendingRequests.clear();

    final retry = requestBuilder();
    if (_accessToken != null) {
      retry.headers["Authorization"] = "Bearer $_accessToken";
    }
    return await _httpClient.send(retry);
  }

  Future<Map<String, dynamic>?> getMe() async {
    try {
      final r = await sendAuthorizedRequest("GET", "/me");
      if (r.statusCode == 200) {
        return jsonDecode(r.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // ignore: avoid_print
      print('GetMe error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> sendInvoice({
    required String supplierName,
    required double amount,
    required String purpose,
    String? number,
    String? desiredDateIso,
    String? orgCode,
    String? vendorCode,
    bool urgent = false,
  }) async {
    final Map<String, dynamic> body = {
      'org_code': orgCode ?? '',
      'vendor_code': vendorCode ?? '',
      'vendor_name': supplierName,
      'amount': amount.toString(),
      'purpose': purpose,
      'urgent': urgent,
      if (desiredDateIso != null && desiredDateIso.isNotEmpty)
        'desired_date': desiredDateIso,
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
      throw Exception('Помилка надсилання заявки: ${r.statusCode} ${r.body}');
    }
  }

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

    // ignore: avoid_print
    print('registerDevice: ${r.statusCode} ${r.body}');
  }

  Future<void> unregisterDevice({required String deviceId}) async {
    final body = jsonEncode({"deviceId": deviceId});

    final r = await sendAuthorizedRequest(
      "POST",
      "/devices/unregister",
      body: body,
    );

    // ignore: avoid_print
    print('unregisterDevice: ${r.statusCode} ${r.body}');
  }
}
