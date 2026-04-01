import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import '../main.dart'; // ✅ ВАЖНО: с ;
import 'package:flutter/material.dart';

typedef ApprovalPushHandler = void Function({
required String type,
required String requestUid,
String? orgUid,
});

class PushService {
  PushService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final FirebaseMessaging _fm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static const _prefDeviceId = 'device_id';

  ApprovalPushHandler? onApprovalPush;
  VoidCallback? onDataRefreshNeeded;

  String? initialApprovalRequestId;

  bool _localInited = false;

  Future<void> init() async {
    if (!kIsWeb) {
      await _fm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    await _initLocalNotifications();

    /// 🔥 FOREGROUND PUSH
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint(
        'FCM onMessage: ${message.notification?.title} | '
            '${message.notification?.body} | data=${message.data}',
      );

      /// 1. системное уведомление
      await _showForegroundNotification(message);

      /// 2. snackbar (на любой странице)
      _showGlobalSnack(message.data);

      /// 3. обработка (навигация)
      _handleApprovalData(message.data);

      /// 4. обновление UI
      onDataRefreshNeeded?.call();
    });

    /// 🔥 BACKGROUND TAP
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM onMessageOpenedApp: data=${message.data}');
      _handleApprovalData(message.data);
    });

    /// 🔥 APP CLOSED → OPENED BY PUSH
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

  Future<void> _initLocalNotifications() async {
    if (_localInited || kIsWeb) return;

    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;

        try {
          final data =
          Map<String, dynamic>.from(jsonDecode(payload) as Map);
          _handleApprovalData(data);
        } catch (e) {
          debugPrint('Local notification payload parse error: $e');
        }
      },
    );

    const channel = AndroidNotificationChannel(
      'mova_approvals',
      'MOVA approvals',
      description: 'Approval notifications',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _localInited = true;
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (kIsWeb) return;

    final title =
        message.notification?.title ?? _titleFromData(message.data) ?? 'MOVA';

    final body =
        message.notification?.body ??
            _bodyFromData(message.data) ??
            'Нове повідомлення';

    final payload = jsonEncode(message.data);

    const androidDetails = AndroidNotificationDetails(
      'mova_approvals',
      'MOVA approvals',
      channelDescription: 'Approval notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  void _showGlobalSnack(Map<String, dynamic> data) {
    final messenger = rootMessengerKey.currentState;
    if (messenger == null) return;

    final type = (data['type'] ?? '').toString();

    String text;
    switch (type) {
      case 'approval_new':
        text = 'Нова заявка на погодження';
        break;
      case 'approval_approved':
        text = 'Заявку погоджено';
        break;
      case 'approval_rejected':
        text = 'Заявку відхилено';
        break;
      default:
        text = 'Нове повідомлення';
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Відкрити',
          onPressed: () {
            _handleApprovalData(data);
          },
        ),
      ),
    );
  }

  String? _titleFromData(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString();

    switch (type) {
      case 'approval_new':
        return 'Нова заявка';
      case 'approval_approved':
        return 'Заявку погоджено';
      case 'approval_rejected':
        return 'Заявку відхилено';
      default:
        return 'MOVA';
    }
  }

  String? _bodyFromData(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString();

    switch (type) {
      case 'approval_new':
        return 'Є нова заявка на погодження';
      case 'approval_approved':
        return 'Ваша заявка погоджена';
      case 'approval_rejected':
        return 'Ваша заявка відхилена';
      default:
        return 'Натисніть, щоб відкрити';
    }
  }

  Future<void> registerCurrentDevice() async {
    final token = await _fm.getToken();
    debugPrint('FCM current token: $token');

    if (token == null) return;
    await _register(token);
  }

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

    final requestUid =
    (data['request_uid'] ?? data['requestUid'] ?? '').toString();
    final orgUid = (data['org_uid'] ?? data['orgUid'])?.toString();

    if (requestUid.isEmpty) return;

    if (onApprovalPush != null) {
      onApprovalPush!(
        type: type,
        requestUid: requestUid,
        orgUid: orgUid,
      );
      return;
    }

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