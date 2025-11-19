// animated_splash_registration.dart - اسپلش و ثبت‌نام با انیمیشن یکپارچه
import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;

class AnimatedSplashRegistration extends StatefulWidget {
  final VoidCallback onComplete;

  const AnimatedSplashRegistration({
    super.key,
    required this.onComplete,
  });

  @override
  State<AnimatedSplashRegistration> createState() =>
      _AnimatedSplashRegistrationState();
}

class _AnimatedSplashRegistrationState
    extends State<AnimatedSplashRegistration> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();

  // Main animation controller
  late AnimationController _mainController;
  late AnimationController _earthRotationController;

  // Logo animations
  late Animation<double> _logoPositionAnimation;
  late Animation<double> _logoScaleAnimation;

  // Earth animations
  late Animation<double> _earthOpacityAnimation;

  // Background animations
  late Animation<double> _starsOpacityAnimation;

  // Text animations
  late Animation<double> _appNameOpacityAnimation;

  // Form animations
  late Animation<double> _formOpacityAnimation;
  late Animation<double> _field1Animation;
  late Animation<double> _field2Animation;
  late Animation<double> _field3Animation;
  late Animation<double> _field4Animation;
  late Animation<double> _buttonAnimation;

  @override
  void initState() {
    super.initState();

    // Main controller for entire animation sequence (6 seconds total)
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 6000),
      vsync: this,
    );

    // Earth rotation controller (continuous)
    _earthRotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _setupAnimations();
    _startAnimation();
  }

  void _setupAnimations() {
    // Phase 1: Splash (0.0 - 0.3) - Logo centered, stars appear
    _starsOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.2, curve: Curves.easeIn),
    ));

    // Phase 2: Logo moves up (0.15 - 0.45)
    _logoPositionAnimation = Tween<double>(
      begin: 0.0,
      end: -0.25, // Move logo to top
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.15, 0.45, curve: Curves.easeInOut),
    ));

    _logoScaleAnimation = Tween<double>(
      begin: 1.5,
      end: 0.75, // Scale down logo (not too small)
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.15, 0.45, curve: Curves.easeInOut),
    ));

    // Phase 3: Earth fades in (0.15 - 0.35)
    _earthOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 0.4, // Keep earth visible throughout
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.15, 0.35, curve: Curves.easeIn),
    ));

    // Phase 4: App name appears (0.3 - 0.5)
    _appNameOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.3, 0.5, curve: Curves.easeIn),
    ));

    // Phase 5: Form fields appear (0.5 - 1.0)
    _formOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.45, 0.55, curve: Curves.easeIn),
    ));

    // Staggered field animations
    _field1Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.5, 0.65, curve: Curves.easeOut),
      ),
    );

    _field2Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.55, 0.7, curve: Curves.easeOut),
      ),
    );

    _field3Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.6, 0.75, curve: Curves.easeOut),
      ),
    );

    _field4Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.65, 0.8, curve: Curves.easeOut),
      ),
    );

    _buttonAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.7, 0.85, curve: Curves.easeOut),
      ),
    );
  }

  void _startAnimation() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _mainController.forward();
  }

  void _handleRegistration() {
    // if (_formKey.currentState!.validate()) {
      widget.onComplete();
    // }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _mainController.dispose();
    _earthRotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _mainController,
        builder: (context, child) {
          return Stack(
            children: [
              // Background gradient (lowest layer)
              _buildBackgroundGradient(),

              // Animated Stars
              _buildStarryBackground(),

              // Rotating Earth (above stars)
              _buildRotatingEarth(size),

              // Logo (moves from center to top)
              _buildLogo(size),

              // App Name (appears below logo)
              _buildAppName(size),

              // Registration Form (fades in)
              _buildRegistrationForm(size),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBackgroundGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF000000),
            Color(0xFF0A0A1A),
            Color(0xFF000000),
          ],
        ),
      ),
    );
  }

  Widget _buildStarryBackground() {
    return AnimatedOpacity(
      opacity: _starsOpacityAnimation.value,
      duration: const Duration(milliseconds: 100),
      child: CustomPaint(
        painter: StarsPainter(opacity: _starsOpacityAnimation.value),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildRotatingEarth(Size size) {
    // Earth stays in same position - only fades in
    return Positioned(
      left: -size.width * 0.1,
      right: -size.width * 0.1,
      top: size.height * 0.15, // Fixed position
      child: AnimatedBuilder(
        animation: _earthRotationController,
        builder: (context, child) {
          return Opacity(
            opacity: _earthOpacityAnimation.value,
            child: Transform.rotate(
              angle: _earthRotationController.value * 2 * math.pi,
              child: Image.asset(
                'assets/earth.png',
                width: size.width * 1.2,
                height: size.width * 1.2,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: size.width * 1.2,
                    height: size.width * 1.2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.blue.withValues(alpha: 0.3),
                          Colors.blue.withValues(alpha: 0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogo(Size size) {
    // Logo size
    const double logoSize = 200.0;

    // Logo position calculation - center it properly
    final logoTop = (size.height / 2) - (logoSize / 2) +
                    (size.height * _logoPositionAnimation.value);

    return Positioned(
      left: 0,
      right: 0,
      top: logoTop,
      child: Transform.scale(
        scale: _logoScaleAnimation.value,
        child: Center(
          child: Image.asset(
            'assets/logo_white.png',
            width: logoSize,
            height: logoSize,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: logoSize,
                height: logoSize,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(Icons.psychology, size: 100, color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAppName(Size size) {
    // Logo size
    const double logoSize = 200.0;

    // App name stays below logo - calculate proper position
    final nameTop = (size.height / 2) - (logoSize / 2) +
                    (size.height * _logoPositionAnimation.value) +
                    (logoSize * _logoScaleAnimation.value) ;

    return Positioned(
      left: 0,
      right: 0,
      top: nameTop,
      child: Opacity(
        opacity: _appNameOpacityAnimation.value,
        child: Column(
          children: [
            Text(
              'Distributed AI',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2.0,
                shadows: [
                  Shadow(
                    blurRadius: 10.0,
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Labs Edition',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white70,
                letterSpacing: 1.0,
                shadows: [
                  Shadow(
                    blurRadius: 8.0,
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationForm(Size size) {
    return Positioned(
      left: 24,
      right: 24,
      top: size.height * 0.42,
      child: Opacity(
        opacity: _formOpacityAnimation.value,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // First Name Field
              _buildAnimatedField(
                animation: _field1Animation,
                controller: _firstNameController,
                label: 'Name',
                hint: 'Enter your first name',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 16),

              // Last Name Field
              _buildAnimatedField(
                animation: _field2Animation,
                controller: _lastNameController,
                label: 'Last Name',
                hint: 'Enter your last name',
                icon: Icons.person,
              ),
              const SizedBox(height: 16),

              // Username Field
              _buildAnimatedField(
                animation: _field3Animation,
                controller: _usernameController,
                label: 'Username',
                hint: 'Enter your username',
                icon: Icons.alternate_email,
              ),
              const SizedBox(height: 16),

              // Email Field
              _buildAnimatedField(
                animation: _field4Animation,
                controller: _emailController,
                label: 'E-mail',
                hint: 'Enter your email address',
                icon: Icons.email_outlined,
                isEmail: true,
              ),
              const SizedBox(height: 24),

              // Register Button
              _buildAnimatedButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedField({
    required Animation<double> animation,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isEmail = false,
  }) {
    return FadeTransition(
      opacity: animation,
      child: Transform.translate(
        offset: Offset(0, (1 - animation.value) * 20),
        child: _buildGlassmorphicField(
          controller: controller,
          label: label,
          hint: hint,
          icon: icon,
          isEmail: isEmail,
        ),
      ),
    );
  }

  Widget _buildGlassmorphicField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isEmail = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: TextFormField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.8)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'this field is required';
              }
              if (isEmail && !value.contains('@')) {
                return 'Please Enter valid email';
              }
              return null;
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedButton() {
    return FadeTransition(
      opacity: _buttonAnimation,
      child: Transform.translate(
        offset: Offset(0, (1 - _buttonAnimation.value) * 20),
        child: _buildGlassmorphicButton(),
      ),
    );
  }

  Widget _buildGlassmorphicButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.withValues(alpha: 0.6),
                Colors.blue.withValues(alpha: 0.4),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _handleRegistration,
              borderRadius: BorderRadius.circular(16),
              child: const Center(
                child: Text(
                  'Register',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Custom Painter for Stars
class StarsPainter extends CustomPainter {
  final double opacity;

  StarsPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final random = math.Random(42); // Fixed seed for consistent stars

    // Draw 150 stars
    for (int i = 0; i < 150; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 2;

      canvas.drawCircle(
        Offset(x, y),
        radius,
        paint..color = Colors.white.withValues(alpha: opacity * random.nextDouble()),
      );
    }
  }

  @override
  bool shouldRepaint(StarsPainter oldDelegate) {
    return oldDelegate.opacity != opacity;
  }
}
