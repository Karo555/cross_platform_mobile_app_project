import 'package:flutter_test/flutter_test.dart';
import 'package:patient_tracker/core/event_id.dart';

void main() {
  test('is a version 4 UUID', () {
    expect(
      newEventId(),
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
          r'[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test('is different every time', () {
    final ids = {for (var i = 0; i < 1000; i++) newEventId()};
    expect(ids, hasLength(1000));
  });
}
