// sales_invoice_master.dart
import 'package:apidemo/utils/dateparsing.dart';
import 'package:flutter/material.dart';

class SalesInvoiceMaster {
  final String billNo;
  final String accountName;
  final String paymentMode;
  final double totalBillAmount;
  final DateTime? invoiceDate;
  final DateTime? entryDate;

  SalesInvoiceMaster({
    required this.billNo,
    required this.accountName,
    required this.paymentMode,
    required this.totalBillAmount,
    required this.invoiceDate,
    required this.entryDate,
  });

  factory SalesInvoiceMaster.fromJson(Map<String, dynamic> json) {
    return SalesInvoiceMaster(
      billNo: json['billno']?.toString() ?? '',
      accountName: json['accountname']?.toString() ?? '',
      paymentMode: json['paymentmode']?.toString() ?? '',
      totalBillAmount: double.tryParse(json['totalbillamount']?.toString() ?? '0.0') ?? 0.0,
      invoiceDate: _parseDate(json['invoicedate']),
      entryDate: _parseDate(json['entrydate']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'billno': billNo,
      'accountname': accountName,
      'paymentmode': paymentMode,
      'totalbillamount': totalBillAmount,
      'invoicedate': invoiceDate?.toIso8601String(),
      'entrydate': entryDate?.toIso8601String(),
    };
  }

  static DateTime? _parseDate(dynamic dateString) {
    if (dateString == null || dateString == "") return null;
    try {
      // First try standard ISO format
      try {
        return DateTime.parse(dateString.toString()).toLocal();
      } catch (_) {
        // Fall back to RFC1123 parser
        return parseRfc1123(dateString.toString());
      }
    } catch (e) {
      debugPrint('Error parsing date $dateString: $e');
      return null;
    }
  }
}