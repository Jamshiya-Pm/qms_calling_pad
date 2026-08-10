// screens/homescreen.dart
import 'dart:convert';
import 'dart:async';
import 'package:callingpad_app/app_theme.dart';
import 'package:callingpad_app/models/model.dart';
import 'package:callingpad_app/services/api_service.dart';
import 'package:callingpad_app/services/sharedpref_service.dart';
import 'package:callingpad_app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// UI Colors
class _UI {
  static const bg = Color(0xFFF3F6F6);
  static const card = Colors.white;
  static const border = Color(0xFFE3E8E8);
  static const chip = Color(0xFFF0F3F3);
  static const textDark = Color(0xFF1E2A2B);
  static const textGray = Color(0xFF7B8788);
  static const teal = AppTheme.primary;
  static const tealDark = AppTheme.primaryDark;
  static const tealLight = AppTheme.primaryLight;
  static const red = Color(0xFFE0453F);
  static const grayBorder = Color(0xFFD9DEDE);

  // App logo asset, used top-left on mobile and top-right on web/tablet/TV.
  static const String logoAsset = 'assets/icon/ttcallpad.png';

  // Elevation used only by the web/tablet/TV layout to give cards real depth
  // instead of a flat bordered look.
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.07),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];
}

// ─── Responsive breakpoints ─────────────────────────────────────────────────
// < _kMobileBreakpoint          -> Mobile (vertical / portrait style) layout
// >= _kMobileBreakpoint         -> Tablet / Web / TV (horizontal) layout
// >= _kWideContentMaxBreakpoint -> content gets an extra-wide max width (TV)
const double _kMobileBreakpoint = 600;
const double _kWideContentMaxBreakpoint = 1400;
const double _kWideContentMaxWidth = 1200;
const double _kTvContentMaxWidth = 1600;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Staff? _staff;
  PrefsService? _prefs;
  ApiService? _api;
  String _deviceId = '';

  CallResponse? _callResponse;
  int _pendingTickets = 0;
  List<Counter> _counters = [];
  List<QueueService> _services = [];

  _PadState _padState = _PadState.idle;
  bool _isLoading = false;
  int _navIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late AnimationController _ticketAnimController;
  late Animation<double> _ticketScale;
  late AnimationController _countAnimController;
  late Animation<double> _countFade;

  Timer? _durationTimer;
  DateTime? _callStartTime;
  String _elapsed = '00:00';
  Timer? _ticketTimer;

  @override
  void initState() {
    super.initState();
    _ticketAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _ticketScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ticketAnimController, curve: Curves.elasticOut),
    );
    _countAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _countFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _countAnimController, curve: Curves.easeOut),
    );

    _init();
    _startTicketPolling();
  }

  @override
  void dispose() {
    _ticketAnimController.dispose();
    _countAnimController.dispose();
    _durationTimer?.cancel();
    _ticketTimer?.cancel();
    super.dispose();
  }
  

  void _startTicketPolling() {
    // Cancel any existing timer first
    _ticketTimer?.cancel();
    
    // Load immediately
    _loadPendingTickets();
    
    // Then set up periodic polling
    _ticketTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _loadPendingTickets();
      }
    });
  }

  Future<void> _init() async {
    try {
      _prefs = await PrefsService.getInstance();
      _api = ApiService(_prefs!);

      _deviceId = await _prefs?.getDeviceData() ?? '';

      final loginData = _prefs?.loginData ?? '';
      if (loginData.isNotEmpty) {
        try {
          final json = jsonDecode(loginData) as Map<String, dynamic>;
          _staff = Staff.fromJson(json);
        } catch (e) {
          print('Error parsing login data: $e');
        }
      }

      if (mounted) setState(() {});

      await Future.wait([
        _loadPendingTickets(),
        _loadCounters(),
        _loadServices(),
      ]);
    } catch (e) {
      print('Init error: $e');
    }
  }

  String get _dateString => DateFormat('yyyy/MM/dd').format(DateTime.now());

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _callStartTime = DateTime.now();
    _elapsed = '00:00';
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _callStartTime == null) return;
      final diff = DateTime.now().difference(_callStartTime!);
      final m = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
      if (mounted) {
        setState(() => _elapsed = '$m:$s');
      }
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _callStartTime = null;
    _elapsed = '00:00';
  }

  Future<void> _loadPendingTickets() async {
    if (_api == null || _staff == null) return;

    try {
      final resp = await _api!.getPendingTickets(
        staffId: _staff!.staffID,
        deviceId: _deviceId,
      );

      if (resp['error'] == false) {
        final data = resp['data'] as List?;
        if (data != null && data.isNotEmpty) {
          final count =
              int.tryParse(data[0]['PendingTickets']?.toString() ?? '0') ?? 0;
          if (mounted) {
            setState(() => _pendingTickets = count);
            _countAnimController.forward(from: 0);
          }
          await _prefs?.savePendingTickets(count);
        } else {
          if (mounted) setState(() => _pendingTickets = 0);
        }
      }
    } catch (e) {
      print('❌ Error loading pending tickets: $e');
    }
  }

  Future<void> _loadCounters() async {
    if (_api == null || _staff == null) return;

    try {
      final resp = await _api!.getCounters(
        companyId: _staff!.compID,
        staffId: _staff!.staffID,
        deviceId: _deviceId,
      );

      if (resp['error'] == false) {
        final data = resp['data'] as List? ?? [];
        if (mounted) {
          setState(() {
            _counters = data.map((e) => Counter.fromJson(e)).toList();
          });
        }
      }
    } catch (e) {
      print('❌ Error loading counters: $e');
    }
  }

  Future<void> _loadServices() async {
    if (_api == null || _staff == null) return;

    try {
      final resp = await _api!.getServices(
        companyId: _staff!.compID,
        staffId: _staff!.staffID,
        deviceId: _deviceId,
      );

      if (resp['error'] == false) {
        final data = resp['data'] as List? ?? [];
        if (mounted) {
          setState(() {
            _services = data.map((e) => QueueService.fromJson(e)).toList();
          });
        }
      }
    } catch (e) {
      print('❌ Error loading services: $e');
    }
  }

  Future<void> _callNext() async {
    if (_api == null || _staff == null) {
      _showMsg('API or Staff not initialized', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final resp = await _api!.callTicket(
        staffId: _staff!.staffID,
        deviceId: _deviceId,
      );

      if (resp['error'] == false) {
        final data = resp['data'] as List?;
        if (data != null && data.isNotEmpty) {
          final responseData = data[0] as Map<String, dynamic>;
          _callResponse = CallResponse.fromJson(responseData);

          if (mounted) {
            setState(() => _padState = _PadState.called);
            _ticketAnimController.forward(from: 0);
            _startDurationTimer();
          }

          await _loadPendingTickets();
          _showMsg('Ticket ${_callResponse?.ticketNumber} called');
        } else {
          _showMsg('No ticket to call', isError: true);
        }
      } else {
        final errorMsg = resp['message']?.toString() ?? 'Error calling ticket';
        _showMsg(errorMsg, isError: true);
      }
    } catch (e) {
      print('❌ Call error: $e');
      _showMsg('Network error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _randomCall() async {
    final ticketNo = await _showRandomCallDialog();
    if (ticketNo == null || ticketNo.isEmpty) return;

    if (_api == null || _staff == null) {
      _showMsg('API or Staff not initialized', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final resp = await _api!.randomCall(
        ticketNo: ticketNo,
        staffId: _staff!.staffID,
        dateString: _dateString,
        deviceId: _deviceId,
      );

      if (resp['error'] == false) {
        if (mounted) {
          setState(() => _padState = _PadState.randomCalled);
        }
        final message = resp['data']?[0]?['Message']?.toString() ?? 'Done';
        _showMsg(message);
        await _loadPendingTickets();
      } else {
        final errorMsg = resp['message']?.toString() ?? 'Error';
        _showMsg(errorMsg, isError: true);
      }
    } catch (e) {
      print('❌ Random call error: $e');
      _showMsg('Network error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _recallTicket() async {
    if (_callResponse == null) {
      _showMsg('No active ticket to recall', isError: true);
      return;
    }

    if (_api == null || _staff == null) {
      _showMsg('API or Staff not initialized', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final resp = await _api!.recallTicket(
        companyId: _staff!.compID,
        serviceId: _callResponse!.serviceId,
        seq: _callResponse!.seq,
        dateString: _dateString,
        deviceId: _deviceId,
      );

      if (resp['error'] == false) {
        final message = resp['data']?[0]?['Message']?.toString() ?? 'Recalled';
        _showMsg(message);
        await _loadPendingTickets();
      } else {
        final errorMsg = resp['message']?.toString() ?? 'Error';
        _showMsg(errorMsg, isError: true);
      }
    } catch (e) {
      print('❌ Recall error: $e');
      _showMsg('Network error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _abortTicket() async {
    if (_callResponse == null) {
      _showMsg('No active ticket to abort', isError: true);
      return;
    }

    final confirmed = await _showConfirmDialog(
      'Abort Ticket',
      'Are you sure you want to abort ${_callResponse!.ticketNumber}?',
    );
    if (!confirmed) return;

    if (_api == null || _staff == null) {
      _showMsg('API or Staff not initialized', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final resp = await _api!.abortTicket(
        companyId: _staff!.compID,
        serviceId: _callResponse!.serviceId,
        seq: _callResponse!.seq,
        dateString: _dateString,
        deviceId: _deviceId,
      );

      if (resp['error'] == false) {
        if (mounted) {
          setState(() {
            _padState = _PadState.idle;
            _callResponse = null;
          });
        }
        _stopDurationTimer();
        final message = resp['data']?[0]?['Message']?.toString() ?? 'Aborted';
        _showMsg(message);
        await _loadPendingTickets();
      } else {
        final errorMsg = resp['message']?.toString() ?? 'Error';
        _showMsg(errorMsg, isError: true);
      }
    } catch (e) {
      print('❌ Abort error: $e');
      _showMsg('Network error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startService() async {
    if (_callResponse == null) {
      _showMsg('No active ticket to start service', isError: true);
      return;
    }

    if (_api == null || _staff == null) {
      _showMsg('API or Staff not initialized', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final resp = await _api!.startService(
        companyId: _staff!.compID,
        serviceId: _callResponse!.serviceId,
        seq: _callResponse!.seq,
        dateString: _dateString,
        deviceId: _deviceId,
      );

      if (resp['error'] == false) {
        if (mounted) {
          setState(() => _padState = _PadState.serving);
        }
        final message =
            resp['data']?[0]?['Message']?.toString() ?? 'Service started';
        _showMsg(message);
      } else {
        final errorMsg = resp['message']?.toString() ?? 'Error';
        _showMsg(errorMsg, isError: true);
      }
    } catch (e) {
      print('❌ Start service error: $e');
      _showMsg('Network error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _endService() async {
    if (_callResponse == null) {
      _showMsg('No active ticket to end service', isError: true);
      return;
    }

    if (_api == null || _staff == null) {
      _showMsg('API or Staff not initialized', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final resp = await _api!.endService(
        companyId: _staff!.compID,
        serviceId: _callResponse!.serviceId,
        seq: _callResponse!.seq,
        dateString: _dateString,
        deviceId: _deviceId,
      );

      if (resp['error'] == false) {
        if (mounted) {
          setState(() => _padState = _PadState.ended);
        }
        final message =
            resp['data']?[0]?['Message']?.toString() ?? 'Service ended';
        _showMsg(message);
      } else {
        final errorMsg = resp['message']?.toString() ?? 'Error';
        _showMsg(errorMsg, isError: true);
      }
    } catch (e) {
      print('❌ End service error: $e');
      _showMsg('Network error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _finished() {
    if (mounted) {
      setState(() {
        _padState = _PadState.idle;
        _callResponse = null;
      });
    }
    _stopDurationTimer();
    _loadPendingTickets();
    _showMsg('Service completed');
  }

  Future<void> _transferTicket() async {
    if (_callResponse == null) {
      _showMsg('No active ticket to transfer', isError: true);
      return;
    }

    final option = await showDialog<String>(
      context: context,
      builder: (_) => const _TransferOptionsDialog(),
    );

    if (option == 'counter') {
      await _showCounterList();
    } else if (option == 'service') {
      await _showServiceList();
    }
  }

  Future<void> _showCounterList() async {
    if (_callResponse == null) {
      _showMsg('No active ticket to transfer', isError: true);
      return;
    }

    final available = _counters
        .where((c) => c.counterId != _staff?.counterId)
        .toList();

    if (available.isEmpty) {
      _showMsg('No counters available', isError: true);
      return;
    }

    final counter = await showDialog<Counter>(
      context: context,
      builder: (_) => _SelectListDialog<Counter>(
        title: 'Transfer to Counter',
        items: available,
        labelBuilder: (c) => c.counterName,
      ),
    );

    if (counter == null) return;

    final confirmed = await _showConfirmDialog(
      'Confirm Transfer',
      'Transfer ${_callResponse?.ticketNumber ?? ''} to ${counter.counterName}?',
    );
    if (!confirmed) return;

    if (_api == null || _staff == null) {
      _showMsg('API or Staff not initialized', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final resp = await _api!.transferToCounter(
        companyId: _staff!.compID,
        staffId: _staff!.staffID,
        serviceId: _callResponse!.serviceId,
        seq: _callResponse!.seq,
        transferCounterId: counter.counterId,
        ticketNo: _callResponse!.ticketNumber,
        dateString: _dateString,
        deviceId: _deviceId,
      );

      print('transfre$resp');

      if (resp['error'] == false) {
        if (mounted) {
          setState(() {
            _padState = _PadState.idle;
            _callResponse = null;
          });
        }
        _stopDurationTimer();
        final message =
            resp['data']?[0]?['Message']?.toString() ?? 'Transferred';
        _showMsg(message);
        await _loadPendingTickets();
      } else {
        final errorMsg = resp['message']?.toString() ?? 'Error';
        _showMsg(errorMsg, isError: true);
      }
    } catch (e) {
      print('❌ Transfer to counter error: $e');
      _showMsg('Network error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showServiceList() async {
    if (_callResponse == null) {
      _showMsg('No active ticket to transfer', isError: true);
      return;
    }

    final available = _services
        .where((s) => s.serviceId != _callResponse?.serviceId)
        .toList();

    if (available.isEmpty) {
      _showMsg('No services available', isError: true);
      return;
    }

    final service = await showDialog<QueueService>(
      context: context,
      builder: (_) => _SelectListDialog<QueueService>(
        title: 'Transfer to Service',
        items: available,
        labelBuilder: (s) => s.serviceName,
      ),
    );

    if (service == null) return;

    final confirmed = await _showConfirmDialog(
      'Confirm Transfer',
      'Transfer ${_callResponse?.ticketNumber ?? ''} to ${service.serviceName}?',
    );
    if (!confirmed) return;

    if (_api == null || _staff == null) {
      _showMsg('API or Staff not initialized', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final resp = await _api!.transferToService(
        companyId: _staff!.compID,
        staffId: _staff!.staffID,
        serviceId: service.serviceId,
        seq: _callResponse!.seq,
        ticketNo: _callResponse!.ticketNumber,
        dateString: _dateString,
        deviceId: _deviceId,
      );

      if (resp['error'] == false) {
        if (mounted) {
          setState(() {
            _padState = _PadState.idle;
            _callResponse = null;
          });
        }
        _stopDurationTimer();
        final message =
            resp['data']?[0]?['Message']?.toString() ?? 'Transferred';
        _showMsg(message);
        await _loadPendingTickets();
      } else {
        final errorMsg = resp['message']?.toString() ?? 'Error';
        _showMsg(errorMsg, isError: true);
      }
    } catch (e) {
      print('❌ Transfer to service error: $e');
      _showMsg('Network error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _UI.card,
        title: Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            color: _UI.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(message, style: GoogleFonts.inter(color: _UI.textGray)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _UI.textGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _UI.teal),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<String?> _showRandomCallDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _UI.card,
        title: Text(
          'Random Call',
          style: GoogleFonts.spaceGrotesk(
            color: _UI.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter ticket number to call directly',
              style: GoogleFonts.inter(color: _UI.textGray, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller,
              keyboardType: TextInputType.text,
              style: const TextStyle(color: _UI.textDark),
              decoration: InputDecoration(
                labelText: 'Ticket Number',
                prefixIcon: const Icon(Icons.confirmation_number_outlined),
                filled: true,
                fillColor: _UI.chip,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _UI.border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _UI.textGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: _UI.teal),
            child: const Text('Call'),
          ),
        ],
      ),
    );
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await _showConfirmDialog(
      'Sign Out',
      'Are you sure you want to sign out?',
    );
    if (!confirmed) return;
    await _prefs?.clearLogin();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _onNavTap(int index) {
    if (index == _navIndex) return;
    setState(() => _navIndex = index);
  }

  // Shared helper: renders the app logo image, with a graceful themed
  // fallback if the asset hasn't been bundled yet. Used by both the mobile
  // top bar and the web/tablet/TV header.
  Widget _buildLogo({double size = 38, double radius = 10}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        _UI.logoAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_UI.teal, _UI.tealDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Icon(
            Icons.confirmation_number_rounded,
            color: Colors.white,
            size: size * 0.55,
          ),
        ),
      ),
    );
  }

  // ─── Responsive root build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _UI.bg,
      // The sidebar (hamburger menu) holds all Settings content on
      // Web / Tablet / TV — there is no separate Settings page there,
      // the dashboard is always the default view.
      drawer: _buildSettingsDrawer(),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= _kMobileBreakpoint;

            // Tablet / Web / TV -> website-style layout: slim top bar with a
            // hamburger icon (opens the settings sidebar) on the left and
            // the app logo on the right, dashboard content underneath.
            if (isWide) {
              return Column(
                children: [
                  _buildWebHeader(),
                  Expanded(child: _buildDashboardBodyWide(constraints)),
                ],
              );
            }

            // Mobile -> vertical layout: slim top bar with the logo on the
            // left, a bottom navigation bar, and separate
            // Dashboard / Settings pages.
            final pages = <Widget>[
              _buildDashboardBody(),
              _buildSettingsBody(),
            ];
            return Column(
              children: [
                _buildMobileTopBar(),
                Expanded(
                  child: IndexedStack(index: _navIndex, children: pages),
                ),
                _buildBottomNav(),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─── Mobile top bar (logo top-left) ──────────────────────────────────────
  Widget _buildMobileTopBar() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: _UI.card,
        border: Border(bottom: BorderSide(color: _UI.border)),
      ),
      child: Row(
        children: [
          _buildLogo(size: 34, radius: 9),
          const SizedBox(width: 10),
          Text(
            'TTQueue',
            style: GoogleFonts.spaceGrotesk(
              color: _UI.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _UI.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Counter ${_staff?.counterId ?? '-'}',
              style: GoogleFonts.inter(
                color: _UI.tealDark,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Web / Tablet / TV top bar (website style) ───────────────────────────
  // Kept intentionally minimal, like a typical web app shell: a menu button
  // on the left that opens the sidebar (all settings / profile / sign-out
  // live there) and the brand logo on the right. No title text needed.
  Widget _buildWebHeader() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: _UI.card,
        boxShadow: _UI.softShadow,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kTvContentMaxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Material(
                  color: _UI.chip,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    child: const Padding(
                      padding: EdgeInsets.all(11),
                      child: Icon(
                        Icons.menu_rounded,
                        color: _UI.textDark,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _UI.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Counter ${_staff?.counterId ?? '-'}',
                    style: GoogleFonts.inter(
                      color: _UI.tealDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                _buildLogo(size: 42, radius: 11),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Web / Tablet / TV settings sidebar (opened from the hamburger) ─────
  Widget _buildSettingsDrawer() {
    return Drawer(
      backgroundColor: _UI.bg,
      width: 360,
      elevation: 8,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildLogo(size: 30, radius: 8),
                      const SizedBox(width: 10),
                      Text(
                        'Settings',
                        style: GoogleFonts.spaceGrotesk(
                          color: _UI.textDark,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Material(
                    color: _UI.chip,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.close_rounded,
                          color: _UI.textGray,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileCard(),
                      const SizedBox(height: 20),
                      Text(
                        'GENERAL',
                        style: GoogleFonts.inter(
                          color: _UI.textGray,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _SettingsTile(
                        icon: Icons.settings_ethernet_rounded,
                        label: 'Server Configuration',
                        onTap: () {
                          Navigator.of(context).maybePop();
                          Navigator.pushNamed(context, '/config');
                        },
                      ),
                      const SizedBox(height: 10),
                      _SettingsTile(
                        icon: Icons.refresh_rounded,
                        label: 'Refresh Queue Data',
                        onTap: () {
                          Navigator.of(context).maybePop();
                          _loadPendingTickets();
                          _loadCounters();
                          _loadServices();
                        },
                      ),
                      const SizedBox(height: 10),
                      _SettingsTile(
                        icon: Icons.delete_outline_rounded,
                        label: 'Abort Current Ticket',
                        onTap: () {
                          Navigator.of(context).maybePop();
                          _abortTicket();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _ServiceButton(
                  label: 'Sign Out',
                  icon: Icons.logout_rounded,
                  style: _BtnStyle.outlinedRed,
                  onPressed: () {
                    Navigator.of(context).maybePop();
                    _logout();
                  },
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'TTQueue Calling Pad v1.0.0',
                  style: GoogleFonts.inter(color: _UI.textGray, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Mobile bottom navigation (vertical layout) ──────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: _UI.card,
        border: Border(top: BorderSide(color: _UI.border)),
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: _navIndex,
          onTap: _onNavTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: _UI.card,
          elevation: 0,
          selectedItemColor: _UI.teal,
          unselectedItemColor: _UI.textGray,
          selectedLabelStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  double _wideContentMaxWidth(BoxConstraints constraints) {
    if (constraints.maxWidth >= _kWideContentMaxBreakpoint) {
      return _kTvContentMaxWidth;
    }
    return _kWideContentMaxWidth;
  }

  // ─── Section label helper (small uppercase caption used to organize the
  // mobile dashboard into clear, scannable sections) ───────────────────────
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: _UI.textGray,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // ─── Dashboard: Mobile vertical layout ───────────────────────────────────
  Widget _buildDashboardBody() {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Welcome back, ${_staff?.staffName ?? 'Staff'}',
              style: GoogleFonts.spaceGrotesk(
                color: _UI.textDark,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Here\'s what\'s happening at your counter today',
              style: GoogleFonts.inter(color: _UI.textGray, fontSize: 13),
            ),
            const SizedBox(height: 20),
            _sectionLabel('QUEUE OVERVIEW'),
            _buildCounterHeader(),
            const SizedBox(height: 12),
            _buildStatsRow(),
            const SizedBox(height: 22),
            _sectionLabel('CURRENT TICKET'),
            _buildTicketCard(),
            const SizedBox(height: 22),
            _buildActionGrid(),
          ],
        ),
      ),
    );
  }

  // ─── Dashboard: Tablet / Web / TV horizontal layout ──────────────────────
  Widget _buildDashboardBodyWide(BoxConstraints constraints) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _wideContentMaxWidth(constraints)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildWideDashboardHeading(),
                const SizedBox(height: 26),
                _buildKpiRowWide(),
                const SizedBox(height: 24),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 6, child: _buildHeroTicketCardWide()),
                      const SizedBox(width: 24),
                      Expanded(flex: 5, child: _buildActionGridCardWide()),
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

  // Page title + subtitle + a refresh chip, like a typical web app dashboard.
  Widget _buildWideDashboardHeading() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: GoogleFonts.spaceGrotesk(
                  color: _UI.textDark,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Welcome back, ${_staff?.staffName ?? 'Staff'}',
                style: GoogleFonts.inter(color: _UI.textGray, fontSize: 14),
              ),
            ],
          ),
        ),
        Material(
          color: _UI.card,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _loadPendingTickets,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: _UI.softShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh_rounded, color: _UI.teal, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Refresh',
                    style: GoogleFonts.inter(
                      color: _UI.textDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // A row of real-data KPI cards: queue size, live status, and call
  // duration — all sourced from existing state, nothing fabricated.
  Widget _buildKpiRowWide() {
    final isActive = _callResponse != null;
    final statusLabel = isActive ? _padState.label : 'Idle';
    final statusColor = isActive ? _padState.color : _UI.textGray;
    final showsDuration = isActive &&
        (_padState == _PadState.called || _padState == _PadState.serving);

    return Row(
      children: [
        Expanded(
          child: _kpiCardWide(
            icon: Icons.groups_2_rounded,
            accent: _UI.teal,
            label: 'Tickets in Queue',
            value: '$_pendingTickets',
            fade: true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _kpiCardWide(
            icon: Icons.bolt_rounded,
            accent: statusColor,
            label: 'Current Status',
            value: statusLabel,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _kpiCardWide(
            icon: Icons.timer_outlined,
            accent: AppTheme.info,
            label: 'Call Duration',
            value: showsDuration ? _elapsed : '--:--',
          ),
        ),
      ],
    );
  }

  Widget _kpiCardWide({
    required IconData icon,
    required Color accent,
    required String label,
    required String value,
    bool fade = false,
  }) {
    final valueText = Text(
      value,
      style: GoogleFonts.spaceGrotesk(
        color: _UI.textDark,
        fontSize: 26,
        fontWeight: FontWeight.w800,
      ),
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _UI.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _UI.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: _UI.textGray,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                fade
                    ? FadeTransition(opacity: _countFade, child: valueText)
                    : valueText,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Hero ticket card: the visual centerpiece of the wide dashboard, driven
  // by the exact same _callResponse / _padState the mobile card uses.
  Widget _buildHeroTicketCardWide() {
    final isActive = _callResponse != null;
    return ScaleTransition(
      scale: isActive ? _ticketScale : const AlwaysStoppedAnimation(1.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [_UI.teal, _UI.tealDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isActive ? null : _UI.card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: _UI.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CURRENT TICKET',
                  style: GoogleFonts.inter(
                    color: isActive ? Colors.white70 : _UI.textGray,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white.withOpacity(0.18)
                        : _UI.chip,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive
                        ? (_padState == _PadState.serving
                            ? 'NOW SERVING'
                            : _padState.label.toUpperCase())
                        : 'WAITING',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.white : _UI.textGray,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (!isActive) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: _UI.chip,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.confirmation_number_outlined,
                      color: _UI.textGray,
                      size: 38,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No ticket called',
                          style: GoogleFonts.spaceGrotesk(
                            color: _UI.textDark,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Use Call Next or Random Call to bring up a customer.',
                          style: GoogleFonts.inter(
                            color: _UI.textGray,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                _callResponse!.ticketNumber,
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _callResponse!.serviceName,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Wraps the exact same _buildActionGrid() (same handlers, same enabled
  // logic) in an elevated panel so it matches the new dashboard's depth.
  Widget _buildActionGridCardWide() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _UI.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _UI.cardShadow,
      ),
      child: _buildActionGrid(),
    );
  }

  Widget _buildCounterHeader() {
    final counterLabel = 'Counter ${_staff?.counterId ?? '-'}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _UI.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: _UI.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.storefront_rounded, color: _UI.teal, size: 15),
                  const SizedBox(width: 6),
                  Text(
                    counterLabel.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: _UI.textGray,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Material(
                color: _UI.chip,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _loadPendingTickets,
                  child: const Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(
                      Icons.refresh_rounded,
                      color: _UI.textGray,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_pendingTickets / 20).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: _UI.chip,
              valueColor: const AlwaysStoppedAnimation<Color>(_UI.teal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard() {
    final isActive = _callResponse != null;
    return ScaleTransition(
      scale: isActive ? _ticketScale : const AlwaysStoppedAnimation(1.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _UI.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _UI.border),
          boxShadow: _UI.softShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // This makes it wrap content height
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? _padState.color.withOpacity(0.12)
                      : _UI.chip,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive
                      ? (_padState == _PadState.serving
                            ? 'NOW SERVING'
                            : _padState.label.toUpperCase())
                      : '!',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isActive ? _padState.color : _UI.textGray,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (!isActive) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: _UI.chip,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.confirmation_number_outlined,
                  color: _UI.textGray,
                  size: 34,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'No Called ticket',
                style: GoogleFonts.inter(
                  color: _UI.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Press Call to serve a customer',
                style: GoogleFonts.inter(color: _UI.textGray, fontSize: 12),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Text(
                'Ticket Number',
                style: GoogleFonts.inter(
                  color: _UI.textGray,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _callResponse!.ticketNumber,
                style: GoogleFonts.spaceGrotesk(
                  color: _UI.teal,
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _UI.chip,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: _UI.textGray,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _callResponse!.serviceName,
                      style: GoogleFonts.inter(
                        color: _UI.textDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _statBox(
            icon: Icons.groups_2_rounded,
            label: 'Tickets in Queue',
            value: '$_pendingTickets',
            fadeAnim: true,
          ),
        ),
      ],
    );
  }

  Widget _statBox({
    required IconData icon,
    required String label,
    required String value,
    bool fadeAnim = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _UI.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _UI.teal.withOpacity(0.35)),
        boxShadow: _UI.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _UI.teal.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _UI.teal, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: _UI.textGray,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                fadeAnim
                    ? FadeTransition(
                        opacity: _countFade,
                        child: Text(
                          value,
                          style: GoogleFonts.spaceGrotesk(
                            color: _UI.textDark,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : Text(
                        value,
                        style: GoogleFonts.spaceGrotesk(
                          color: _UI.textDark,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionGrid() {
    final canCallNext =
        _padState == _PadState.idle || _padState == _PadState.randomCalled;
    final canStart = _padState == _PadState.called;
    final canRecall = _padState == _PadState.called;
    final canTransfer =
        _padState == _PadState.called ||
        _padState == _PadState.serving ||
        _padState == _PadState.ended;
    final canEnd = _padState == _PadState.serving;
    final isEnded = _padState == _PadState.ended;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'SERVICE CONTROLS',
          style: GoogleFonts.inter(
            color: _UI.textGray,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ServiceButton(
                label: 'Call Next',
                icon: Icons.campaign_rounded,
                style: _BtnStyle.filledDark,
                onPressed: canCallNext ? _callNext : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ServiceButton(
                label: 'Start Service',
                icon: Icons.play_arrow_rounded,
                style: _BtnStyle.filledTeal,
                onPressed: canStart ? _startService : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ServiceButton(
                label: 'Random Call',
                icon: Icons.shuffle_rounded,
                style: _BtnStyle.outlinedTeal,
                onPressed: canCallNext ? _randomCall : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ServiceButton(
                label: 'Recall',
                icon: Icons.replay_rounded,
                style: _BtnStyle.outlinedGray,
                onPressed: canRecall ? _recallTicket : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ServiceButton(
                label: 'Transfer',
                icon: Icons.call_split_rounded,
                style: _BtnStyle.outlinedGray,
                onPressed: canTransfer ? _transferTicket : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ServiceButton(
                label: isEnded ? 'Finished' : 'End Service',
                icon: isEnded
                    ? Icons.check_circle_outline_rounded
                    : Icons.stop_circle_outlined,
                style: isEnded
                    ? _BtnStyle.outlinedGreen
                    : _BtnStyle.outlinedRed,
                onPressed: isEnded ? _finished : (canEnd ? _endService : null),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Settings: Mobile vertical layout ────────────────────────────────────
  Widget _buildSettingsBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: GoogleFonts.spaceGrotesk(
              color: _UI.textDark,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Manage your profile, server and queue data',
            style: GoogleFonts.inter(color: _UI.textGray, fontSize: 13),
          ),
          const SizedBox(height: 18),
          _buildProfileCard(),
          const SizedBox(height: 20),
          _sectionLabel('GENERAL'),
          _SettingsTile(
            icon: Icons.settings_ethernet_rounded,
            label: 'Server Configuration',
            onTap: () => Navigator.pushNamed(context, '/config'),
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.refresh_rounded,
            label: 'Refresh Queue Data',
            onTap: () {
              _loadPendingTickets();
              _loadCounters();
              _loadServices();
            },
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.delete_outline_rounded,
            label: 'Abort Current Ticket',
            onTap: _abortTicket,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: _ServiceButton(
              label: 'Sign Out',
              icon: Icons.logout_rounded,
              style: _BtnStyle.outlinedRed,
              onPressed: _logout,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'TTQueue Calling Pad v1.0.0',
              style: GoogleFonts.inter(color: _UI.textGray, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared profile card (used by the mobile Settings page and the
  // web/tablet/TV sidebar drawer) ───────────────────────────────────────────
  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_UI.teal, _UI.tealDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: _UI.softShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              _staff?.staffName.isNotEmpty == true
                  ? _staff!.staffName[0].toUpperCase()
                  : '?',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _staff?.staffName ?? 'Staff',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _staff?.userRole ?? '',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Counter: ${_staff?.counterId ?? '—'}',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pad State Enum ───────────────────────────────────────────────────────────
enum _PadState {
  idle,
  called,
  randomCalled,
  serving,
  ended;

  String get label {
    switch (this) {
      case _PadState.idle:
        return '';
      case _PadState.called:
        return 'Called';
      case _PadState.randomCalled:
        return 'Called';
      case _PadState.serving:
        return 'Serving';
      case _PadState.ended:
        return 'Ended';
    }
  }

  Color get color {
    switch (this) {
      case _PadState.idle:
        return _UI.textGray;
      case _PadState.called:
        return AppTheme.warning;
      case _PadState.randomCalled:
        return AppTheme.warning;
      case _PadState.serving:
        return AppTheme.success;
      case _PadState.ended:
        return AppTheme.info;
    }
  }
}

// ─── Service Button ─────────────────────────────────────────────────────────
enum _BtnStyle {
  filledDark,
  filledTeal,
  outlinedTeal,
  outlinedGray,
  outlinedRed,
  outlinedGreen,
}

class _ServiceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final _BtnStyle style;
  final VoidCallback? onPressed;

  const _ServiceButton({
    required this.label,
    required this.icon,
    required this.style,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    Color bg;
    Color fg;
    Color? borderColor;

    switch (style) {
      case _BtnStyle.filledDark:
        bg = enabled ? _UI.tealDark : _UI.chip;
        fg = enabled ? Colors.white : _UI.textGray.withOpacity(0.5);
        borderColor = null;
        break;
      case _BtnStyle.filledTeal:
        bg = enabled ? _UI.teal : _UI.chip;
        fg = enabled ? Colors.white : _UI.textGray.withOpacity(0.5);
        borderColor = null;
        break;
      case _BtnStyle.outlinedTeal:
        bg = _UI.card;
        fg = enabled ? _UI.teal : _UI.textGray.withOpacity(0.4);
        borderColor = enabled ? _UI.teal : _UI.grayBorder;
        break;
      case _BtnStyle.outlinedGray:
        bg = _UI.card;
        fg = enabled ? _UI.textDark : _UI.textGray.withOpacity(0.4);
        borderColor = _UI.grayBorder;
        break;
      case _BtnStyle.outlinedRed:
        bg = _UI.card;
        fg = enabled ? _UI.red : _UI.textGray.withOpacity(0.4);
        borderColor = enabled ? _UI.red : _UI.grayBorder;
        break;
      case _BtnStyle.outlinedGreen:
        bg = _UI.card;
        fg = enabled ? AppTheme.success : _UI.textGray.withOpacity(0.4);
        borderColor = enabled ? AppTheme.success : _UI.grayBorder;
        break;
    }

    return SizedBox(
      height: 56,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: borderColor != null
                  ? Border.all(color: borderColor)
                  : null,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: fg, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: fg,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Settings Tile ─────────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _UI.chip,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: _UI.teal, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: _UI.textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: _UI.textGray,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Transfer Options Dialog ───────────────────────────────────────────────
class _TransferOptionsDialog extends StatelessWidget {
  const _TransferOptionsDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _UI.card,
      title: Text(
        'Transfer Ticket',
        style: GoogleFonts.spaceGrotesk(
          color: _UI.textDark,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Choose transfer type',
            style: GoogleFonts.inter(color: _UI.textGray, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _OptionCard(
                  icon: Icons.countertops_rounded,
                  label: 'Counter',
                  onTap: () => Navigator.pop(context, 'counter'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OptionCard(
                  icon: Icons.miscellaneous_services_rounded,
                  label: 'Service',
                  onTap: () => Navigator.pop(context, 'service'),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: _UI.textGray)),
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _UI.chip,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _UI.teal.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: _UI.teal, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: _UI.textDark,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Select List Dialog ────────────────────────────────────────────────────
class _SelectListDialog<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) labelBuilder;

  const _SelectListDialog({
    required this.title,
    required this.items,
    required this.labelBuilder,
  });

  @override
  State<_SelectListDialog<T>> createState() => _SelectListDialogState<T>();
}

class _SelectListDialogState<T> extends State<_SelectListDialog<T>> {
  int _selectedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _UI.card,
      title: Text(
        widget.title,
        style: GoogleFonts.spaceGrotesk(
          color: _UI.textDark,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: widget.items.length,
          separatorBuilder: (_, __) =>
              const Divider(color: _UI.border, height: 1),
          itemBuilder: (ctx, i) {
            final isSelected = _selectedIndex == i;
            return ListTile(
              selected: isSelected,
              selectedTileColor: _UI.teal.withOpacity(0.08),
              onTap: () => setState(() => _selectedIndex = i),
              title: Text(
                widget.labelBuilder(widget.items[i]),
                style: GoogleFonts.inter(
                  color: isSelected ? _UI.teal : _UI.textDark,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
              trailing: isSelected
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: _UI.teal,
                      size: 20,
                    )
                  : null,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: _UI.textGray)),
        ),
        ElevatedButton(
          onPressed: _selectedIndex >= 0
              ? () => Navigator.pop(context, widget.items[_selectedIndex])
              : null,
          style: ElevatedButton.styleFrom(backgroundColor: _UI.teal),
          child: const Text('Select'),
        ),
      ],
    );
  }
}