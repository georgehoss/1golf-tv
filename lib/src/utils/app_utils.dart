import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

String localHour(String hour, {bool isUtc = false}) {
  try {
    DateFormat hourFormat = DateFormat('HH:mm');
    var now = hourFormat.parse(hour, isUtc);
    if (isUtc) {
      now = now.toLocal();
    }
    var formatter = DateFormat('hh:mm a');
    return formatter.format(now);
  } on Exception catch (e) {
    debugPrint(e.toString());
  }
  return '';
}

String dayMonthAndYear(String date, String language, {String hours = ''}) {
  try {
    language = (language.contains('es')) ? 'es_US' : 'en_US';
    String format = 'yyyy-MM-dd HH:mm';
    if (date == 'null') return '';

    initializeDateFormatting();
    var oldFormat = DateFormat(format);
    var oldDate = oldFormat.parse(date, false);
    oldDate = oldDate.toLocal();
    var formatter = DateFormat.yMMMMd(language);
    var formatter2 = DateFormat.EEEE(language);
    var timeF = DateFormat('hh:mm a');

    String newDate =
        '${formatter2.format(oldDate)} ${formatter.format(oldDate)} - ${hours.isNotEmpty ? localHour(hours) : timeF.format(oldDate)}';
    return capitalization(newDate);
  } on Exception catch (e) {
    debugPrint(e.toString());
  }
  return date;
}

String capitalization(String value) {
  try {
    return value[0].toUpperCase() + value.substring(1);
  } catch (e) {
    return '';
  }
}

Future<void> blaunchUrl(String url) async {
  try {
    if (await canLaunchUrl(Uri.parse(url.trim()))) {
      await launchUrlString(url);
    } else {
      debugPrint('Could not launch $url');
    }
  } on Exception {
    // no-op
  }
}

int compareVersions(String actualVersion, String serverVersion) {
  List<String> actualSegments = actualVersion.split('.');
  List<String> serverSegments = serverVersion.split('.');

  int maxLength = actualSegments.length > serverSegments.length
      ? actualSegments.length
      : serverSegments.length;

  for (int i = 0; i < maxLength; i++) {
    int actualPart =
        i < actualSegments.length ? int.tryParse(actualSegments[i]) ?? 0 : 0;
    int serverPart =
        i < serverSegments.length ? int.tryParse(serverSegments[i]) ?? 0 : 0;

    if (actualPart > serverPart) return 1;
    if (actualPart < serverPart) return -1;
  }

  return 0;
}
