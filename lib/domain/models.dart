import 'dart:convert';

enum PumpCommand { on, off, auto }

extension PumpCommandX on PumpCommand {
  String get path => switch (this) {
        PumpCommand.on => '/pump/on',
        PumpCommand.off => '/pump/off',
        PumpCommand.auto => '/pump/auto',
      };
  String get label => switch (this) {
        PumpCommand.on => 'Pump ON (manual)',
        PumpCommand.off => 'Pump OFF (manual)',
        PumpCommand.auto => 'Automatic mode',
      };
}

enum PumpMode { auto, manualOn, manualOff }

/// Snapshot returned by the ESP32 `/status` endpoint.
class SensorStatus {
  final int moisture; // 0..100 (% wet)
  final int tank; // 0..100 (% full)
  final double distance; // ultrasonic cm, negative = no valid echo
  final bool pump;
  final bool manual;
  final bool wifi;
  final String ip;

  const SensorStatus({
    required this.moisture,
    required this.tank,
    required this.distance,
    required this.pump,
    required this.manual,
    required this.wifi,
    required this.ip,
  });

  /// The firmware reports distance -1 when the ultrasonic sensor got no echo.
  /// In that case the tank percentage is meaningless.
  bool get tankSensorValid => distance >= 0;

  PumpMode get mode =>
      !manual ? PumpMode.auto : (pump ? PumpMode.manualOn : PumpMode.manualOff);

  factory SensorStatus.fromJson(Map<String, dynamic> j) {
    int toInt(dynamic v, int d) {
      if (v is num) return v.round();
      return int.tryParse('$v') ?? d;
    }

    double toDouble(dynamic v, double d) {
      if (v is num) return v.toDouble();
      return double.tryParse('$v') ?? d;
    }

    bool toBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      return '$v'.toLowerCase() == 'true';
    }

    if (!j.containsKey('moisture')) {
      throw const FormatException('Missing "moisture" in /status response');
    }
    return SensorStatus(
      moisture: toInt(j['moisture'], 0).clamp(0, 100),
      tank: toInt(j['tank'], 0).clamp(0, 100),
      distance: toDouble(j['distance'], -1),
      pump: toBool(j['pump']),
      manual: toBool(j['manual']),
      wifi: j.containsKey('wifi') ? toBool(j['wifi']) : true,
      ip: '${j['ip'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() => {
        'moisture': moisture,
        'tank': tank,
        'distance': distance,
        'pump': pump,
        'manual': manual,
        'wifi': wifi,
        'ip': ip,
      };
}

class HourlyPoint {
  final DateTime time; // UTC instant
  final double precipProb; // %
  final double precip; // mm
  final double temp;
  const HourlyPoint(this.time, this.precipProb, this.precip, this.temp);
}

class DailyPoint {
  final DateTime date;
  final int code;
  final double tMax;
  final double tMin;
  final double precipProbMax;
  const DailyPoint(this.date, this.code, this.tMax, this.tMin, this.precipProbMax);
}

class WeatherData {
  final double temp;
  final int code;
  final double precipNow;
  final List<HourlyPoint> hourly;
  final List<DailyPoint> daily;
  final DateTime fetchedAt;

  const WeatherData({
    required this.temp,
    required this.code,
    required this.precipNow,
    required this.hourly,
    required this.daily,
    required this.fetchedAt,
  });

  /// Parses the Open-Meteo `/v1/forecast` response (timezone=auto).
  factory WeatherData.fromApi(Map<String, dynamic> j, DateTime fetchedAt) {
    final offset = (j['utc_offset_seconds'] as num?)?.toInt() ?? 0;
    DateTime instant(String s) =>
        DateTime.parse('${s}Z').subtract(Duration(seconds: offset));

    final cur = (j['current'] as Map?)?.cast<String, dynamic>() ?? {};
    final h = (j['hourly'] as Map?)?.cast<String, dynamic>() ?? {};
    final d = (j['daily'] as Map?)?.cast<String, dynamic>() ?? {};

    double num0(List? l, int i) =>
        (l != null && i < l.length && l[i] is num) ? (l[i] as num).toDouble() : 0;

    final times = (h['time'] as List?) ?? const [];
    final hourly = <HourlyPoint>[
      for (var i = 0; i < times.length; i++)
        HourlyPoint(
          instant('${times[i]}'),
          num0(h['precipitation_probability'] as List?, i),
          num0(h['precipitation'] as List?, i),
          num0(h['temperature_2m'] as List?, i),
        ),
    ];

    final days = (d['time'] as List?) ?? const [];
    final daily = <DailyPoint>[
      for (var i = 0; i < days.length; i++)
        DailyPoint(
          DateTime.parse('${days[i]}'),
          num0(d['weather_code'] as List?, i).round(),
          num0(d['temperature_2m_max'] as List?, i),
          num0(d['temperature_2m_min'] as List?, i),
          num0(d['precipitation_probability_max'] as List?, i),
        ),
    ];

    return WeatherData(
      temp: (cur['temperature_2m'] as num?)?.toDouble() ?? 0,
      code: (cur['weather_code'] as num?)?.toInt() ?? 0,
      precipNow: (cur['precipitation'] as num?)?.toDouble() ?? 0,
      hourly: hourly,
      daily: daily,
      fetchedAt: fetchedAt,
    );
  }

  /// First upcoming hour (within [hours]) where rain is likely, or null.
  HourlyPoint? rainOutlook(DateTime now, int hours, double probThreshold) {
    if (precipNow >= 0.2) {
      return HourlyPoint(now, 100, precipNow, temp);
    }
    final from = now.subtract(const Duration(minutes: 59));
    final to = now.add(Duration(hours: hours));
    for (final p in hourly) {
      if (p.time.isAfter(from) &&
          !p.time.isAfter(to) &&
          (p.precipProb >= probThreshold || p.precip >= 0.5)) {
        return p;
      }
    }
    return null;
  }

  static WeatherData? tryDecode(String? raw, DateTime fetchedAt) {
    if (raw == null) return null;
    try {
      return WeatherData.fromApi(
          (jsonDecode(raw) as Map).cast<String, dynamic>(), fetchedAt);
    } catch (_) {
      return null;
    }
  }
}

String weatherLabel(int code) {
  if (code == 0) return 'Clear sky';
  if (code <= 2) return 'Partly cloudy';
  if (code == 3) return 'Overcast';
  if (code == 45 || code == 48) return 'Fog';
  if (code >= 51 && code <= 57) return 'Drizzle';
  if (code == 61 || code == 80) return 'Light rain';
  if (code == 63 || code == 81) return 'Rain';
  if (code == 65 || code == 82) return 'Heavy rain';
  if (code == 66 || code == 67) return 'Freezing rain';
  if (code >= 71 && code <= 77) return 'Snow';
  if (code == 85 || code == 86) return 'Snow showers';
  if (code >= 95) return 'Thunderstorm';
  return 'Mixed';
}

bool isRainyCode(int code) =>
    (code >= 51 && code <= 67) || (code >= 80 && code <= 82) || code >= 95;

class Reading {
  final DateTime time;
  final int moisture;
  final int tank;
  final bool pump;
  const Reading(this.time, this.moisture, this.tank, this.pump);
}

class EventRecord {
  final int id;
  final DateTime time;
  final String kind; // alert | pump | system
  final String type; // tank, rain, thirsty, offline, watering, pump, safety, system
  final String title;
  final String detail;
  final int severity; // 0 info, 1 warning, 2 critical
  const EventRecord({
    required this.id,
    required this.time,
    required this.kind,
    required this.type,
    required this.title,
    required this.detail,
    required this.severity,
  });
}
