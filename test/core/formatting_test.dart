import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/core/util/formatting.dart';

void main() {
  final now = DateTime(2026, 3, 9, 14, 32);

  test('today shows the time', () {
    expect(formatTimestamp(DateTime(2026, 3, 9, 9, 5), now: now), '09:05');
  });

  test('yesterday is named', () {
    expect(formatTimestamp(DateTime(2026, 3, 8, 23, 59), now: now),
        'yesterday');
  });

  test('earlier this year shows day and month', () {
    expect(formatTimestamp(DateTime(2026, 1, 4, 8), now: now), '4 Jan');
  });

  test('other years include the year', () {
    expect(formatTimestamp(DateTime(2025, 11, 20, 8), now: now), '20 Nov 2025');
  });

  test('plural picks the right word', () {
    expect(plural(1, 'part'), '1 part');
    expect(plural(2, 'part'), '2 parts');
    expect(plural(0, 'net'), '0 nets');
  });
}
