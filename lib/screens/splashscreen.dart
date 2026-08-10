// screens/splashscreen.dart
import 'dart:convert';
import 'package:callingpad_app/app_theme.dart';
import 'package:callingpad_app/models/model.dart';
import 'package:callingpad_app/services/api_service.dart';
import 'package:callingpad_app/services/sharedpref_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _pulseController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0, 0.4)),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );
    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _logoController.forward().then((_) => _textController.forward());

    // Start the navigation check after animations
    Future.delayed(const Duration(milliseconds: 2400), _checkLoginStatus);
  }

  Future<void> _checkLoginStatus() async {
    if (!mounted) return;
    
    try {
      final prefs = await PrefsService.getInstance();
      
      // Check if server config exists
      if (!prefs.hasConfig) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/config');
        }
        return;
      }

      // Get device ID from preferences
      final deviceId = await prefs.getDeviceData() ?? '';
      
      if (deviceId.isEmpty) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      // Initialize API service
      final apiService = ApiService(prefs);
      
      print('🔐 Checking login status for device: $deviceId');
      
      final response = await apiService.login(deviceId: deviceId);
      
      print('🔐 Login response: $response');
      
      if (response['error'] == false) {
        final data = response['data'] as List?;
        if (data != null && data.isNotEmpty) {
          final staffData = data[0] as Map<String, dynamic>;
          final staff = Staff.fromJson(staffData);
          
          // Save staff data
          final staffJson = jsonEncode(staffData);
          await prefs.saveLoginData(staffJson);
          await prefs.saveStaffData(staffJson);
          
          print('✅ Staff data saved: ${staff.staffName}');
          
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          print('⚠️ No staff data in response');
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        }
      } else {
        final message = response['message']?.toString() ?? 'Login failed';
        print('⚠️ Login failed: $message');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
      
    } catch (e) {
      print('❌ Error checking login status: $e');
      if (mounted) {
        // Try to go to home if we have cached login data
        try {
          final prefs = await PrefsService.getInstance();
          final loginData = prefs.loginData;
          if (loginData.isNotEmpty) {
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/home');
            }
          } else {
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          }
        } catch (_) {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.background, AppTheme.background],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _GridPainter()),
            ),
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.primary.withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -60,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.primaryLight.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, child) => Transform.scale(
                      scale: _pulse.value,
                      child: child,
                    ),
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: FadeTransition(
                        opacity: _logoOpacity,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.surface, AppTheme.surface],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withOpacity(0.5),
                                blurRadius: 40,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Image(
                          image: AssetImage('assets/image/ttqbg.png'),
                          width: 95,
                          height: 95,
                        ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 80),
                  FadeTransition(
                    opacity: _textOpacity,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 120,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: const LinearProgressIndicator(
                              backgroundColor: Color(0xFF21262D),
                              valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                              minHeight: 2,
                            ),
                          ),
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
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primary.withOpacity(0.04)
      ..strokeWidth = 0.5;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}