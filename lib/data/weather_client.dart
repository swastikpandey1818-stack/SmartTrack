import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class GeoPlace {
  final String name;
  final String region;
  final double lat;
  final double lon;
  const GeoPlace(this.name, this.region, this.lat, this.lon);
  String get label => region.isEmpty ? name : '$name, $region';
}

class WeatherFetch {
  final String raw;
  final Map<String, dynamic> json;
  const WeatherFetch(this.raw, this.json);
}

/// Open-Meteo forecast + geocoding (no API key required).
class WeatherClient {
  WeatherClient({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  Future<WeatherFetch> fetch(double lat, double lon) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toStringAsFixed(4),
      'longitude': lon.toStringAsFixed(4),
      'current': 'temperature_2m,weather_code,precipitation',
      'hourly': 'temperature_2m,precipitation_probability,precipitation',
      'daily':
          'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
      'forecast_days': '5',
      'timezone': 'auto',
    });
    final r = await _http.get(uri).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) {
      throw Exception('Open-Meteo HTTP ${r.statusCode}');
    }
    return WeatherFetch(r.body, (jsonDecode(r.body) as Map).cast<String, dynamic>());
  }

  Future<List<GeoPlace>> searchPlaces(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': q,
      'count': '6',
      'language': 'en',
      'format': 'json',
    });
    final r = await _http.get(uri).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw Exception('Geocoding HTTP ${r.statusCode}');
    final j = (jsonDecode(r.body) as Map).cast<String, dynamic>();
    final list = (j['results'] as List?) ?? const [];
    return [
      for (final e in list.whereType<Map>())
        GeoPlace(
          '${e['name']}',
          [e['admin1'], e['country']].where((x) => x != null).join(', '),
          (e['latitude'] as num).toDouble(),
          (e['longitude'] as num).toDouble(),
        ),
    ];
  }
}
