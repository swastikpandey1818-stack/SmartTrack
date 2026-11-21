import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import '../domain/settings.dart';

/// Settings and the offline cache (last device status + last weather).
class SettingsStore {
  static const _kSettings = 'settings_v1';
  static const _kStatus = 'cache_status';
  static const _kStatusAt = 'cache_status_at';
  static const _kWeather = 'cache_weather';
  static const _kWeatherAt = 'cache_weather_at';

  Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  Future<AppSettings> loadSettings() async {
    final p = await _p;
    final raw = p.getString(_kSettings);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromMap((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings s) async {
    final p = await _p;
    await p.setString(_kSettings, jsonEncode(s.toMap()));
  }

  Future<void> saveStatus(SensorStatus s, DateTime at) async {
    final p = await _p;
    await p.setString(_kStatus, jsonEncode(s.toJson()));
    await p.setInt(_kStatusAt, at.millisecondsSinceEpoch);
  }

  Future<(SensorStatus, DateTime)?> loadStatus() async {
    final p = await _p;
    final raw = p.getString(_kStatus);
    final at = p.getInt(_kStatusAt);
    if (raw == null || at == null) return null;
    try {
      return (
        SensorStatus.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>()),
        DateTime.fromMillisecondsSinceEpoch(at)
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveWeatherRaw(String raw, DateTime at) async {
    final p = await _p;
    await p.setString(_kWeather, raw);
    await p.setInt(_kWeatherAt, at.millisecondsSinceEpoch);
  }

  Future<WeatherData?> loadWeather() async {
    final p = await _p;
    final at = p.getInt(_kWeatherAt);
    if (at == null) return null;
    return WeatherData.tryDecode(
        p.getString(_kWeather), DateTime.fromMillisecondsSinceEpoch(at));
  }

  Future<void> clearCache() async {
    final p = await _p;
    for (final k in [_kStatus, _kStatusAt, _kWeather, _kWeatherAt]) {
      await p.remove(k);
    }
  }
}
