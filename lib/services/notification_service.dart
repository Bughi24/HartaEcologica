import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    // Cerere permisiuni pentru Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint("Utilizatorul a apăsat pe notificare");
      },
    );
    debugPrint("NotificationService Initialized");
  }

  static Future<void> showNotification(String title, String body) async {
    debugPrint("Încerc să afișez notificarea: $title");

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'scan_results_channel_v3', 
      'Rezultate Scanare AI', 
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    try {
      await _notificationsPlugin.show(
        DateTime.now().millisecond, 
        title,
        body,
        platformChannelSpecifics,
      );
      debugPrint("Notificare trimisă cu succes la sistem");
    } catch (e) {
      debugPrint("Eroare la showNotification: $e");
    }
  }
}