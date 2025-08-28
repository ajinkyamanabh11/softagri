// import 'dart:developer';
// import 'package:http/http.dart' as http;
// import'../Model/item_model.dart';
// import'package:get/get.dart';
// import'dart:convert';
//
// class ItemController extends GetxController{
//   //obervable list to hold the fetched items
//   var items=<Item>[].obs;
//   //observable boolean for loading state
//   var isloading=true.obs;
//   //observable string for error messages
//   var errorMessage="".obs;
//   var filteredItems=<Item>[].obs;
//   var userName=''.obs;
//
//   @override
//   void onInit(){
//     super.onInit();
//
//   }
//   void setUserName(String name){
//     userName.value=name;
//     fetchItems();
//   }
//   Future<void> fetchItems()async{
//     if(userName.isEmpty){
//       errorMessage('username is not entered');
//       isloading(false);
//       return;
//     }
//     try{
//       isloading(true);
//       errorMessage('');
//       final response= await http.get(Uri.parse('http://103.26.205.120:5000/read_table?subfolder=${userName.value}/20252026&filename=softagri_be.mdb&table=ItemMaster'));
//       if(response.statusCode==200){
//         final Map<String, dynamic> decodedData = json.decode(response.body);
//         final List<dynamic> jsonResponse = decodedData['data'];
//
//         if(jsonResponse.isNotEmpty){
//           final List<Item>fetchedItems=jsonResponse.map((json)=>Item.fromJson(json)).toList();
//           items.assignAll(fetchedItems);
//           filteredItems.assignAll(fetchedItems);
//         }
//         else{
//           errorMessage('No data found in the Csv file');
//         }
//       }
//       else{
//         errorMessage('Failed to load data: ${response.statusCode}');
//       }
//     }
//     catch(e){
//       errorMessage('Error fetching data: $e');
//       log('Error :$e');
//
//     }
//     finally{
//       isloading(false);
//     }
//   }
//   void searchItems(String query){
//     if(query.isEmpty){
//       filteredItems.assignAll(items);
//     }
//     else{
//       filteredItems.assignAll(items.where((item){
//         return item.itemname.toLowerCase().contains(query.toLowerCase());
//       }).toList());
//
//     }
//   }
//
//
// }