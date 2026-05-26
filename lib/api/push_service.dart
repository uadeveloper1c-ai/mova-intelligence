import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_version.dart';
import 'api_client.dart';

typedef ApprovalPushHandler = void Function({
  required String type,
  required String requestUid,
  String? orgUid,
});

class PushService {
  PushService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;
  FirebaseMessaging get _fm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static const MethodChannel _badgeChannel =
      MethodChannel('mova_intelligence_app/badge');

  static const _prefDeviceId = 'device_id';
  static const _badgeResetNotificationId = 777001;

  bool get _supportsPushPlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Хэндлер, который выставляется в main.dart и делает навигацию в заявку
  ApprovalPushHandler? onApprovalPush;

  /// Если пуш был получен до старта UI/роутера — сохраним requestUid сюда
  String? initialApprovalRequestId;

  Future<void> init() async {
    if (!_supportsPushPlatform) {
      debugPrint('PushService: push skipped on this platform');
      return;
    }

    await _initLocalNotifications();

    final settings = await _fm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');
    if (Platform.isIOS) {
      final apnsToken = await _fm.getAPNSToken();
      debugPrint('APNs token after permission request: $apnsToken');
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
      clearSystemNotifications();
      _handleApprovalData(message.data);
    });

    // ✅ Когда приложение было полностью закрыто и запустилось пушем
    final initialMessage = await _fm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('FCM getInitialMessage: data=${initialMessage.data}');
      clearSystemNotifications();
      _handleApprovalData(initialMessage.data);
    }

    _fm.onTokenRefresh.listen((token) async {
      debugPrint('FCM token refresh: $token');
      await _register(token);
    });
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      defaultPresentAlert: false,
      defaultPresentBadge: false,
      defaultPresentSound: false,
    );

    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
    );

    await _localNotifications.initialize(settings);
  }

  Future<void> clearSystemNotifications() async {
    if (!_supportsPushPlatform) return;

    try {
      await _localNotifications.cancelAll();

      if (Platform.isIOS) {
        try {
          await _badgeChannel.invokeMethod<void>('clearBadge');
        } catch (e) {
          debugPrint(
              'PushService.clearSystemNotifications iOS badge error: $e');
        }

        const details = NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: false,
            presentSound: false,
            presentBadge: false,
            badgeNumber: 0,
          ),
        );

        await _localNotifications.show(
          _badgeResetNotificationId,
          '',
          '',
          details,
        );
        await _localNotifications.cancel(_badgeResetNotificationId);
      }
    } catch (e) {
      debugPrint('PushService.clearSystemNotifications error: $e');
    }
  }

  /// Регистрация текущего устройства в 1С
  Future<void> registerCurrentDevice() async {
    if (!_supportsPushPlatform) return;

    final token = await _obtainMessagingToken();
    debugPrint('FCM current token: $token');

    if (token == null) return;
    await _register(token);
  }

  Future<String?> _obtainMessagingToken() async {
    if (!_supportsPushPlatform) return null;

    for (var attempt = 0; attempt < 4; attempt++) {
      if (Platform.isIOS) {
        final apnsToken = await _fm.getAPNSToken();
        debugPrint('APNs token attempt ${attempt + 1}: $apnsToken');
      }

      final token = await _fm.getToken();
      if (token != null && token.isNotEmpty) {
        return token;
      }

      if (attempt < 3) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }

    return null;
  }

  /// Разрегистрация устройства (на logout)
  Future<void> unregisterCurrentDevice() async {
    if (!_supportsPushPlatform) return;

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
    final requestUid =
        (data['request_uid'] ?? data['requestUid'] ?? '').toString();
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
    final appVersion = AppVersion.buildNumber.isNotEmpty
        ? '${AppVersion.version} (${AppVersion.buildNumber})'
        : AppVersion.version;

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
