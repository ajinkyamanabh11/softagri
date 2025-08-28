// import 'package:apidemo/Screens/loginpage.dart';
// import 'package:flutter/material.dart';
// import '../Controller/item_controller.dart';
// import 'package:get/get.dart';
//
// class ItemListPage extends StatelessWidget {
//   ItemListPage({super.key});
//
//   //Find the controller instance
//   final ItemController itemController = Get.find<ItemController>();
//   final TextEditingController _searchController = TextEditingController();
//   final FocusNode _searchfocus = FocusNode();
//   void dispose() {
//     _searchController.dispose();
//     _searchfocus.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("ItemMaster data"),
//         centerTitle: true,
//         actions: [
//           IconButton(
//             onPressed: () {
//               _searchController.clear();
//               _searchfocus.unfocus();
//               itemController.fetchItems();
//             },
//             icon: const Icon(Icons.refresh),
//           ),
//           IconButton(
//             onPressed: () => Get.offAll(LoginPage()),
//             icon: Icon(Icons.logout),
//             tooltip: 'logout',
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: TextField(
//               controller: _searchController,
//               focusNode: _searchfocus,
//               decoration: InputDecoration(
//                 labelText: 'Search By Item Name',
//                 prefixIcon: const Icon(Icons.search),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(32.0),
//                 ),
//               ),
//               onChanged: (value) {
//                 itemController.searchItems(value);
//               },
//             ),
//           ),
//           Expanded(
//             child: Obx(() {
//               // Obx rebuilds its child whenever an observable changes
//               if (itemController.isloading.value) {
//                 return const Center(child: CircularProgressIndicator());
//               } else if (itemController.errorMessage.isNotEmpty) {
//                 return Center(
//                   child: Padding(
//                     padding: const EdgeInsets.all(16.0),
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         const Icon(
//                           Icons.error_outline,
//                           color: Colors.red,
//                           size: 50,
//                         ),
//                         const SizedBox(height: 10),
//                         Text(
//                           "Error:${itemController.errorMessage.value}",
//                           textAlign: TextAlign.center,
//                           style: const TextStyle(
//                             color: Colors.red,
//                             fontSize: 16,
//                           ),
//                         ),
//                         const SizedBox(height: 20),
//                         ElevatedButton(
//                           onPressed: () => itemController.fetchItems(),
//                           child: const Text('Retry'),
//                         ),
//                       ],
//                     ),
//                   ),
//                 );
//               } else if (itemController.filteredItems.isEmpty) {
//                 return const Center(
//                   child: Text(
//                     'No items found .check your Json file or server',
//                     style: TextStyle(fontSize: 16, color: Colors.grey),
//                     textAlign: TextAlign.center,
//                   ),
//                 );
//               } else {
//                 //Display data in a ListView
//                 return ListView.builder(
//                   padding: const EdgeInsets.all(8.0),
//                   itemCount: itemController.items.length,
//                   itemBuilder: (context, index) {
//                     if (index >= itemController.filteredItems.length) {
//                       return null;
//                     }
//                     final item = itemController.filteredItems[index];
//                     return Card(
//                       margin: const EdgeInsets.symmetric(
//                         vertical: 8.0,
//                         horizontal: 4.0,
//                       ),
//                       elevation: 4,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Padding(
//                         padding: EdgeInsets.all(16),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'Item Code: ${item.itemcode}',
//                               style: const TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 16,
//                               ),
//                             ),
//                             const SizedBox(height: 4),
//                             Text(
//                               'Item Name:${item.itemname}',
//                               style: const TextStyle(fontSize: 15),
//                             ),
//                             const SizedBox(height: 4),
//                             Text(
//                               'Item Type :${item.itemtype}',
//                               style: const TextStyle(
//                                 fontStyle: FontStyle.italic,
//                                 color: Colors.green,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     );
//                   },
//                 );
//               }
//             }),
//           ),
//         ],
//       ),
//     );
//   }
// }
