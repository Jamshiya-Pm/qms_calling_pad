// screens/configscreen.dart
import 'package:callingpad_app/app_theme.dart';
import 'package:callingpad_app/services/sharedpref_service.dart';
import 'package:callingpad_app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  String _selectedScheme = 'http';
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _scaleAnim;

  // Responsive breakpoints
  static const double _mobileMaxWidth = 600;
  static const double _tabletMaxWidth = 1200;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _scaleAnim = Tween<double>(begin: 0.95, end: 1.0)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutBack));
    _animController.forward();
    _loadSavedConfig();
  }

  Future<void> _loadSavedConfig() async {
    final prefs = await PrefsService.getInstance();
    if (prefs.hasConfig) {
      setState(() {
        _selectedScheme = prefs.scheme.isNotEmpty ? prefs.scheme : 'http';
        _hostController.text = prefs.host;
        _portController.text = prefs.port;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final prefs = await PrefsService.getInstance();
      await prefs.saveConfig(
        scheme: _selectedScheme,
        host: _hostController.text.trim(),
        port: _portController.text.trim(),
      );
      if (!mounted) return;
      _showSnack('Configuration saved successfully!', AppTheme.success);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      _showSnack('Failed to save configuration.', AppTheme.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // Helper method to determine screen type
  ScreenType _getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < _mobileMaxWidth) return ScreenType.mobile;
    if (width < _tabletMaxWidth) return ScreenType.tablet;
    return ScreenType.web;
  }

  @override
  Widget build(BuildContext context) {
    final screenType = _getScreenType(context);
    final isMobile = screenType == ScreenType.mobile;
    final isTablet = screenType == ScreenType.tablet;
    final isWeb = screenType == ScreenType.web;

    // Responsive dimensions
    final horizontalPadding = isMobile ? 20.0 : isTablet ? 40.0 : 60.0;
    final verticalPadding = isMobile ? 20.0 : isTablet ? 40.0 : 60.0;
    final maxContentWidth = isWeb ? 580.0 : isTablet ? 520.0 : double.infinity;
    final logoSize = isMobile ? 70.0 : isTablet ? 90.0 : 100.0;
    final spacing = isMobile ? 14.0 : isTablet ? 18.0 : 22.0;
    final buttonHeight = isMobile ? 52.0 : isTablet ? 56.0 : 60.0;
    final fontSizeScale = isMobile ? 1.0 : isTablet ? 1.1 : 1.2;
    final cardPadding = isMobile ? 24.0 : isTablet ? 36.0 : 44.0;
    final cardRadius = isMobile ? 24.0 : isTablet ? 30.0 : 36.0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(cardRadius),
                          // Decorative border on all 4 sides
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
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                            
                               
                                // Logo
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppTheme.primary,
                                        AppTheme.primaryLight,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primary.withOpacity(0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Image(
                                      image: const AssetImage('assets/icon/ttcallpad.png'),
                                      width: logoSize,
                                      height: logoSize,
                                    ),
                                  ),
                                ),
                                SizedBox(height: spacing),

                                // // Title
                                // Text(
                                //   'Server Configuration',
                                //   style: GoogleFonts.inter(
                                //     color: AppTheme.textPrimary,
                                //     fontSize: 22 * fontSizeScale,
                                //     fontWeight: FontWeight.w700,
                                //     letterSpacing: 0.5,
                                //   ),
                                // ),
                                // SizedBox(height: spacing * 0.5),

                                // Subtitle
                                Text(
                                  'Connect to your calling pad server',
                                  style: GoogleFonts.inter(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13 * fontSizeScale,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                SizedBox(height: spacing * 1.2),

                                // Info card
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 14 : 18,
                                    vertical: isMobile ? 12 : 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.primary.withOpacity(0.12),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.info_outline_rounded,
                                          color: AppTheme.primary,
                                          size: isMobile ? 18 : 20,
                                        ),
                                      ),
                                      SizedBox(width: isMobile ? 10 : 14),
                                      Expanded(
                                        child: Text(
                                          'Enter your server address to connect the calling pad.',
                                          style: GoogleFonts.inter(
                                            color: AppTheme.textSecondary,
                                            fontSize: 12 * fontSizeScale,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: spacing),

                                // Protocol selection
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 14 : 18,
                                    vertical: isMobile ? 6 : 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceVariant.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.primary.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.http_rounded,
                                        color: AppTheme.textSecondary,
                                        size: isMobile ? 20 : 22,
                                      ),
                                      SizedBox(width: isMobile ? 10 : 14),
                                      Text(
                                        'Protocol',
                                        style: GoogleFonts.inter(
                                          color: AppTheme.textSecondary,
                                          fontSize: 14 * fontSizeScale,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const Spacer(),
                                      _SchemeToggle(
                                        selected: _selectedScheme,
                                        onChanged: (v) =>
                                            setState(() => _selectedScheme = v),
                                        fontSizeScale: fontSizeScale,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: spacing),

                                // Host input
                                TextFormField(
                                  controller: _hostController,
                                  keyboardType: TextInputType.url,
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 15 * fontSizeScale,
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty
                                      ? 'Host is required'
                                      : null,
                                  decoration: InputDecoration(
                                    labelText: 'Host / IP Address',
                                    labelStyle: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13 * fontSizeScale,
                                    ),
                                    hintText: 'e.g. 192.168.1.100',
                                    hintStyle: TextStyle(
                                      color: AppTheme.textSecondary.withOpacity(0.5),
                                      fontSize: 13 * fontSizeScale,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.dns_rounded,
                                      color: AppTheme.primary,
                                      size: isMobile ? 22 : 24,
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 14 : 18,
                                      vertical: isMobile ? 14 : 18,
                                    ),
                                    filled: true,
                                    fillColor: AppTheme.surfaceVariant.withOpacity(0.1),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppTheme.primary.withOpacity(0.3),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppTheme.primary.withOpacity(0.3),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppTheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: AppTheme.error,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: spacing),

                                // Port input
                                TextFormField(
                                  controller: _portController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 15 * fontSizeScale,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Port (optional)',
                                    labelStyle: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13 * fontSizeScale,
                                    ),
                                    hintText: 'e.g. 8080',
                                    hintStyle: TextStyle(
                                      color: AppTheme.textSecondary.withOpacity(0.5),
                                      fontSize: 13 * fontSizeScale,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.electrical_services_rounded,
                                      color: AppTheme.primary,
                                      size: isMobile ? 22 : 24,
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 14 : 18,
                                      vertical: isMobile ? 14 : 18,
                                    ),
                                    filled: true,
                                    fillColor: AppTheme.surfaceVariant.withOpacity(0.1),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppTheme.primary.withOpacity(0.3),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppTheme.primary.withOpacity(0.3),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppTheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: spacing * 2),

                                // Submit button
                                SizedBox(
                                  width: double.infinity,
                                  height: buttonHeight,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _save,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: Container(
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.save_rounded,
                                            size: isMobile ? 20 : 22,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Save & Continue',
                                            style: GoogleFonts.inter(
                                              fontSize: 16 * fontSizeScale,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: spacing * 0.8),

                                // Version text
                                Text(
                                  'TTCalling Pad v1.0.0',
                                  style: GoogleFonts.inter(
                                    color: const Color.fromARGB(255, 123, 123, 125).withOpacity(0.6),
                                    fontSize: 11 * fontSizeScale,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: spacing * 0.3),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
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

// Enhanced scheme toggle
class _SchemeToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final double fontSizeScale;

  const _SchemeToggle({
    required this.selected,
    required this.onChanged,
    this.fontSizeScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['http', 'https'].map((scheme) {
          final isSelected = selected == scheme;
          return GestureDetector(
            onTap: () => onChanged(scheme),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: 14 * fontSizeScale,
                vertical: 7 * fontSizeScale,
              ),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                scheme.toUpperCase(),
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  fontSize: 11 * fontSizeScale,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Screen type enum
enum ScreenType {
  mobile,
  tablet,
  web,
}