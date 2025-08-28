  // customer_info_model.dart
  class CustomerInfoModel {
    final int accountNumber;
    final String mobile;
    final String area;

    CustomerInfoModel({
      required this.accountNumber,
      required this.mobile,
      required this.area,
    });

    factory CustomerInfoModel.fromJson(Map<String, dynamic> json) {
      return CustomerInfoModel(
        accountNumber: _parseInt(json['accountnumber']),
        mobile: _parseString(json['mobileno']),
        area: _parseString(json['area']),
      );
    }
    Map<String, dynamic> toJson() => {
      'accountnumber': accountNumber,
      'mobileno': mobile,
      'area': area,
    };
    static int _parseInt(dynamic value) => int.tryParse(value.toString()) ?? 0;
    static String _parseString(dynamic value) => value?.toString() ?? '';
  }