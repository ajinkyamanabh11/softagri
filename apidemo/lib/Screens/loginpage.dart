import 'dart:math';
import 'dart:math' as math;
import 'dart:ui';
import 'package:apidemo/Screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../Controller/login_controller.dart';
import 'homeScreen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final LoginController _loginController = Get.put(LoginController());
  final TextEditingController _usernameController = TextEditingController();
  final FocusNode _usernameFocusNode = FocusNode();

  // Single animation controller for sequential animations
  late AnimationController _masterAnimationController;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  // Particle system variables
  final List<Particle> _particles = [];
  late AnimationController _particleAnimationController;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeParticles();
  }

  void _initializeAnimations() {
    // Master animation controller
    _masterAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Opacity animation
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterAnimationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    // Scale animation
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterAnimationController,
        curve: const Interval(0.3, 0.8, curve: Curves.elasticOut),
      ),
    );

    // Slide animation
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _masterAnimationController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    // Particle animation
    _particleAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Start animations
    _masterAnimationController.forward();
  }

  void _initializeParticles() {
    // Create floating particles
    for (int i = 0; i < 15; i++) {
      _particles.add(Particle());
    }
  }

  @override
  void dispose() {
    _masterAnimationController.dispose();
    _particleAnimationController.dispose();
    _usernameController.dispose();
    _usernameFocusNode.dispose();
    super.dispose();
  }

  Widget _buildAppLogo() {
    return Container(
      width: 110, // Reduced from 140
      height: 110, // Reduced from 140
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.white.withOpacity(0.8),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(55), // Adjusted for new size
        child: Image.asset(
          "assets/applogo_circle.png",
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.green[400]!,
                    Colors.green[600]!,
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.agriculture,
                size: 50, // Reduced from 60
                color: Colors.white,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildParticles() {
    return AnimatedBuilder(
      animation: _particleAnimationController,
      builder: (context, child) {
        // Update particles
        for (var particle in _particles) {
          particle.update();
        }

        return CustomPaint(
          painter: ParticlePainter(_particles),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildLoginForm() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Improved Input field with icon
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child:Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                        child: TextField(
                          controller: _usernameController,
                          focusNode: _usernameFocusNode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.transparent,
                            prefixIcon: Container(
                              margin: const EdgeInsets.only(left: 12, right: 8),
                              child: Icon(
                                Icons.badge_outlined,
                                color: Colors.white.withOpacity(0.9),
                                size: 22,
                              ),
                            ),
                            hintText: 'Enter your ID number',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            isDense: true,
                          ),
                          cursorColor: Colors.white,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Login button
                Obx(
                      () => ElevatedButton(
                    onPressed: _loginController.isLoading.value
                        ? null
                        : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF2E7D32),
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 5,
                      shadowColor: Colors.black.withOpacity(0.3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 14,
                      ),
                    ),
                    child: _loginController.isLoading.value
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF2E7D32)),
                      ),
                    )
                        : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Continue",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ),
                ),

                Spacer(),

                // Help text
                Text(
                  'Enter your unique ID provided by your organization',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleLogin() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      _showErrorSnackbar('Please enter your ID number');
      return;
    }

    FocusScope.of(context).unfocus();

    final success = await _loginController.login(username);
    if (success) {
      _showSuccessAnimation();
      await Future.delayed(const Duration(milliseconds: 800));
      Get.offAll(() => const SplashScreen());
    } else {
      _showErrorSnackbar('Invalid ID number. Please try again.');
    }
  }

  void _showErrorSnackbar(String message) {
    Get.snackbar(
      'Error',
      message,
      colorText: Colors.white,
      backgroundColor: Colors.red.withOpacity(0.8),
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(20),
      borderRadius: 15,
      animationDuration: const Duration(milliseconds: 300),
    );
  }

  void _showSuccessAnimation() {
    // You can add a success animation here
    // For example, show a confetti effect or checkmark animation
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image with gradient overlay
          Image.asset(
            "assets/loginbg1.png",
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),

          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.4),
                ],
              ),
            ),
          ),

          // Floating particles
          _buildParticles(),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                height: size.height,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top section with logo and title
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          // App logo with animation
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: FadeTransition(
                              opacity: _opacityAnimation,
                              child: _buildAppLogo(),
                            ),
                          ),
                          const SizedBox(height: 20), // Reduced from 25

                          // App name with animation
                          FadeTransition(
                            opacity: _opacityAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: const Text(
                                'Manabh Softagri',
                                style: TextStyle(
                                  fontSize: 28, // Reduced from 32
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2, // Reduced from 1.5
                                  shadows: [
                                    Shadow(
                                      blurRadius: 10,
                                      color: Colors.black,
                                      offset: Offset(2, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 6), // Reduced from 8

                          // Tagline with animation
                          FadeTransition(
                            opacity: _opacityAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: Text(
                                'Agricultural Management Solution',
                                style: TextStyle(
                                  fontSize: 14, // Reduced from 16
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: 1.0, // Reduced from 1.2
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Login form section
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        child: _buildLoginForm(),
                      ),
                    ),

                    // Footer
                    Padding(
                      padding: const EdgeInsets.only(bottom: 30),
                      child: Text(
                        'Secure Login • Version 1.0.0',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
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
}

// Particle system for background animation
class Particle {
  double x = 0;
  double y = 0;
  double size = 0;
  double speed = 0;
  double angle = 0;
  double opacity = 0;

  Particle() {
    reset();
  }

  void reset() {
    x = Random().nextDouble() * 400;
    y = Random().nextDouble() * 800;
    size = Random().nextDouble() * 3 + 1;
    speed = Random().nextDouble() * 0.5 + 0.1;
    angle = Random().nextDouble() * 360;
    opacity = Random().nextDouble() * 0.5 + 0.3;
  }

  void update() {
    x += math.cos(angle * math.pi / 180) * speed;
    y += math.sin(angle * math.pi / 180) * speed;

    if (x < -50 || x > 450 || y < -50 || y > 850) {
      reset();
    }
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.srcOver;

    for (var particle in particles) {
      paint.color = Colors.white.withOpacity(particle.opacity);
      canvas.drawCircle(
        Offset(particle.x, particle.y),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}