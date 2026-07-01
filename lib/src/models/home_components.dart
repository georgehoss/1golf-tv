import 'calendar_components.dart';
import 'items_list.dart';

/// Components of the `home` screen returned by `GET /app`.
class HomeComponents {
  OBChannels? channels;
  List<GolfTournament>? calendar;
  ItemsList? leagues;
  ItemsList? shows;
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

  HomeComponents({
    this.channels,
    this.calendar,
    this.leagues,
    this.shows,
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

  factory HomeComponents.fromJson(Map<String, dynamic> json) => HomeComponents(
        channels: json['channels'] == null
            ? null
            : OBChannels.fromJson(json['channels']),
        calendar: tournamentsFromCalendar(json['calendar']),
        leagues:
            json['leagues'] == null ? null : ItemsList.fromJson(json['leagues']),
        shows: json['shows'] == null ? null : ItemsList.fromJson(json['shows']),
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
        'channels': channels?.toJson(),
        'calendar': calendar == null
            ? []
            : List<dynamic>.from(calendar!.map((x) => x.toJson())),
        'leagues': leagues?.toJson(),
        'shows': shows?.toJson(),
        'itemslist_1': itemslist1?.toJson(),
        'itemslist_2': itemslist2?.toJson(),
        'itemslist_3': itemslist3?.toJson(),
      };
}

class OBChannels {
  String? title;
  List<OBChannel>? items;

  OBChannels({this.title, this.items});

  factory OBChannels.fromJson(Map<String, dynamic> json) => OBChannels(
        title: json['title'],
        items: json['items'] == null
            ? []
            : List<OBChannel>.from(
                json['items']!.map((x) => OBChannel.fromJson(x)),
              ),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'items': items == null
            ? []
            : List<dynamic>.from(items!.map((x) => x.toJson())),
      };
}

class OBChannel {
  int? objectId;
  String? title;
  String? thummb;
  String? typeEvent;
  String? livestreamId;
  String? streamEvent;
  String? streamTv;
  String? fullPathEvent;
  bool? isPrivate;
  String? channel;
  bool? activateDm;
  String? picture;
  String? picturemb;

  OBChannel({
    this.objectId,
    this.title,
    this.thummb,
    this.typeEvent,
    this.livestreamId,
    this.streamEvent,
    this.streamTv,
    this.fullPathEvent,
    this.isPrivate,
    this.channel,
    this.activateDm,
    this.picture,
    this.picturemb,
  });

  factory OBChannel.fromJson(Map<String, dynamic> json) => OBChannel(
        objectId: json['object_id'],
        title: json['title'],
        thummb: json['thummb'],
        typeEvent: json['typeEvent'],
        livestreamId: json['livestreamID'],
        streamEvent: json['streamEvent'],
        streamTv: json['streamTv'],
        fullPathEvent: json['fullPathEvent'],
        isPrivate: json['private'] != null
            ? json['private'] is String
                ? json['private'] == 'true'
                : json['private']
            : false,
        channel: json['channel'],
        activateDm: json['activate_dm'] ?? false,
        picture: json['picture'],
        picturemb: json['picturemb'],
      );

  Map<String, dynamic> toJson() => {
        'object_id': objectId,
        'title': title,
        'thummb': thummb,
        'typeEvent': typeEvent,
        'livestreamID': livestreamId,
        'streamEvent': streamEvent,
        'streamTv': streamTv,
        'fullPathEvent': fullPathEvent,
        'private': isPrivate,
        'channel': channel,
        'activate_dm': activateDm,
        'picture': picture,
        'picturemb': picturemb,
      };
}
