// main.dart - نسخه تصحیح شده
import 'package:flutter/material.dart';
import 'core/services/backend_factory.dart';
import 'ui/screens/modernized_model_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize backend factory
  BackendFactory.initialize();
  
  runApp(const ModernizedChatApp());
}

class ModernizedChatApp extends StatelessWidget {
  const ModernizedChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Distributed AI Chat v2',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: Colors.grey[850],
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      themeMode: ThemeMode.dark,
      // حذف home و استفاده از initialRoute
      initialRoute: '/',
      routes: {
        '/': (context) => const SafeArea(child: ModernizedModelSelectionScreen()),
      },
    );
  }
}