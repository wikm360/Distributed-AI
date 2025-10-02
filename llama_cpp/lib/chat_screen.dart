// lib/chat_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Custom format for Qwen models
class QwenFormat extends PromptFormat {
  QwenFormat()
      : super(
          PromptFormatType.raw,
          inputSequence: '<|im_start|>user\n',
          outputSequence: '<|im_start|>assistant\n',
          systemSequence: '<|im_start|>system\n',
          stopSequence: '<|im_end|>',
        );
}

class ChatScreen extends StatefulWidget {
  final String libPath;
  final String modelPath;
  const ChatScreen({Key? key, required this.libPath, required this.modelPath}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late LlamaParent llamaParent;
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  bool _isTyping = false;
  bool _isGenerating = false;

  // Node ID management
  String? _nodeId;

  // Worker Timer
  Timer? _workerTimer;

  // Set of query numbers already answered
  final Set<int> _answeredQueries = <int>{};

  // Stream subscriptions for cancellation
  StreamSubscription? _currentStreamSub;
  StreamSubscription? _currentCompletionSub;

  // Routing server URL
  static const String routingServerUrl = "http://85.133.228.31:8313";

  @override
  void initState() {
    super.initState();
    _initializeNode();
    initModel();
  }

  // Initialize node and register with server
  Future<void> _initializeNode() async {
    final prefs = await SharedPreferences.getInstance();
    String? nodeId = prefs.getString('node_id');

    if (nodeId == null || nodeId.isEmpty) {
      // Register new node with server
      try {
        final response = await http.post(
          Uri.parse('$routingServerUrl/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'node_capabilities': {},
            'node_info': {'platform': 'flutter'}
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          nodeId = data['node_id'];
          await prefs.setString('node_id', nodeId!);
          print("[INFO] ✅ Node registered: $nodeId");
        }
      } catch (e) {
        print("[ERROR] ❌ Node registration failed: $e");
        // Generate local node ID as fallback
        nodeId = 'flutter_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString('node_id', nodeId);
      }
    }

    setState(() {
      _nodeId = nodeId;
    });

    // Start background worker after node is initialized
    if (_nodeId != null) {
      startBackgroundWorker();
    }
  }

  Future<void> initModel() async {
    try {
      Llama.libraryPath = widget.libPath;

      final contextParams = ContextParams()
        ..nCtx = 4096
        ..nBatch = 512
        ..nThreads = 8
        ..nPredict = 128;

      final samplerParams = SamplerParams()
        ..temp = 0.6
        ..topP = 0.9
        ..topK = 50;

      final loadCommand = LlamaLoad(
        path: widget.modelPath,
        modelParams: ModelParams(),
        contextParams: contextParams,
        samplingParams: samplerParams,
        format: QwenFormat(),
      );

      llamaParent = LlamaParent(loadCommand);
      await llamaParent.init();

      int attempts = 0;
      while (llamaParent.status != LlamaStatus.ready && attempts < 30) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
      }

      if (llamaParent.status != LlamaStatus.ready) {
        addSystemMessage("❌ Model failed to load.");
        return;
      }

      print("[INFO] ✅ Model loaded successfully.");
    } catch (e) {
      addSystemMessage("❌ Model initialization error: $e");
      print("[ERROR] ❌ initModel: $e");
    }
  }

  void addSystemMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(text: text, isFromUser: false));
    });
  }

  // Start background worker – checks every 3 seconds
  void startBackgroundWorker() {
    _workerTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted || _nodeId == null) return;

      try {
        final response = await http.get(
          Uri.parse('$routingServerUrl/request'),
          headers: {'x-node-id': _nodeId!},
        );
        
        if (response.statusCode == 200) {
          final List<dynamic> queries = jsonDecode(response.body);
          if (queries.isEmpty) return;

          for (var queryData in queries) {
            final String query = queryData['query'];
            final int queryNumber = queryData['query_number'];

            if (_answeredQueries.contains(queryNumber)) continue;

            print("[Worker] 🚀 پردازش کوئری $queryNumber: ${query.substring(0, query.length < 50 ? query.length : 50)}...");

            // علامت‌گذاری پاسخ داده شده
            _answeredQueries.add(queryNumber);

            try {
              final prompt = '''
<|im_start|>system
You are a helpful, concise AI assistant. Answer shortly and directly.<|im_end|>
<|im_start|>user
$query<|im_end|>
<|im_start|>assistant
''';

              final StringBuffer buffer = StringBuffer();
              StreamSubscription? streamSub;
              StreamSubscription? completionSub;

              streamSub = llamaParent.stream.listen(
                (token) {
                  buffer.write(token);
                  print("[Worker Token] $token");
                },
                onError: (e) => print("[Worker] ❌ استریم خطا داد: $e"),
              );

              completionSub = llamaParent.completions.listen((event) async {
                if (event.success) {
                  final answer = buffer.toString().trim();
                  final success = await sendResponseToServer(queryNumber, answer);
                  if (success) {
                    print("[Worker] ✅ پاسخ برای کوئری $queryNumber ارسال شد.");
                  }
                } else {
                  print("[Worker] ❌ تولید پاسخ ناموفق بود.");
                }
                await streamSub?.cancel();
                await completionSub?.cancel();
              });

              await llamaParent.sendPrompt(prompt);
            } catch (e) {
              print("[Worker] ❌ خطای پردازش: $e");
              _answeredQueries.remove(queryNumber);
            }
          }
        }
      } catch (e) {
        // سرور در دسترس نیست
      }
    });
  }

  // Send response to server
  Future<bool> sendResponseToServer(int queryNumber, String answer) async {
    if (_nodeId == null) return false;
    
    print("[Worker] 📤 Sending response to server for query $queryNumber");
    try {
      final response = await http.post(
        Uri.parse('$routingServerUrl/response'),
        headers: {
          'Content-Type': 'application/json',
          'x-node-id': _nodeId!,
        },
        body: jsonEncode({
          "query_number": queryNumber,
          "response": answer,
        }),
      );

      if (response.statusCode == 200) {
        print("[Worker] ✅ Response sent: $queryNumber");
        return true;
      } else {
        print("[Worker] ❌ Failed to send: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      print("[Worker] ❌ Send error: $e");
      return false;
    }
  }

  // Stop current generation
  void _stopGeneration() {
    print("[User] 🛑 Stopping generation...");
    
    _currentStreamSub?.cancel();
    _currentCompletionSub?.cancel();
    
    setState(() {
      _isTyping = false;
      _isGenerating = false;
      if (_messages.isNotEmpty && !_messages.last.isFromUser) {
        _messages.last.text += "\n\n⏹️ متوقف شد";
      }
    });
  }

  // User sends message
  void _sendMessage(String text) async {
    final input = text.trim();
    if (input.isEmpty || _isTyping) return;

    setState(() {
      _messages.add(ChatMessage(text: input, isFromUser: true));
      _isTyping = true;
      _isGenerating = true;
      _messages.add(ChatMessage(text: "", isFromUser: false));
    });
    _controller.clear();

    // کنسل کردن subscription‌های قبلی در صورت وجود
    await _currentStreamSub?.cancel();
    await _currentCompletionSub?.cancel();

    // استریم برای نمایش توکن به توکن در UI
    _currentStreamSub = llamaParent.stream.listen(
      (token) {
        if (!mounted) return;
        print("[Token] $token"); // پرینت هر توکن
        setState(() {
          if (_isTyping && _messages.isNotEmpty) {
            _messages.last.text += token;
          }
        });
      },
      onError: (e) {
        if (!mounted) return;
        print("[Error] ❌ Stream error: $e");
        setState(() {
          _messages.last.text += "\n\n❌ خطای مدل: $e";
          _isTyping = false;
          _isGenerating = false;
        });
      },
      onDone: () {
        print("[Stream] ✅ Stream completed");
      },
    );

    try {
      // سعی در حالت شبکه
      final queryNumber = await submitQuery(input);
      if (queryNumber == null) {
        // فیل‌بک به آفلاین
        print("[User] 🌐 سرور در دسترس نیست، حالت آفلاین فعال شد...");

        final prompt = '''
<|im_start|>system
You are a helpful, concise AI assistant. Answer shortly and directly.<|im_end|>
<|im_start|>user
$input<|im_end|>
<|im_start|>assistant
''';

        await llamaParent.sendPrompt(prompt);
      } else {
        print("[User] ✅ درخواست ارسال شد، query_number: $queryNumber");

        final workerResponses = await waitForWorkerResponses(queryNumber);
        print("[User] 📥 ${workerResponses.length} پاسخ از دیگر نودها دریافت شد");

        final finalPrompt = buildFinalPrompt(input, workerResponses);
        print("[User] 📝 پرامپت نهایی آماده است.");

        await llamaParent.sendPrompt(finalPrompt);

        await cleanupQuery(queryNumber);
      }
    } catch (e) {
      print("[User] ❌ خطای کلی: $e");
      final prompt = '''
<|im_start|>system
You are a helpful assistant.<|im_end|>
<|im_start|>user
$input<|im_end|>
<|im_start|>assistant
''';
      await llamaParent.sendPrompt(prompt);
    }

    // شنوننده برای پایان تولید - با onDone
    _currentCompletionSub = llamaParent.completions.listen(
      (event) {
        if (!mounted) return;
        
        print("[Completion] Event received - Success: ${event.success}");
        
        if (event.success) {
          print("[Completion] ✅ Generation completed successfully");
          if (mounted) {
            setState(() {
              _isTyping = false;
              _isGenerating = false;
            });
          }
        } else {
          print("[Completion] ❌ Generation failed");
          if (mounted) {
            setState(() {
              _messages.last.text += "\n\n❌ تولید پاسخ ناموفق بود.";
              _isTyping = false;
              _isGenerating = false;
            });
          }
        }
      },
      onError: (e) {
        print("[Completion] ❌ Completion error: $e");
        if (mounted) {
          setState(() {
            _isTyping = false;
            _isGenerating = false;
          });
        }
      },
      onDone: () {
        print("[Completion] ✅ Completion stream done");
        if (mounted) {
          setState(() {
            _isTyping = false;
            _isGenerating = false;
          });
        }
        _currentStreamSub?.cancel();
        _currentCompletionSub?.cancel();
      },
    );
  }

  // Submit query to server
  Future<int?> submitQuery(String query) async {
    if (_nodeId == null) return null;
    
    try {
      final response = await http.post(
        Uri.parse('$routingServerUrl/query'),
        headers: {
          'Content-Type': 'application/json',
          'x-node-id': _nodeId!,
        },
        body: jsonEncode({'query': query}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['query_number'];
        print("[User] ✅ query_number received: $result");
        return result;
      } else {
        print("[User] ❌ Query submission failed: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("[User] ❌ Connection error: $e");
      return null;
    }
  }

  // Wait for responses from other nodes
  Future<List<String>> waitForWorkerResponses(int queryNumber) async {
    if (_nodeId == null) return [];
    
    const maxWait = 25;
    int elapsed = 0;

    while (elapsed < maxWait) {
      try {
        final response = await http.get(
          Uri.parse('$routingServerUrl/response?query_number=$queryNumber'),
          headers: {'x-node-id': _nodeId!},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is List && data.isNotEmpty) {
            final converted = data.map((e) => e.toString()).toList();
            print("[User] ✅ تعداد پاسخ‌های دریافتی: ${converted.length}");
            print("=" * 60);
            for (int i = 0; i < converted.length; i++) {
              print("[Response ${i + 1}] ${converted[i]}");
              print("-" * 60);
            }
            print("=" * 60);
            return converted;
          }
        }
      } catch (e) {
        print("[User] ❌ Error fetching responses: $e");
      }

      await Future.delayed(const Duration(seconds: 1));
      elapsed++;
    }

    print("[User] ⏳ Timeout waiting for responses.");
    return [];
  }

  // Build final prompt
  String buildFinalPrompt(String userQuery, List<String> workerResponses) {
    if (workerResponses.isEmpty) {
      return '''
<|im_start|>system
You are a helpful AI assistant.<|im_end|>
<|im_start|>user
$userQuery<|im_end|>
<|im_start|>assistant
''';
    } else {
      final context = workerResponses.join('\n\n');
      return '''
<|im_start|>system
You are a helpful AI assistant. Answer based on the context from other nodes.<|im_end|>
<|im_start|>user
Context from other nodes:
$context

User Question: $userQuery<|im_end|>
<|im_start|>assistant
''';
    }
  }

  // Cleanup query
  Future<void> cleanupQuery(int queryNumber) async {
    if (_nodeId == null) return;
    
    try {
      await http.post(
        Uri.parse('$routingServerUrl/end'),
        headers: {
          'Content-Type': 'application/json',
          'x-node-id': _nodeId!,
        },
        body: jsonEncode({'query_number': queryNumber}),
      );
      print("[User] 🧹 Query $queryNumber cleaned up.");
    } catch (e) {
      print("[User] ❌ Cleanup error: $e");
    }
  }

  @override
  void dispose() {
    _workerTimer?.cancel();
    _currentStreamSub?.cancel();
    _currentCompletionSub?.cancel();
    _controller.dispose();
    llamaParent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI Assistant', style: TextStyle(fontSize: 18)),
            if (_nodeId != null)
              Text(
                'Node: ${_nodeId!.substring(0, 12)}...',
                style: const TextStyle(fontSize: 10, color: Colors.white60),
              ),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.grey[900],
        actions: [
          if (_isGenerating)
            IconButton(
              icon: const Icon(Icons.stop, color: Colors.red),
              onPressed: _stopGeneration,
              tooltip: 'توقف تولید',
            ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () {
              setState(() {
                _messages.clear();
              });
            },
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFF121212),
        child: Column(
          children: <Widget>[
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
            if (_isTyping)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                color: Colors.blueGrey[900],
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "در حال تولید پاسخ...",
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
              ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isFromUser;
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
            child: Text(
              message.text.isEmpty && !isUser ? "..." : message.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.5,
              ),
              textAlign: TextAlign.left,
              softWrap: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey[600]!, width: 1),
              ),
              child: TextField(
                controller: _controller,
                onSubmitted: _isTyping ? null : _sendMessage,
                enabled: !_isTyping,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'پیام خود را بنویسید...',
                  hintStyle: TextStyle(color: Colors.grey),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _isTyping ? null : () => _sendMessage(_controller.text),
            backgroundColor: _isTyping ? Colors.grey : Colors.blue,
            elevation: 2,
            mini: true,
            child: const Icon(Icons.send, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  String text;
  final bool isFromUser;
  ChatMessage({required this.text, required this.isFromUser});
}