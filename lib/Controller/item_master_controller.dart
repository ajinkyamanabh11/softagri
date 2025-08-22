import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../model/item_master.dart';

class ItemMasterController extends GetxController{
  var isloading =false.obs;
  var errorMessage=Rx<String?>(null);
  var itemMasterData=<ItemMaster>[].obs;

  final String _baseApiUrl='http://103.26.205.120:5000/read_table';
  final String _subfolder='20252026';
  final String _filename='softagri.mdb';


}

