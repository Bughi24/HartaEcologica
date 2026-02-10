import 'package:flutter/material.dart';
import 'home_page.dart';
import 'scan_page.dart';
import 'result_page.dart';
import 'map_page.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const TrashSelectorApp());
}

class TrashSelectorApp extends StatelessWidget {
  const TrashSelectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Trash Selector',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => HomePage(),
        '/scan': (context) => ScanPage(),
        '/result': (context) => ResultPage(),
        '/map': (context) => MapPage(),
      },
    );
  }
}
