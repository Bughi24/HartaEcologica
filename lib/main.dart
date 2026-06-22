import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'scan_page.dart';
import 'result_page.dart';
import 'map_page.dart';
import 'splash_page.dart';
import 'profile_page.dart';
import 'history_page.dart';
import 'leaderboard_page.dart';

// Handler pentru notificările primite când aplicația este închisă (Background)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Notificare de fundal primită: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inițializare baze de date locale și Cloud
  await Hive.initFlutter();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inițializare servicii notificări
  await NotificationService.initialize();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  runApp(const TrashSelectorApp());
}

class TrashSelectorApp extends StatefulWidget {
  const TrashSelectorApp({super.key});

  @override
  State<TrashSelectorApp> createState() => _TrashSelectorAppState();
}

class _TrashSelectorAppState extends State<TrashSelectorApp> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  
  // Variabilă pentru a preveni dublarea notificărilor
  String? _lastMessageId;

  @override
  void initState() {
    super.initState();
    _setupPushNotifications();
  }

  Future<void> _setupPushNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Cerem permisiunea pentru notificări (iOS/Android 13+)
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Ascultăm notificările primite în timp ce aplicația este deschisă (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (message.messageId == _lastMessageId) return; 
      _lastMessageId = message.messageId;

      if (message.notification != null) {
        debugPrint("Notificare primită: ${message.notification!.title}");

        // Afișăm un banner vizual în aplicație (SnackBar)
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('${message.notification!.title}: ${message.notification!.body}'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Declanșăm notificarea în bara de sistem a telefonului
        await NotificationService.showNotification(
          message.notification!.title ?? "Trash Selector",
          message.notification!.body ?? "",
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'Trash Selector',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      // Sistemul de pază pentru Autentificare
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Verificăm dacă conexiunea cu Firebase este activă
          if (snapshot.connectionState == ConnectionState.active) {
            User? user = snapshot.data;
            if (user == null) {
              return const LoginPage(); // Nu e logat
            }
            return const HomePage(); // Este logat
          }
          
          // Ecran de tranziție scurtă (Loading/Splash)
          return const SplashPage();
        },
      ),
      // Definirea rutelor pentru navigarea manuală
      routes: {
        '/splash': (context) => const SplashPage(),
        '/home': (context) => const HomePage(),
        '/scan': (context) => const ScanPage(),
        '/result': (context) => const ResultPage(),
        '/map': (context) => const MapPage(),
        '/login': (context) => const LoginPage(),
        '/profile': (context) => const ProfilePage(),
        '/history': (context) => const HistoryPage(),
        '/leaderboard': (context) => const LeaderboardPage(),
      },
    );
  }
}