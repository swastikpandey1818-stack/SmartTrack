import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_track/data/esp_client.dart';
import 'package:smart_track/domain/models.dart';

void main() {
  test('normalizeHost strips scheme and trailing slash', () {
    expect(EspClient.normalizeHost(' http://192.168.4.1/ '), '192.168.4.1');
    expect(EspClient.normalizeHost('esp32.local'), 'esp32.local');
  });

  test('fetchStatus calls /status and parses JSON', () async {
    late Uri called;
    final client = EspClient(
      client: MockClient((req) async {
        called = req.url;
        return http.Response(
          '{"moisture":42,"tank":77,"distance":6.5,"pump":true,"manual":true,"wifi":true,"ip":"192.168.4.1"}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final s = await client.fetchStatus('192.168.4.1');
    expect(called.toString(), 'http://192.168.4.1/status');
    expect(s.moisture, 42);
    expect(s.mode, PumpMode.manualOn);
  });

  test('pump commands hit the right endpoints', () async {
    final paths = <String>[];
    final client = EspClient(client: MockClient((req) async {
      paths.add(req.url.path);
      return http.Response('ok', 200);
    }));
    for (final c in PumpCommand.values) {
      await client.sendPump('192.168.4.1', c);
    }
    expect(paths, ['/pump/on', '/pump/off', '/pump/auto']);
  });

  test('HTTP errors, bad JSON and network failures become EspException', () async {
    final bad = EspClient(client: MockClient((_) async => http.Response('nope', 500)));
    expect(bad.fetchStatus('h'), throwsA(isA<EspException>()));
    expect(bad.sendPump('h', PumpCommand.on), throwsA(isA<EspException>()));

    final garbage = EspClient(client: MockClient((_) async => http.Response('<html>', 200)));
    expect(garbage.fetchStatus('h'), throwsA(isA<EspException>()));

    final down = EspClient(client: MockClient((_) async => throw http.ClientException('unreachable')));
    expect(down.fetchStatus('h'), throwsA(isA<EspException>()));
  });
}
