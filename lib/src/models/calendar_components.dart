/// The golf API returns `calendar` as an object `{ "events": [...] }`, where
/// each event is a tournament. This helper extracts that list.
List<GolfTournament> tournamentsFromCalendar(dynamic calendarJson) {
  if (calendarJson == null) return [];
  final events = calendarJson is Map ? calendarJson['events'] : calendarJson;
  if (events is! List) return [];
  return List<GolfTournament>.from(
    events.map((x) => GolfTournament.fromJson(x)),
  );
}

class GolfTournament {
  String? id;
  String? name;
  String? logo;
  String? course;
  String? location;
  String? date;
  String? status;

  GolfTournament({
    this.id,
    this.name,
    this.logo,
    this.course,
    this.location,
    this.date,
    this.status,
  });

  factory GolfTournament.fromJson(Map<String, dynamic> json) => GolfTournament(
        id: json['id']?.toString(),
        name: json['name'],
        logo: json['logo'],
        course: json['course'],
        location: json['location'],
        date: json['date'],
        status: json['status'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'logo': logo,
        'course': course,
        'location': location,
        'date': date,
        'status': status,
      };
}
