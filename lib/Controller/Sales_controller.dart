import 'dart:developer';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../Model/item_master.dart';
import '../Model/salesReport_Models/salesInvoiceDetail_model.dart';
import '../Model/salesReport_Models/salesInvoiceMaster_model.dart';
import '../Model/salesReport_Models/salesItemDetail_combined.dart';
import '../Services/http_data_service.dart';
import 'base_remote_controller.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
class SalesController extends GetxController with BaseRemoteController {
  final HttpDataServices httpService = Get.find<HttpDataServices>();

  // Observable data
  final salesMaster = <SalesInvoiceMaster>[].obs;
  final salesDetails = <SalesInvoiceDetail>[].obs;
  final itemMaster = <ItemMaster>[].obs;
  final sales = <SalesEntry>[].obs;

  // Cache status
  final cacheStatus = 'Loading cache status...'.obs;
  final isCacheValid = false.obs;
  final isGeneratingBill = false.obs;

  @override
  void onInit() {
    super.onInit();
    _setupSubfolderListener();
    _initialDataLoad();
  }

  void _setupSubfolderListener() {
    // Listen to the RxString directly
    ever(httpService.subfolderRx, (String subfolder) {
      if (subfolder.isNotEmpty) {
        fetchSales();
      }
    });
  }

  void _initialDataLoad() {
    if (httpService.subfolderRx.isNotEmpty) {
      fetchSales();
    }
  }

  void _updateCacheStatus() {
    cacheStatus.value = '''
    Sales Master: ${httpService.getCacheStatus('salesInvoiceMaster')}
    Sales Details: ${httpService.getCacheStatus('salesInvoiceDetails')}
    Items: ${httpService.getCacheStatus('itemMaster')}
    ''';

    isCacheValid.value = httpService.isCacheValid('salesInvoiceMaster') &&
        httpService.isCacheValid('salesInvoiceDetails') &&
        httpService.isCacheValid('itemMaster');
  }

  Future<void> fetchSales({bool forceRefresh = false}) async {
    log('Fetching sales data for subfolder: ${httpService.subfolderRx}');
    return guard(() async {
      await _loadAllData(forceRefresh);
      _processCombinedSalesData();
      _updateCacheStatus();
    });
  }

  Future<void> _loadAllData(bool forceRefresh) async {
    final results = await Future.wait([
      httpService.fetchSalesInvoiceMaster(forceRefresh: forceRefresh),
      httpService.fetchSalesInvoiceDetails(forceRefresh: forceRefresh),
      httpService.fetchItemMaster(forceRefresh: forceRefresh),
    ]);

    salesMaster.value = results[0] as List<SalesInvoiceMaster>;
    salesDetails.value = results[1] as List<SalesInvoiceDetail>;
    itemMaster.value = results[2] as List<ItemMaster>;
  }

  void _processCombinedSalesData() {
    final itemCodeToName = _createItemCodeMap();
    final detailsByBillNo = _groupDetailsByBillNo(itemCodeToName);

    sales.value = salesMaster.map((master) => SalesEntry(
      accountName: master.accountName,
      billNo: master.billNo,
      paymentMode: master.paymentMode,
      amount: master.totalBillAmount,
      entryDate: master.entryDate,
      invoiceDate: master.invoiceDate,
      items: detailsByBillNo[master.billNo] ?? [],
    )).toList();
  }

  Map<String, String> _createItemCodeMap() {
    return {for (var item in itemMaster) item.itemcode: item.itemname};
  }

  Map<String, List<SalesItemDetail>> _groupDetailsByBillNo(Map<String, String> itemCodeToName) {
    final detailsByBillNo = <String, List<SalesItemDetail>>{};

    for (var detail in salesDetails) {
      if (detail.billNo.isEmpty) continue;

      detailsByBillNo.putIfAbsent(detail.billNo, () => []).add(
        SalesItemDetail(
          billNo: detail.billNo,
          itemCode: detail.itemCode,
          itemName: itemCodeToName[detail.itemCode] ?? 'Unknown Item',
          batchNo: detail.batchNo,
          packing: detail.packing,
          quantity: detail.quantity,
          rate: detail.salesPrice,
          amount: detail.total,
        ),
      );
    }

    return detailsByBillNo;
  }

  // Getters for totals
  double get totalCash => sales
      .where((s) => s.paymentMode?.toLowerCase() == 'cash')
      .fold(0.0, (sum, s) => sum + s.amount);

  double get totalCredit => sales
      .where((s) => s.paymentMode?.toLowerCase() == 'credit')
      .fold(0.0, (sum, s) => sum + s.amount);

  List<SalesEntry> filter({
    required String nameQ,
    required String billQ,
    DateTime? date,
  }) {
    return sales.where((s) {
      final nameMatch = s.accountName.toLowerCase().contains(nameQ.toLowerCase());
      final billMatch = s.billNo.toLowerCase().contains(billQ.toLowerCase());
      final dateMatch = date == null ||
          (s.entryDate != null && DateUtils.isSameDay(s.entryDate!, date));

      return nameMatch && billMatch && dateMatch;
    }).toList();
  }
  Future<void> generateAndShareSalesBill(SalesEntry entry) async {
    try {
      isGeneratingBill(true); // Set bill generation flag
      isLoading(true);

      // Generate PDF
      final pdfFile = await _generateSalesBillPdf(entry);

      // Share PDF
      await _sharePdf(pdfFile, entry.billNo);

      Get.snackbar(
          'Success',
          'Bill generated and shared successfully',
          snackPosition: SnackPosition.BOTTOM,
          duration: Duration(seconds: 2),
          colorText: Colors.black
      );
    } catch (e, st) {
      error.value = 'Failed to generate bill: ${e.toString()}';
      log('Error generating bill: $e\n$st');
      Get.snackbar(
          'Error',
          'Failed to generate bill: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM,
          duration: Duration(seconds: 4),
          colorText: Colors.black
      );
    } finally {
      isGeneratingBill(false); // Reset bill generation flag
      isLoading(false);
    }
  }

  Future<File> _generateSalesBillPdf(SalesEntry entry) async {
    final pdf = pw.Document();
    final _box = GetStorage();
    final companyName = _box.read('companyname') ?? 'Company Name';

    // Header with company info
    final header = pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(companyName,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('Sales Invoice',
                style: pw.TextStyle(fontSize: 14)),
          ],
        ),
        pw.Text('Generated On - ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10)),
      ],
    );

    // Bill Info
    final billInfo = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Bill No: ${entry.billNo}',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.Text('Customer: ${entry.accountName}',
            style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Payment Mode: ${entry.paymentMode?.toUpperCase() ?? 'N/A'}',
            style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Date: ${entry.entryDate != null ? DateFormat('dd/MM/yyyy').format(entry.entryDate!) : 'N/A'}',
            style: const pw.TextStyle(fontSize: 10)),
      ],
    );
    final footer=pw.Footer(title: pw.Text('This is a Computer Generated Bill',style: pw.TextStyle(color: PdfColors.grey,fontStyle: pw.FontStyle.italic)));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              header,
              pw.SizedBox(height: 15),
              billInfo,
              pw.SizedBox(height: 15),
              _buildItemsTable(entry.items),
              pw.SizedBox(height: 15),
              _buildTotalsSection(entry.amount),
              pw.SizedBox(height: 15),
              footer,

            ],
          );
        },
      ),

    );


    // Get directory and save file
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/Sales_Bill_${entry.billNo.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${entry.accountName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf');
    await file.writeAsBytes(await pdf.save());


    return file;
  }

  pw.Widget _buildItemsTable(List<SalesItemDetail> items) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.0), // Item Name
        1: const pw.FlexColumnWidth(1.0), // Batch
        2: const pw.FlexColumnWidth(0.8), // Qty
        3: const pw.FlexColumnWidth(1.0), // Rate
        4: const pw.FlexColumnWidth(1.2), // Amount
      },
      children: [
        // Table Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Item Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Batch', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Rate', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
          ],
        ),
        // Table Rows
        ...items.map((item) {
          return pw.TableRow(
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item.itemName, style: const pw.TextStyle(fontSize: 8))),
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item.batchNo, style: const pw.TextStyle(fontSize: 8))),
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item.quantity.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8))),
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${item.rate.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8))),
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${item.amount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8))),
            ],
          );
        }).toList(),
      ],
    );
  }

  pw.Widget _buildTotalsSection(double totalAmount) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Total Amount:', style:  pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text('Rs. ${totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _sharePdf(File file, String billNo) async {
    // Check and request storage permission if needed
    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
    }

    // Share the file
    await Share.shareXFiles([XFile(file.path)], text: 'Sales Bill - $billNo');
  }
}