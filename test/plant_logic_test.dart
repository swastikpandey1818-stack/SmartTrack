import 'package:flutter_test/flutter_test.dart';
import 'package:smart_track/domain/models.dart';
import 'package:smart_track/domain/plant_logic.dart';
import 'package:smart_track/domain/settings.dart';

SensorStatus status({
  int moisture = 60,
  int tank = 80,
  double distance = 8,
  bool pump = false,
  bool manual = false,
}) =>
    SensorStatus(
        moisture: moisture,
        tank: tank,
        distance: distance,
        pump: pump,
        manual: manual,
        wifi: true,
        ip: '192.168.4.1');


void main() {
  const settings = AppSettings();
  final now = DateTime(2026, 11, 21, 12);

  group('derivePlantState', () {
    PlantState d(SensorStatus? s, {bool connected = true, bool rainSoon = false}) =>
        derivePlantState(status: s, connected: connected, rainSoon: rainSoon, settings: settings);

    test('offline wins over everything', () {
      expect(d(status(), connected: false), PlantState.offline);
      expect(d(null), PlantState.offline);
    });
    test('watering while the pump runs', () {
      expect(d(status(pump: true, moisture: 10)), PlantState.watering);
    });
    test('healthy when moist', () => expect(d(status()), PlantState.healthy));
    test('thirsty when dry', () => expect(d(status(moisture: 20)), PlantState.thirsty));
    test('waiting for rain when dry and rain is coming', () {
      expect(d(status(moisture: 20), rainSoon: true), PlantState.waitingForRain);
    });
    test('tank empty when dry and tank is empty', () {
      expect(d(status(moisture: 20, tank: 3)), PlantState.tankEmpty);
    });
    test('an invalid tank sensor does not read as an empty tank', () {
      expect(d(status(moisture: 20, tank: 0, distance: -1)), PlantState.thirsty);
    });
  });

  group('checkPumpStart safety', () {
    PumpDecision check(
      SensorStatus? s, {
      bool connected = true,
      HourlyPoint? rainOutlook,
      DateTime? lastStop,
    }) =>
        checkPumpStart(
          status: s,
          connected: connected,
          rainOutlook: rainOutlook,
          settings: settings,
          lastStopAt: lastStop,
          now: now,
        );

    test('allows a normal start with no warnings', () {
      final r = check(status(moisture: 20));
      expect(r.allowed, isTrue);
      expect(r.warnings, isEmpty);
    });
    test('blocks when offline or unknown', () {
      expect(check(status(), connected: false).allowed, isFalse);
      expect(check(null).allowed, isFalse);
    });
    test('blocks when the pump is already running', () {
      expect(check(status(pump: true)).allowed, isFalse);
    });
    test('blocks on an empty tank (dry-run protection)', () {
      final r = check(status(tank: 5));
      expect(r.allowed, isFalse);
      expect(r.blockReason, contains('tank'));
    });
    test('enforces the cooldown', () {
      final r = check(status(), lastStop: now.subtract(const Duration(seconds: 30)));
      expect(r.allowed, isFalse);
      expect(check(status(), lastStop: now.subtract(const Duration(minutes: 5))).allowed, isTrue);
    });
    test('warns (but allows) with unknown tank, wet soil or rain', () {
      final r = check(
        status(distance: -1, moisture: 90),
        rainOutlook: HourlyPoint(now, 80, 1, 20),
      );
      expect(r.allowed, isTrue);
      expect(r.warnings.length, 3);
    });
  });

  test('formatting helpers', () {
    expect(fmtDuration(const Duration(seconds: 45)), '45s');
    expect(fmtDuration(const Duration(seconds: 125)), '2m 5s');
    expect(ago(now.subtract(const Duration(minutes: 7)), now), '7m ago');
    expect(ago(now.subtract(const Duration(seconds: 5)), now), 'just now');
  });

  test('settings round-trip and clamp', () {
    const s = AppSettings(host: '10.0.0.5', dryThreshold: 40, lat: 1.5, lon: 2.5, placeName: 'X');
    final back = AppSettings.fromMap(s.toMap());
    expect(back.host, '10.0.0.5');
    expect(back.dryThreshold, 40);
    expect(back.hasLocation, isTrue);
    expect(AppSettings.fromMap({'maxPumpSeconds': 99999}).maxPumpSeconds, 600);
    expect(AppSettings.fromMap({'host': '  '}).host, '192.168.4.1');
  });
}
