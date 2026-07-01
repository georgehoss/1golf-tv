import 'dart:convert';

import 'items_list.dart';

List<ShowDetails> showDetailsFromJson(String str) {
  final jsonData = jsonDecode(str);
  return List<ShowDetails>.from(jsonData.map((x) => ShowDetails.fromJson(x)));
}

class ShowDetails {
  int? id;
  String? title;
  String? description;
  String? type;
  String? thumb;
  ShowComponents? components;

  ShowDetails({
    this.id,
    this.title,
    this.description,
    this.type,
    this.thumb,
    this.components,
  });

  factory ShowDetails.fromJson(Map<String, dynamic> json) => ShowDetails(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    type: json['type'],
    thumb: json['thumb'],
    components: json['components'] == null
        ? null
        : ShowComponents.fromJson(json['components']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type,
    'thumb': thumb,
    'components': components?.toJson(),
  };
}

class ShowComponents {
  List<ShowItem>? items;
  ItemsList? itemslist1;
  ItemsList? itemslist2;
  ItemsList? itemslist3;
  ItemsList? itemslist4;
  ItemsList? itemslist5;
  ItemsList? itemslist6;
  ItemsList? itemslist7;
  ItemsList? itemslist8;
  ItemsList? itemslist9;
  ItemsList? itemslist10;
  ItemsList? itemslist11;
  ItemsList? itemslist12;
  ItemsList? itemslist13;
  ItemsList? itemslist14;
  ItemsList? itemslist15;
  ItemsList? itemslist16;
  ItemsList? itemslist17;
  ItemsList? itemslist18;
  ItemsList? itemslist19;
  ItemsList? itemslist20;

  ShowComponents({
    this.items,
    this.itemslist1,
    this.itemslist2,
    this.itemslist3,
    this.itemslist4,
    this.itemslist5,
    this.itemslist6,
    this.itemslist7,
    this.itemslist8,
    this.itemslist9,
    this.itemslist10,
    this.itemslist11,
    this.itemslist12,
    this.itemslist13,
    this.itemslist14,
    this.itemslist15,
    this.itemslist16,
    this.itemslist17,
    this.itemslist18,
    this.itemslist19,
    this.itemslist20,
  });

  factory ShowComponents.fromJson(Map<String, dynamic> json) => ShowComponents(
    items: json['items'] == null
        ? []
        : List<ShowItem>.from(json['items']!.map((x) => ShowItem.fromJson(x))),
    itemslist1: json['itemslist_1'] == null
        ? null
        : ItemsList.fromJson(json['itemslist_1']),
    itemslist2: json['itemslist_2'] == null
        ? null
        : ItemsList.fromJson(json['itemslist_2']),
    itemslist3: json['itemslist_3'] == null
        ? null
        : ItemsList.fromJson(json['itemslist_3']),
    itemslist4: json['itemslist_4'] == null
        ? null
        : ItemsList.fromJson(json['itemslist_4']),
    itemslist5: json['itemslist_5'] == null
        ? null
        : ItemsList.fromJson(json['itemslist_5']),
    itemslist6: json['itemslist_6'] == null
        ? null
        : ItemsList.fromJson(json['itemslist_6']),
    itemslist7: json['itemslist_7'] == null
        ? null
        : ItemsList.fromJson(json['itemslist_7']),
    itemslist8: json['itemslist_8'] == null
        ? null
        : ItemsList.fromJson(json['itemslist_8']),
    itemslist9: json['itemslist_9'] == null
        ? null
        : ItemsList.fromJson(json['itemslist_9']),
    itemslist10: json['itemslist_10'] == null
        ? null
        : ItemsList.fromJson(json['itemslist_10']),
    itemslist11: json['itemslist_11'] == null
        ? null
        : ItemsList.fromJson(json['itemslist_11']),
    itemslist12: json['itemslist_12'] == null
        ? null
        : ItemsList.fromJson(json['itemslist_12']),
    itemslist13: json['itemslist_13'] == null
        ? null
        : ItemsList.fromJson(json['itemslist_13']),
    itemslist14: json['itemslist_14'] == null
        ? null
        : ItemsList.fromJson(json['itemslist_14']),
    itemslist15: json['itemslist_15'] == null
        ? null
        : ItemsList.fromJson(json['itemslist_15']),
    itemslist16: json['itemslist_16'] == null
        ? null
        : ItemsList.fromJson(json['itemslist_16']),
    itemslist17: json['itemslist_17'] == null
        ? null
        : ItemsList.fromJson(json['itemslist_17']),
    itemslist18: json['itemslist_18'] == null
        ? null
        : ItemsList.fromJson(json['itemslist_18']),
    itemslist19: json['itemslist_19'] == null
        ? null
        : ItemsList.fromJson(json['itemslist_19']),
    itemslist20: json['itemslist_20'] == null
        ? null
        : ItemsList.fromJson(json['itemslist_20']),
  );

  Map<String, dynamic> toJson() => {
    'items': items == null
        ? []
        : List<dynamic>.from(items!.map((x) => x.toJson())),
  };
}

class ShowItem {
  int? objectId;
  String? title;
  String? date;
  String? image;
  String? media;
  bool? private;

  ShowItem({
    this.objectId,
    this.title,
    this.date,
    this.image,
    this.media,
    this.private,
  });

  factory ShowItem.fromJson(Map<String, dynamic> json) => ShowItem(
    objectId: json['object_id'],
    title: json['title'],
    date: json['date'],
    image: json['image'],
    media: json['media'],
    private: json['private'],
  );

  Map<String, dynamic> toJson() => {
    'object_id': objectId,
    'title': title,
    'date': date,
    'image': image,
    'media': media,
    'private': private,
  };
}
