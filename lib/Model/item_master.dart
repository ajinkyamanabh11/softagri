class ItemMaster {
  final String itemcode;
  final String itemname;
  final String itemtype;

  ItemMaster({
    required this.itemname,
    required this.itemtype,
    required this.itemcode,
  });

  factory ItemMaster.fromJson(Map<String, dynamic> json) {
    return ItemMaster(
      itemname: json['itemname']?.toString().trim() ?? '',
      itemtype: json['itemtype']?.toString() ?? '',
      itemcode: json['itemcode']?.toString() ?? '',
    );
  }
  Map<String, dynamic> toJson() => {
    'itemcode': itemcode,
    'itemname': itemname,
    'itemtype': itemtype,
  };
}
