// shared/protected_files.dart - مدیریت فایل‌های محافظت‌شده از حذف
import 'package:shared_preferences/shared_preferences.dart';
import 'logger.dart';

/// Singleton برای مدیریت لیست فایل‌های محافظت‌شده
/// این کلاس از حذف تصادفی فایل‌های مدل embedding توسط flutter_gemma جلوگیری می‌کند
class ProtectedFiles {
  static final ProtectedFiles _instance = ProtectedFiles._internal();
  factory ProtectedFiles() => _instance;
  ProtectedFiles._internal();

  static const String _key = 'protected_model_files';
  final Set<String> _protectedFiles = {};

  /// بارگذاری لیست فایل‌های محافظت‌شده از SharedPreferences
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final files = prefs.getStringList(_key) ?? [];
      _protectedFiles.clear();
      _protectedFiles.addAll(files);

      if (_protectedFiles.isNotEmpty) {
        Log.i('Loaded ${_protectedFiles.length} protected files', 'ProtectedFiles');
      }
    } catch (e) {
      Log.e('Failed to load protected files', 'ProtectedFiles', e);
    }
  }

  /// ذخیره لیست فایل‌های محافظت‌شده در SharedPreferences
  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _protectedFiles.toList());
    } catch (e) {
      Log.e('Failed to save protected files', 'ProtectedFiles', e);
    }
  }

  /// اضافه کردن فایل به لیست محافظت‌شده
  Future<void> protect(String filename) async {
    if (_protectedFiles.add(filename)) {
      await _save();
      Log.i('Protected file: $filename', 'ProtectedFiles');
    }
  }

  /// حذف فایل از لیست محافظت‌شده
  Future<void> unprotect(String filename) async {
    if (_protectedFiles.remove(filename)) {
      await _save();
      Log.i('Unprotected file: $filename', 'ProtectedFiles');
    }
  }

  /// بررسی اینکه آیا فایل محافظت‌شده است
  bool isProtected(String filename) {
    return _protectedFiles.contains(filename);
  }

  /// دریافت لیست تمام فایل‌های محافظت‌شده
  List<String> getAll() {
    return _protectedFiles.toList();
  }

  /// پاک کردن تمام فایل‌های محافظت‌شده
  Future<void> clear() async {
    _protectedFiles.clear();
    await _save();
    Log.i('Cleared all protected files', 'ProtectedFiles');
  }

  /// نمایش تعداد فایل‌های محافظت‌شده
  int get count => _protectedFiles.length;
}
