import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../utils/dateparsing.dart';

class AllAccounts_Model {
  final int transactionNo;
  final String transactionType;
  final int accountCode;
  final DateTime? transactionDate;
  final String? invoiceNo;
  final double amount;
  final bool isCash;
  final bool isDr;
  final String narrations;

  AllAccounts_Model({
    required this.amount,
    required this.accountCode,
    required this.narrations,
    required this.isDr,
    required this.isCash,
    required this.transactionType,
    required this.transactionNo,
    required this.transactionDate,
    required this.invoiceNo,
  });

  factory AllAccounts_Model.fromJson(Map<String, dynamic> json) {
    return AllAccounts_Model(
      amount: _parseDouble(json['amount']),
      accountCode: _parseInt(json['accountcode']),
      narrations: _parseString(json['narrations'], defaultValue: '-'),
      isDr: _parseBool(json['isitdr']),
      isCash: _parseBool(json['isitcash']),
      transactionType: _parseString(json['transactiontype'], defaultValue: '-'),
      transactionDate: _parseDate(json['transactiondate']),
      transactionNo: _parseInt(json['transactionno']),
      invoiceNo: _parseString(json['invoiceno'], defaultValue: '-'),
    );
  }

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'accountcode': accountCode,
    'narrations': narrations,
    'isitdr': isDr,
    'isitcash': isCash,
    'transactiontype': transactionType,
    'transactiondate': transactionDate?.toIso8601String(),
    'transactionno': transactionNo,
    'invoiceno': invoiceNo,
  };

  String get formattedDate {
    if (transactionDate == null) return '-';
    return DateFormat('dd/MM/yyyy').format(transactionDate!);
  }

  String get formattedAmount {
    return '₹${amount.toStringAsFixed(2)}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is AllAccounts_Model &&
              runtimeType == other.runtimeType &&
              transactionNo == other.transactionNo;

  @override
  int get hashCode => transactionNo.hashCode;

  @override
  String toString() {
    return 'AllAccounts_Model{transactionNo: $transactionNo, accountCode: $accountCode, '
        'amount: $amount, type: $transactionType}';
  }

  // Helper methods for parsing
  static DateTime? _parseDate(dynamic dateString) {
    if (dateString == null || dateString.toString().isEmpty) return null;

    try {
      // First try standard ISO format
      try {
        return DateTime.parse(dateString.toString()).toLocal();
      } catch (_) {
        // Fall back to RFC1123 parser
        return _parseRfc1123(dateString.toString());
      }
    } catch (e) {
      debugPrint('Error parsing date $dateString: $e');
      return null;
    }
  }

  static DateTime? _parseRfc1123(String dateString) {
    try {
      // Example format: "Tue, 01 Apr 2025 00:00:00 GMT"
      final months = {
        'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
        'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
      };

      final parts = dateString.split(' ');
      if (parts.length < 6) return null;

      final day = int.tryParse(parts[1]) ?? 1;
      final month = months[parts[2]] ?? 1;
      final year = int.tryParse(parts[3]) ?? DateTime.now().year;
      final timeParts = parts[4].split(':');
      final hour = timeParts.length > 0 ? int.tryParse(timeParts[0]) ?? 0 : 0;
      final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;
      final second = timeParts.length > 2 ? int.tryParse(timeParts[2]) ?? 0 : 0;

      return DateTime(year, month, day, hour, minute, second);
    } catch (e) {
      debugPrint('Error parsing RFC1123 date $dateString: $e');
      return null;
    }
  }
  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    return value.toString().toLowerCase() == 'true';
  }

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