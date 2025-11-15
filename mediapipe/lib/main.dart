// main.dart - نقطه ورود برنامه
import 'package:flutter/material.dart';
import 'config.dart';
import 'frontend/screens/model_list_screen.dart';
import 'rag/rag_manager.dart';
import 'rag/embedding_service.dart';
import 'network/rag_worker.dart';
import 'network/routing_client.dart';
import 'shared/logger.dart';

// Global RAG instances for access across the app
late final RAGManager ragManager;
RAGWorker? ragWorker;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize RAG system
  Log.i('Initializing RAG system...', 'Main');

  final embeddingService = EmbeddingService();
  ragManager = RAGManager(embeddingService);

  // Initialize ObjectBox
  final objectBoxInitialized = await ragManager.initialize();
  if (objectBoxInitialized) {
    Log.s('ObjectBox initialized successfully', 'Main');

    // Try to auto-load embedding model if available
    final modelLoaded = await ragManager.autoLoadEmbeddingModel();
    if (modelLoaded) {
      Log.s('Embedding model loaded successfully', 'Main');

      // Start RAG Worker in background
      try {
        final client = RoutingClient(AppConfig.routingServerUrl);
        ragWorker = RAGWorker(ragManager, client);
        await ragWorker!.start();
        Log.s('RAG Worker started in background', 'Main');
      } catch (e) {
        Log.w('Failed to start RAG Worker: $e', 'Main');
        ragWorker = null;
      }
    } else {
      Log.i('No embedding model found, RAG Worker not started', 'Main');
      ragWorker = null;
    }
  } else {
    Log.e('Failed to initialize ObjectBox', 'Main');
    ragWorker = null;
  }

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