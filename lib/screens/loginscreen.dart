// screens/loginscreen.dart
import 'dart:convert';
import 'dart:ui';
import 'package:callingpad_app/app_theme.dart';
import 'package:callingpad_app/services/api_service.dart';
import 'package:callingpad_app/services/device_info.dart';
import 'package:callingpad_app/services/sharedpref_service.dart';
import 'package:callingpad_app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoGlow;

  final DeviceInfoService _deviceInfoService = DeviceInfoService();

  // Responsive breakpoints
  static const double _mobileMaxWidth = 600;
  static const double _tabletMaxWidth = 1200;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoGlow = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOut));

    _logoController.forward().then((_) => _animController.forward());
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  // Helper method to determine screen type
  ScreenType _getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < _mobileMaxWidth) return ScreenType.mobile;
    if (width < _tabletMaxWidth) return ScreenType.tablet;
    return ScreenType.web;
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final prefs = await PrefsService.getInstance();
      final api = ApiService(prefs);

      final deviceInfo = await _deviceInfoService.getDeviceInfo();

      String uniqueDeviceId = deviceInfo['uniqueDeviceId'] ?? 'Android1';
      String deviceBrand = deviceInfo['brand'] ?? 'Samsung';
      String deviceModel = deviceInfo['model'] ?? 'S22';
      int apiLevel = deviceInfo['apiLevel'] ?? 30;
      String deviceType = deviceInfo['isPhysicalDevice'] == true
          ? 'Mobile'
          : 'Virtual';

      int width = MediaQueryData.fromView(
        PlatformDispatcher.instance.views.first,
      ).size.width.toInt();

      final registerRequestBody = {
        'Staff_Username': _usernameController.text.trim(),
        'Staff_Password': _passwordController.text.trim(),
        'DeviceId': uniqueDeviceId,
        'Device_AndroidVersion': apiLevel,
        'Device_ApiLevel': apiLevel,
        'Device_Brand': deviceBrand,
        'Device_Model': deviceModel,
        'Device_Type': deviceType,
        'Device_Width': width,
      };

      print('=== REGISTER REQUEST BODY ===');
      print(jsonEncode(registerRequestBody));
      print('=== END REGISTER REQUEST BODY ===');

      // Step 1: Register the device/user
      final registerResp = await api.register(
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
        deviceId: uniqueDeviceId,
        androidVersion: apiLevel,
        apiLevel: apiLevel,
        brand: deviceBrand,
        model: deviceModel,
        deviceType: deviceType,
        width: width,
      );

      print('=== REGISTER RESPONSE ===');
      print('Response: $registerResp');
      print('=== END REGISTER RESPONSE ===');

      if (!mounted) return;

      if (registerResp['error'] == true) {
        _showError(
          registerResp['message']?.toString() ?? 'Registration failed',
        );
        setState(() => _isLoading = false);
        return;
      }

      // Step 2: After successful registration, call login
      print('🔐 Registration successful, calling login...');

      final loginResp = await api.login(deviceId: uniqueDeviceId);

      print('=== LOGIN RESPONSE ===');
      print('Response: $loginResp');
      print('=== END LOGIN RESPONSE ===');

      if (!mounted) return;

      if (loginResp['error'] == false) {
        final data = loginResp['data'] as List?;
        if (data != null && data.isNotEmpty) {
          final staffJson = jsonEncode(data[0]);
          await prefs.saveLoginData(staffJson);
          await prefs.saveStaffData(staffJson);
          await prefs.saveDeviceData(uniqueDeviceId);

          print('✅ Login successful, navigating to home');

          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          _showError('Invalid response from server.');
          setState(() => _isLoading = false);
        }
      } else {
        final message = loginResp['message']?.toString() ?? 'Login failed';
        _showError('Registration succeeded but login failed: $message');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('=== LOGIN ERROR ===');
      print('Error: $e');
      print('=== END ERROR ===');
      _showError('Connection failed: ${e.toString()}');
      setState(() => _isLoading = false);
    } finally {
      // Only set loading to false if we haven't navigated away
      if (mounted) {
        // Don't set isLoading to false if we're about to navigate
        // The navigation will dispose the widget anyway
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: AppTheme.error,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenType = _getScreenType(context);
    final isMobile = screenType == ScreenType.mobile;
    final isTablet = screenType == ScreenType.tablet;
    final isWeb = screenType == ScreenType.web;

    // Responsive dimensions
    final horizontalPadding = isMobile
        ? 20.0
        : isTablet
        ? 40.0
        : 60.0;
    final verticalPadding = isMobile
        ? 20.0
        : isTablet
        ? 40.0
        : 60.0;
    final maxContentWidth = isWeb
        ? 520.0
        : isTablet
        ? 480.0
        : double.infinity;
    final logoSize = isMobile
        ? 90.0
        : isTablet
        ? 110.0
        : 120.0;
    final spacing = isMobile
        ? 14.0
        : isTablet
        ? 18.0
        : 22.0;
    final buttonHeight = isMobile
        ? 52.0
        : isTablet
        ? 56.0
        : 58.0;
    final fontSizeScale = isMobile
        ? 1.0
        : isTablet
        ? 1.1
        : 1.2;
    final cardPadding = isMobile
        ? 24.0
        : isTablet
        ? 32.0
        : 36.0;
    final cardRadius = isMobile
        ? 24.0
        : isTablet
        ? 30.0
        : 36.0;
    final titleFontSize = isMobile
        ? 22.0
        : isTablet
        ? 26.0
        : 28.0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.background, AppTheme.background],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Decorative background circles - responsive
              Positioned(
                top: isMobile ? -40 : -60,
                left: isMobile ? -40 : -60,
                child: Container(
                  width: isMobile ? 180 : 250,
                  height: isMobile ? 180 : 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.primary.withOpacity(0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: isMobile ? -60 : -80,
                right: isMobile ? -30 : -40,
                child: Container(
                  width: isMobile ? 160 : 220,
                  height: isMobile ? 160 : 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.primaryLight.withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo with enhanced animation
                        ScaleTransition(
                          scale: _logoScale,
                          child: AnimatedBuilder(
                            animation: _logoGlow,
                            builder: (context, child) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppTheme.surface,
                                      AppTheme.surface,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary.withOpacity(
                                        0.45 * _logoGlow.value,
                                      ),
                                      blurRadius:
                                          32 * (1 + _logoGlow.value * 0.3),
                                      spreadRadius: 2 * _logoGlow.value,
                                    ),
                                  ],
                                ),
                                child: Image(
                                  image: const AssetImage(
                                    'assets/image/ttqbg.png',
                                  ),
                                  width: logoSize,
                                  height: logoSize,
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: spacing * 3.5),

                        // Login Card
                        FadeTransition(
                          opacity: _fadeAnim,
                          child: SlideTransition(
                            position: _slideAnim,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: maxContentWidth,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                    cardRadius,
                                  ),
                                  border: Border.all(
                                    color: AppTheme.primary.withOpacity(0.2),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary.withOpacity(0.08),
                                      blurRadius: 30,
                                      offset: const Offset(0, 8),
                                      spreadRadius: 4,
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 50,
                                      offset: const Offset(0, 12),
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(cardPadding),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Title
                                        Text(
                                          'Sign In',
                                          style: GoogleFonts.spaceGrotesk(
                                            color: AppTheme.primary,
                                            fontSize: titleFontSize,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        SizedBox(height: spacing * 0.5),

                                        // Subtitle
                                        Text(
                                          'Enter your credentials to continue',
                                          style: GoogleFonts.inter(
                                            color: AppTheme.textSecondary,
                                            fontSize: 13 * fontSizeScale,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        SizedBox(height: spacing * 2),

                                        // Username field
                                        TextFormField(
                                          controller: _usernameController,
                                          style: TextStyle(
                                            color: AppTheme.primary,
                                            fontSize: 15 * fontSizeScale,
                                          ),
                                          validator: (v) =>
                                              v == null || v.trim().isEmpty
                                              ? 'Username is required'
                                              : null,
                                          decoration: InputDecoration(
                                            labelText: 'Username',
                                            labelStyle: TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 13 * fontSizeScale,
                                            ),
                                            hintText: 'Enter your username',
                                            hintStyle: TextStyle(
                                              color: AppTheme.textSecondary
                                                  .withOpacity(0.5),
                                              fontSize: 13 * fontSizeScale,
                                            ),
                                            prefixIcon: Icon(
                                              Icons.person_outline_rounded,
                                              color: AppTheme.primary,
                                              size: isMobile ? 22 : 24,
                                            ),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: isMobile
                                                      ? 14
                                                      : 18,
                                                  vertical: isMobile ? 14 : 18,
                                                ),
                                            filled: true,
                                            fillColor: AppTheme.surfaceVariant
                                                .withOpacity(0.1),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: AppTheme.primary
                                                    .withOpacity(0.3),
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: AppTheme.primary
                                                    .withOpacity(0.3),
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: AppTheme.primary,
                                                width: 2,
                                              ),
                                            ),
                                            errorBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: const BorderSide(
                                                color: AppTheme.error,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: spacing),

                                        // Password field
                                        TextFormField(
                                          controller: _passwordController,
                                          obscureText: _obscurePassword,
                                          style: TextStyle(
                                            color: AppTheme.primary,
                                            fontSize: 15 * fontSizeScale,
                                          ),
                                          validator: (v) =>
                                              v == null || v.trim().isEmpty
                                              ? 'Password is required'
                                              : null,
                                          decoration: InputDecoration(
                                            labelText: 'Password',
                                            labelStyle: TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 13 * fontSizeScale,
                                            ),
                                            hintText: 'Enter your password',
                                            hintStyle: TextStyle(
                                              color: AppTheme.textSecondary
                                                  .withOpacity(0.5),
                                              fontSize: 13 * fontSizeScale,
                                            ),
                                            prefixIcon: Icon(
                                              Icons.lock_outline_rounded,
                                              color: AppTheme.primary,
                                              size: isMobile ? 22 : 24,
                                            ),
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _obscurePassword
                                                    ? Icons
                                                          .visibility_off_outlined
                                                    : Icons.visibility_outlined,
                                                size: isMobile ? 20 : 22,
                                                color: AppTheme.textSecondary,
                                              ),
                                              onPressed: () => setState(
                                                () => _obscurePassword =
                                                    !_obscurePassword,
                                              ),
                                            ),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: isMobile
                                                      ? 14
                                                      : 18,
                                                  vertical: isMobile ? 14 : 18,
                                                ),
                                            filled: true,
                                            fillColor: AppTheme.surfaceVariant
                                                .withOpacity(0.1),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: AppTheme.primary
                                                    .withOpacity(0.3),
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: AppTheme.primary
                                                    .withOpacity(0.3),
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: AppTheme.primary,
                                                width: 2,
                                              ),
                                            ),
                                            errorBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: const BorderSide(
                                                color: AppTheme.error,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: spacing * 0.5),

                                        // Login button
                                        SizedBox(
                                          width: double.infinity,
                                          height: buttonHeight,
                                          child: ElevatedButton(
                                            onPressed: _isLoading
                                                ? null
                                                : _login,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.primary,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              elevation: 0,
                                              padding: EdgeInsets.zero,
                                            ),
                                            child: Container(
                                              alignment: Alignment.center,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                  ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.login_rounded,
                                                    size: isMobile ? 20 : 22,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    'Sign In',
                                                    style: GoogleFonts.inter(
                                                      fontSize:
                                                          16 * fontSizeScale,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      letterSpacing: 0.3,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: spacing * 1.5),

                        // Server config link
                        FadeTransition(
                          opacity: _fadeAnim,
                          child: TextButton.icon(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/config'),
                            icon: Icon(
                              Icons.settings_outlined,
                              size: isMobile ? 16 : 18,
                              color: AppTheme.textSecondary,
                            ),
                            label: Text(
                              'Server Configuration',
                              style: GoogleFonts.inter(
                                color: AppTheme.textSecondary,
                                fontSize: 13 * fontSizeScale,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
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
        ),
      ),
    );
  }
}

// Screen type enum (matching config screen)
enum ScreenType { mobile, tablet, web }
