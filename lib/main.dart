import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'timeline/controller/timeline_controller.dart';
import 'theme.dart';
import 'screens/home_screen.dart';

// Your clubs imports
import 'package:nimbus_2k26_frontend/departmental_clubs_page.dart';
import 'core_clubs_page.dart';

import 'events_page.dart'; // make sure file name matches
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => TimelineController(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
       theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xffF5F6FA), // ✅ light UI
        primaryColor: Colors.blue,
        useMaterial3: true,
      ),

      home: const HomeScreen(),
    );
  }
}
