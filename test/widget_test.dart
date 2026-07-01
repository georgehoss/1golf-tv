import 'package:flutter_test/flutter_test.dart';

import 'package:one_golf_android_tv/main.dart';

void main() {
  testWidgets('App boots and shows the 1Golf TV placeholder home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('1Golf TV'), findsOneWidget);
  });
}
