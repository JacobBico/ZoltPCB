import 'package:intl/intl.dart';

final _time = DateFormat('HH:mm');
final _dayMonth = DateFormat('d MMM');
final _dayMonthYear = DateFormat('d MMM yyyy');

/// A short, glanceable timestamp for list rows: `14:32`, `9 Mar`,
/// `9 Mar 2024`.
String formatTimestamp(DateTime value, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final thatDay = DateTime(value.year, value.month, value.day);

  if (thatDay == today) return _time.format(value);
  if (thatDay == today.subtract(const Duration(days: 1))) {
    return 'yesterday';
  }
  if (value.year == reference.year) return _dayMonth.format(value);
  return _dayMonthYear.format(value);
}

/// `12 parts`, `1 part`.
String plural(int count, String singular, [String? pluralForm]) {
  final word = count == 1 ? singular : (pluralForm ?? '${singular}s');
  return '$count $word';
}
