// frontend/screens/model_list_screen.dart - Featured Products Design
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/models.dart';
import 'download_screen.dart';
import 'settings_screen.dart';
import 'backpack_screen.dart';
import 'worker_log_screen.dart';

class ModelListScreen extends StatefulWidget {
  const ModelListScreen({super.key});

  @override
  State<ModelListScreen> createState() => _ModelListScreenState();
}

class _ModelListScreenState extends State<ModelListScreen> {
  int _currentPage = 0;
  int _selectedBottomIndex = 0;
  final PageController _pageController = PageController(viewportFraction: 0.8);

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      int next = _pageController.page!.round();
      if (_currentPage != next) {
        setState(() {
          _currentPage = next;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1D2E),
      body: IndexedStack(
        index: _selectedBottomIndex,
        children: [
          _buildHomeScreen(),
          const BackpackScreen(),
          const WorkerLogScreen(),
          const SettingsScreen(), // Removed UniqueKey() for better performance
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHomeScreen() {
    final models = AIModel.values;

    return Container(
      // Removed gradient for better performance - use solid color instead
      color: const Color(0xFF1A1D2E),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            Expanded(
              child: Column(
                children: [
                  // Featured Products text
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Featured',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withOpacity(0.6),
                              height: 1.0,
                            ),
                          ),
                          Text(
                            'Models',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Carousel
                  SizedBox(
                    height: 380,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: models.length,
                      itemBuilder: (context, index) {
                        return _buildModelCard(models[index], index);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Page indicators - optimized with RepaintBoundary
                  RepaintBoundary(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        models.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? Colors.blue.shade400
                                : Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Menu icon
          Text(
            'DAI',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              // height: 1.0,
            ),
          ),
          // Shopping cart icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              // Simplified: solid color instead of gradient for performance
              color: Colors.blue.shade600,
              borderRadius: BorderRadius.circular(15),
              // Removed shadow for better performance
            ),
            child: IconButton(
              icon: const Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelCard(AIModel model, int index) {
    final isActive = index == _currentPage;

    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: EdgeInsets.symmetric(
          horizontal: 8,
          vertical: isActive ? 0 : 20,
        ),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _navigateToDownload(model);
          },
          child: Container(
            decoration: BoxDecoration(
              // Simplified: removed gradient for better performance
              color: const Color(0xFF2A2D3E),
              borderRadius: BorderRadius.circular(32),
              // Simplified shadow - reduced blur for better performance
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: isActive ? 12 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Stack(
                children: [
                  // Removed gradient overlay for better performance
                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top section - Robot/AI Icon
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: Icon(
                            Icons.smart_toy,
                            size: 120,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ),
                      // Bottom section - Model info
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              model.displayName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Official ${model.backend.name.toUpperCase()} model',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.6),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            // Feature badges
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _buildBadge(model.sizeDisplay, Colors.blue),
                                if (model.hasImage)
                                  _buildBadge('Vision', Colors.purple),
                                if (model.hasFunctionCalls)
                                  _buildBadge('Functions', Colors.orange),
                                if (model.isThinking)
                                  _buildBadge('Thinking', Colors.green),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color.withOpacity(0.9),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Color(0xFF2A2D3E),
        // Removed shadow for better performance
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home_rounded, 'Home', 0),
          _buildNavItem(Icons.backpack_outlined, 'Backpack', 1),
          _buildNavItem(Icons.description_outlined, 'Log', 2),
          _buildNavItem(Icons.settings_outlined, 'Settings', 3),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedBottomIndex == index;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _selectedBottomIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200), // Reduced duration for snappier feel
          curve: Curves.easeOut, // Faster curve
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            // Simplified: solid color instead of gradient
            color: isSelected ? Colors.blue.shade600 : null,
            borderRadius: BorderRadius.circular(20),
          ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
              size: 24,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200), // Reduced duration
              curve: Curves.easeOut,
              child: isSelected
                  ? Row(
                      children: [
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    )
    );
  }

  void _navigateToDownload(AIModel model) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            DownloadScreen(model: model),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
