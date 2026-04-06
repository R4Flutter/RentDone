import 'package:flutter_test/flutter_test.dart';
import 'package:rentdone/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    group('defaults()', () {
      test('returns all-enabled defaults', () {
        final config = AppConfig.defaults();
        expect(config.paymentsEnabled, isTrue);
        expect(config.manualPaymentsEnabled, isTrue);
        expect(config.razorpayEnabled, isTrue);
        expect(config.maintenanceMode, isFalse);
        expect(config.lastUpdatedAt, isNull);
      });
    });

    group('fromMap()', () {
      test('returns defaults for null map', () {
        final config = AppConfig.fromMap(null);
        expect(config.paymentsEnabled, isTrue);
        expect(config.maintenanceMode, isFalse);
      });

      test('returns defaults for empty map', () {
        final config = AppConfig.fromMap({});
        expect(config.paymentsEnabled, isTrue);
        expect(config.razorpayEnabled, isTrue);
      });

      test('parses all fields correctly', () {
        final config = AppConfig.fromMap({
          'paymentsEnabled': false,
          'manualPaymentsEnabled': false,
          'razorpayEnabled': false,
          'maintenanceMode': true,
          'lastUpdatedAt': '2026-01-15T10:00:00.000Z',
        });
        expect(config.paymentsEnabled, isFalse);
        expect(config.manualPaymentsEnabled, isFalse);
        expect(config.razorpayEnabled, isFalse);
        expect(config.maintenanceMode, isTrue);
        expect(config.lastUpdatedAt, isNotNull);
        expect(config.lastUpdatedAt!.year, 2026);
      });

      test('parses integer timestamp for lastUpdatedAt', () {
        final ms = DateTime(2026, 3, 1).millisecondsSinceEpoch;
        final config = AppConfig.fromMap({'lastUpdatedAt': ms});
        expect(config.lastUpdatedAt, isNotNull);
      });

      test('parses DateTime for lastUpdatedAt', () {
        final date = DateTime(2026, 3, 1);
        final config = AppConfig.fromMap({'lastUpdatedAt': date});
        expect(config.lastUpdatedAt, date);
      });

      test('handles invalid lastUpdatedAt gracefully', () {
        final config = AppConfig.fromMap({'lastUpdatedAt': 'not-a-date'});
        expect(config.lastUpdatedAt, isNull);
      });

      test('treats missing boolean values as true (except maintenanceMode)', () {
        final config = AppConfig.fromMap({
          'maintenanceMode': null,
        });
        expect(config.paymentsEnabled, isTrue);
        expect(config.razorpayEnabled, isTrue);
        expect(config.maintenanceMode, isFalse);
      });
    });

    group('toMap()', () {
      test('serializes defaults correctly', () {
        final map = AppConfig.defaults().toMap();
        expect(map['paymentsEnabled'], isTrue);
        expect(map['manualPaymentsEnabled'], isTrue);
        expect(map['razorpayEnabled'], isTrue);
        expect(map['maintenanceMode'], isFalse);
        expect(map['lastUpdatedAt'], isNull);
      });

      test('round-trips through fromMap/toMap', () {
        final original = AppConfig.fromMap({
          'paymentsEnabled': false,
          'manualPaymentsEnabled': true,
          'razorpayEnabled': false,
          'maintenanceMode': true,
          'lastUpdatedAt': '2026-06-15T12:00:00.000Z',
        });
        final map = original.toMap();
        final restored = AppConfig.fromMap(map);

        expect(restored.paymentsEnabled, original.paymentsEnabled);
        expect(restored.manualPaymentsEnabled, original.manualPaymentsEnabled);
        expect(restored.razorpayEnabled, original.razorpayEnabled);
        expect(restored.maintenanceMode, original.maintenanceMode);
        expect(restored.lastUpdatedAt, isNotNull);
      });
    });
  });
}
