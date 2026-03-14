import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // <-- NOU 1: Importul pentru FCM
import 'firebase_options.dart';

import 'home_page.dart';
import 'scan_page.dart';
import 'result_page.dart';
import 'map_page.dart';
import 'splash_page.dart';

// <-- NOU 2: Funcția de fundal (Trebuie să fie mereu sus, în afara claselor)
// Aici procesăm notificările primite când aplicația este complet închisă
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Asigură-te că Firebase este inițializat pentru procesul de fundal
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Notificare de fundal primită: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // <-- NOU 3: Înregistrăm funcția de fundal înainte să pornim aplicația
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const TrashSelectorApp());
}

// <-- NOU 4: Am transformat TrashSelectorApp în StatefulWidget
class TrashSelectorApp extends StatefulWidget {
  const TrashSelectorApp({super.key});

  @override
  State<TrashSelectorApp> createState() => _TrashSelectorAppState();
}

class _TrashSelectorAppState extends State<TrashSelectorApp> {
  // <-- NOU 5: Creăm o cheie globală pentru a putea afișa SnackBar-uri oriunde
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    // Pornim configurarea notificărilor imediat ce se deschide aplicația
    _setupPushNotifications();
  }

  // --- LOGICA PENTRU NOTIFICĂRI ---
  Future<void> _setupPushNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // 1. Cerem permisiunea utilizatorului (obligatoriu pe Android 13+ și iOS)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Utilizatorul a permis notificările!');
    } else {
      debugPrint('Utilizatorul a refuzat notificările.');
    }

    // 2. Ascultăm notificările care vin MENTRE aplicația este pe ecran (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('A venit o notificare în timp ce foloseam aplicația!');
      
      if (message.notification != null) {
        // Afișăm un banner verde deasupra paginii curente
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('${message.notification!.title}: ${message.notification!.body}', style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating, // Îl face să arate modern, ca un card plutitor
            margin: const EdgeInsets.all(10),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey, // <-- NOU 6: Am conectat cheia aici!
      debugShowCheckedModeBanner: false,
      title: 'Trash Selector',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashPage(),
        '/': (context) => HomePage(),
        '/scan': (context) => ScanPage(),
        '/result': (context) => ResultPage(),
        '/map': (context) => MapPage(),
      },
    );
  }
}