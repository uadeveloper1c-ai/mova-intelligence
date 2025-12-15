import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

typedef ApprovalPushHandler = void Function({
required String type,
required String requestUid,
String? orgUid,
});

class PushService {
  PushService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final FirebaseMessaging _fm = FirebaseMessaging.instance;

  static const _prefDeviceId = 'device_id';

  /// Хэндлер, который выставляется в main.dart и делает навигацию в заявку
  ApprovalPushHandler? onApprovalPush;

  /// Если пуш был получен до старта UI/роутера — сохраним requestUid сюда
  String? initialApprovalRequestId;

  Future<void> init() async {
    if (!kIsWeb) {
      await _fm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // ✅ Foreground сообщения
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        'FCM onMessage: ${message.notification?.title} | '
            '${message.notification?.body} | data=${message.data}',
      );

      _handleApprovalData(message.data);
    });

    // ✅ Когда пользователь тапнул по пушу и приложение было в фоне
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM onMessageOpenedApp: data=${message.data}');
      _handleApprovalData(message.data);
    });

    // ✅ Когда приложение было полностью закрыто и запустилось пушем
    final initialMessage = await _fm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('FCM getInitialMessage: data=${initialMessage.data}');
      _handleApprovalData(initialMessage.data);
    }

    _fm.onTokenRefresh.listen((token) async {
      debugPrint('FCM token refresh: $token');
      await _register(token);
    });
  }

  /// Регистрация текущего устройства в 1С
  Future<void> registerCurrentDevice() async {
    final token = await _fm.getToken();
    debugPrint('FCM current token: $token');

    if (token == null) return;
    await _register(token);
  }

  /// Разрегистрация устройства (на logout)
  Future<void> unregisterCurrentDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString(_prefDeviceId);
    if (deviceId == null) return;

    try {
      await _apiClient.unregisterDevice(deviceId: deviceId);
      debugPrint('Device unregistered: $deviceId');
    } catch (e) {
      debugPrint('unregisterDevice error: $e');
    }
  }

  void _handleApprovalData(Map<String, dynamic> data) {
    if (data.isEmpty) return;

    final type = (data['type'] ?? '').toString();
    if (type.isEmpty) return;

    // ожидаем: approval_new / approval_approved / approval_rejected
    final requestUid = (data['request_uid'] ?? data['requestUid'] ?? '').toString();
    final orgUid = (data['org_uid'] ?? data['orgUid'])?.toString();

    if (requestUid.isEmpty) return;

    // если UI уже готов — дергаем колбэк
    if (onApprovalPush != null) {
      onApprovalPush!(
        type: type,
        requestUid: requestUid,
        orgUid: orgUid,
      );
      return;
    }

    // иначе сохраним, main потом подхватит
    initialApprovalRequestId = requestUid;
  }

  Future<void> _register(String token) async {
    final prefs = await SharedPreferences.getInstance();
    const appVersion = '1.0.0';

    final deviceId = prefs.getString(_prefDeviceId) ?? token;
    await prefs.setString(_prefDeviceId, deviceId);

    final platform = Platform.isAndroid
        ? 'android'
        : Platform.isIOS
        ? 'ios'
        : 'web';

    try {
      await _apiClient.registerDevice(
        deviceId: deviceId,
        pushToken: token,
        platform: platform,
        appVersion: appVersion,
      );
      debugPrint('Device registered: $deviceId, platform=$platform');
    } catch (e) {
      debugPrint('registerDevice error: $e');
    }
  }
}
