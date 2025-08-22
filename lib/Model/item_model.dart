import 'package:flutter/material.dart';
class Item{
  final int itemcode;
  final String itemname;
  final String itemtype;
  Item({required this.itemtype,required this.itemname,required this.itemcode});
  //Factory contructor to create an Item from a JSON map
  factory Item.fromJson (Map<String,dynamic>json){

    return Item(
      itemcode: int.tryParse(json['itemcode']?.toString()??'')??0,
      itemname: json['itemname']?.toString()??"",
      itemtype: json['itemtype']?.toString()??''


    );
  }
}