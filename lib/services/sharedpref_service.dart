// services/sharedpref_service.dart
import 'package:callingpad_app/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  static PrefsService? _instance;
  static SharedPreferences? _prefs;

  PrefsService._();

  static Future<PrefsService> getInstance() async {
    _instance ??= PrefsService._();
    _prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  // ─── Config ──────────────────────────────────────────────────────────────
  Future<void> saveConfig({
    required String scheme,
    required String host,
    required String port,
  }) async {
    await _prefs!.setString(AppConstants.ttqScheme, scheme);
    await _prefs!.setString(AppConstants.ttqHost, host);
    await _prefs!.setString(AppConstants.ttqPort, port);

    final url = _buildBaseUrl(scheme: scheme, host: host, port: port);
    await _prefs!.setString(AppConstants.baseUrl, url);
  }

  String _buildBaseUrl({
    required String scheme,
    required String host,
    required String port,
  }) {
    String s = scheme.contains('://') ? scheme : '$scheme://';
    if (port.isEmpty) {
      return '${s}$host/QueApp.svc/';
    } else {
      String h = host.contains(':') ? host : '$host:';
      return '$s$h$port/QueApp.svc/';
    }
  }

  String get scheme => _prefs!.getString(AppConstants.ttqScheme) ?? 'http';
  String get host => _prefs!.getString(AppConstants.ttqHost) ?? '';
  String get port => _prefs!.getString(AppConstants.ttqPort) ?? '';
  String get savedBaseUrl => _prefs!.getString(AppConstants.baseUrl) ?? '';
  bool get hasConfig => host.isNotEmpty;

  // ─── Login ──────────────────────────────────────────────────────────────
  Future<void> saveLoginData(String jsonData) async {
    await _prefs!.setString(AppConstants.loginData, jsonData);
    await _prefs!.setBool(AppConstants.isLoggedIn, true);
  }

  Future<void> saveDeviceData(String deviceId) async {
    await _prefs!.setString(AppConstants.deviceid, deviceId);
  }

  Future<String?> getDeviceData() async {
    return _prefs?.getString(AppConstants.deviceid);
  }

  Future<void> clearLogin() async {
    await _prefs!.remove(AppConstants.loginData);
    await _prefs!.setBool(AppConstants.isLoggedIn, false);
  }

  String get loginData => _prefs!.getString(AppConstants.loginData) ?? '';
  bool get isLoggedIn => _prefs!.getBool(AppConstants.isLoggedIn) ?? false;

  // ─── Pending tickets ──────────────────────────────────────────────────
  Future<void> savePendingTickets(int count) async {
    await _prefs!.setInt(AppConstants.pendingTickets, count);
  }

  int get pendingTickets => _prefs!.getInt(AppConstants.pendingTickets) ?? 0;

  // ─── Staff Data ──────────────────────────────────────────────────────
  Future<void> saveStaffData(String staffJson) async {
    await _prefs?.setString(AppConstants.staffData, staffJson);
  }

  Future<String?> getStaffData() async {
    return _prefs?.getString(AppConstants.staffData);
  }
}