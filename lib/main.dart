import 'package:flutter/material.dart';
import 'home_page.dart';
import 'scan_page.dart';
import 'result_page.dart';
import 'map_page.dart';

void main() => runApp(TrashSelectorApp());

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
