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
          SettingsScreen(key: UniqueKey()), // Force rebuild each time
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHomeScreen() {
    final models = AIModel.values;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1D2E),
            const Color(0xFF2A2D3E),
            Colors.blue.shade900.withOpacity(0.3),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            // _buildFeatureIcons(),
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
                            style: TextStyle(
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
                  // Page indicators
                  Row(
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
          Container(
            // width: 50,
            // height: 50,
            // decoration: BoxDecoration(
            //   color: const Color(0xFF2A2D3E),
            //   borderRadius: BorderRadius.circular(15),
            // ),
            child:Text(
              'Dist-AI',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                // height: 1.0,
              ),
            )
          ),
          // Shopping cart icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade600,
                  Colors.blue.shade400,
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
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

  // Widget _buildFeatureIcons() {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 32),
  //     child: Row(
  //       mainAxisAlignment: MainAxisAlignment.start,
  //       children: [
  //         _buildIconButton(Icons.psychology_outlined, true),
  //         const SizedBox(width: 16),
  //         _buildIconButton(Icons.chat_bubble_outline, false),
  //         const SizedBox(width: 16),
  //         _buildIconButton(Icons.mic_none, false),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildIconButton(IconData icon, bool isSelected) {
  //   return Container(
  //     width: 56,
  //     height: 56,
  //     decoration: BoxDecoration(
  //       gradient: isSelected
  //           ? LinearGradient(
  //               colors: [
  //                 Colors.blue.shade600,
  //                 Colors.blue.shade400,
  //               ],
  //             )
  //           : null,
  //       color: isSelected ? null : const Color(0xFF2A2D3E),
  //       borderRadius: BorderRadius.circular(16),
  //       boxShadow: isSelected
  //           ? [
  //               BoxShadow(
  //                 color: Colors.blue.withOpacity(0.4),
  //                 blurRadius: 12,
  //                 offset: const Offset(0, 4),
  //               ),
  //             ]
  //           : null,
  //     ),
  //     child: Icon(
  //       icon,
  //       color: Colors.white,
  //       size: 28,
  //     ),
  //   );
  // }

  Widget _buildModelCard(AIModel model, int index) {
    bool isActive = index == _currentPage;

    return AnimatedContainer(
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
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF2A2D3E),
                const Color(0xFF1A1D2E),
              ],
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Stack(
              children: [
                // Background gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          Colors.blue.withOpacity(0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
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
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  Colors.blue.withOpacity(0.3),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons.smart_toy,
                              size: 120,
                              color: Colors.white.withOpacity(0.9),
                            ),
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
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
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
    bool isSelected = _selectedBottomIndex == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedBottomIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    Colors.blue.shade600,
                    Colors.blue.shade400,
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                size: 24,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
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
