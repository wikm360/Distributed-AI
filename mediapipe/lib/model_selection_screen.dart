// model_selection_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/pigeon.g.dart';
import 'chat_screen.dart';
import 'model_download_screen.dart';
import 'models/model.dart';

enum SortType {
  defaultOrder('Default'),
  alphabetical('Alphabetical'),
  size('Size');

  const SortType(this.displayName);
  final String displayName;
}

class ModelSelectionScreen extends StatefulWidget {
  const ModelSelectionScreen({super.key});

  @override
  State<ModelSelectionScreen> createState() => _ModelSelectionScreenState();
}

class _ModelSelectionScreenState extends State<ModelSelectionScreen> {
  SortType selectedSort = SortType.defaultOrder;
  bool showFilters = false;
  
  // Filter states
  bool filterMultimodal = false;
  bool filterFunctionCalls = false;
  bool filterThinking = false;

  // Convert size string to MB for sorting
  double _sizeToMB(String size) {
    final numStr = size.replaceAll(RegExp(r'[^0-9.]'), '');
    final num = double.tryParse(numStr) ?? 0;
    
    if (size.toUpperCase().contains('GB')) {
      return num * 1024; // Convert GB to MB
    } else if (size.toUpperCase().contains('TB')) {
      return num * 1024 * 1024; // Convert TB to MB
    }
    return num; // Assume MB if no unit
  }

  List<Model> _sortModels(List<Model> models) {
    switch (selectedSort) {
      case SortType.alphabetical:
        return [...models]..sort((a, b) => a.displayName.compareTo(b.displayName));
      case SortType.size:
        return [...models]..sort((a, b) => _sizeToMB(a.size).compareTo(_sizeToMB(b.size)));
      case SortType.defaultOrder:
        return models; // Keep original order
    }
  }

  List<Model> _filterModels(List<Model> models) {
    return models.where((model) {
      // Feature filters
      if (filterMultimodal && !model.supportImage) return false;
      if (filterFunctionCalls && !model.supportsFunctionCalls) return false;
      if (filterThinking && !model.isThinking) return false;
      
      return true;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      filterMultimodal = false;
      filterFunctionCalls = false;
      filterThinking = false;
    });
  }

  // ignore: unused_element
  String _getModelsWord(int count) {
    if (count == 1) {
      return 'model';
    } else {
      return 'models';
    }
  }

  @override
  Widget build(BuildContext context) {
    var models = Model.values.where((model) {
      if (model.localModel) {
        return kIsWeb;
      }
      if (!kIsWeb) return true;
      return model.preferredBackend == PreferredBackend.gpu && !model.needsAuth;
    }).toList();

    // Apply filtering then sorting
    models = _filterModels(models);
    models = _sortModels(models);
    
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('انتخاب مدل AI'),
        backgroundColor: Colors.grey[900],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Filters section
            Container(
              margin: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                children: [
                  // Filter header
                  InkWell(
                    onTap: () {
                      setState(() {
                        showFilters = !showFilters;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Icon(
                            showFilters ? Icons.filter_list : Icons.filter_list_outlined,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'فیلترها',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            showFilters ? Icons.expand_less : Icons.expand_more,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Filter options
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: showFilters ? null : 0,
                    child: showFilters ? Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Features
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
                                selected: filterMultimodal,
                                onSelected: (bool selected) {
                                  setState(() {
                                    filterMultimodal = selected;
                                  });
                                },
                                selectedColor: Colors.orange[700],
                                labelStyle: TextStyle(
                                  color: filterMultimodal ? Colors.white : null,
                                ),
                              ),
                              FilterChip(
                                label: const Text('فراخوانی تابع'),
                                selected: filterFunctionCalls,
                                onSelected: (bool selected) {
                                  setState(() {
                                    filterFunctionCalls = selected;
                                  });
                                },
                                selectedColor: Colors.purple[600],
                                labelStyle: TextStyle(
                                  color: filterFunctionCalls ? Colors.white : null,
                                ),
                              ),
                              FilterChip(
                                label: const Text('تفکر'),
                                selected: filterThinking,
                                onSelected: (bool selected) {
                                  setState(() {
                                    filterThinking = selected;
                                  });
                                },
                                selectedColor: Colors.indigo[600],
                                labelStyle: TextStyle(
                                  color: filterThinking ? Colors.white : null,
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
            ),
            // Sort selector
            Container(
              margin: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                children: [
                  const Text(
                    'مرتب‌سازی:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<SortType>(
                      value: selectedSort,
                      isExpanded: true,
                      dropdownColor: Colors.grey[800],
                      style: const TextStyle(color: Colors.white),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      items: SortType.values.map((type) {
                        return DropdownMenuItem<SortType>(
                          value: type,
                          child: Text(type.displayName),
                        );
                      }).toList(),
                      onChanged: (SortType? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedSort = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Results counter
            Container(
              margin: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                'نمایش ${models.length} مدل',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ),
            // Models list
            Expanded(
              child: ListView.builder(
                itemCount: models.length,
                itemBuilder: (context, index) {
                  final model = models[index];
                  return ModelCard(model: model);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ModelCard extends StatefulWidget {
  final Model model;
  
  const ModelCard({super.key, required this.model});
  
  @override
  State<ModelCard> createState() => _ModelCardState();
}

class _ModelCardState extends State<ModelCard> {
  late PreferredBackend selectedBackend;
  
  @override
  void initState() {
    super.initState();
    selectedBackend = widget.model.preferredBackend;
  }
  
  // Check if model supports both backends
  bool get supportsBothBackends {
    return !widget.model.localModel;
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      color: Colors.grey[850],
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16.0),
            title: Text(
              widget.model.displayName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16.0,
                color: Colors.white,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4.0),
                if (supportsBothBackends) ...[
                  // Backend switcher for models that support both
                  Row(
                    children: [
                      const Text(
                        'پردازنده: ',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SegmentedButton<PreferredBackend>(
                        segments: const [
                          ButtonSegment<PreferredBackend>(
                            value: PreferredBackend.cpu,
                            label: Text('CPU', style: TextStyle(fontSize: 12)),
                          ),
                          ButtonSegment<PreferredBackend>(
                            value: PreferredBackend.gpu,
                            label: Text('GPU', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                        selected: {selectedBackend},
                        onSelectionChanged: (Set<PreferredBackend> selection) {
                          setState(() {
                            selectedBackend = selection.first;
                          });
                        },
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Just show the backend for models that don't support switching
                  Text(
                    'پردازنده: ${widget.model.preferredBackend.name.toUpperCase()}',
                    style: TextStyle(
                      color: widget.model.preferredBackend == PreferredBackend.gpu 
                          ? Colors.green[600] 
                          : Colors.blue[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 2.0),
                Text(
                  'حجم: ${widget.model.size}',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                if (widget.model.supportsFunctionCalls || widget.model.supportImage || widget.model.isThinking) ...[
                  const SizedBox(height: 4.0),
                  Wrap(
                    spacing: 4.0,
                    children: [
                      if (widget.model.supportsFunctionCalls)
                        Chip(
                          label: const Text('فراخوانی تابع', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500)),
                          backgroundColor: Colors.purple[600],
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      if (widget.model.supportImage)
                        Chip(
                          label: const Text('چندرسانه‌ای', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500)),
                          backgroundColor: Colors.orange[700],
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      if (widget.model.isThinking)
                        Chip(
                          label: const Text('تفکر', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500)),
                          backgroundColor: Colors.indigo[600],
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                ],
              ],
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
            ),
            onTap: () {
              // Navigate to download screen (non-web) or chat screen (web)
              if (!kIsWeb) {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => ModelDownloadScreen(
                      model: widget.model,
                      selectedBackend: selectedBackend,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => ChatScreen(
                      model: widget.model,
                      selectedBackend: selectedBackend,
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}