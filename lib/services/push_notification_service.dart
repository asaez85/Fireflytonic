import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Logger _log = Logger('PushNotificationService');

const String _fcmTokenKey = 'FCM_TOKEN';
const String _pushEnabledKey = 'push_notifications_enabled';
const String _channelId = 'fcm_movements';
const String _channelName = 'Nuevos movimientos';
const String _channelDescription =
    'Notificaciones push de nuevos movimientos importados';

Future<FlutterLocalNotificationsPlugin> _initNotificationsPlugin() async {
  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_notification'),
    ),
  );
  return plugin;
}

Future<bool> _pushNotificationsEnabled() async {
  final SharedPreferencesAsync prefs = SharedPreferencesAsync();
  return await prefs.getBool(_pushEnabledKey) ?? true;
}

Future<void> _showLocalNotification(
  FlutterLocalNotificationsPlugin plugin,
  RemoteMessage message,
) async {
  if (!(await _pushNotificationsEnabled())) {
    _log.fine(
      () =>
          'FCM message ${message.messageId} skipped: push notifications disabled',
    );
    return;
  }

  final String? title =
      message.notification?.title ?? message.data['title'] as String?;
  final String? body =
      message.notification?.body ?? message.data['body'] as String?;

  if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
    _log.fine(
      () =>
          'FCM message ${message.messageId} has no displayable content, skipping local notification',
    );
    return;
  }

  final int notificationId =
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch;

  await plugin.show(
    id: notificationId,
    title: title ?? 'Nuevo movimiento',
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_notification',
      ),
    ),
    payload: message.data['payload'] ?? message.data.toString(),
  );
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  _log.finest(() => 'FCM background message received: ${message.messageId}');
  final FlutterLocalNotificationsPlugin plugin =
      await _initNotificationsPlugin();
  await _showLocalNotification(plugin, message);
}

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();

  factory PushNotificationService() => _instance;

  PushNotificationService._internal();

  bool _initialized = false;
  FlutterLocalNotificationsPlugin? _plugin;

  Future<void> initialize() async {
    if (_initialized) {
      _log.finest(() => 'PushNotificationService already initialized');
      return;
    }
    if (kIsWeb || !Platform.isAndroid) {
      _log.finest(
        () =>
            'PushNotificationService skipped: push notifications are Android-only',
      );
      return;
    }

    try {
      await Firebase.initializeApp();
      _log.info('Firebase initialized successfully');
    } catch (e, stackTrace) {
      _log.warning(
        () =>
            'Firebase initialization failed (google-services.json might be missing): $e',
        e,
        stackTrace,
      );
      return;
    }

    _plugin = await _initNotificationsPlugin();

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final NotificationSettings settings = await FirebaseMessaging.instance
        .requestPermission(alert: true, badge: true, sound: true);
    _log.info('FCM permission status: ${settings.authorizationStatus}');

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        ?.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final bool? granted = await androidPlugin?.requestNotificationsPermission();
    _log.info('Android POST_NOTIFICATIONS permission granted: $granted');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _log.info('FCM foreground message received: ${message.messageId}');
      if (_plugin != null) {
        _showLocalNotification(_plugin!, message);
      }
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((String token) async {
      _log.info('FCM token refreshed');
      await _storeToken(token);
    });

    try {
      final String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        _log.info('FCM token: $token');
        await _storeToken(token);
      } else {
        _log.warning('FCM token is null');
      }
    } catch (e, stackTrace) {
      _log.warning('Failed to get FCM token: $e', e, stackTrace);
    }

    _initialized = true;
  }

  Future<bool> isEnabled() async {
    final SharedPreferencesAsync prefs = SharedPreferencesAsync();
    return await prefs.getBool(_pushEnabledKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final SharedPreferencesAsync prefs = SharedPreferencesAsync();
    await prefs.setBool(_pushEnabledKey, enabled);
    _log.info('Push notifications enabled: $enabled');
  }

  Future<bool> isSystemPermissionGranted() async {
    try {
      final NotificationSettings settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e, stackTrace) {
      _log.warning(
        'Could not read FCM notification settings: $e',
        e,
        stackTrace,
      );
      return false;
    }
  }

  Future<bool> requestSystemPermission() async {
    try {
      final NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e, stackTrace) {
      _log.warning('Could not request FCM permission: $e', e, stackTrace);
      return false;
    }
  }

  Future<void> _storeToken(String token) async {
    final SharedPreferencesAsync prefs = SharedPreferencesAsync();
    await prefs.setString(_fcmTokenKey, token);
    _log.info('FCM token stored in SharedPreferences');
  }

  Future<String?> getStoredToken() {
    final SharedPreferencesAsync prefs = SharedPreferencesAsync();
    return prefs.getString(_fcmTokenKey);
  }

  Future<void> showTestNotification() async {
    if (kIsWeb || !Platform.isAndroid) {
      _log.finest(() => 'showTestNotification skipped: not Android');
      return;
    }

    final FlutterLocalNotificationsPlugin plugin =
        _plugin ?? await _initNotificationsPlugin();

    await plugin.show(
      id: DateTime.now().millisecondsSinceEpoch,
      title: 'Prueba de Fireflytonic',
      body: 'Las notificaciones push están funcionando correctamente.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_notification',
        ),
      ),
      payload: 'push_test',
    );
    _log.info('Test notification shown');
  }
}
