import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

DateTime? parseRfc1123(String dateString) {
  try {
    // Remove the day name and comma if present
    final cleaned = dateString.replaceFirst(RegExp(r'^\w{3},\s*'), '');
    // Parse the remaining date string
    return DateFormat('dd MMM yyyy HH:mm:ss').parse(cleaned);
  } catch (e) {
    debugPrint('Error parsing date $dateString: $e');
    return null;
  }
}