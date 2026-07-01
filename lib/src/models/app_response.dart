import 'dart:convert';

/// Top-level shape of `GET /app`: a list of named screens (`home`, `programas`,
/// `estadisticas`, `contacto`, `live`, ...), each with a loosely-typed
/// `components` map whose keys depend on the screen. Callers pick the screen
/// by `name` and parse `components` into the matching typed model
/// (e.g. `HomeComponents.fromJson` for the `home` screen).
class AppResponseList {
  List<AppResponse> list = [];

  AppResponseList({required this.list});

  AppResponseList.fromJson(List<dynamic> jsonList) {
    for (final item in jsonList) {
      list.add(AppResponse.fromJson(item));
    }
  }

  @override
  String toString() => 'list: $list';
}

AppResponse appResponseFromJson(String str) =>
    AppResponse.fromJson(json.decode(str));

class AppResponse {
  String? name;
  String? title;
  Map<String, dynamic>? components;
  AppUserInfo? user;

  AppResponse({this.name, this.title, this.components, this.user});

  factory AppResponse.fromJson(Map<String, dynamic> json) => AppResponse(
        name: json['name'],
        title: json['title'],
        components: json['components'],
        user: json['user'] == null ? null : AppUserInfo.fromJson(json['user']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'title': title,
        'components': components,
        'user': user?.toJson(),
      };

  @override
  String toString() =>
      'name: $name, title: $title, components: $components, user: $user';
}

/// Minimal user/geo info returned alongside the screens (used for geoblocking).
class AppUserInfo {
  String? geo;

  AppUserInfo({this.geo});

  factory AppUserInfo.fromJson(Map<String, dynamic> json) =>
      AppUserInfo(geo: json['geo']);

  Map<String, dynamic> toJson() => {'geo': geo};
}
