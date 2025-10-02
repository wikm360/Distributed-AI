// main.dart - نقطه ورود برنامه
import 'package:flutter/material.dart';
import 'config.dart';
import 'frontend/screens/model_list_screen.dart';

void main() {
  runApp(const AIDistributedApp());
}

class AIDistributedApp extends StatelessWidget {
  const AIDistributedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Distributed AI Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppConfig.bgDark,
        cardColor: AppConfig.cardDark,
        primaryColor: AppConfig.primaryColor,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConfig.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: const SafeArea(child: ModelListScreen()),
    );
  }
}