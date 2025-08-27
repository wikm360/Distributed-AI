// main.dart
import 'package:flutter/material.dart';
import 'model_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Distributed AI Chat',
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Color(0xFF121212),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      themeMode: ThemeMode.dark,
      home: const SafeArea(child: ModelSelectionScreen()),
    );
  }
}