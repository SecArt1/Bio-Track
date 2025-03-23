import 'package:flutter/material.dart';
import 'package:bio_track/logInPage.dart';
import 'package:bio_track/register.dart';
import 'package:bio_track/stillStart.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'dart:math' as math;
import 'dart:async';

class StartScreen extends StatefulWidget {
  @override
  _StartScreenState createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  late DraggableScrollableController _controller;
  bool _showLogoAndText = false;
  bool _showHeartbeat = true; // New state variable

  @override
  void initState() {
    super.initState();
    _controller = DraggableScrollableController();
    _controller.addListener(_onSwipe);
  }

  @override
  void dispose() {
    _controller.removeListener(_onSwipe);
    _controller.dispose();
    super.dispose();
  }

  void _onSwipe() {
    final size = _controller.size;
    if (size > 0.1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0383c2),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with delayed appearance
                if (_showLogoAndText) ...[
                  AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 500),
                    child: Center(
                      child: Image.asset('assets/Logo.png', width: 300),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (_showHeartbeat) // Conditional rendering for heartbeat
                  Center(
                    child: HeartbeatAnimation(
                      onComplete: () {
                        setState(() {
                          _showLogoAndText = true;
                          _showHeartbeat = false; // Hide heartbeat
                        });
                      },
                    ),
                  ),
                const SizedBox(height: 20),
                // Text with delayed appearance
                if (_showLogoAndText)
                  AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 500),
                    child: Center(
                      child: AnimatedTextKit(
                        animatedTexts: [
                          TypewriterAnimatedText(
                            'Your Health, Your Data,\n Your Control',
                            textStyle: const TextStyle(
                              fontSize: 22.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            speed: const Duration(milliseconds: 200),
                          ),
                        ],
                        totalRepeatCount: 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          DraggableScrollableSheet(
            controller: _controller,
            initialChildSize: 0.1,
            minChildSize: 0.1,
            maxChildSize: 0.5,
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                color: const Color(0xff0383c2),
                child: ListView(
                  controller: scrollController,
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            // Only show SwipeUpIndicator after heartbeat animation completes
                            if (_showLogoAndText) // This ties it to the same condition as logo/text
                              AnimatedOpacity(
                                opacity: 1.0,
                                duration: const Duration(milliseconds: 500),
                                child: SwipeUpIndicator(), 
                              ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class HeartbeatPainter extends CustomPainter {
  final double value;

  HeartbeatPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final path = Path();

    // Starting point
    path.moveTo(0, size.height * 0.5);

    // P wave (small bump)
    path.lineTo(size.width * 0.1, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.15, size.height * 0.4,
        size.width * 0.2, size.height * 0.5);

    // PR segment (flat)
    path.lineTo(size.width * 0.25, size.height * 0.5);

    // QRS complex
    path.lineTo(size.width * 0.3, size.height * 0.6); // Q wave
    path.lineTo(size.width * 0.35, size.height * 0.1); // R wave peak
    path.lineTo(size.width * 0.4, size.height * 0.7); // S wave

    // ST segment
    path.lineTo(size.width * 0.45, size.height * 0.5);

    // T wave
    path.quadraticBezierTo(size.width * 0.5, size.height * 0.3,
        size.width * 0.55, size.height * 0.5);

    // Continue baseline
    path.lineTo(size.width, size.height * 0.5);

    final animatedPath = Path();
    final pathMetric = path.computeMetrics().first;
    animatedPath.addPath(
      pathMetric.extractPath(0, pathMetric.length * value),
      Offset.zero,
    );

    canvas.drawPath(animatedPath, paint);
  }

  @override
  bool shouldRepaint(HeartbeatPainter oldDelegate) => true;
}

class HeartbeatAnimation extends StatefulWidget {
  final VoidCallback? onComplete;

  const HeartbeatAnimation({
    Key? key,
    this.onComplete,
  }) : super(key: key);

  @override
  _HeartbeatAnimationState createState() => _HeartbeatAnimationState();
}

class _HeartbeatAnimationState extends State<HeartbeatAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(count: 2); // Show exactly 2 intervals

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _completed = true;
        });
        // Notify parent to show logo and text
        if (widget.onComplete != null) {
          widget.onComplete!();
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: screenWidth,
          height: 60, // Increased height for better visibility
          child: CustomPaint(
            painter: HeartbeatPainter(_controller.value),
          ),
        );
      },
    );
  }
}

class LogoAnimation extends StatefulWidget {
  const LogoAnimation({Key? key}) : super(key: key);

  @override
  _LogoAnimationState createState() => _LogoAnimationState();
}

class _LogoAnimationState extends State<LogoAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Image.asset('assets/Logo.png', width: 300),
        );
      },
    );
  }
}

class SwipeUpIndicator extends StatefulWidget {
  const SwipeUpIndicator({Key? key}) : super(key: key);

  @override
  _SwipeUpIndicatorState createState() => _SwipeUpIndicatorState();
}

class _SwipeUpIndicatorState extends State<SwipeUpIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -0.5),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SlideTransition(
          position: _offsetAnimation,
          child: Column(
            children: [
              const Text(
                "Swipe Up",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              const Icon(
                Icons.keyboard_arrow_up,
                color: Colors.white,
                size: 36.0,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
