import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class AccountMaster_Model {
  final int accountNumber;
  final String accountName;
  final double openingBalance;
  final String type;

  AccountMaster_Model({
    required this.accountName,
    required this.accountNumber,
    required this.openingBalance,
    required this.type,
  });

  factory AccountMaster_Model.fromJson(Map<String, dynamic> json) {
    return AccountMaster_Model(
      accountNumber: _parseInt(json['accountnumber']),
      accountName: _parseString(json['accountname']),
      openingBalance: _parseDouble(json['openingbalance']),
      type: _parseString(json['is_customer_supplier'], defaultValue: 'N/A'),
    );
  }

  Map<String, dynamic> toJson() => {
    'accountnumber': accountNumber,
    'accountname': accountName,
    'openingbalance': openingBalance,
    'is_customer_supplier': type,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is AccountMaster_Model &&
              runtimeType == other.runtimeType &&
              accountNumber == other.accountNumber;

  @override
  int get hashCode => accountNumber.hashCode;

  @override
  String toString() {
    return 'AccountMaster_Model{accountNumber: $accountNumber, accountName: $accountName, '
        'openingBalance: $openingBalance, type: $type}';
  }

  // Helper methods for parsing
  static int _parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    return int.tryParse(value.toString()) ?? defaultValue;
  }

  static double _parseDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    return double.tryParse(value.toString()) ?? defaultValue;
  }

  static String _parseString(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    return value.toString().trim();
  }
}
