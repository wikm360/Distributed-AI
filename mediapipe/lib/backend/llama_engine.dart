// // backend/llama_engine.dart - پیاده‌سازی LlamaCpp
// import 'dart:async';
// import 'package:llama_cpp_dart/llama_cpp_dart.dart';
// import 'ai_engine.dart';
// import '../shared/logger.dart';

// class QwenFormat extends PromptFormat {
//   QwenFormat() : super(
//     PromptFormatType.raw,
//     inputSequence: '<|im_start|>user\n',
//     outputSequence: '<|im_start|>assistant\n',
//     systemSequence: '<|im_start|>system\n',
//     stopSequence: '<|im_end|>',
//   );
// }

// class LlamaEngine implements AIEngine {
//   late LlamaParent _llama;
//   bool _isReady = false;
//   bool _isGenerating = false;
//   final List<String> _history = [];
//   StreamController<String>? _streamController;

//   @override
//   String get name => 'LlamaCpp';
  
//   @override
//   bool get isReady => _isReady;
  
//   @override
//   bool get isGenerating => _isGenerating;

//   @override
//   Future<void> init(String modelPath, Map<String, dynamic> config) async {
//     try {
//       Log.i('Initializing LlamaCpp...', 'LlamaEngine');
      
//       Llama.libraryPath = config['libraryPath'] ?? './llama.dll';

//       final contextParams = ContextParams()
//         ..nCtx = config['nCtx'] ?? 4096
//         ..nBatch = 512
//         ..nThreads = 8
//         ..nPredict = 256;

//       final samplerParams = SamplerParams()
//         ..temp = config['temperature']?.toDouble() ?? 0.6
//         ..topP = config['topP']?.toDouble() ?? 0.9
//         ..topK = config['topK'] ?? 50;

//       final loadCommand = LlamaLoad(
//         path: modelPath,
//         modelParams: ModelParams(),
//         contextParams: contextParams,
//         samplingParams: samplerParams,
//         format: QwenFormat(),
//       );

//       _llama = LlamaParent(loadCommand);
//       await _llama.init();

//       // Wait for ready
//       for (int i = 0; i < 60; i++) {
//         if (_llama.status == LlamaStatus.ready) break;
//         await Future.delayed(const Duration(milliseconds: 500));
//       }

//       if (_llama.status != LlamaStatus.ready) {
//         throw Exception('Model load timeout');
//       }

//       _isReady = true;
//       Log.s('LlamaCpp initialized', 'LlamaEngine');
//     } catch (e) {
//       _isReady = false;
//       Log.e('LlamaCpp init failed', 'LlamaEngine', e);
//       rethrow;
//     }
//   }

//   @override
//   Future<String> generate(String prompt) async {
//     if (!_isReady) throw StateError('Not initialized');
//     if (_isGenerating) throw StateError('Already generating');

//     try {
//       _isGenerating = true;
//       final completer = Completer<String>();
//       final buffer = StringBuffer();

//       final streamSub = _llama.stream.listen((token) => buffer.write(token));
//       final completionSub = _llama.completions.listen((event) {
//         if (event.success && !completer.isCompleted) {
//           completer.complete(buffer.toString().trim());
//         }
//       });

//       await _llama.sendPrompt(_formatPrompt(prompt));
//       final result = await completer.future.timeout(const Duration(seconds: 60));

//       await streamSub.cancel();
//       await completionSub.cancel();

//       _history.add("User: $prompt");
//       _history.add("Assistant: $result");

//       return result;
//     } finally {
//       _isGenerating = false;
//     }
//   }

//   @override
//   Stream<String> generateStream(String prompt) async* {
//     if (!_isReady) throw StateError('Not initialized');
//     if (_isGenerating) throw StateError('Already generating');

//     _streamController = StreamController<String>();
//     _isGenerating = true;

//     final streamSub = _llama.stream.listen(
//       (token) {
//         if (_streamController != null && !_streamController!.isClosed) {
//           _streamController!.add(token);
//         }
//       },
//     );

//     final completionSub = _llama.completions.listen(
//       (event) {
//         if (_streamController != null && !_streamController!.isClosed) {
//           _streamController!.close();
//         }
//         _isGenerating = false;
//       },
//     );

//     await _llama.sendPrompt(_formatPrompt(prompt));
//     yield* _streamController!.stream;

//     await streamSub.cancel();
//     await completionSub.cancel();
//   }

//   @override
//   Future<void> stop() async {
//     _isGenerating = false;
//     if (_streamController != null && !_streamController!.isClosed) {
//       _streamController!.close();
//     }
//   }

//   @override
//   Future<void> clearHistory() async {
//     _history.clear();
//   }

//   @override
//   Future<void> dispose() async {
//     await stop();
//     if (_isReady) {
//       _llama.dispose();
//     }
//     _history.clear();
//     _isReady = false;
//   }

//   @override
//   Future<bool> healthCheck() async {
//     return _isReady && _llama.status == LlamaStatus.ready;
//   }

//   String _formatPrompt(String userPrompt) {
//     final buffer = StringBuffer();
//     buffer.writeln('<|im_start|>system');
//     buffer.writeln('You are a helpful AI assistant.');
//     buffer.writeln('<|im_end|>');

//     for (final item in _history.takeLast(10)) {
//       if (item.startsWith('User: ')) {
//         buffer.writeln('<|im_start|>user');
//         buffer.writeln(item.substring(6));
//         buffer.writeln('<|im_end|>');
//       } else if (item.startsWith('Assistant: ')) {
//         buffer.writeln('<|im_start|>assistant');
//         buffer.writeln(item.substring(11));
//         buffer.writeln('<|im_end|>');
//       }
//     }

//     buffer.writeln('<|im_start|>user');
//     buffer.writeln(userPrompt);
//     buffer.writeln('<|im_end|>');
//     buffer.write('<|im_start|>assistant');

//     return buffer.toString();
//   }
// }

// extension<T> on List<T> {
//   List<T> takeLast(int n) {
//     if (length <= n) return this;
//     return sublist(length - n);
//   }
// }