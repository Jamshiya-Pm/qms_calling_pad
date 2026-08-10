// models/model.dart
import 'dart:convert';

class Staff {
  final String staffName;
  final String userRoleID;
  final String userRole;
  final String staffID;
  final String compID;
  final String custID;
  final String counterId;
  final String showNationalID;
  final String showMobile;
  final String showPassport;

  Staff({
    required this.staffName,
    required this.userRoleID,
    required this.userRole,
    required this.staffID,
    required this.compID,
    required this.custID,
    required this.counterId,
    required this.showNationalID,
    required this.showMobile,
    required this.showPassport,
  });

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      staffName: json['StaffName']?.toString() ?? '',
      userRoleID: json['UserRoleID']?.toString() ?? '',
      userRole: json['UserRole']?.toString() ?? '',
      staffID: json['StaffID']?.toString() ?? '',
      compID: json['CompID']?.toString() ?? '',
      custID: json['CustID']?.toString() ?? '',
      counterId: json['CounterId']?.toString() ?? '',
      showNationalID: json['showNationalID']?.toString() ?? 'False',
      showMobile: json['showMobile']?.toString() ?? 'False',
      showPassport: json['showPassport']?.toString() ?? 'False',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'StaffName': staffName,
      'UserRoleID': userRoleID,
      'UserRole': userRole,
      'StaffID': staffID,
      'CompID': compID,
      'CustID': custID,
      'CounterId': counterId,
      'showNationalID': showNationalID,
      'showMobile': showMobile,
      'showPassport': showPassport,
    };
  }
}

class CallResponse {
  final String ticketNumber;
  final String serviceName;
  final String trnDate;
  final String serviceId;
  final String seq;
  final String? visitorNationalId;
  final String? visitorMobile;
  final String? visitorPassport;

  CallResponse({
    required this.ticketNumber,
    required this.serviceName,
    required this.trnDate,
    required this.serviceId,
    required this.seq,
    this.visitorNationalId,
    this.visitorMobile,
    this.visitorPassport,
  });

  factory CallResponse.fromJson(Map<String, dynamic> json) {
    return CallResponse(
      ticketNumber: json['ticketNumber']?.toString() ?? '',
      serviceName: json['serviceName']?.toString() ?? '',
      trnDate: json['trnDate']?.toString() ?? '',
      serviceId: json['serviceId']?.toString() ?? '',
      seq: json['seq']?.toString() ?? '',
      visitorNationalId: json['visitorNationalId']?.toString(),
      visitorMobile: json['visitorMobile']?.toString(),
      visitorPassport: json['visitorPassport']?.toString(),
    );
  }
}

class Counter {
  final String counterId;
  final String counterName;

  Counter({
    required this.counterId,
    required this.counterName,
  });

  factory Counter.fromJson(Map<String, dynamic> json) {
    return Counter(
      counterId: json['CounterId']?.toString() ?? '',
      counterName: json['CounterName']?.toString() ?? '',
    );
  }
}

class QueueService {
  final String serviceId;
  final String serviceName;

  QueueService({
    required this.serviceId,
    required this.serviceName,
  });

  factory QueueService.fromJson(Map<String, dynamic> json) {
    return QueueService(
      serviceId: json['ServiceId']?.toString() ?? '',
      serviceName: json['ServiceName']?.toString() ?? '',
    );
  }
}