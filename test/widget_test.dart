import 'package:flutter_test/flutter_test.dart';
import 'package:moto_race_xtreme/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const MotoRaceApp());
    expect(find.text('MOTO RACE XTREME'), findsOneWidget);
  });
}
