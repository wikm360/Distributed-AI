import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../objectbox.g.dart';
import 'rag_entity.dart';

class FileManager {
  static final FileManager _instance = FileManager._internal();
  factory FileManager() => _instance;
  FileManager._internal();

  Store? _store;
  Box<UserFolder>? _folderBox;
  Box<UserFile>? _fileBox;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<bool> initialize(Store store) async {
    if (_isInitialized) return true;

    try {
      _store = store;
      _folderBox = _store!.box<UserFolder>();
      _fileBox = _store!.box<UserFile>();

      // Create user files directory
      final dir = await getApplicationDocumentsDirectory();
      final userFilesDir = Directory('${dir.path}/user_files');
      if (!userFilesDir.existsSync()) {
        await userFilesDir.create(recursive: true);
      }

      _isInitialized = true;
      return true;
    } catch (e) {
      print('FileManager initialization error: $e');
      return false;
    }
  }

  // Folder operations
  Future<UserFolder> createFolder(String name, {int parentId = 0, String? color}) async {
    if (!_isInitialized) throw Exception('FileManager not initialized');

    final folder = UserFolder(
      name: name,
      parentId: parentId,
      color: color,
    );
    _folderBox!.put(folder);
    return folder;
  }

  List<UserFolder> getFolders({int parentId = 0}) {
    if (!_isInitialized) return [];

    return _folderBox!
        .query(UserFolder_.parentId.equals(parentId))
        .order(UserFolder_.name)
        .build()
        .find();
  }

  Future<void> deleteFolder(int folderId) async {
    if (!_isInitialized) return;

    // Delete all files in folder
    final files = getFilesInFolder(folderId);
    for (final file in files) {
      await deleteFile(file.id);
    }

    // Delete sub-folders recursively
    final subFolders = getFolders(parentId: folderId);
    for (final folder in subFolders) {
      await deleteFolder(folder.id);
    }

    // Delete the folder itself
    _folderBox!.remove(folderId);
  }

  Future<void> renameFolder(int folderId, String newName) async {
    if (!_isInitialized) return;

    final folder = _folderBox!.get(folderId);
    if (folder != null) {
      folder.name = newName;
      folder.updatedAt = DateTime.now();
      _folderBox!.put(folder);
    }
  }

  // File operations
  Future<UserFile?> addFile(File sourceFile, {int folderId = 0}) async {
    if (!_isInitialized) return null;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final userFilesDir = Directory('${dir.path}/user_files');

      final fileName = sourceFile.path.split('/').last;
      final extension = fileName.contains('.') ? fileName.split('.').last : '';
      final targetPath = '${userFilesDir.path}/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      // Copy file to user_files directory
      final copiedFile = await sourceFile.copy(targetPath);
      final fileSize = await copiedFile.length();

      final userFile = UserFile(
        name: fileName,
        filePath: targetPath,
        folderId: folderId,
        fileSize: fileSize,
        extension: extension,
        mimeType: _getMimeType(extension),
      );

      _fileBox!.put(userFile);
      return userFile;
    } catch (e) {
      print('Error adding file: $e');
      return null;
    }
  }

  List<UserFile> getFilesInFolder(int folderId) {
    if (!_isInitialized) return [];

    return _fileBox!
        .query(UserFile_.folderId.equals(folderId))
        .order(UserFile_.name)
        .build()
        .find();
  }

  List<UserFile> getAllFiles() {
    if (!_isInitialized) return [];
    return _fileBox!.getAll();
  }

  Future<void> deleteFile(int fileId) async {
    if (!_isInitialized) return;

    final userFile = _fileBox!.get(fileId);
    if (userFile != null) {
      // Delete actual file from storage
      final file = File(userFile.filePath);
      if (file.existsSync()) {
        await file.delete();
      }
      // Remove from database
      _fileBox!.remove(fileId);
    }
  }

  Future<void> moveFile(int fileId, int newFolderId) async {
    if (!_isInitialized) return;

    final file = _fileBox!.get(fileId);
    if (file != null) {
      file.folderId = newFolderId;
      file.updatedAt = DateTime.now();
      _fileBox!.put(file);
    }
  }

  Future<void> renameFile(int fileId, String newName) async {
    if (!_isInitialized) return;

    final file = _fileBox!.get(fileId);
    if (file != null) {
      file.name = newName;
      file.updatedAt = DateTime.now();
      _fileBox!.put(file);
    }
  }

  // Stats
  int get totalFolders => _folderBox?.count() ?? 0;
  int get totalFiles => _fileBox?.count() ?? 0;

  int get totalStorageUsed {
    if (!_isInitialized) return 0;
    final files = _fileBox!.getAll();
    return files.fold(0, (sum, file) => sum + file.fileSize);
  }

  String _getMimeType(String extension) {
    final ext = extension.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'mp3':
        return 'audio/mpeg';
      case 'mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
