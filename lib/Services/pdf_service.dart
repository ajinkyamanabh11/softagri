// // pdf_service.dart
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
// import '../Model/AllAccounts_Model.dart';
//
// class PdfService {
//   static Future<File> generateCustomerLedgerPdf({
//     required String customerName,
//     required List<AllAccounts_Model> transactions,
//     required double drTotal,
//     required double crTotal,
//     required double netOutstanding,
//   }) async {
//     final pdf = pw.Document();
//
//     pdf.addPage(
//       pw.MultiPage(
//         pageFormat: PdfPageFormat.a4,
//         build: (pw.Context context) {
//           return [
//             // Header
//             pw.Header(
//               level: 0,
//               child: pw.Row(
//                 mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                 children: [
//                   pw.Text('Customer Ledger Report',
//                       style: pw.TextStyle(
//                           fontSize: 20, fontWeight: pw.FontWeight.bold)),
//                   pw.Text(
//                       DateFormat('yyyy-MM-dd').format(DateTime.now()),
//                       style: const pw.TextStyle(fontSize: 12)),
//                 ],
//               ),
//             ),
//             pw.SizedBox(height: 10),
//             pw.Text(
//               'Customer Name: $customerName',
//               style: pw.TextStyle(fontSize: 16),
//             ),
//             pw.SizedBox(height: 20),
//
//             // Ledger Table
//             pw.Table.fromTextArray(
//               context: context,
//               headers: [
//                 'Date',
//                 'Invoice No',
//                 'Narration',
//                 'Debit (Dr)',
//                 'Credit (Cr)',
//               ],
//               data: transactions.map((t) {
//                 return [
//                   t.transactionDate != null
//                       ? DateFormat('dd/MM/yyyy').format(t.transactionDate!)
//                       : '-',
//                   t.invoiceNo ?? '-',
//                   t.narrations,
//                   t.isDr ? t.amount.toStringAsFixed(2) : '-',
//                   !t.isDr ? t.amount.toStringAsFixed(2) : '-',
//                 ];
//               }).toList(),
//               headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
//               cellAlignment: pw.Alignment.centerLeft,
//               cellAlignments: {
//                 0: pw.Alignment.center,
//                 1: pw.Alignment.center,
//                 2: pw.Alignment.center,
//                 3: pw.Alignment.center,
//                 4: pw.Alignment.center,
//               },
//             ),
//
//             pw.SizedBox(height: 20),
//
//             // Totals
//             pw.Container(
//               alignment: pw.Alignment.centerRight,
//               child: pw.Column(
//                 crossAxisAlignment: pw.CrossAxisAlignment.end,
//                 children: [
//                   pw.Divider(),
//                   pw.Row(
//                     mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                     children: [
//                       pw.Text('Debit Total:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
//                       pw.Text('₹${drTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
//                     ],
//                   ),
//                   pw.SizedBox(height: 8),
//                   pw.Row(
//                     mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                     children: [
//                       pw.Text('Credit Total:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
//                       pw.Text('₹${crTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
//                     ],
//                   ),
//                   pw.Divider(),
//                   pw.Row(
//                     mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                     children: [
//                       pw.Text('Net Outstanding:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
//                       pw.Text(
//                         '₹${netOutstanding.abs().toStringAsFixed(2)} ${netOutstanding < 0 ? 'Cr' : 'Dr'}',
//                         style: pw.TextStyle(
//                           fontWeight: pw.FontWeight.bold,
//                           color: netOutstanding < 0 ? PdfColors.red : PdfColors.green,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ];
//         },
//       ),
//     );
//
//     final output = await getTemporaryDirectory();
//     final file = File('${output.path}/ledger_report.pdf');
//     await file.writeAsBytes(await pdf.save());
//     return file;
//   }
// }