//Model for combined data
class SalesItemDetail{
  final String billNo;
  final String itemCode;
  final String itemName;
  final String batchNo;
  final String packing;
  final double quantity;
  final double rate;
  final double amount;

  SalesItemDetail({
    required this.billNo,
    required this.quantity,
    required this.packing,
    required this.itemCode,
    required this.itemName,
    required this.batchNo,
    required this.amount,
    required this.rate
});
  Map<String,dynamic> toMap(){
    return{
      'BillNo':billNo,
      'ItemCode':itemCode,
      'ItemName':itemName,
      'BatchNo':batchNo,
      'Packing':packing,
      'Quantity':quantity,
      'Rate':rate,
      'Amount':amount
    };
  }
}
class SalesEntry{
  final String accountName;
  final String billNo;
  final String? paymentMode;
  final double amount;
  final DateTime? entryDate;
  final DateTime? invoiceDate;
  final List<SalesItemDetail>items;

  SalesEntry({
    required this.amount,
    required this.billNo,
    this.entryDate,
    this.invoiceDate,
    required this.paymentMode,
    required this.accountName,
    this.items=const[],

});
  int compareTo(SalesEntry other){
    final dateA = entryDate??invoiceDate??DateTime(0);
    final dateB=other.entryDate??other.invoiceDate??DateTime(0);
    return dateA.compareTo(dateB);
  }
  Map<String,dynamic> toMap(){
    return{
      'AccountName':accountName,
      'BillNo':billNo,
      'PaymentMode':paymentMode,
      'Amount':amount,
      'EntryDate':entryDate,
      'InvoiceDate':invoiceDate,
      'Items':items.map((item)=>item.toMap()).toList(),
    };
  }
}