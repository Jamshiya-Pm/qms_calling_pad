import 'dart:convert';
import 'package:flutter/foundation.dart'; // Import for kIsWeb check
import 'package:callingpad_app/constants/app_constants.dart';
import 'package:callingpad_app/services/sharedpref_service.dart';
import 'package:http/http.dart' as http;

class ApiService {
  final PrefsService _prefs;

  ApiService(this._prefs);

  String get _baseUrl => _prefs.savedBaseUrl;

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    print('📡 url: $url');
    print('📦 dataer: ${jsonEncode(body)}');

    try {
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      print('📨 Response Status: ${response.statusCode}');
      print('📨 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        // Strip BOM marker if present (common in WCF responses)
        String cleanBody = response.body;
        if (cleanBody.startsWith('\uFEFF')) {
          cleanBody = cleanBody.substring(1);
        }
        return jsonDecode(cleanBody) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Server error: ${response.statusCode} - Body: ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Network error: $e');
      if (kIsWeb) {
        throw Exception('Network error (Web/CORS check): $e');
      }
      throw Exception('Network error: $e');
    }
  }

  // ─── Register ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String deviceId,
    required int androidVersion,
    required int apiLevel,
    required String brand,
    required String model,
    required String deviceType,
    required int width,
  }) {
    return _post(AppConstants.register, {
      'Staff_Username': username,
      'Staff_Password': password,
      'DeviceId': deviceId,
      'Device_AndroidVersion': androidVersion,
      'Device_ApiLevel': apiLevel,
      'Device_Brand': brand,
      'Device_Model': model,
      'Device_Type': deviceType,
      'Device_Width': width,
    });
  }

  // ─── Login ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login({required String deviceId}) {
    return _post(AppConstants.login, {'DeviceId': deviceId});
  }

  // ─── Logout ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> logout({required String deviceId}) {
    return _post(AppConstants.logout, {'DeviceId': deviceId});
  }

  // ─── Pending Tickets ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> getPendingTickets({
    required String staffId,
    required String deviceId,
  }) {
    _validateRequiredParams({'Staff_Id': staffId, 'DeviceId': deviceId});
    return _post(AppConstants.ticketCountPending, {
      AppConstants.paramStaffId: staffId,
      AppConstants.paramDeviceId: deviceId,
    });
  }

  // ─── Call Ticket ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> callTicket({
    required String staffId,
    required String deviceId,
  }) {
    _validateRequiredParams({'Staff_Id': staffId, 'DeviceId': deviceId});
    return _post(AppConstants.ticketCall, {
      AppConstants.paramStaffId: staffId,
      AppConstants.paramDeviceId: deviceId,
    });
  }

  // ─── Random Call ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> randomCall({
    required String ticketNo,
    required String staffId,
    required String dateString,
    required String deviceId,
  }) {
    _validateRequiredParams({'Staff_Id': staffId, 'DeviceId': deviceId});
    return _post(AppConstants.ticketRandomCall, {
      AppConstants.paramTicketNo: ticketNo,
      AppConstants.paramStaffId: staffId,
      AppConstants.paramDateString: dateString,
      AppConstants.paramDeviceId: deviceId,
    });
  }

  // ─── Recall ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> recallTicket({
    required String companyId,
    required String serviceId,
    required String seq,
    required String dateString,
    required String deviceId,
  }) {
    _validateRequiredParams({'CompanyId': companyId, 'DeviceId': deviceId});
    return _post(AppConstants.ticketRecall, {
      AppConstants.paramCompanyId: companyId,
      AppConstants.paramDateString: dateString,
      AppConstants.paramServiceId: serviceId,
      AppConstants.paramSequence: seq,
      AppConstants.paramDeviceId: deviceId,
    });
  }

  // ─── Abort ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> abortTicket({
    required String companyId,
    required String serviceId,
    required String seq,
    required String dateString,
    required String deviceId,
  }) {
    _validateRequiredParams({'CompanyId': companyId, 'DeviceId': deviceId});
    return _post(AppConstants.ticketAbort, {
      AppConstants.paramCompanyId: companyId,
      AppConstants.paramDateString: dateString,
      AppConstants.paramServiceId: serviceId,
      AppConstants.paramSequence: seq,
      AppConstants.paramDeviceId: deviceId,
    });
  }

  // ─── Start Service ────────────────────────────────────────────────────
  Future<Map<String, dynamic>> startService({
    required String companyId,
    required String serviceId,
    required String seq,
    required String dateString,
    required String deviceId,
  }) {
    _validateRequiredParams({'CompanyId': companyId, 'DeviceId': deviceId});
    return _post(AppConstants.ticketServiceStart, {
      AppConstants.paramCompanyId: companyId,
      AppConstants.paramDateString: dateString,
      AppConstants.paramServiceId: serviceId,
      AppConstants.paramSequence: seq,
      AppConstants.paramDeviceId: deviceId,
    });
  }

  // ─── End Service ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> endService({
    required String companyId,
    required String serviceId,
    required String seq,
    required String dateString,
    required String deviceId,
  }) {
    _validateRequiredParams({'CompanyId': companyId, 'DeviceId': deviceId});
    return _post(AppConstants.ticketServiceEnd, {
      AppConstants.paramCompanyId: companyId,
      AppConstants.paramDateString: dateString,
      AppConstants.paramServiceId: serviceId,
      AppConstants.paramSequence: seq,
      AppConstants.paramDeviceId: deviceId,
    });
  }

  // ─── Counters ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getCounters({
    required String companyId,
    required String staffId,
    required String deviceId,
  }) {
    _validateRequiredParams({
      'CompanyId': companyId,
      'Staff_Id': staffId,
      'DeviceId': deviceId,
    });
    return _post(AppConstants.ticketListAllCounters, {
      AppConstants.paramCompanyId: companyId,
      AppConstants.paramStaffId: staffId,
      AppConstants.paramDeviceId: deviceId,
    });
  }

  // ─── Services ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getServices({
    required String companyId,
    required String staffId,
    required String deviceId,
  }) {
    _validateRequiredParams({
      'CompanyId': companyId,
      'Staff_Id': staffId,
      'DeviceId': deviceId,
    });
    return _post(AppConstants.ticketListAllServices, {
      AppConstants.paramCompanyId: companyId,
      AppConstants.paramStaffId: staffId,
      AppConstants.paramDeviceId: deviceId,
    });
  }

  // ─── Transfer to Counter ─────────────────────────────────────────────
  Future<Map<String, dynamic>> transferToCounter({
    required String companyId,
    required String staffId,
    required String serviceId,
    required String seq,
    required String transferCounterId,
    required String ticketNo,
    required String dateString,
    required String deviceId,
  }) {
    _validateRequiredParams({
      'CompanyId': companyId,
      'Staff_Id': staffId,
      'DeviceId': deviceId,
    });
    return _post(AppConstants.ticketTransferToCounter, {
      AppConstants.paramCompanyId: companyId,
      AppConstants.paramDateString: dateString,
      AppConstants.paramServiceId: serviceId,
      AppConstants.paramSequence: seq,
      AppConstants.paramStaffId: staffId,
      AppConstants.paramTransferCounter: transferCounterId,
      AppConstants.paramTicketNo: ticketNo,
      AppConstants.paramDeviceId: deviceId,
    });
  }

  // ─── Transfer to Service ─────────────────────────────────────────────
  Future<Map<String, dynamic>> transferToService({
    required String companyId,
    required String staffId,
    required String serviceId,
    required String seq,
    required String ticketNo,
    required String dateString,
    required String deviceId,
  }) {
    _validateRequiredParams({
      'CompanyId': companyId,
      'Staff_Id': staffId,
      'DeviceId': deviceId,
    });
    return _post(AppConstants.ticketTransferToService, {
      AppConstants.paramCompanyId: companyId,
      AppConstants.paramDateString: dateString,
      AppConstants.paramServiceId: serviceId,
      AppConstants.paramStaffId: staffId,
      AppConstants.paramSequence: seq,
      AppConstants.paramTicketNo: ticketNo,
      AppConstants.paramDeviceId: deviceId,
    });
  }

  // ─── Helper Validation ─────────────────────────────────────────────────
  void _validateRequiredParams(Map<String, String> params) {
    params.forEach((key, value) {
      if (value.trim().isEmpty) {
        print('⚠️ WARNING: $key is empty! WCF endpoint will fail with HTTP 400.');
      }
    });
  }
}