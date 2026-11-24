import 'package:biblia_jg/services/ebd_reminder.dart';
import 'package:biblia_jg/services/places.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('primeiro domingo do trimestre', () {
    expect(firstSundayOfQuarter(2026, 4), DateTime(2026, 10, 4));
    expect(firstSundayOfQuarter(2027, 1), DateTime(2027, 1, 3));
  });

  test('referência OSIS', () {
    expect(osisToRef('Gen.12.8'), (0, 12, 8));
    expect(osisToRef('Rev.22.21'), (65, 22, 21));
    expect(osisToRef('xx'), isNull);
  });

  test('lugares e histórias carregam', () async {
    final d = await PlacesData.load();
    expect(d.stories.length, greaterThanOrEqualTo(7));
    expect(d.places.length, greaterThan(1000));
    expect(d.forVerse(0, 12, 8).map((p) => p.name), contains('Betel'));
    expect(d.search('Jerusalém').first.name, 'Jerusalém');
  });
}
