// ui/screens/modernized_model_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_gemma/pigeon.g.dart';
import '../../core/services/backend_factory.dart';
import '../../models/model.dart';
import '../widgets/model_info_card.dart';
import '../widgets/backend_selector.dart';
import 'modernized_chat_screen.dart';
import 'model_download_screen.dart';

class ModernizedModelSelectionScreen extends StatefulWidget {
  const ModernizedModelSelectionScreen({super.key});

  @override
  State<ModernizedModelSelectionScreen> createState() => _ModernizedModelSelectionScreenState();
}

class _ModernizedModelSelectionScreenState extends State<ModernizedModelSelectionScreen> {
  // Filter states
  String? _selectedBackend;
  bool _filterMultimodal = false;
  bool _filterFunctionCalls = false;
  bool _filterThinking = false;
  bool _showFilters = false;
  
  // Sort options
  SortType _selectedSort = SortType.defaultOrder;
  
  // Loading state
  String? _loadingModelId;

  @override
  void initState() {
    super.initState();
    _selectedBackend = BackendFactory.supportedBackends.isNotEmpty 
        ? BackendFactory.supportedBackends.first 
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final filteredModels = _getFilteredAndSortedModels();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('انتخاب مدل AI - نسخه 2'),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // Backend Selector
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'انتخاب Backend:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                BackendSelector(
                  selectedBackend: _selectedBackend,
                  onBackendChanged: (backend) {
                    setState(() {
                      _selectedBackend = backend;
                    });
                  },
                ),
              ],
            ),
          ),
          
          // Filters and Sort
          _buildFiltersSection(),
          
          // Models List
          Expanded(
            child: filteredModels.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredModels.length,
                    itemBuilder: (context, index) {
                      final model = filteredModels[index];
                      return ModelInfoCard(
                        model: model,
                        isLoading: _loadingModelId == model.name,
                        onTap: () => _onModelSelected(model),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Filter header
          InkWell(
            onTap: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(
                    _showFilters ? Icons.filter_list : Icons.filter_list_outlined,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'فیلترها و مرتب‌سازی',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _showFilters ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          
          // Filter options
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _showFilters ? null : 0,
            child: _showFilters ? Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sort options
                  Row(
                    children: [
                      const Text(
                        'مرتب‌سازی:',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButton<SortType>(
                          value: _selectedSort,
                          isExpanded: true,
                          dropdownColor: Colors.grey[700],
                          style: const TextStyle(color: Colors.white),
                          items: SortType.values.map((type) {
                            return DropdownMenuItem<SortType>(
                              value: type,
                              child: Text(_getSortDisplayName(type)),
                            );
                          }).toList(),
                          onChanged: (SortType? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedSort = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Feature filters
                  const Text(
                    'ویژگی‌ها:',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('چندرسانه‌ای'),
                        selected: _filterMultimodal,
                        onSelected: (bool selected) {
                          setState(() {
                            _filterMultimodal = selected;
                          });
                        },
                        selectedColor: Colors.orange[700],
                        labelStyle: TextStyle(
                          color: _filterMultimodal ? Colors.white : null,
                        ),
                      ),
                      FilterChip(
                        label: const Text('فراخوانی تابع'),
                        selected: _filterFunctionCalls,
                        onSelected: (bool selected) {
                          setState(() {
                            _filterFunctionCalls = selected;
                          });
                        },
                        selectedColor: Colors.purple[600],
                        labelStyle: TextStyle(
                          color: _filterFunctionCalls ? Colors.white : null,
                        ),
                      ),
                      FilterChip(
                        label: const Text('تفکر'),
                        selected: _filterThinking,
                        onSelected: (bool selected) {
                          setState(() {
                            _filterThinking = selected;
                          });
                        },
                        selectedColor: Colors.indigo[600],
                        labelStyle: TextStyle(
                          color: _filterThinking ? Colors.white : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Clear filters button
                  Center(
                    child: TextButton(
                      onPressed: _clearFilters,
                      child: const Text(
                        'پاک کردن فیلترها',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ),
                ],
              ),
            ) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'هیچ مدلی با فیلترهای انتخاب شده یافت نشد',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _clearFilters,
            child: const Text(
              'پاک کردن فیلترها',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  List<Model> _getFilteredAndSortedModels() {
    var models = Model.values.where((model) {
      // Platform compatibility check
      if (_selectedBackend != null) {
        final backendName = _selectedBackend!.toLowerCase();
        if (backendName.contains('gemma') && !_isGemmaCompatible(model)) {
          return false;
        }
        if (backendName.contains('llama') && !_isLlamaCompatible(model)) {
          return false;
        }
      }
      
      // Feature filters
      if (_filterMultimodal && !model.supportImage) return false;
      if (_filterFunctionCalls && !model.supportsFunctionCalls) return false;
      if (_filterThinking && !model.isThinking) return false;
      
      return true;
    }).toList();

    // Apply sorting
    switch (_selectedSort) {
      case SortType.alphabetical:
        models.sort((a, b) => a.displayName.compareTo(b.displayName));
        break;
      case SortType.size:
        models.sort((a, b) => _sizeToMB(a.size).compareTo(_sizeToMB(b.size)));
        break;
      case SortType.defaultOrder:
        // Keep original order
        break;
    }

    return models;
  }

  bool _isGemmaCompatible(Model model) {
    // Add logic to check if model is compatible with Gemma backend
    return true; // For now, assume all models are compatible
  }

  bool _isLlamaCompatible(Model model) {
    // Add logic to check if model is compatible with LlamaCpp backend
    return false; // LlamaCpp not implemented yet
  }

  double _sizeToMB(String size) {
    final numStr = size.replaceAll(RegExp(r'[^0-9.]'), '');
    final num = double.tryParse(numStr) ?? 0;
    
    if (size.toUpperCase().contains('GB')) {
      return num * 1024;
    } else if (size.toUpperCase().contains('TB')) {
      return num * 1024 * 1024;
    }
    return num;
  }

  String _getSortDisplayName(SortType type) {
    switch (type) {
      case SortType.alphabetical:
        return 'الفبایی';
      case SortType.size:
        return 'حجم';
      case SortType.defaultOrder:
        return 'پیش‌فرض';
    }
  }

  void _clearFilters() {
    setState(() {
      _filterMultimodal = false;
      _filterFunctionCalls = false;
      _filterThinking = false;
    });
  }

  Future<void> _onModelSelected(Model model) async {
    setState(() {
      _loadingModelId = model.name;
    });

    try {
      // Navigate to appropriate screen based on platform
      final isWeb = Theme.of(context).platform == TargetPlatform.fuchsia; // Web detection
      
      if (isWeb) {
        // Navigate directly to chat for web
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ModernizedChatScreen(
              model: model,
              selectedBackend: _parsePreferredBackend(_selectedBackend),
            ),
          ),
        );
      } else {
        // Navigate to download screen for mobile
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ModernizedModelDownloadScreen(
              model: model,
              selectedBackend: _parsePreferredBackend(_selectedBackend),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در بارگذاری مدل: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingModelId = null;
        });
      }
    }
  }

  PreferredBackend? _parsePreferredBackend(String? backendName) {
    if (backendName == null) return null;
    
    switch (backendName.toLowerCase()) {
      case 'cpu':
        return PreferredBackend.cpu;
      case 'gpu':
        return PreferredBackend.gpu;
      default:
        return null;
    }
  }

  void _showInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('درباره سیستم', style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('سیستم چت هوش مصنوعی توزیع‌یافته', 
                 style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('ویژگی‌های جدید:', style: TextStyle(color: Colors.white70)),
            Text('• معماری جداسازی شده', style: TextStyle(color: Colors.white70)),
            Text('• پشتیبانی از چندین Backend', style: TextStyle(color: Colors.white70)),
            Text('• Worker پس‌زمینه بهینه شده', style: TextStyle(color: Colors.white70)),
            Text('• رابط کاربری مدرن', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 8),
            Text('نسخه: 2.0.0', style: TextStyle(color: Colors.blue)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }
}

enum SortType {
  defaultOrder('Default'),
  alphabetical('Alphabetical'),
  size('Size');

  const SortType(this.displayName);
  final String displayName;
}