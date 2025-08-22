class SalesInvoiceDetail {
  final String billNo;
  final String itemCode;
  final String batchNo;
  final String packing;
  final double quantity;
  final double salesPrice;
  final double total;
  final double cgstTaxableAmt;

  SalesInvoiceDetail({
    required this.billNo,
    required this.itemCode,
    required this.batchNo,
    required this.packing,
    required this.quantity,
    required this.salesPrice,
    required this.total,
    required this.cgstTaxableAmt,
  });

  factory SalesInvoiceDetail.fromJson(Map<String, dynamic> json) {
    print('Raw JSON for SalesInvoiceDetail: $json');
    return SalesInvoiceDetail(
      billNo: json['billno']?.toString() ?? '',
      itemCode: json['itemcode']?.toString() ?? '',
      batchNo: json['batchno']?.toString() ?? '',
      packing: json['packing']?.toString() ?? '',
      quantity: _parseDouble(json['qty']),
      salesPrice: _parseDouble(json['salesprice']),
      total: _parseDouble(json['total']),
      cgstTaxableAmt: _parseDouble(json['cgsttaxableamt'] ?? 0.0), // Simplified this line
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'billno': billNo,
      'itemcode': itemCode,
      'batchno': batchNo,
      'packing': packing,
      'qty': quantity,
      'salesprice': salesPrice,
      'total': total,
      'cgsttaxableamt': cgstTaxableAmt,
    };
  }
}