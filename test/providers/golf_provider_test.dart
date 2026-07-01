import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_golf_android_tv/src/models/app_response.dart';
import 'package:one_golf_android_tv/src/models/home_components.dart';
import 'package:one_golf_android_tv/src/models/show_details.dart';

/// Parses a captured real response from `GET /app` (see
/// test/fixtures/app_response_sample.json) to lock in the contract that
/// GolfProvider.getHome() + HomeComponents.fromJson() rely on, without
/// depending on live network access during `flutter test`.
void main() {
  test('AppResponseList + HomeComponents parse the real /app payload', () {
    final raw = File(
      'test/fixtures/app_response_sample.json',
    ).readAsStringSync();
    final decoded = json.decode(raw) as List<dynamic>;

    final response = AppResponseList.fromJson(decoded);
    expect(response.list, isNotEmpty);

    final home = response.list.firstWhere((item) => item.name == 'home');
    expect(home.components, isNotNull);

    final homeComponents = HomeComponents.fromJson(home.components!);

    expect(homeComponents.channels?.title, 'EN VIVO');
    expect(homeComponents.channels?.items, hasLength(1));

    expect(homeComponents.leagues?.title, 'TOURS');
    expect(homeComponents.leagues?.items, hasLength(2));

    expect(homeComponents.shows?.title, 'NUESTROS PROGRAMAS');
    expect(homeComponents.shows?.items, hasLength(13));

    expect(homeComponents.calendar, hasLength(6));
  });

  test(
    'ShowDetails tolerates image: false (real quirk from GET /show/{id})',
    () {
      final raw = File(
        'test/fixtures/show_details_sample.json',
      ).readAsStringSync();

      final list = showDetailsFromJson(raw);
      expect(list, hasLength(1));

      final items = list.first.components?.itemslist1?.items ?? [];
      expect(items, hasLength(10));
      // La API devuelve `image: false` cuando el episodio no tiene thumbnail;
      // debe parsearse como null en vez de lanzar un type error, sin afectar
      // a los items que sí traen una URL real.
      final withoutImage = items.where((item) => item.image == null);
      final withImage = items.where((item) => item.image != null);
      expect(withoutImage, hasLength(9));
      expect(withImage, hasLength(1));
      expect(withImage.first.image, startsWith('https://static.1golf.tv'));
    },
  );
}
