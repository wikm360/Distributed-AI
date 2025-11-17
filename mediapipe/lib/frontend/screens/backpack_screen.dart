import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/starfield_background.dart';
import '../../rag/file_manager.dart';
import '../../rag/rag_entity.dart';
import '../../main.dart' as main;

class BackpackScreen extends StatefulWidget {
  const BackpackScreen({super.key});

  @override
  State<BackpackScreen> createState() => _BackpackScreenState();
}

class _BackpackScreenState extends State<BackpackScreen> {
  final _searchController = TextEditingController();
  final FileManager _fileManager = FileManager();
  int _currentFolderId = 0;
  final List<int> _folderHistory = [];
  String _currentFolderName = 'My Files';

  List<UserFolder> _folders = [];
  List<UserFile> _files = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  String _processingStatus = '';

  @override
  void initState() {
    super.initState();
    _initializeFileManager();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _initializeFileManager() async {
    if (!_fileManager.isInitialized && main.ragManager.store != null) {
      await _fileManager.initialize(main.ragManager.store!);
    }
    _loadContent();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  Future<void> _loadContent() async {
    setState(() => _isLoading = true);

    if (!_fileManager.isInitialized) {
      // FileManager will be initialized when ObjectBox is ready
      setState(() => _isLoading = false);
      return;
    }

    _folders = _fileManager.getFolders(parentId: _currentFolderId);
    _files = _fileManager.getFilesInFolder(_currentFolderId);

    setState(() => _isLoading = false);
  }

  List<dynamic> _filteredItems() {
    final query = _searchController.text.trim().toLowerCase();
    final items = <dynamic>[];

    for (final folder in _folders) {
      if (query.isEmpty || folder.name.toLowerCase().contains(query)) {
        items.add(folder);
      }
    }

    for (final file in _files) {
      if (query.isEmpty || file.name.toLowerCase().contains(query)) {
        items.add(file);
      }
    }

    return items;
  }

  Future<void> _createFolder() async {
    final nameController = TextEditingController();

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'New Folder',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Folder Name',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (nameController.text.trim().isNotEmpty) {
                      Navigator.pop(context, nameController.text.trim());
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Create',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && _fileManager.isInitialized) {
      await _fileManager.createFolder(result, parentId: _currentFolderId);
      _loadContent();
    }
  }

  Future<void> _pickAndUploadFile() async {
    if (!_fileManager.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File manager not initialized')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final userFile =
          await _fileManager.addFile(file, folderId: _currentFolderId);

      if (userFile != null) {
        _loadContent();

        // Process file for RAG if it's a text file
        if (_isTextFile(userFile.extension ?? '')) {
          await _processFileForRAG(file, userFile.name);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${userFile.name} uploaded successfully')),
            );
          }
        }
      }
    }
  }

  bool _isTextFile(String extension) {
    final textExtensions = ['txt', 'md', 'json', 'xml', 'csv', 'log'];
    return textExtensions.contains(extension.toLowerCase());
  }

  Future<void> _processFileForRAG(File file, String fileName) async {
    if (!main.ragManager.isReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '$fileName uploaded (RAG not ready - no embedding model)')),
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingStatus = 'Reading file...';
    });

    try {
      setState(() => _processingStatus = 'Chunking text...');
      await Future.delayed(const Duration(milliseconds: 100));

      setState(() => _processingStatus = 'Generating embeddings...');
      final success = await main.ragManager.importTextFile(file);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingStatus = '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? '$fileName uploaded and indexed for RAG'
                : '$fileName uploaded (embedding failed)'),
            backgroundColor: success ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingStatus = '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$fileName uploaded (processing error: $e)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _openFolder(UserFolder folder) {
    _folderHistory.add(_currentFolderId);
    _currentFolderId = folder.id;
    _currentFolderName = folder.name;
    _loadContent();
  }

  void _goBack() {
    if (_folderHistory.isNotEmpty) {
      _currentFolderId = _folderHistory.removeLast();
      _currentFolderName = _currentFolderId == 0 ? 'My Files' : 'Folder';
      _loadContent();
    }
  }

  Future<void> _deleteItem(dynamic item) async {
    final isFolder = item is UserFolder;
    final name = isFolder ? item.name : (item as UserFile).name;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          'Delete ${isFolder ? 'Folder' : 'File'}?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "$name"?${isFolder ? '\nThis will delete all contents inside.' : ''}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (isFolder) {
        await _fileManager.deleteFolder(item.id);
      } else {
        await _fileManager.deleteFile((item as UserFile).id);
      }
      _loadContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StarfieldBackground(
      starCount: 120,
      backgroundColor: const Color(0xFF0F0F0F),
      child: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildSearchRow(),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _isLoading
                        ? _buildLoadingState()
                        : _filteredItems().isEmpty
                            ? _buildEmptyState()
                            : _buildGridView(),
                  ),
                ],
              ),
            ),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (_folderHistory.isNotEmpty)
              IconButton(
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentFolderName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                if (_isProcessing)
                  Text(
                    _processingStatus,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 14,
                    ),
                  )
                else
                  Text(
                    '${_folders.length} folders, ${_files.length} files',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ],
        ),
        _buildStorageInfo(),
      ],
    );
  }

  Widget _buildStorageInfo() {
    final totalSize =
        _fileManager.formatFileSize(_fileManager.totalStorageUsed);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        totalSize,
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSearchRow() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.white60),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Search files and folders...',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    final items = _filteredItems();
    return RefreshIndicator(
      onRefresh: () async => _loadContent(),
      color: Colors.white,
      backgroundColor: Colors.black,
      child: GridView.builder(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 80),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 16,
          childAspectRatio: 0.9,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          if (item is UserFolder) {
            return _buildFolderCard(item);
          } else {
            return _buildFileCard(item as UserFile);
          }
        },
      ),
    );
  }

  Widget _buildFolderCard(UserFolder folder) {
    return GestureDetector(
      onTap: () => _openFolder(folder),
      onLongPress: () => _deleteItem(folder),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF99E6FF),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF99E6FF).withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.folder,
              size: 80,
              color: Color(0xFF111111),
            ),
            const SizedBox(height: 16),
            Text(
              folder.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(folder.createdAt),
              style: TextStyle(
                color: const Color(0xFF111111).withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileCard(UserFile file) {
    return GestureDetector(
      onTap: () => _showFileMoveDialog(file),
      onLongPress: () => _deleteItem(file),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD588),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD588).withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getFileIcon(file.extension ?? ''),
              size: 80,
              color: const Color(0xFF111111),
            ),
            const SizedBox(height: 16),
            Text(
              file.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _fileManager.formatFileSize(file.fileSize),
              style: TextStyle(
                color: const Color(0xFF111111).withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFileMoveDialog(UserFile file) async {
    // Get all folders recursively
    List<UserFolder> getAllFoldersRecursive([int parentId = 0, int depth = 0]) {
      final folders = <UserFolder>[];
      final currentFolders = _fileManager.getFolders(parentId: parentId);
      for (final folder in currentFolders) {
        folders.add(folder);
        if (depth < 3) { // Limit depth to prevent infinite recursion
          folders.addAll(getAllFoldersRecursive(folder.id, depth + 1));
        }
      }
      return folders;
    }

    final folders = getAllFoldersRecursive();

    final selectedFolderId = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Move File',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              file.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        // Root folder option
                        if (file.folderId != 0)
                          _buildFolderSelectItem(
                            id: 0,
                            name: 'Root (My Files)',
                            icon: Icons.home,
                            isCurrentFolder: file.folderId == 0,
                          ),
                        // All other folders
                        ...folders.where((f) => f.id != file.folderId).map(
                          (folder) => _buildFolderSelectItem(
                            id: folder.id,
                            name: folder.name,
                            icon: Icons.folder,
                            isCurrentFolder: file.folderId == folder.id,
                          ),
                        ),
                        if (folders.isEmpty && file.folderId == 0)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                'No folders available.\nCreate a folder first.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selectedFolderId != null && selectedFolderId != file.folderId) {
      await _fileManager.moveFile(file.id, selectedFolderId);
      _loadContent();
      if (mounted) {
        final folderName = selectedFolderId == 0
            ? 'Root'
            : folders.firstWhere((f) => f.id == selectedFolderId).name;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved "${file.name}" to $folderName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Widget _buildFolderSelectItem({
    required int id,
    required String name,
    required IconData icon,
    required bool isCurrentFolder,
  }) {
    return GestureDetector(
      onTap: isCurrentFolder ? null : () => Navigator.pop(context, id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isCurrentFolder
              ? const Color(0xFF1A1A1A).withValues(alpha: 0.5)
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrentFolder ? Colors.white24 : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isCurrentFolder ? Colors.white38 : const Color(0xFF99E6FF),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: isCurrentFolder ? Colors.white38 : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            if (isCurrentFolder)
              const Text(
                'Current',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              )
            else
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white54,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Positioned(
      bottom: 120, // Above navbar (70px height + 20px margin + buffer)
      left: 24,
      right: 24,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _createFolder,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.create_new_folder_outlined,
                        color: Colors.black, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'New Folder',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: _pickAndUploadFile,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF99E6FF),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF99E6FF).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upload_file_outlined,
                        color: Colors.black, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Upload File',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder_open, color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty
                ? 'No files or folders yet'
                : 'No results found',
            style: const TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a folder or upload files to get started',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'txt':
        return Icons.description;
      case 'doc':
      case 'docx':
        return Icons.article;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      case 'mp4':
      case 'avi':
        return Icons.video_file;
      case 'zip':
      case 'rar':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
