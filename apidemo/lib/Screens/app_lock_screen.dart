import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../Controller/login_controller.dart';
import '../routes/routes.dart';
import '../utils/themes.dart';
import 'data_loading_screen.dart';
import 'loginpage.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> with SingleTickerProviderStateMixin {
  final LoginController _loginController = Get.find<LoginController>();
  bool _isAuthenticating = false;
  bool _showAlternative = false;
  int _attemptCount = 0;
  final int _maxAttempts = 3;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _animationController.forward();

    // Attempt authentication after animations
    Future.delayed(const Duration(milliseconds: 800), _attemptAuthentication);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _attemptAuthentication() async {
    if (_isAuthenticating) return;

    setState(() => _isAuthenticating = true);

    final authenticated = await _loginController.authenticateAppLock();

    if (authenticated) {
      // Authentication successful, proceed to data loading
      Get.offAll(() => const DataLoadingScreen());
    } else {
      _attemptCount++;
      setState(() {
        _isAuthenticating = false;
        _showAlternative = true;
      });

      // If max attempts reached, force logout
      if (_attemptCount >= _maxAttempts) {
        _forceLogout();
      }
    }
  }

  void _forceLogout() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Dialog(
            backgroundColor: Colors.white.withOpacity(0.85),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Authentication Failed',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Maximum attempts reached. Please login again.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: () {
                          Get.back();
                          _loginController.logout(fromAppLock: true);
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _Logout() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Dialog(
            backgroundColor: Colors.white.withOpacity(0.85),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Confirmation',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Are you sure you want to login through a different account?',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => Get.back(),
                        child: Text(
                          'No',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: () {
                          Get.back();
                          _loginController.logout(fromAppLock: true);
                        },
                        child: const Text('Yes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFingerprintIcon(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final iconSize = size.shortestSide * 0.15;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: _isAuthenticating
          ? SizedBox(
        width: iconSize,
        height: iconSize,
        child: CircularProgressIndicator(
          strokeWidth: iconSize * 0.03,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      )
          : Container(
        width: iconSize,
        height: iconSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.2),
              Colors.white.withOpacity(0.1),
            ],
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: iconSize * 0.02,
          ),
        ),
        child: Icon(
          Icons.fingerprint,
          size: iconSize * 0.6,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildAppLogo(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final logoSize = size.shortestSide * 0.2;

    return Container(
      width: logoSize,
      height: logoSize,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            spreadRadius: 1,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(logoSize / 2),
        child: Image.asset(
          'assets/applogo_circle.png',
          width: logoSize,
          height: logoSize,
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
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.agriculture, size: logoSize * 0.3, color: Colors.white),
                    SizedBox(height: logoSize * 0.02),
                    Text(
                      'Manabh\nSoftagri',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: logoSize * 0.1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.height < 600;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image with overlay
          Image.asset(
            "assets/loginbg1.png",
            fit: BoxFit.cover,
          ),
          Container(
            color: Colors.black.withOpacity(0.4),
          ),

          // Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Top section with logo
                          Flexible(
                            flex: 2,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(height: isSmallScreen ? 5 : 10),
                                ScaleTransition(
                                  scale: _scaleAnimation,
                                  child: _buildAppLogo(context),
                                ),
                                SizedBox(height: isSmallScreen ? 5 : 10),
                              ],
                            ),
                          ),

                          // Main content
                          Flexible(
                            flex: 3,
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildFingerprintIcon(context),
                                    SizedBox(height: isSmallScreen ? 15 : 20),
                                    Text(
                                      'App Security',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 20 : 25,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 8,
                                            color: Colors.black.withOpacity(0.5),
                                            offset: const Offset(2, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: isSmallScreen ? 8 : 10),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isSmallScreen ? 15 : 20,
                                      ),
                                      child: Text(
                                        _showAlternative
                                            ? 'Authentication failed. Please try again'
                                            : 'Verify your identity to access your data',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 12 : 15,
                                          color: Colors.white.withOpacity(0.9),
                                          fontWeight: FontWeight.w400,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    if (_showAlternative) ...[
                                      SizedBox(height: isSmallScreen ? 4 : 6),
                                      Text(
                                        'Attempt $_attemptCount of $_maxAttempts',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 11 : 13,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                    SizedBox(height: isSmallScreen ? 15 : 25),
                                    if (_showAlternative) ...[
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: Colors.green[700],
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isSmallScreen ? 24 : 28,
                                            vertical: isSmallScreen ? 8 : 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          elevation: 2,
                                        ),
                                        onPressed: _attemptAuthentication,
                                        child: Text(
                                          'Try Again',
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 13 : 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: isSmallScreen ? 8 : 12),
                                      TextButton(
                                        onPressed: _Logout,
                                        child: Text(
                                          'Use Different Account',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.8),
                                            fontSize: isSmallScreen ? 11 : 13,
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Column(
                                        children: [
                                          Text(
                                            'Authenticating...',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: isSmallScreen ? 10 : 11,
                                            ),
                                          ),
                                          SizedBox(height: isSmallScreen ? 6 : 8),
                                          SizedBox(
                                            width: isSmallScreen ? 14 : 16,
                                            height: isSmallScreen ? 14 : 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.5,
                                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white70),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Footer
                          Flexible(
                            flex: 1,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(height: isSmallScreen ? 5 : 10),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 30),
                                  child: Text(
                                    'Manabh Softagri - Secure Access',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: isSmallScreen ? 10 : 11,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}