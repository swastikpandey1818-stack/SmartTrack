import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/app_database.dart';
import '../data/esp_client.dart';
import '../data/settings_store.dart';
import '../data/weather_client.dart';
import '../domain/models.dart';
import '../domain/plant_logic.dart';
import '../domain/settings.dart';
import '../services/notification_service.dart';

class PumpResult {
  final bool ok;
  final String message;
  const PumpResult(this.ok, this.message);
}

/// Single source of truth for the UI: polling, caching, alerts and pump control.
class AppController extends ChangeNotifier with WidgetsBindingObserver {
  AppController({
    EspClient? esp,
    WeatherClient? weatherClient,
    AppDatabase? db,
    SettingsStore? store,
    Notifier? notifier,
  })  : _esp = esp ?? EspClient(),
        _weatherClient = weatherClient ?? WeatherClient(),
        db = db ?? AppDatabase(),
        _store = store ?? SettingsStore(),
        _notifier = notifier ?? NotificationService();

  final EspClient _esp;
  final WeatherClient _weatherClient;
  final AppDatabase db;
  final SettingsStore _store;
  final Notifier _notifier;

  AppSettings settings = const AppSettings();
  SensorStatus? status;
  DateTime? lastSeen;
  bool connected = false;
  bool statusFromCache = false;
  String? lastError;
  int _failures = 0;

  WeatherData? weather;
  bool weatherStale = false;
  bool weatherLoading = false;
  String? weatherError;

  PlantState plantState = PlantState.offline;
  bool pumpBusy = false;
  List<EventRecord> alerts = [];
  List<EventRecord> history = [];
  bool ready = false;

  Timer? _pollTimer;
  Timer? _weatherTimer;
  Timer? _runTimer;
  bool _polling = false;
  DateTime? _pumpSince;
  DateTime? _lastStopAt;
  DateTime? _lastReadingAt;
  bool _lastReadingPump = false;
  bool _safetyStopping = false;
  final Map<String, bool> _conditionActive = {};
  final Map<String, DateTime> _conditionFiredAt = {};
  int _notifId = 100;

  // ---------------------------------------------------------------- lifecycle

  Future<void> init() async {
    settings = await _store.loadSettings();
    final cached = await _store.loadStatus();
    if (cached != null) {
      status = cached.$1;
      lastSeen = cached.$2;
      statusFromCache = true;
    }
    weather = await _store.loadWeather();
    weatherStale = weather != null;
    await _notifier.init();
    try {
      await db.prune();
      alerts = await db.activeAlerts();
      history = await db.history();
    } catch (e) {
      debugPrint('DB init failed: $e');
    }
    _recompute();
    ready = true;
    WidgetsBinding.instance.addObserver(this);
    notifyListeners();
    _startTimers();
    unawaited(refreshStatus());
    unawaited(refreshWeather());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _weatherTimer?.cancel();
    _runTimer?.cancel();
    _esp.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
      _weatherTimer?.cancel();
      final s = status;
      if (settings.stopOnBackground && connected && s != null && s.pump && s.manual) {
        unawaited(_failSafeStop('App was sent to the background'));
      }
    } else if (state == AppLifecycleState.resumed) {
      _startTimers();
      unawaited(refreshStatus());
      if (weatherStale || weather == null) unawaited(refreshWeather());
    }
  }

  void _startTimers() {
    _pollTimer?.cancel();
    _weatherTimer?.cancel();
    _pollTimer = Timer.periodic(
        Duration(seconds: settings.pollSeconds), (_) => refreshStatus());
    _weatherTimer =
        Timer.periodic(const Duration(minutes: 20), (_) => refreshWeather());
  }

  // ---------------------------------------------------------------- settings

  Future<void> updateSettings(AppSettings s, {bool refreshWeatherNow = false}) async {
    final hostChanged = s.host != settings.host;
    final pollChanged = s.pollSeconds != settings.pollSeconds;
    settings = s;
    await _store.saveSettings(s);
    _recompute();
    notifyListeners();
    if (pollChanged) _startTimers();
    if (hostChanged) unawaited(refreshStatus());
    if (refreshWeatherNow) unawaited(refreshWeather());
  }

  Future<String> testConnection(String host) async {
    try {
      final s = await _esp.fetchStatus(host);
      return 'Connected. Moisture ${s.moisture}%, '
          '${s.tankSensorValid ? 'tank ${s.tank}%' : 'tank sensor: no reading'}.';
    } catch (e) {
      return e.toString();
    }
  }

  Future<List<GeoPlace>> searchPlaces(String q) => _weatherClient.searchPlaces(q);

  // ----------------------------------------------------------------- polling

  Future<void> refreshStatus() async {
    if (_polling) return;
    _polling = true;
    try {
      final s = await _esp.fetchStatus(settings.host);
      await _onStatus(s);
    } catch (e) {
      await _onFailure(e);
    } finally {
      _polling = false;
      notifyListeners();
    }
  }

  Future<void> _onStatus(SensorStatus s) async {
    final now = DateTime.now();
    final prev = connected ? status : null;
    final wasDown = _failures >= 3;
    status = s;
    lastSeen = now;
    statusFromCache = false;
    connected = true;
    lastError = null;
    _failures = 0;
    unawaited(_store.saveStatus(s, now));

    if (wasDown) {
      _conditionActive['offline'] = false;
      await _log('system', 'system', 'Connection restored', 'ESP32 is back online.',
          severity: 0);
    }
    await _recordReading(now, s);
    await _trackPump(prev, s, now);
    _recompute();
    await _evaluateAlerts(s);
  }

  Future<void> _onFailure(Object e) async {
    _failures++;
    lastError = e.toString();
    if (_failures >= 3) {
      connected = false;
      _recompute();
      await _condition(
        'offline',
        true,
        type: 'offline',
        title: 'Connection lost',
        body: 'Smart Track cannot reach the ESP32 at ${settings.host}.',
        severity: 2,
        cooldown: const Duration(hours: 2),
        enabled: settings.notifyOffline,
        urgent: true,
      );
    }
  }

  Future<void> _recordReading(DateTime now, SensorStatus s) async {
    final due = _lastReadingAt == null ||
        now.difference(_lastReadingAt!).inSeconds >= 30 ||
        _lastReadingPump != s.pump;
    if (!due) return;
    _lastReadingAt = now;
    _lastReadingPump = s.pump;
    try {
      await db.insertReading(now, s);
    } catch (e) {
      debugPrint('insertReading failed: $e');
    }
  }

  Future<void> _trackPump(SensorStatus? prev, SensorStatus s, DateTime now) async {
    if (prev != null && !prev.pump && s.pump) {
      _pumpSince = now;
      await _log('pump', 'pump', 'Pump started', s.manual ? 'Manual' : 'Automatic',
          severity: 0);
    }
    if (s.pump && _pumpSince == null) _pumpSince = now;
    if (prev != null && prev.pump && !s.pump) {
      final ran = _pumpSince == null ? null : now.difference(_pumpSince!);
      _pumpSince = null;
      _lastStopAt = now;
      _runTimer?.cancel();
      final detail = ran == null ? 'Pump stopped.' : 'Pump ran for ${fmtDuration(ran)}.';
      await _log('alert', 'watering', 'Watering complete', detail,
          severity: 0, notify: settings.notifyWatering);
    }
    if (!s.pump) _pumpSince = null;
    if (s.pump &&
        _pumpSince != null &&
        now.difference(_pumpSince!).inSeconds > settings.maxPumpSeconds) {
      unawaited(_safetyStop());
    }
  }

  // --------------------------------------------------------------- alerts

  HourlyPoint? get rainOutlook => weather?.rainOutlook(DateTime.now(),
      settings.rainLookaheadHours, settings.rainProbThreshold.toDouble());

  bool get rainSoon => rainOutlook != null;

  void _recompute() {
    plantState = derivePlantState(
      status: status,
      connected: connected,
      rainSoon: rainSoon,
      settings: settings,
    );
  }

  Future<void> _evaluateAlerts(SensorStatus s) async {
    final tankLow = s.tankSensorValid && s.tank <= settings.tankLowPercent;
    final tankRecovered = !s.tankSensorValid || s.tank > settings.tankLowPercent + 10;
    await _condition(
      'tank',
      tankLow ? true : (tankRecovered ? false : (_conditionActive['tank'] ?? false)),
      type: 'tank',
      title: 'Water Tank Low (${s.tank}%)',
      body: s.tank <= settings.tankEmptyPercent
          ? 'Tank is almost empty. Pump is blocked until it is refilled.'
          : 'Refill the tank soon.',
      severity: s.tank <= settings.tankEmptyPercent ? 2 : 1,
      cooldown: const Duration(hours: 3),
      enabled: settings.notifyTank,
    );

    final thirsty = s.moisture < settings.dryThreshold && !s.pump && !rainSoon;
    await _condition(
      'thirsty',
      thirsty,
      type: 'thirsty',
      title: 'Plant is thirsty',
      body: 'Soil moisture is ${s.moisture}% (limit ${settings.dryThreshold}%).',
      severity: 1,
      cooldown: const Duration(hours: 3),
      enabled: settings.notifyThirsty,
    );
  }

  Future<void> _evaluateRainAlert() async {
    final r = rainOutlook;
    final hours = r == null ? 0 : r.time.difference(DateTime.now()).inMinutes / 60.0;
    await _condition(
      'rain',
      r != null,
      type: 'rain',
      title: hours <= 0.5
          ? 'Rain expected now'
          : 'Rain expected in ${hours.ceil()} hour${hours.ceil() == 1 ? '' : 's'}',
      body: 'Automatic watering decisions will account for the forecast.',
      severity: 0,
      cooldown: const Duration(hours: 4),
      enabled: settings.notifyRain,
    );
  }

  /// Fires once when a condition becomes active, and again only after [cooldown].
  Future<void> _condition(
    String key,
    bool active, {
    required String type,
    required String title,
    required String body,
    required int severity,
    required Duration cooldown,
    required bool enabled,
    bool urgent = false,
  }) async {
    final was = _conditionActive[key] ?? false;
    _conditionActive[key] = active;
    if (!active) return;
    final last = _conditionFiredAt[key];
    final now = DateTime.now();
    if (was && last != null && now.difference(last) < cooldown) return;
    _conditionFiredAt[key] = now;
    await _log('alert', type, title, body,
        severity: severity, notify: enabled, urgent: urgent);
  }

  Future<void> _log(
    String kind,
    String type,
    String title,
    String detail, {
    required int severity,
    bool notify = false,
    bool urgent = false,
  }) async {
    final now = DateTime.now();
    try {
      final id = await db.insertEvent(
          time: now,
          kind: kind,
          type: type,
          title: title,
          detail: detail,
          severity: severity);
      final e = EventRecord(
          id: id,
          time: now,
          kind: kind,
          type: type,
          title: title,
          detail: detail,
          severity: severity);
      history = [e, ...history].take(300).toList();
      if (kind == 'alert') alerts = [e, ...alerts];
    } catch (err) {
      debugPrint('log failed: $err');
    }
    if (notify) {
      await _notifier.show(_notifId++, title, detail, urgent: urgent || severity >= 2);
    }
    notifyListeners();
  }

  Future<void> clearAlerts() async {
    await db.dismissAlerts();
    alerts = [];
    notifyListeners();
  }

  Future<List<Reading>> loadReadings(Duration range) =>
      db.readingsSince(DateTime.now().subtract(range));

  Future<void> clearData() async {
    await db.clearAll();
    await _store.clearCache();
    alerts = [];
    history = [];
    notifyListeners();
  }

  // --------------------------------------------------------------- weather

  Future<void> refreshWeather() async {
    if (!settings.hasLocation || weatherLoading) return;
    weatherLoading = true;
    notifyListeners();
    try {
      final f = await _weatherClient.fetch(settings.lat!, settings.lon!);
      final now = DateTime.now();
      weather = WeatherData.fromApi(f.json, now);
      weatherStale = false;
      weatherError = null;
      await _store.saveWeatherRaw(f.raw, now);
      _recompute();
      await _evaluateRainAlert();
    } catch (e) {
      weatherStale = true;
      weatherError = 'Weather offline. Showing the last saved forecast.';
    } finally {
      weatherLoading = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------ pump control

  PumpDecision evaluatePumpOn([DateTime? now]) => checkPumpStart(
        status: status,
        connected: connected,
        rainOutlook: rainOutlook,
        settings: settings,
        lastStopAt: _lastStopAt,
        now: now ?? DateTime.now(),
      );

  Duration? get pumpRunning =>
      _pumpSince == null ? null : DateTime.now().difference(_pumpSince!);

  /// Sends a pump command. Starting the pump re-checks all safety rules here
  /// so the rules hold even if the UI is bypassed.
  Future<PumpResult> sendPump(PumpCommand cmd) async {
    if (pumpBusy) return const PumpResult(false, 'Another command is in progress.');
    if (cmd == PumpCommand.on) {
      final d = evaluatePumpOn();
      if (!d.allowed) return PumpResult(false, d.blockReason ?? 'Blocked for safety.');
    }
    pumpBusy = true;
    notifyListeners();
    try {
      await _esp.sendPump(settings.host, cmd);
      await _log('pump', 'pump', cmd.label, 'Sent from the app.', severity: 0);
      if (cmd == PumpCommand.on) {
        _pumpSince = DateTime.now();
        _runTimer?.cancel();
        _runTimer = Timer(Duration(seconds: settings.maxPumpSeconds), _safetyStop);
      } else {
        _runTimer?.cancel();
        if (cmd == PumpCommand.off) _lastStopAt = DateTime.now();
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
      _polling = false;
      await refreshStatus();
      final s = status;
      if (s != null) {
        if (cmd == PumpCommand.on && !s.pump) {
          return const PumpResult(false,
              'Command was sent but the ESP32 does not report the pump running.');
        }
        if (cmd == PumpCommand.off && s.pump) {
          return const PumpResult(
              false, 'Stop was sent but the pump still reports running. Retrying is advised.');
        }
        if (cmd == PumpCommand.auto && s.manual) {
          return const PumpResult(
              false, 'Auto was sent but the ESP32 still reports manual mode.');
        }
      }
      return PumpResult(true, switch (cmd) {
        PumpCommand.on => 'Watering started. Auto-stop in ${settings.maxPumpSeconds}s.',
        PumpCommand.off => 'Pump stopped.',
        PumpCommand.auto => 'Back to automatic mode.',
      });
    } catch (e) {
      return PumpResult(false, e.toString());
    } finally {
      pumpBusy = false;
      notifyListeners();
    }
  }

  Future<void> _safetyStop() async {
    if (_safetyStopping) return;
    _safetyStopping = true;
    try {
      await _esp.sendPump(settings.host, PumpCommand.off);
      _lastStopAt = DateTime.now();
      await _log('alert', 'safety', 'Safety stop',
          'Pump exceeded the ${settings.maxPumpSeconds}s limit and was switched off.',
          severity: 1, notify: true);
    } catch (e) {
      await _log('alert', 'safety', 'Safety stop failed',
          'Could not switch the pump off: $e', severity: 2, notify: true, urgent: true);
    } finally {
      _safetyStopping = false;
      _polling = false;
      await refreshStatus();
    }
  }

  Future<void> _failSafeStop(String reason) async {
    try {
      await _esp.sendPump(settings.host, PumpCommand.off);
      _runTimer?.cancel();
      _lastStopAt = DateTime.now();
      await _log('pump', 'safety', 'Pump stopped', '$reason. Manual watering was switched off.',
          severity: 0);
    } catch (_) {}
  }
}
