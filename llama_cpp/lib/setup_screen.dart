// setup_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_screen.dart';

class SetupScreen extends StatefulWidget {
  @override
  _SetupScreenState createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String? _libPath;
  String? _modelPath;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedPaths(); // فقط بارگیری مسیرها، بدون ریدایرکت خودکار
  }

  Future<void> _loadSavedPaths() async {
    final prefs = await SharedPreferences.getInstance();
    final libPath = prefs.getString('libllama_path');
    final modelPath = prefs.getString('model_path');

    setState(() {
      _libPath = libPath;
      _modelPath = modelPath;
    });
  }

  Future<void> _pickLibrary() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      // allowedExtensions: ['so', 'dll', 'dylib'],
    );
    if (result != null) {
      setState(() {
        _libPath = result.files.single.path!;
      });
    }
  }

  Future<void> _pickModel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      // allowedExtensions: ['gguf'],
    );
    if (result != null) {
      setState(() {
        _modelPath = result.files.single.path!;
      });
    }
  }

  Future<void> _saveAndContinue() async {
    if (_libPath == null || _modelPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لطفاً هر دو فایل را انتخاب کنید.')),
      );
      return;
    }

    final fileLib = File(_libPath!);
    final fileModel = File(_modelPath!);

    if (!fileLib.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فایل کتابخانه وجود ندارد.')),
      );
      return;
    }
    if (!fileModel.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فایل مدل وجود ندارد.')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('libllama_path', _libPath!);
    await prefs.setString('model_path', _modelPath!);

    setState(() {
      _loading = true;
    });

    // کمی تأخیر برای نمایش وضعیت
    await Future.delayed(Duration(milliseconds: 600));

    // حذف تمام صفحه‌ها و رفتن به ChatScreen
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(libPath: _libPath!, modelPath: _modelPath!),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('انتخاب فایل‌ها'),
        backgroundColor: Colors.grey[900],
      ),
      body: Container(
        color: Color(0xFF121212),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPathButton(
              icon: Icons.folder,
              label: 'انتخاب کتابخانه (libllama.so)',
              path: _libPath,
              onTap: _pickLibrary,
            ),
            SizedBox(height: 16),
            _buildPathButton(
              icon: Icons.model_training,
              label: 'انتخاب مدل (model.gguf)',
              path: _modelPath,
              onTap: _pickModel,
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loading ? null : _saveAndContinue,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _loading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'شروع چت',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPathButton({
    required IconData icon,
    required String label,
    required String? path,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[600]!),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    path?.split('/').last ?? 'هنوز انتخاب نشده',
                    style: TextStyle(
                      color: path != null ? Colors.white : Colors.grey,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}