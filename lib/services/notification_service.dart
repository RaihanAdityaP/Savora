import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/supabase_client.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  RealtimeChannel? _notificationChannel;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('NotificationService already initialized');
      return;
    }

    // Skip initialization for web platform
    if (kIsWeb) {
      debugPrint('Web platform detected — skipping notification initialization.');
      _isInitialized = true;
      return;
    }

    try {
      debugPrint('Starting NotificationService initialization...');

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
      );

      final bool? initialized = await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      debugPrint('Plugin initialization result: $initialized');

      await _requestPermission();
      await _createNotificationChannel();

      _isInitialized = true;
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
      _isInitialized = true;
    }
  }

  /// Create Android notification channel (CRITICAL for Android 8.0+)
  Future<void> _createNotificationChannel() async {
    if (kIsWeb) return;

    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'savora_channel',
        'Savora Notifications',
        description: 'Notifikasi dari aplikasi Savora',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        showBadge: true,
      );

      final androidImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(channel);
        debugPrint('Notification channel created: ${channel.id}');
      } else {
        debugPrint('Android implementation is NULL');
      }
    } catch (e) {
      debugPrint('Error creating notification channel: $e');
    }
  }

  /// Request notification permission (Android 13+)
  Future<void> _requestPermission() async {
    if (kIsWeb) return;

    try {
      final androidImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final bool? granted =
            await androidImplementation.requestNotificationsPermission();
        debugPrint('Notification permission granted: $granted');
        
        if (granted == false) {
          debugPrint('Permission denied. Notifications will not work.');
        }
      } else {
        debugPrint('Cannot request permission - Android implementation is NULL');
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    final String? payload = response.payload;

    if (payload != null) {
      debugPrint('Notification tapped with payload: $payload');
    }
  }

  /// Show local notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    debugPrint('Attempting to show notification: $title');

    if (kIsWeb) {
      debugPrint('Web platform — notification skipped.');
      return;
    }

    if (!_isInitialized) {
      debugPrint('NotificationService not initialized. Attempting to initialize...');
      await initialize();
    }

    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'savora_channel',
        'Savora Notifications',
        channelDescription: 'Notifikasi dari aplikasi Savora',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFFFF6B6B),
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(
          '',
          htmlFormatBigText: false,
          contentTitle: '',
          htmlFormatContentTitle: false,
          summaryText: 'Savora',
          htmlFormatSummaryText: false,
        ),
        ticker: 'Savora Notification',
        channelShowBadge: true,
        autoCancel: true,
        ongoing: false,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      final int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      debugPrint('Notification shown successfully');
    } catch (e, stackTrace) {
      debugPrint('Error showing notification: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Setup Supabase realtime listener for notifications
  void setupRealtimeListener(String userId) {
    debugPrint('Setting up realtime listener for user: $userId');

    _notificationChannel?.unsubscribe();

    try {
      _notificationChannel = supabase
          .channel('notifications_realtime_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              debugPrint('New notification received from database');

              final newRecord = payload.newRecord;

              showNotification(
                title: newRecord['title'] ?? 'Savora',
                body: newRecord['message'] ?? '',
                payload: _generatePayload(
                  newRecord['type'],
                  newRecord['related_entity_id'],
                ),
              );
            },
          )
          .subscribe();

      debugPrint('Realtime notification listener active');
    } catch (e) {
      debugPrint('Error setting up realtime listener: $e');
    }
  }

  /// Generate payload for navigation
  String? _generatePayload(String? type, String? entityId) {
    if (type == null || entityId == null) return null;

    if ([
      'new_recipe_from_following',
      'recipe_approved',
      'recipe_rejected'
    ].contains(type)) {
      return 'recipe:$entityId';
    } else if (type == 'new_follower') {
      return 'follower:$entityId';
    }

    return null;
  }

  /// Check if notification service is initialized
  bool get isInitialized => _isInitialized;

  /// Dispose realtime listener
  void dispose() {
    try {
      _notificationChannel?.unsubscribe();
      _notificationChannel = null;
      debugPrint('Notification service disposed');
    } catch (e) {
      debugPrint('Error disposing notification service: $e');
    }
  }
}