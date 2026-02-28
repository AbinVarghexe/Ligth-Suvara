import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // 1. Request permissions (for iOS, though handled automatically by FCM plugin on Android mostly, good practice)
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // 2. Initialize Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Note: iOS initialization would go here if needed
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    // 3. Configure FCM background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Configure FCM foreground handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint(
          'Message also contained a notification: ${message.notification}',
        );
        _showLocalNotification(message);
      }
    });

    // 5. Get Fcm Token (Optional - for debugging)
    String? token = await _firebaseMessaging.getToken();
    debugPrint("FCM Token: $token");

    // Subscribe to broadcasts with retry logic
    subscribeToBroadcastsWithRetry();
  }

  Future<void> subscribeToBroadcastsWithRetry() async {
    int attempts = 0;
    while (attempts < 3) {
      try {
        await _firebaseMessaging.subscribeToTopic('broadcasts');
        print("🔔 Subscribed to topic: broadcasts");
        debugPrint("Subscribed to topic: broadcasts");
        return;
      } catch (e) {
        attempts++;
        debugPrint("Failed to subscribe to broadcasts (attempt $attempts): $e");
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    debugPrint("Failed to subscribe to broadcasts after 3 attempts");
  }

  // --- NEW: Topic Subscription logic for specific users ---
  Future<void> subscribeToUserTopic(String userId) async {
    String topic = 'school_$userId';
    await _firebaseMessaging.subscribeToTopic(topic);
    debugPrint("Subscribed to topic: $topic");
  }

  Future<void> unsubscribeFromUserTopic(String userId) async {
    String topic = 'school_$userId';
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    debugPrint("Unsubscribed from topic: $topic");
  }

  Future<void> subscribeToRoleTopic(String role) async {
    String topic = 'role_$role';
    await _firebaseMessaging.subscribeToTopic(topic);
    debugPrint("Subscribed to role topic: $topic");
  }

  Future<void> unsubscribeFromRoleTopic(String role) async {
    String topic = 'role_$role';
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    debugPrint("Unsubscribed from role topic: $topic");
  }

  // Complete cleanup - unsubscribe from user and role topics explicitly
  // NOTE: We do NOT unsubscribe from 'broadcasts' anymore, as public notifications should persist.
  Future<void> unsubscribeAll(String userId, String? role) async {
    // Unsubscribe from user-specific topic
    await unsubscribeFromUserTopic(userId);

    // Unsubscribe from role topic if exists
    if (role != null && role.isNotEmpty) {
      await unsubscribeFromRoleTopic(role);
    }

    // REMOVED: await unsubscribeFromBroadcasts();
    // Broadcasts should remain subscribed even after logout.

    debugPrint(
      "Complete topic cleanup completed for user: $userId (Broadcasts persisted)",
    );
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    String? imageUrl = message.data['imageUrl'] ?? android?.imageUrl;
    BigPictureStyleInformation? bigPictureStyleInformation;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final String largeIconPath = await _downloadAndSaveFile(
          imageUrl,
          'largeIcon',
        );
        final String bigPicturePath = await _downloadAndSaveFile(
          imageUrl,
          'bigPicture',
        );

        bigPictureStyleInformation = BigPictureStyleInformation(
          FilePathAndroidBitmap(bigPicturePath),
          largeIcon: FilePathAndroidBitmap(largeIconPath),
          contentTitle: notification?.title,
          summaryText: notification?.body,
        );
      } catch (e) {
        debugPrint('Error downloading notification image: $e');
      }
    }

    if (notification != null && android != null) {
      await _flutterLocalNotificationsPlugin.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', // id
            'High Importance Notifications', // title
            channelDescription:
                'This channel is used for important notifications.',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            styleInformation: bigPictureStyleInformation,
          ),
        ),
        payload: message.data.toString(),
      );
    }
  }

  Future<String> _downloadAndSaveFile(String url, String fileName) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName';
    final http.Response response = await http.get(Uri.parse(url));
    final File file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }
}

// Top-level function for background handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you need to access Firestore or other Firebase services here, you must call Firebase.initializeApp()
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}
