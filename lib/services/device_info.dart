// services/device_info.dart
import 'dart:io' show Platform;
import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceInfoService {
  static const String _keyDeviceId = 'device_unique_id';

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final AndroidId _androidId = const AndroidId();
  final Uuid _uuid = const Uuid();

  /// Get comprehensive device information safely across Web, Android, iOS, and Desktop
  Future<Map<String, dynamic>> getDeviceInfo() async {
    Map<String, dynamic> deviceInfo = {};

    try {
      if (kIsWeb) {
        deviceInfo = await _getWebInfo();
      } else if (Platform.isAndroid) {
        deviceInfo = await _getAndroidInfo();
      } else if (Platform.isIOS) {
        deviceInfo = await _getIosInfo();
      } else {
        deviceInfo = await _getOtherPlatformInfo();
      }

      // Attach unique device / client identifier
      deviceInfo['uniqueDeviceId'] = await _getUniqueDeviceId();

      return deviceInfo;
    } catch (e) {
      debugPrint('Error getting device info: $e');
      return _getFallbackDeviceInfo();
    }
  }

  /// Get or create a unique device/client ID
  Future<String> _getUniqueDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? savedId = prefs.getString(_keyDeviceId);

      if (savedId != null && savedId.isNotEmpty) {
        return savedId;
      }

      String uniqueId = '';

      // On Android native, attempt to fetch Android ID first
      if (!kIsWeb && Platform.isAndroid) {
        try {
          final androidId = await _androidId.getId();
          if (androidId != null && androidId.isNotEmpty) {
            uniqueId = androidId;
          }
        } catch (e) {
          debugPrint('Error getting Android ID: $e');
        }
      }

      // Fallback: Generate UUID v4 for Web, iOS, Desktop, or if Android ID fails
      if (uniqueId.isEmpty) {
        uniqueId = _uuid.v4();
      }

      await prefs.setString(_keyDeviceId, uniqueId);
      return uniqueId;
    } catch (e) {
      debugPrint('Error generating unique device ID: $e');
      return _uuid.v4();
    }
  }

  /// Get Web Browser device information safely without importing dart:html or JS bindings
  Future<Map<String, dynamic>> _getWebInfo() async {
    try {
      final webBrowserInfo = await _deviceInfo.webBrowserInfo;

      return {
        'brand': webBrowserInfo.browserName.name,
        'model': webBrowserInfo.platform ?? 'Web',
        'device': 'Browser',
        'manufacturer': webBrowserInfo.vendor ?? 'Unknown',
        'osVersion': webBrowserInfo.appVersion ?? 'Unknown',
        'apiLevel': 0,
        'osName': 'Web (${webBrowserInfo.browserName.name})',
        'isPhysicalDevice': false,
        // 'userAgent': webBrowserInfo.userAgent ?? 'Unknown',
        // 'language': webBrowserInfo.language ?? 'Unknown',
        // 'hardwareConcurrency': webBrowserInfo.hardwareConcurrency ?? 0,
        // 'maxTouchPoints': webBrowserInfo.maxTouchPoints ?? 0,
      };
    } catch (e) {
      debugPrint('Error getting web info: $e');
      return {
        'brand': 'Web',
        'model': 'Unknown',
        'device': 'Browser',
        'manufacturer': 'Web',
        'osVersion': 'Unknown',
        'apiLevel': 0,
        'osName': 'Web',
        'isPhysicalDevice': false,
      };
    }
  }

  /// Get Android device information
  Future<Map<String, dynamic>> _getAndroidInfo() async {
    try {
      final androidInfo = await _deviceInfo.androidInfo;

      return {
        'brand': androidInfo.brand,
        'model': androidInfo.model,
        'device': androidInfo.device,
        'manufacturer': androidInfo.manufacturer,
        'osVersion': androidInfo.version.release,
        'apiLevel': androidInfo.version.sdkInt,
        'osName': 'Android',
        'isPhysicalDevice': androidInfo.isPhysicalDevice,
      };
    } catch (e) {
      debugPrint('Error getting Android info: $e');
      return _getDefaultAndroidInfo();
    }
  }

  /// Get iOS device information
  Future<Map<String, dynamic>> _getIosInfo() async {
    try {
      final iosInfo = await _deviceInfo.iosInfo;

      return {
        'brand': 'Apple',
        'model': iosInfo.model,
        'device': iosInfo.name,
        'manufacturer': 'Apple',
        'osVersion': iosInfo.systemVersion,
        'osName': 'iOS',
        'isPhysicalDevice': iosInfo.isPhysicalDevice,
        'identifierForVendor': iosInfo.identifierForVendor ?? 'unknown',
      };
    } catch (e) {
      debugPrint('Error getting iOS info: $e');
      return _getDefaultIosInfo();
    }
  }

  /// Get information for Desktop platforms (Windows, macOS, Linux)
  Future<Map<String, dynamic>> _getOtherPlatformInfo() async {
    return {
      'osName': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'model': 'Desktop',
      'brand': 'Desktop',
      'manufacturer': 'Desktop',
      'isPhysicalDevice': true,
      'apiLevel': 0,
    };
  }

  /// Default Android info fallback
  Map<String, dynamic> _getDefaultAndroidInfo() {
    return {
      'brand': 'Unknown',
      'model': 'Unknown',
      'device': 'Unknown',
      'manufacturer': 'Unknown',
      'osVersion': 'Unknown',
      'apiLevel': 0,
      'osName': 'Android',
      'isPhysicalDevice': false,
    };
  }

  /// Default iOS info fallback
  Map<String, dynamic> _getDefaultIosInfo() {
    return {
      'brand': 'Apple',
      'model': 'Unknown',
      'device': 'Unknown',
      'manufacturer': 'Apple',
      'osVersion': 'Unknown',
      'osName': 'iOS',
      'isPhysicalDevice': false,
      'identifierForVendor': 'unknown',
    };
  }

  /// Fallback device info for unhandled errors
  Map<String, dynamic> _getFallbackDeviceInfo() {
    return {
      'brand': kIsWeb ? 'Web' : 'Unknown',
      'model': 'Unknown',
      'osVersion': kIsWeb ? 'Web' : Platform.operatingSystemVersion,
      'osName': kIsWeb ? 'Web' : Platform.operatingSystem,
      'isPhysicalDevice': false,
      'uniqueDeviceId': _uuid.v4(),
      'apiLevel': 0,
    };
  }
}