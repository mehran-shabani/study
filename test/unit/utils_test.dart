import 'package:flutter_test/flutter_test.dart';
import 'package:study/core/utils.dart';

void main() {
  group('Date formatting and parsing', () {
    test('formatDate formats DateTime correctly', () {
      final date = DateTime(2025, 1, 15);
      expect(AppUtils.formatDate(date), '2025-01-15');
    });

    test('parseDate parses string correctly', () {
      final date = AppUtils.parseDate('2025-01-15');
      expect(date.year, 2025);
      expect(date.month, 1);
      expect(date.day, 15);
    });

    test('today returns current date string', () {
      final today = AppUtils.today();
      expect(today, matches(r'^\d{4}-\d{2}-\d{2}$'));
    });
  });

  group('Workspace name validation', () {
    test('accepts valid name', () {
      expect(AppUtils.validateWorkspaceName('Valid Name'), isNull);
    });

    test('rejects empty name', () {
      expect(AppUtils.validateWorkspaceName(''), isNotNull);
      expect(AppUtils.validateWorkspaceName(null), isNotNull);
    });

    test('rejects name exceeding max length', () {
      final longName = 'a' * 51;
      expect(AppUtils.validateWorkspaceName(longName), isNotNull);
    });
  });

  group('Date validation', () {
    test('accepts valid date', () {
      expect(AppUtils.validateDate('2025-01-15'), isNull);
    });

    test('rejects empty date', () {
      expect(AppUtils.validateDate(''), isNotNull);
      expect(AppUtils.validateDate(null), isNotNull);
    });

    test('rejects invalid date format', () {
      expect(AppUtils.validateDate('15-01-2025'), isNotNull);
      expect(AppUtils.validateDate('2025/01/15'), isNotNull);
      expect(AppUtils.validateDate('invalid'), isNotNull);
    });
  });

  group('Date range validation', () {
    test('accepts valid date range', () {
      expect(AppUtils.validateDateRange('2025-01-01', '2025-12-31'), isNull);
    });

    test('rejects end date before start date', () {
      expect(AppUtils.validateDateRange('2025-12-31', '2025-01-01'), isNotNull);
    });

    test('accepts same start and end date', () {
      expect(AppUtils.validateDateRange('2025-01-01', '2025-01-01'), isNull);
    });
  });

  group('Entry title validation', () {
    test('accepts valid title', () {
      expect(AppUtils.validateEntryTitle('Math Study'), isNull);
    });

    test('rejects empty title', () {
      expect(AppUtils.validateEntryTitle(''), isNotNull);
      expect(AppUtils.validateEntryTitle(null), isNotNull);
    });

    test('rejects title exceeding max length', () {
      final longTitle = 'a' * 81;
      expect(AppUtils.validateEntryTitle(longTitle), isNotNull);
    });
  });

  group('Hours validation', () {
    test('accepts valid hours', () {
      expect(AppUtils.validateHours('1.5'), isNull);
      expect(AppUtils.validateHours('4.0'), isNull);
      expect(AppUtils.validateHours('24.0'), isNull);
    });

    test('rejects empty hours', () {
      expect(AppUtils.validateHours(''), isNotNull);
      expect(AppUtils.validateHours(null), isNotNull);
    });

    test('rejects invalid number', () {
      expect(AppUtils.validateHours('abc'), isNotNull);
    });

    test('rejects hours below minimum', () {
      expect(AppUtils.validateHours('0.1'), isNotNull);
    });

    test('rejects hours above maximum', () {
      expect(AppUtils.validateHours('25.0'), isNotNull);
    });
  });

  group('daysBetween', () {
    test('calculates days between dates', () {
      final start = DateTime(2025, 1, 1);
      final end = DateTime(2025, 1, 10);
      expect(AppUtils.daysBetween(start, end), 10);
    });

    test('returns 1 for same date', () {
      final date = DateTime(2025, 1, 1);
      expect(AppUtils.daysBetween(date, date), 1);
    });
  });

  group('Formatting', () {
    test('formatHours formats correctly', () {
      expect(AppUtils.formatHours(2.5), '2.5h');
      expect(AppUtils.formatHours(1.0), '1.0h');
    });

    test('formatPercentage formats correctly', () {
      expect(AppUtils.formatPercentage(75.5), '75.5%');
      expect(AppUtils.formatPercentage(100.0), '100.0%');
    });
  });
}
