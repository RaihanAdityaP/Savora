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

    // Request permission (Android 13+)
    await _requestPermission();

    _isInitialized = true;
    debugPrint('✅ NotificationService initialized');
  }

  /// Request notification permission (Android 13+)
  Future<void> _requestPermission() async {
    final androidImplementation = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final bool? granted = await androidImplementation.requestNotificationsPermission();
      debugPrint('✅ Notification permission granted: $granted');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    final String? payload = response.payload;
    
    if (payload != null) {
      debugPrint('🎯 Notification tapped with payload: $payload');
      
      // Payload akan dihandle di main.dart melalui navigator
      // Format: "type:id" contoh: "recipe:123" atau "follower:user-id"
    }
  }

  /// Show local notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'savora_channel', // Channel ID
      'Savora Notifications', // Channel Name
      channelDescription: 'Notifikasi dari aplikasi Savora',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFD4AF37), // Warna golden
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000), // Unique ID
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    debugPrint('📱 Notification shown: $title - $body');
  }

  /// Setup realtime listener untuk notifikasi dari Supabase
  void setupRealtimeListener(String userId) {
    _notificationChannel?.unsubscribe();

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
            
            // Show local notification
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

    debugPrint('🔔 Realtime notification listener setup for user: $userId');
  }

  /// Generate payload for navigation
  String? _generatePayload(String? type, String? entityId) {
    if (type == null || entityId == null) return null;
    
    if (type == 'new_recipe_from_following' || 
        type == 'recipe_approved' || 
        type == 'recipe_rejected') {
      return 'recipe:$entityId';
    } else if (type == 'new_follower') {
      return 'follower:$entityId';
    }
    
    return null;
  }

  /// Dispose listener
  void dispose() {
    _notificationChannel?.unsubscribe();
    _notificationChannel = null;
  }
}