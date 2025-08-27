// main.dart
import 'package:flutter/material.dart';
import 'setup_screen.dart'; // فقط SetupScreen باید اول نمایش داده شود

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local ChatBot',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Color(0xFF121212),
      ),
      home: SetupScreen(), // اولین صفحه
    );
  }
}