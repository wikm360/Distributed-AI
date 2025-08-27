// chat_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/pigeon.g.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'models/model.dart';
import 'loading_widget.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key, 
    this.model = Model.gemma3_1B, 
    this.selectedBackend,
  });

  final Model model;
  final PreferredBackend? selectedBackend;

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final _gemma = FlutterGemmaPlugin.instance;
  InferenceChat? chat;
  final _messages = <Message>[];
  bool _isModelInitialized = false;
  bool _isStreaming = false;
  String? _error;

  // Background worker variables
  Timer? _workerTimer;
  final Set<int> _answeredQueries = <int>{};
  static const String routingServerUrl = "http://85.133.228.31:8313";

  // UI controller
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeModel();
    _startBackgroundWorker();
  }

  @override
  void dispose() {
    _workerTimer?.cancel();
    _controller.dispose();
    _gemma.modelManager.deleteModel();
    super.dispose();
  }

  Future<void> _initializeModel() async {
    try {
      if (!await _gemma.modelManager.isModelInstalled) {
        final path = kIsWeb
            ? widget.model.url
            : '${(await getApplicationDocumentsDirectory()).path}/${widget.model.filename}';
        await _gemma.modelManager.setModelPath(path);
      }

      final model = await _gemma.createModel(
        modelType: widget.model.modelType,
        preferredBackend: widget.selectedBackend ?? widget.model.preferredBackend,
        maxTokens: widget.model.maxTokens,
        supportImage: widget.model.supportImage,
        maxNumImages: widget.model.maxNumImages ?? 1,
      );

      chat = await model.createChat(
        temperature: widget.model.temperature,
        randomSeed: 1,
        topK: widget.model.topK,
        topP: widget.model.topP,
        tokenBuffer: 256,
        supportImage: widget.model.supportImage,
        supportsFunctionCalls: widget.model.supportsFunctionCalls,
        tools: [], // Empty tools for distributed mode
        isThinking: widget.model.isThinking,
        modelType: widget.model.modelType,
      );

      setState(() {
        _isModelInitialized = true;
      });

      print("[INFO] ✅ Flutter Gemma model loaded successfully.");
    } catch (e) {
      setState(() {
        _error = "Model initialization error: $e";
      });
      print("[ERROR] ❌ initModel: $e");
    }
  }

  // Background worker - checks for distributed queries
  void _startBackgroundWorker() {
    _workerTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) return;

      try {
        final response = await http.get(Uri.parse('$routingServerUrl/request'));
        if (response.statusCode == 200) {
          final List<dynamic> queries = jsonDecode(response.body);
          if (queries.isEmpty) return;

          for (var queryData in queries) {
            final String query = queryData['query'];
            final int queryNumber = queryData['query_number'];

            if (_answeredQueries.contains(queryNumber)) continue;

            print("[Worker] 🚀 پردازش کوئری $queryNumber: ${query.substring(0, 50)}...");
            _answeredQueries.add(queryNumber);

            try {
              final answer = await _generateDistributedResponse(query);
              final success = await _sendResponseToServer(queryNumber, answer);
              if (success) {
                print("[Worker] ✅ پاسخ برای کوئری $queryNumber ارسال شد.");
              }
            } catch (e) {
              print("[Worker] ❌ خطای پردازش: $e");
              _answeredQueries.remove(queryNumber);
            }
          }
        }
      } catch (e) {
        // Server not reachable - continue silently
      }
    });
  }

  // Generate response using Flutter Gemma for distributed queries
  Future<String> _generateDistributedResponse(String query) async {
    try {
      final tempMessage = Message.text(text: query, isUser: true);
      await chat!.addQuery(tempMessage);

      final StringBuffer buffer = StringBuffer();
      
      await for (final response in chat!.generateChatResponseAsync()) {
        if (response is TextResponse) {
          buffer.write(response.token);
        }
        // Skip other response types for distributed mode
      }

      final result = buffer.toString().trim();
      print("[Worker] 📝 Generated response: $result");
      return result.isEmpty ? "No response generated." : result;
    } catch (e) {
      print("[Worker] ❌ Error generating response: $e");
      return "Error: $e";
    }
  }

  // Send response to routing server
  Future<bool> _sendResponseToServer(int queryNumber, String answer) async {
    try {
      final response = await http.post(
        Uri.parse('$routingServerUrl/response'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "query_number": queryNumber,
          "response": answer,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("[Worker] ❌ Send error: $e");
      return false;
    }
  }

  // User sends message
  void _sendMessage(String text) async {
    final input = text.trim();
    if (input.isEmpty || _isStreaming || chat == null) return;

    setState(() {
      _messages.add(Message.text(text: input, isUser: true));
      _isStreaming = true;
      _messages.add(Message.text(text: "", isUser: false));
    });
    _controller.clear();

    try {
      // Try distributed approach first
      final queryNumber = await _submitQuery(input);
      
      if (queryNumber != null) {
        // Distributed mode
        print("[User] ✅ درخواست ارسال شد، query_number: $queryNumber");
        
        final workerResponses = await _waitForWorkerResponses(queryNumber);
        print("[User] 📥 ${workerResponses.length} پاسخ از دیگر نودها دریافت شد");

        // Combine responses and generate final answer
        final finalResponse = await _generateFinalResponse(input, workerResponses);
        
        setState(() {
          _messages.last = Message.text(text: finalResponse, isUser: false);
          _isStreaming = false;
        });

        await _cleanupQuery(queryNumber);
      } else {
        // Fallback to local mode
        print("[User] 🌐 سرور در دسترس نیست، حالت آفلاین فعال شد...");
        
        await chat!.addQuery(Message.text(text: input, isUser: true));
        
        final StringBuffer buffer = StringBuffer();
        await for (final response in chat!.generateChatResponseAsync()) {
          if (response is TextResponse) {
            buffer.write(response.token);
            setState(() {
              _messages.last = Message.text(text: buffer.toString(), isUser: false);
            });
          }
        }
        
        setState(() {
          _isStreaming = false;
        });
      }
    } catch (e) {
      print("[User] ❌ خطای کلی: $e");
      setState(() {
        _messages.last = Message.text(text: "Error: $e", isUser: false);
        _isStreaming = false;
      });
    }
  }

  // Submit query to routing server
  Future<int?> _submitQuery(String query) async {
    try {
      final response = await http.post(
        Uri.parse('$routingServerUrl/query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query}),
      );

      if (response.statusCode == 200) {
        return int.tryParse(response.body.trim());
      }
    } catch (e) {
      print("[User] ❌ Connection error: $e");
    }
    return null;
  }

  // Wait for responses from other nodes
  Future<List<String>> _waitForWorkerResponses(int queryNumber) async {
    const maxWait = 25;
    int elapsed = 0;

    while (elapsed < maxWait) {
      try {
        final response = await http.get(
          Uri.parse('$routingServerUrl/response?query_number=$queryNumber'),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is List && data.isNotEmpty) {
            return data.map((item) => item.toString()).toList();
          }
        }
      } catch (e) {
        print("[User] ❌ Error fetching responses: $e");
      }

      await Future.delayed(const Duration(seconds: 1));
      elapsed++;
    }

    print("[User] ⏳ Timeout waiting for worker responses.");
    return [];
  }

  // Generate final response combining worker responses
  Future<String> _generateFinalResponse(String userQuery, List<String> workerResponses) async {
    if (workerResponses.isEmpty) {
      return await _generateDistributedResponse(userQuery);
    }

    // Build context from worker responses
    final context = workerResponses.join('\n\n');
    
    final combinedQuery = '''
Based on these responses from other AI nodes:
$context

User's original question: $userQuery

Please provide a comprehensive answer that combines the best insights from the responses above.
''';

    return await _generateDistributedResponse(combinedQuery);
  }

  // Cleanup query on server
  Future<void> _cleanupQuery(int queryNumber) async {
    try {
      await http.post(
        Uri.parse('$routingServerUrl/end'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query_number': queryNumber}),
      );
    } catch (e) {
      print("[User] ❌ Cleanup error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text('${widget.model.displayName} - چت توزیع‌شده'),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () {
              setState(() {
                _messages.clear();
              });
            },
          ),
          // Connection status indicator
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Icon(
              Icons.circle,
              size: 12,
              color: _isModelInitialized ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
      body: _isModelInitialized
          ? Column(
              children: <Widget>[
                if (_error != null) _buildErrorBanner(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
                ),
                if (_isStreaming) _buildTypingIndicator(),
                _buildInputArea(),
              ],
            )
          : const LoadingWidget(message: 'بارگیری مدل...'),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      color: Colors.red,
      padding: const EdgeInsets.all(8.0),
      child: Text(
        _error!,
        style: const TextStyle(color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: Colors.blueGrey[900],
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "در حال ترکیب پاسخ‌ها...",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isUser = message.isUser;
    final color = isUser ? Colors.blue[600]! : Colors.grey[800]!;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: alignment,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: isUser ? Radius.circular(16) : Radius.circular(4),
                bottomRight: isUser ? Radius.circular(4) : Radius.circular(16),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display image if available
                if (message.hasImage) ...[
                  _buildImageWidget(message),
                  if (message.text.isNotEmpty) const SizedBox(height: 8),
                ],
                // Display text
                if (message.text.isNotEmpty)
                  Text(
                    message.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.left,
                    textDirection: TextDirection.ltr,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  )
                else if (!message.hasImage)
                  const Text(
                    "...",
                    style: TextStyle(color: Colors.white70),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageWidget(Message message) {
    return GestureDetector(
      onTap: () => _showImageDialog(message),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 250,
          maxHeight: 150,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            message.imageBytes!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 150,
                height: 100,
                color: Colors.grey[700],
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    SizedBox(height: 4),
                    Text(
                      'خطا در بارگیری تصویر',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showImageDialog(Message message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: Image.memory(
                    message.imageBytes!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: <Widget>[
          // Image picker button (if model supports images)
          if (widget.model.supportImage && !kIsWeb)
            IconButton(
              icon: const Icon(Icons.image, color: Colors.blue),
              onPressed: _isStreaming ? null : _pickImage,
              tooltip: 'افزودن تصویر',
            ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey[600]!, width: 1),
              ),
              child: TextField(
                controller: _controller,
                onSubmitted: _isStreaming ? null : _sendMessage,
                enabled: !_isStreaming,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  hintText: 'پیام خود را تایپ کنید...',
                  hintStyle: TextStyle(color: Colors.grey),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _isStreaming ? null : () => _sendMessage(_controller.text),
            backgroundColor: _isStreaming ? Colors.grey : Colors.blue,
            elevation: 2,
            mini: true,
            child: const Icon(Icons.send, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  // Image picker functionality
  Future<void> _pickImage() async {
    // Note: Image picking would require image_picker package
    // This is a placeholder for the image selection functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('انتخاب تصویر در حال حاضر پشتیبانی نمی‌شود'),
      ),
    );
  }
}