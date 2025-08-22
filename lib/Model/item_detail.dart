// item_detail.dart
class ItemDetail {
  final String itemcode;
  final String batchno;
  final String packing;
  final String cmbunit;
  final double currentstock;
  final double purchasePrice;

  ItemDetail({
    required this.itemcode,
    required this.batchno,
    required this.cmbunit,
    required this.currentstock,
    required this.packing,
    required this.purchasePrice,
  });

  factory ItemDetail.fromJson(Map<String, dynamic> json) {
    // The problem is here. The `cmb_unit` key is empty in your data.
    // Let's add an alternative key check for the unit.
    String unit = json['cmb_unit']?.toString().trim() ?? json['unit']?.toString().trim() ?? '';

    // Check for another potential key, as ItemMaster often contains a unit.
    if (unit.isEmpty) {
      unit = json['itemunit']?.toString().trim() ?? '';
    }

    return ItemDetail(
      itemcode: json['itemcode']?.toString().trim() ?? '',
      batchno: json["batchno"]?.toString().trim() ?? '',
      packing: json['txt_pkg']?.toString().trim() ?? json['packing']?.toString().trim() ?? '',
      cmbunit: unit,
      currentstock: double.tryParse(json['currentstock']?.toString() ?? '0') ?? 0.0,
      purchasePrice: double.tryParse(json['purchaseprice']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'itemcode': itemcode,
    'batchno': batchno,
    'packing': packing,
    'cmbunit': cmbunit,
    'currentstock': currentstock,
    'purchaseprice': purchasePrice,
  };
}