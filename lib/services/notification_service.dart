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
    if (_isInitialized) return;

    // Skip initialization for web platform
    if (kIsWeb) {
      debugPrint('🌐 Web platform detected — skipping notification initialization.');
      _isInitialized = true;
      return;
    }

    try {
      // Android Initialization Settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
      );

      // Initialize plugin
      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Request permission for Android 13+
      await _requestPermission();

      _isInitialized = true;
      debugPrint('✅ NotificationService initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing NotificationService: $e');
      // Set as initialized even on error to prevent repeated initialization attempts
      _isInitialized = true;
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
        debugPrint('✅ Notification permission granted: $granted');
      }
    } catch (e) {
      debugPrint('❌ Error requesting notification permission: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    final String? payload = response.payload;

    if (payload != null) {
      debugPrint('🎯 Notification tapped with payload: $payload');
      // Payload format: "type:id" 
      // Example: "recipe:123" or "follower:user-id"
      // Navigation will be handled in main.dart or via external callback
    }
  }

  /// Show local notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // Skip for web platform
    if (kIsWeb) {
      debugPrint('🌐 Web platform — notification skipped.');
      return;
    }

    if (!_isInitialized) {
      debugPrint('⚠️ NotificationService not initialized. Attempting to initialize...');
      await initialize();
    }

    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'savora_channel', // Channel ID
        'Savora Notifications', // Channel Name
        channelDescription: 'Notifikasi dari aplikasi Savora',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFFD4AF37), // Golden color
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      // Generate unique notification ID
      final int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      debugPrint('📱 Local notification shown: $title');
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
    }
  }

  /// Setup Supabase realtime listener for notifications
  void setupRealtimeListener(String userId) {
    // Unsubscribe existing channel if any
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
              final newRecord = payload.newRecord;

              // Show local notification when new notification is received
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

      debugPrint('🔔 Realtime notification listener active for user: $userId');
    } catch (e) {
      debugPrint('❌ Error setting up realtime listener: $e');
    }
  }

  /// Generate payload for navigation
  String? _generatePayload(String? type, String? entityId) {
    if (type == null || entityId == null) return null;

    // Map notification type to navigation payload
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
      debugPrint('🔕 Notification service disposed');
    } catch (e) {
      debugPrint('❌ Error disposing notification service: $e');
    }
  }
}