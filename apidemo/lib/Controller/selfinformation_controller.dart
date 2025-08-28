import 'dart:convert';

import 'package:get/get.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

class CompanyController extends GetxController {
  final _box = GetStorage();
  final _companyNameKey = 'companyname';
  var companyName = 'Loading...'.obs;
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadStoredCompanyName();
  }

  void loadStoredCompanyName() {
    final storedName = _box.read(_companyNameKey);
    if (storedName != null) {
      companyName.value = storedName;
    }
  }

  Future<void> fetchCompanyName() async {
    try {
      isLoading(true);
      final username = _box.read('username');
      final subfolder = _box.read('subfolder');
      final userIdentifier = username ?? subfolder;

      if (userIdentifier == null) {
        companyName.value = "Company Name";
        return;
      }

      final response = await http.get(Uri.parse(
        'http://103.26.205.120:5000/read_table?subfolder=$userIdentifier/20252026&filename=softagri.mdb&table=SelfInformation',
      ));

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        final List<dynamic> jsonResponse = decodedData['data'] ?? [];

        if (jsonResponse.isNotEmpty) {
          // Try different key variations
          final companyData = jsonResponse[0];
          final name = companyData['companyname'] ??
              companyData['CompanyName'] ??
              companyData['Name'] ??
              "Company Name";

          companyName.value = name.toString();
          _box.write(_companyNameKey, name);
        } else {
          companyName.value = "Company Name";
        }
      } else {
        companyName.value = "Company Name";
      }
    } catch (e) {
      companyName.value = "Company Name";
    } finally {
      isLoading(false);
    }
  }
}