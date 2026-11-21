import 'package:flutter_test/flutter_test.dart';
import 'package:smart_track/domain/models.dart';

void main() {
  group('SensorStatus', () {
    test('parses the real ESP32 /status payload', () {
      final s = SensorStatus.fromJson({
        'moisture': 100,
        'tank': 0,
        'distance': -1.00,
        'pump': false,
        'manual': false,
        'wifi': true,
        'ip': '192.168.4.1',
      });
      expect(s.moisture, 100);
      expect(s.tank, 0);
      expect(s.tankSensorValid, isFalse, reason: 'distance -1 means no echo');
      expect(s.mode, PumpMode.auto);
      expect(s.ip, '192.168.4.1');
    });

    test('derives pump mode', () {
      SensorStatus mk(bool pump, bool manual) => SensorStatus(
          moisture: 50, tank: 50, distance: 10, pump: pump, manual: manual, wifi: true, ip: '');
      expect(mk(true, true).mode, PumpMode.manualOn);
      expect(mk(false, true).mode, PumpMode.manualOff);
      expect(mk(true, false).mode, PumpMode.auto);
    });

    test('is tolerant of numeric types and clamps percentages', () {
      final s = SensorStatus.fromJson({
        'moisture': 140.4,
        'tank': -5,
        'distance': 12,
        'pump': 1,
        'manual': 'true',
      });
      expect(s.moisture, 100);
      expect(s.tank, 0);
      expect(s.pump, isTrue);
      expect(s.manual, isTrue);
      expect(s.tankSensorValid, isTrue);
    });

    test('rejects payloads without moisture', () {
      expect(() => SensorStatus.fromJson({'tank': 1}), throwsFormatException);
    });
  });

  group('WeatherData', () {
    final json = {
      'utc_offset_seconds': 19800, // +05:30
      'current': {'temperature_2m': 24.2, 'weather_code': 61, 'precipitation': 0.0},
      'hourly': {
        'time': ['2026-11-21T14:00', '2026-11-21T15:00', '2026-11-21T16:00'],
        'precipitation_probability': [10, 30, 85],
        'precipitation': [0.0, 0.0, 1.2],
        'temperature_2m': [24.0, 23.0, 22.0],
      },
      'daily': {
        'time': ['2026-11-21', '2026-11-22'],
        'weather_code': [61, 3],
        'temperature_2m_max': [26.0, 27.0],
        'temperature_2m_min': [18.0, 19.0],
        'precipitation_probability_max': [85, 20],
      },
    };

    test('parses current, hourly (with timezone) and daily data', () {
      final w = WeatherData.fromApi(json, DateTime(2026, 11, 21));
      expect(w.temp, 24.2);
      expect(w.hourly.length, 3);
      expect(w.daily.length, 2);
      // 14:00 at +05:30 is 08:30 UTC
      expect(w.hourly.first.time, DateTime.utc(2026, 11, 21, 8, 30));
      expect(weatherLabel(w.code), 'Light rain');
    });

    test('finds rain inside the look-ahead window only', () {
      final w = WeatherData.fromApi(json, DateTime(2026, 11, 21));
      final now = DateTime.utc(2026, 11, 21, 8, 40); // 14:10 local
      expect(w.rainOutlook(now, 2, 60), isNotNull); // 16:00 local = +1h50
      expect(w.rainOutlook(now, 1, 60), isNull);
      expect(w.rainOutlook(now, 2, 95), isNotNull, reason: '1.2mm counts as rain');
    });

    test('rain right now counts as an outlook', () {
      final wet = WeatherData.fromApi({
        ...json,
        'current': {'temperature_2m': 20.0, 'weather_code': 63, 'precipitation': 1.0},
      }, DateTime.now());
      expect(wet.rainOutlook(DateTime.utc(2030), 1, 90), isNotNull);
    });

    test('tryDecode returns null for garbage', () {
      expect(WeatherData.tryDecode('not json', DateTime.now()), isNull);
      expect(WeatherData.tryDecode(null, DateTime.now()), isNull);
    });
  });
}
