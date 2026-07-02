/// Unified model for the item lists used across screens (leagues, shows,
/// `itemslist_N`, etc.) — the golf API reuses the same `{title, type, items}`
/// shape for all of them.
class ItemsList {
  String? title;
  String? type; // 'videos', 'grid', 'carousel', etc.
  List<ItemsListItem>? items;

  ItemsList({this.title, this.type, this.items});

  factory ItemsList.fromJson(Map<String, dynamic> json) => ItemsList(
    title: json['title'],
    type: json['type'],
    items: json['items'] == null
        ? []
        : List<ItemsListItem>.from(
            json['items']!.map((x) => ItemsListItem.fromJson(x)),
          ),
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'type': type,
    'items': items == null
        ? []
        : List<dynamic>.from(items!.map((x) => x.toJson())),
  };
}

class ItemsListItem {
  int? objectId;
  String? size;
  String? title;
  String? image;
  String? thumb;
  String? media; // Video URL
  String? fullPathEvent; // Alternative video URL
  String? type;
  String? dateevent;
  String? content;
  bool? private;
  String? todetail;

  ItemsListItem({
    this.objectId,
    this.size,
    this.title,
    this.image,
    this.thumb,
    this.media,
    this.fullPathEvent,
    this.type,
    this.dateevent,
    this.content,
    this.private,
    this.todetail,
  });

  factory ItemsListItem.fromJson(Map<String, dynamic> json) => ItemsListItem(
    objectId: json['object_id'],
    size: json['size'],
    title: json['title'],
    // La API devuelve `false` (bool) en vez de null cuando no hay imagen.
    image: _asString(json['image']),
    thumb: _asString(json['thumb'] ?? json['logo']),
    media: _asString(json['media']),
    fullPathEvent: _asString(json['fullPathEvent']),
    type: json['type'],
    dateevent: json['dateevent'],
    content: json['content'],
    private: json['private'],
    todetail: json['todetail'],
  );

  static String? _asString(dynamic value) => value is String ? value : null;

  Map<String, dynamic> toJson() => {
    'object_id': objectId,
    'size': size,
    'title': title,
    'image': image,
    'logo': thumb,
    'media': media,
    'fullPathEvent': fullPathEvent,
    'type': type,
    'dateevent': dateevent,
    'content': content,
    'private': private,
    'todetail': todetail,
  };
}
