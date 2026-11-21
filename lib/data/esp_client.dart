import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models.dart';

class EspException implements Exception {
  final String message;
  const EspException(this.message);
  @override
  String toString() => message;
}

/// Talks to the ESP32: GET /status, /pump/on, /pump/off, /pump/auto.
class EspClient {
  EspClient({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;
  static const timeout = Duration(seconds: 4);

  static String normalizeHost(String raw) {
    var h = raw.trim();
    h = h.replaceFirst(RegExp(r'^https?://'), '');
    while (h.endsWith('/')) {
      h = h.substring(0, h.length - 1);
    }
    return h;
  }

  Uri _uri(String host, String path) => Uri.parse('http://${normalizeHost(host)}$path');

  Future<http.Response> _get(String host, String path) async {
    try {
      return await _http.get(_uri(host, path)).timeout(timeout);
    } on TimeoutException {
      throw const EspException('ESP32 did not answer (timeout).');
    } on FormatException {
      throw const EspException('Invalid ESP32 address.');
    } catch (e) {
      throw EspException('Cannot reach ESP32: ${e.toString().split('\n').first}');
    }
  }

  Future<SensorStatus> fetchStatus(String host) async {
    final r = await _get(host, '/status');
    if (r.statusCode != 200) {
      throw EspException('ESP32 returned HTTP ${r.statusCode}.');
    }
    try {
      final j = jsonDecode(r.body);
      if (j is! Map) throw const FormatException('not an object');
      return SensorStatus.fromJson(j.cast<String, dynamic>());
    } on FormatException catch (e) {
      throw EspException('Unexpected /status response: ${e.message}');
    }
  }

  Future<void> sendPump(String host, PumpCommand cmd) async {
    final r = await _get(host, cmd.path);
    if (r.statusCode != 200) {
      throw EspException('Pump command failed (HTTP ${r.statusCode}).');
    }
  }

  void close() => _http.close();
}
