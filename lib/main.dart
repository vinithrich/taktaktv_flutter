import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taktaktv/presentation/splash/screens/splash_screen.dart';

// 1. Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

// Global RouteObserver
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

// Global notification plugin instance
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }

  // Background message handler-ai register seivathu
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // --- Android Notification Channel Setup ---
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'taktaktv_drama_alerts',
    'TakTak Drama Alerts',
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
  );

  // Local notifications initialization settings for Android
  // Note: Notification icon-ku sariyaana drawable white icon name-ai inge kodungal
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@drawable/ic_notification');

  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  // Initialize plugin
  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings, // Illaiyendraal 'initSettings: initializationSettings'
    onDidReceiveNotificationResponse: (NotificationResponse details) {
      String? payload = details.payload;
      if (payload != null) {
        debugPrint('Notification payload: $payload');
      }
    },
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // --- FOREGROUND NOTIFICATION HANDLER ---
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      int notificationId = notification.hashCode;
      if (notificationId < 0) {
        notificationId = notificationId * -1;
      }

      flutterLocalNotificationsPlugin.show(
        id: notificationId,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
          ),
        ),
      );
    }
  });

  runApp(const StoryTvApp());
}

class StoryTvApp extends StatelessWidget {
  const StoryTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TAKTAK TV',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0710),
        primaryColor: const Color(0xFFE6007A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE6007A),
          surface: Color(0xFF140F1D),
        ),
        fontFamily: 'Roboto',
      ),
      navigatorObservers: [routeObserver],
      home: const SplashScreen(), // Splash screen handle pannum existing vs new user routing-ai!
    );
  }
}