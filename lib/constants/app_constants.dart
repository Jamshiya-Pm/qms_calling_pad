// constants/app_constants.dart
class AppConstants {
  // SharedPreferences keys
  static const String ttqScheme = 'ttq_scheme';
  static const String ttqHost = 'ttq_host';
  static const String ttqPort = 'ttq_port';
  static const String baseUrl = 'base_url';
  static const String loginData = 'login_data';
  static const String deviceid = 'device_id';
  static const String isLoggedIn = 'is_logged_in';
  static const String pendingTickets = 'pending_tickets';
  static const String staffData = 'staff_data';

  // API Endpoints
  static const String register = 'Callpad_RegisterCallingPad';
  static const String login = 'Callpad_Login';
  static const String logout = 'Callpad_Logout';
  static const String ticketCountPending = 'Callpad_getCountOfPendingTicketsInQueue';
  static const String ticketCall = 'Callpad_NewCall';
  static const String ticketRecall = 'Callpad_Recall';
  static const String ticketAbort = 'Callpad_AbortCall';
  static const String ticketServiceStart = 'Callpad_StartService';
  static const String ticketServiceEnd = 'Callpad_EndService';
  static const String ticketListAllCounters = 'Callpad_getListOfAllCounters';
  static const String ticketListAllServices = 'Callpad_getListOfAllServices';
  static const String ticketTransferToCounter = 'Callpad_TransferTicket_ToCounter';
  static const String ticketTransferToService = 'Callpad_TransferTicket_ToService';
  static const String ticketRandomCall = 'Callpad_RandomCall';

  // API Parameters
  static const String paramStaffId = 'Staff_Id';
  static const String paramDeviceId = 'DeviceId';
  static const String paramCompanyId = 'CompanyId';
  static const String paramDateString = 'DateString';
  static const String paramServiceId = 'ServiceId';
  static const String paramSequence = 'Sequence';
  static const String paramTicketNo = 'TicketNo';
  static const String paramTransferCounter = 'TransferCounterId';
}