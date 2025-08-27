// lib/chat_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:http/http.dart' as http;

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

  // 🔁 Worker Timer
  late Timer _workerTimer;

  // ✅ Set of query numbers already answered
  final Set<int> _answeredQueries = <int>{};

  // 📡 Routing server URL
  static const String routingServerUrl = "http://85.133.228.31:8313";

  @override
  void initState() {
    super.initState();
    initModel();
    startBackgroundWorker();
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
        // format: ChatMLFormat(),
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

      // ✅ Global listener for completions
      llamaParent.completions.listen((event) {
        if (event.success) {
          print("[INFO] ✅ Response generation completed successfully.");
        } else {
          print("[ERROR] ❌ Response generation failed: ${event.promptId}");
        }
      });
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

  // ✅ Start background worker — checks every 3 seconds
  void startBackgroundWorker() {
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

            // ✅ علامت زدن پاسخ داده شده
            _answeredQueries.add(queryNumber);

            try {
              final prompt = '''
<|im_start|>system
You are a helpful, concise AI assistant. Answer shortly and directly.<|im_end|>
<|im_start|>user
$query<|im_end|>
<|im_start|>assistant
  ''';
// <start_of_turn>user
// You are a helpful, concise assistant. Please answer the following query:
// $query<end_of_turn>
// <start_of_turn>model

              // ✅ استریم برای دیباگ در ترمینال
              final StringBuffer buffer = StringBuffer();
              late StreamSubscription completionSub;

              final streamSub = llamaParent.stream.listen(
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
                await streamSub.cancel();
                await completionSub.cancel();
              });

              await llamaParent.sendPrompt(prompt);
            } catch (e) {
              print("[Worker] ❌ خطای پردازش: $e");
              _answeredQueries.remove(queryNumber);
            }
          }
        }
      } catch (e) {
        // سرور در دسترس نیست — فقط ادامه بده
      }
    });
  }

  // ✅ Generate local response using Completer
// ✅ تغییر: اضافه کردن useTimeout
Future<String> generateLocalResponse(String query, {bool useTimeout = true}) async {
  print("[Worker] 🧠 Starting local response generation for: $query ${useTimeout ? '(with timeout)' : '(no timeout)'}");

  final completer = Completer<String>();
  final StringBuffer buffer = StringBuffer();

  final streamSub = llamaParent.stream.listen(
    (token) {
      buffer.write(token);
      print("[Worker Token] $token");
    },
    onError: (e) {
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    },
  );

  final completionSub = llamaParent.completions.listen(
    (event) {
      if (event.success && !completer.isCompleted) {
        completer.complete(buffer.toString().trim());
      } else if (!completer.isCompleted) {
        completer.completeError("Response generation failed.");
      }
    },
    onError: (e) {
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    },
  );

  try {
    final prompt = '''
<|im_start|>system
You are a helpful, concise AI assistant. Answer shortly and directly.<|im_end|>
<|im_start|>user
$query<|im_end|>
<|im_start|>assistant
''';

// <start_of_turn>user
// You are a helpful, concise assistant. Please answer the following query:
// $query<end_of_turn>
// <start_of_turn>model

    print("[Worker] 📤 Sending prompt to model...");
    await llamaParent.sendPrompt(prompt);

    // ✅ فقط اگر useTimeout=true باشد، تایم‌اوت اعمال شود
    final result = useTimeout
        ? await completer.future.timeout(
            const Duration(seconds: 30),
            onTimeout: () => "❌ Response timed out.",
          )
        : await completer.future; // بدون تایم‌اوت

    await streamSub.cancel();
    await completionSub.cancel();

    print("[Worker] 📝 Final response: $result");
    return result;
  } catch (e) {
    print("[Worker] ❌ Error generating response: $e");
    await streamSub.cancel();
    await completionSub.cancel();
    return "Error: $e";
  }
}

  // Send response to server
  Future<bool> sendResponseToServer(int queryNumber, String answer) async {
    print("[Worker] 📤 Sending response to server for query $queryNumber");
    try {
      final response = await http.post(
        Uri.parse('$routingServerUrl/response'),
        headers: {'Content-Type': 'application/json'},
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

  // User sends message
  void _sendMessage(String text) async {
    final input = text.trim();
    if (input.isEmpty || _isTyping) return;

    setState(() {
      _messages.add(ChatMessage(text: input, isFromUser: true));
      _isTyping = true;
      _messages.add(ChatMessage(text: "", isFromUser: false));
    });
    _controller.clear();

    // ✅ استریم برای نمایش توکن به توکن در UI
    final subscription = llamaParent.stream.listen(
      (token) {
        if (!mounted) return;
        setState(() {
          if (_isTyping && _messages.isNotEmpty) {
            _messages.last.text += token;
          }
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _messages.last.text += "\n\n❌ خطای مدل: $e";
          _isTyping = false;
        });
      },
    );

    try {
      // 🔁 سعی در حالت شبکه
      final queryNumber = await submitQuery(input);
      if (queryNumber == null) {
        // 🔽 فیل‌بک به آفلاین — بدون تایم‌اوت، اما با استریم
        print("[User] 🌐 سرور در دسترس نیست، حالت آفلاین فعال شد...");

        final prompt = '''
<|im_start|>system
You are a helpful, concise AI assistant. Answer shortly and directly.<|im_end|>
<|im_start|>user
$input<|im_end|>
<|im_start|>assistant
  ''';

// <start_of_turn>user
// You are a helpful, concise assistant. Please answer the following query:
// $input<end_of_turn>
// <start_of_turn>model

        await llamaParent.sendPrompt(prompt);
        return; // منتظر می‌مانیم تا `completions` یا `stream` کار کند
      }

      print("[User] ✅ درخواست ارسال شد، query_number: $queryNumber");

      final workerResponses = await waitForWorkerResponses(queryNumber);
      print("[User] 📥 ${workerResponses.length} پاسخ از دیگر نودها دریافت شد");

      final finalPrompt = buildFinalPrompt(input, workerResponses);
      print("[User] 📝 پرامت نهایی آماده است.");

      await llamaParent.sendPrompt(finalPrompt);

      await cleanupQuery(queryNumber);
    } catch (e) {
      print("[User] ❌ خطای کلی: $e");
      // اگر حتی این هم خطا داد، دوباره فیل‌بک
      final prompt = '''
  <|im_start|>system
  You are a helpful assistant.<|im_end|>
  <|im_start|>user
  $input<|im_end|>
  <|im_start|>assistant
  ''';
//   <start_of_turn>user
// You are a helpful, concise assistant. Please answer the following query:
// $input<end_of_turn>
// <start_of_turn>model
      await llamaParent.sendPrompt(prompt);
    }

    // ✅ شنونده برای پایان تولید — فقط یک بار
    late StreamSubscription completionSub;
    completionSub = llamaParent.completions.listen((event) {
      if (!mounted) return;
      if (event.success) {
        setState(() {
          _isTyping = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _messages.last.text += "\n\n❌ تولید پاسخ ناموفق بود.";
            _isTyping = false;
          });
        }
      }
      subscription.cancel();
      completionSub.cancel();
    });
  }

  // Submit query to server
  Future<int?> submitQuery(String query) async {
    try {
      final response = await http.post(
        Uri.parse('$routingServerUrl/query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query}),
      );

      if (response.statusCode == 200) {
        final result = int.tryParse(response.body.trim());
        print("[User] ✅ query_number received: $result");
        return result;
      } else {
        print("[User] ❌ Query submission failed: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      print("[User] ❌ Connection error (server unreachable): $e");
      return null; // Triggers fallback
    }
  }

  // Wait for responses from other nodes
Future<List<List<String>>> waitForWorkerResponses(int queryNumber) async {
  final List<List<String>> responses = [];
  const maxWait = 30; // 25 seconds timeout
  int elapsed = 0;

  while (elapsed < maxWait) {
    try {
      final response = await http.get(
        Uri.parse('$routingServerUrl/response?query_number=$queryNumber'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          final converted = <List<String>>[];
          for (var item in data) {
            if (item is List) {
              converted.add(item.map((e) => e.toString()).toList());
            }
          }
          print("[User] ✅ Received responses: $converted");
          return converted;
        }
      }
    } catch (e) {
      print("[User] ❌ Error fetching responses: $e");
    }

    await Future.delayed(const Duration(seconds: 1));
    elapsed++;
  }

  print("[User] ⏳ Timeout waiting for worker responses.");
  return responses; // خالی برمی‌گرداند
}

  // Build final prompt
  String buildFinalPrompt(String userQuery, List<List<String>> workerResponses) {
    final context = StringBuffer();
    for (var resp in workerResponses) {
      context.write(resp.join(' ') + ' ');
    }

    if (context.isEmpty) {
      return '''
Question: $userQuery
Answer:
''';
    } else {
      return '''
You are a helpful AI assistant. Answer the user's question based on the provided context from other nodes.

Context:
${context.toString().trim()}

User Question: $userQuery
Answer:
''';
    }
  }

  // Cleanup query
  Future<void> cleanupQuery(int queryNumber) async {
    try {
      await http.post(
        Uri.parse('$routingServerUrl/end'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query_number': queryNumber}),
      );
      print("[User] 🧹 Query $queryNumber cleaned up successfully.");
    } catch (e) {
      print("[User] ❌ Cleanup error: $e");
    }
  }

  @override
  void dispose() {
    _workerTimer.cancel();
    _controller.dispose();
    llamaParent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        centerTitle: false,
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () {
              setState(() {
                _messages.clear();
              });
            },
          )
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
                      "Combining responses...",
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
                fontFamily: 'Monospace',
              ),
              textAlign: TextAlign.left,
              textDirection: TextDirection.ltr,
              softWrap: true,
              overflow: TextOverflow.visible,
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
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  hintText: 'Type your message...',
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