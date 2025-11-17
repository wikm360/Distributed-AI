import 'dart:math';
import 'package:flutter/material.dart';

class StarfieldBackground extends StatefulWidget {
  final Widget child;
  final int starCount;
  final Color backgroundColor;

  const StarfieldBackground({
    super.key,
    required this.child,
    this.starCount = 100,
    this.backgroundColor = const Color(0xFF0F0F0F),
  });

  @override
  State<StarfieldBackground> createState() => _StarfieldBackgroundState();
}

class _StarfieldBackgroundState extends State<StarfieldBackground>
    with TickerProviderStateMixin {
  late List<Star> _stars;
  late List<AnimationController> _controllers;
  final Random _random = Random();

  // Shooting star
  ShootingStar? _shootingStar;
  AnimationController? _shootingStarController;

  // Spaceship
  Spaceship? _spaceship;
  AnimationController? _spaceshipController;

  @override
  void initState() {
    super.initState();
    _initializeStars();
    _scheduleShootingStar();
    _scheduleSpaceship();
  }

  void _initializeStars() {
    _stars = List.generate(widget.starCount, (_) => _createStar());
    _controllers = List.generate(widget.starCount, (index) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 1500 + _random.nextInt(3000)),
      );

      // Start at random points in the animation
      controller.value = _random.nextDouble();
      controller.repeat(reverse: true);

      return controller;
    });
  }

  Star _createStar() {
    return Star(
      x: _random.nextDouble(),
      y: _random.nextDouble(),
      size: 0.5 + _random.nextDouble() * 2.0,
      baseOpacity: 0.3 + _random.nextDouble() * 0.7,
    );
  }

  void _scheduleShootingStar() {
    // Random interval between 3-10 seconds
    final delay = Duration(seconds: 3 + _random.nextInt(8));
    Future.delayed(delay, () {
      if (mounted) {
        _createShootingStar();
        _scheduleShootingStar();
      }
    });
  }

  void _createShootingStar() {
    _shootingStarController?.dispose();

    // Random start position (top or right edge)
    final startFromTop = _random.nextBool();
    double startX, startY, endX, endY;

    if (startFromTop) {
      startX = 0.2 + _random.nextDouble() * 0.6;
      startY = 0.0;
      endX = startX - 0.3 - _random.nextDouble() * 0.3;
      endY = 0.6 + _random.nextDouble() * 0.4;
    } else {
      startX = 1.0;
      startY = _random.nextDouble() * 0.4;
      endX = -0.2;
      endY = startY + 0.3 + _random.nextDouble() * 0.4;
    }

    _shootingStar = ShootingStar(
      startX: startX,
      startY: startY,
      endX: endX,
      endY: endY,
      tailLength: 0.1 + _random.nextDouble() * 0.15,
    );

    _shootingStarController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800 + _random.nextInt(600)),
    );

    _shootingStarController!.forward().then((_) {
      if (mounted) {
        setState(() {
          _shootingStar = null;
        });
      }
    });

    setState(() {});
  }

  void _scheduleSpaceship() {
    // Much rarer - every 20-60 seconds
    final delay = Duration(seconds: 20 + _random.nextInt(40));
    Future.delayed(delay, () {
      if (mounted) {
        _createSpaceship();
        _scheduleSpaceship();
      }
    });
  }

  void _createSpaceship() {
    _spaceshipController?.dispose();

    final goingRight = _random.nextBool();
    final yPosition = 0.1 + _random.nextDouble() * 0.6;

    _spaceship = Spaceship(
      startX: goingRight ? -0.1 : 1.1,
      endX: goingRight ? 1.1 : -0.1,
      y: yPosition,
      size: 8 + _random.nextDouble() * 6,
      goingRight: goingRight,
    );

    _spaceshipController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 4000 + _random.nextInt(3000)),
    );

    _spaceshipController!.forward().then((_) {
      if (mounted) {
        setState(() {
          _spaceship = null;
        });
      }
    });

    setState(() {});
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    _shootingStarController?.dispose();
    _spaceshipController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      child: Stack(
        children: [
          // Starfield layer
          Positioned.fill(
            child: CustomPaint(
              painter: StarfieldPainter(
                stars: _stars,
                controllers: _controllers,
                shootingStar: _shootingStar,
                shootingStarController: _shootingStarController,
                spaceship: _spaceship,
                spaceshipController: _spaceshipController,
              ),
            ),
          ),
          // Content layer
          widget.child,
        ],
      ),
    );
  }
}

class Star {
  final double x;
  final double y;
  final double size;
  final double baseOpacity;

  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.baseOpacity,
  });
}

class ShootingStar {
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final double tailLength;

  ShootingStar({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.tailLength,
  });
}

class Spaceship {
  final double startX;
  final double endX;
  final double y;
  final double size;
  final bool goingRight;

  Spaceship({
    required this.startX,
    required this.endX,
    required this.y,
    required this.size,
    required this.goingRight,
  });
}

class StarfieldPainter extends CustomPainter {
  final List<Star> stars;
  final List<AnimationController> controllers;
  final ShootingStar? shootingStar;
  final AnimationController? shootingStarController;
  final Spaceship? spaceship;
  final AnimationController? spaceshipController;

  StarfieldPainter({
    required this.stars,
    required this.controllers,
    this.shootingStar,
    this.shootingStarController,
    this.spaceship,
    this.spaceshipController,
  }) : super(
          repaint: Listenable.merge([
            ...controllers,
            if (shootingStarController != null) shootingStarController,
            if (spaceshipController != null) spaceshipController,
          ]),
        );

  @override
  void paint(Canvas canvas, Size size) {
    // Draw stars
    for (int i = 0; i < stars.length; i++) {
      final star = stars[i];
      final animValue = controllers[i].value;

      // Calculate opacity with twinkling effect
      final opacity = star.baseOpacity * (0.3 + 0.7 * animValue);

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      final position = Offset(
        star.x * size.width,
        star.y * size.height,
      );

      // Draw star with slight glow effect
      canvas.drawCircle(position, star.size, paint);

      // Add subtle glow for brighter stars
      if (star.size > 1.5 && opacity > 0.6) {
        final glowPaint = Paint()
          ..color = Colors.white.withValues(alpha: opacity * 0.3)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(position, star.size * 2, glowPaint);
      }
    }

    // Draw shooting star
    if (shootingStar != null && shootingStarController != null) {
      _drawShootingStar(canvas, size);
    }

    // Draw spaceship
    if (spaceship != null && spaceshipController != null) {
      _drawSpaceship(canvas, size);
    }
  }

  void _drawShootingStar(Canvas canvas, Size size) {
    final progress = shootingStarController!.value;
    final ss = shootingStar!;

    final currentX = ss.startX + (ss.endX - ss.startX) * progress;
    final currentY = ss.startY + (ss.endY - ss.startY) * progress;

    final headPos = Offset(currentX * size.width, currentY * size.height);

    // Calculate tail direction
    final dx = ss.endX - ss.startX;
    final dy = ss.endY - ss.startY;
    final length = sqrt(dx * dx + dy * dy);
    final tailDx = -dx / length * ss.tailLength;
    final tailDy = -dy / length * ss.tailLength;

    final tailPos = Offset(
      (currentX + tailDx) * size.width,
      (currentY + tailDy) * size.height,
    );

    // Draw tail with gradient
    final gradient = LinearGradient(
      colors: [
        Colors.white.withValues(alpha: 0.0),
        Colors.white.withValues(alpha: 0.8),
      ],
    ).createShader(Rect.fromPoints(tailPos, headPos));

    final tailPaint = Paint()
      ..shader = gradient
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(tailPos, headPos, tailPaint);

    // Draw head
    final headPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(headPos, 2.5, headPaint);

    // Glow effect
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(headPos, 4, glowPaint);
  }

  void _drawSpaceship(Canvas canvas, Size size) {
    final progress = spaceshipController!.value;
    final ship = spaceship!;

    final currentX = ship.startX + (ship.endX - ship.startX) * progress;
    final pos = Offset(currentX * size.width, ship.y * size.height);

    canvas.save();
    canvas.translate(pos.dx, pos.dy);

    if (!ship.goingRight) {
      canvas.scale(-1, 1);
    }

    // Draw spaceship body
    final bodyPath = Path();
    bodyPath.moveTo(ship.size, 0); // Nose
    bodyPath.lineTo(-ship.size * 0.6, -ship.size * 0.3); // Top back
    bodyPath.lineTo(-ship.size * 0.8, 0); // Back center
    bodyPath.lineTo(-ship.size * 0.6, ship.size * 0.3); // Bottom back
    bodyPath.close();

    final bodyPaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.fill;
    canvas.drawPath(bodyPath, bodyPaint);

    // Draw cockpit
    final cockpitPaint = Paint()
      ..color = Colors.lightBlue.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(ship.size * 0.3, 0),
        width: ship.size * 0.5,
        height: ship.size * 0.25,
      ),
      cockpitPaint,
    );

    // Draw engine glow
    final engineGlow = Paint()
      ..color = Colors.orange.withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(-ship.size * 0.9, 0), ship.size * 0.2, engineGlow);

    // Draw thruster trail
    final trailPaint = Paint()
      ..color = Colors.orange.withValues(alpha: 0.4)
      ..strokeWidth = ship.size * 0.15
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-ship.size * 0.9, 0),
      Offset(-ship.size * 2.0, 0),
      trailPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(StarfieldPainter oldDelegate) => true;
}
