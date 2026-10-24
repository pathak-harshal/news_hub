import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/core/config/flavor.dart';

void main() {
  group('Flavor.fromName', () {
    test('parses "dev" to Flavor.dev', () {
      expect(Flavor.fromName('dev'), Flavor.dev);
    });

    test('throws FormatException naming the value for an unknown flavor', () {
      expect(
        () => Flavor.fromName('prod'),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('prod'),
          ),
        ),
      );
    });
  });
}
