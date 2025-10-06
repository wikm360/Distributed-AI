// frontend/screens/model_list_screen.dart - Optimized Modern Design
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/models.dart';
import 'download_screen.dart';

class ModelListScreen extends StatefulWidget {
  const ModelListScreen({super.key});

  @override
  State<ModelListScreen> createState() => _ModelListScreenState();
}

class _ModelListScreenState extends State<ModelListScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  String _searchQuery = '';
  String _selectedBackend = 'all';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  List<AIModel> get _filteredModels {
    var models = AIModel.values;
    if (_searchQuery.isNotEmpty) {
      models = models.where((m) =>
          m.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    if (_selectedBackend != 'all') {
      models = models
          .where((m) => m.backend.name == _selectedBackend)
          .toList();
    }
    return models;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0E27),
              Color(0xFF151B3D),
              Color(0xFF0A0E27),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchAndFilter(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildModelList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        Colors.blue.shade400,
                        Colors.purple.shade400,
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      'AI Models',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose a model to get started',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade600,
                      Colors.purple.shade600,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    // Settings action
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: Colors.white.withOpacity(0.5)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search models...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          Container(
            height: 20,
            width: 1,
            color: Colors.white.withOpacity(0.2),
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),
          DropdownButton<String>(
            value: _selectedBackend,
            dropdownColor: const Color(0xFF1A1F3A),
            icon: Icon(Icons.filter_list, color: Colors.white.withOpacity(0.5)),
            underline: const SizedBox(),
            style: const TextStyle(color: Colors.white),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All')),
              DropdownMenuItem(value: 'llamacpp', child: Text('LlamaCPP')),
              DropdownMenuItem(value: 'gml', child: Text('GML')),
            ],
            onChanged: (value) => setState(() => _selectedBackend = value!),
          ),
        ],
      ),
    );
  }

  Widget _buildModelList() {
    final models = _filteredModels;
    if (models.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No models found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }
    
    // ✅ Optimized: Removed TweenAnimationBuilder for better performance
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: models.length,
      itemBuilder: (context, index) {
        return _ModelCard(
          model: models[index],
          onTap: () => _navigateToDownload(models[index]),
        );
      },
    );
  }

  void _navigateToDownload(AIModel model) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            DownloadScreen(model: model),
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.02),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

// ========== Optimized Model Card ==========
class _ModelCard extends StatelessWidget {
  final AIModel model;
  final VoidCallback onTap;
  
  const _ModelCard({required this.model, required this.onTap});

  // ✅ Cached gradients for better performance
  static final _cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withOpacity(0.08),
      Colors.white.withOpacity(0.03),
    ],
  );

  @override
  Widget build(BuildContext context) {
    // ✅ Optimized: Removed AnimationController and scale animation
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: _cardGradient,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _getGradientColors(),
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          model.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            model.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            model.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white.withOpacity(0.4),
                        size: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.storage,
                      model.sizeDisplay,
                      Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      Icons.memory,
                      model.backend.name.toUpperCase(),
                      Colors.purple,
                    ),
                  ],
                ),
                if (model.hasImage ||
                    model.hasFunctionCalls ||
                    model.isThinking) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (model.hasFunctionCalls)
                        _buildFeatureChip(
                            'Functions', Icons.functions, Colors.purple),
                      if (model.hasImage)
                        _buildFeatureChip(
                            'Images', Icons.image, Colors.orange),
                      if (model.isThinking)
                        _buildFeatureChip(
                            'Thinking', Icons.psychology, Colors.indigo),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _getGradientColors() {
    final hash = model.name.hashCode;
    if (hash % 3 == 0) {
      return [Colors.blue.shade600, Colors.cyan.shade600];
    } else if (hash % 3 == 1) {
      return [Colors.purple.shade600, Colors.pink.shade600];
    } else {
      return [Colors.orange.shade600, Colors.amber.shade600];
    }
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}