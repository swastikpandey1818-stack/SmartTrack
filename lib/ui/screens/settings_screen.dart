import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../core/theme.dart';
import '../../data/esp_client.dart';
import '../../data/weather_client.dart';
import '../../domain/settings.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _host = TextEditingController();
  final _place = TextEditingController();
  bool _hostInit = false;
  String? _testResult;
  bool _testing = false;
  List<GeoPlace> _results = [];
  bool _searching = false;
  String? _searchError;

  @override
  void dispose() {
    _host.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _saveHost(AppController c) async {
    final h = EspClient.normalizeHost(_host.text);
    if (h.isEmpty) return;
    _host.text = h;
    await c.updateSettings(c.settings.copyWith(host: h));
    if (mounted) showSnack(context, 'ESP32 address saved.');
  }

  Future<void> _test(AppController c) async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final r = await c.testConnection(_host.text);
    if (mounted) {
      setState(() {
        _testing = false;
        _testResult = r;
      });
    }
  }

  Future<void> _search(AppController c) async {
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final r = await c.searchPlaces(_place.text);
      if (mounted) setState(() => _results = r);
      if (r.isEmpty && mounted) setState(() => _searchError = 'No places found.');
    } catch (_) {
      if (mounted) setState(() => _searchError = 'Search needs internet. Connect to mobile data or home Wi-Fi.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ControllerScope.of(context);
    final s = c.settings;
    if (!_hostInit) {
      _host.text = s.host;
      _hostInit = true;
    }
    Future<void> set(AppSettings n, {bool weather = false}) =>
        c.updateSettings(n, refreshWeatherNow: weather);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          const Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SectionTitle('ESP32 connection'),
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: _host,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                    labelText: 'ESP32 address', hintText: '192.168.4.1', prefixIcon: Icon(Icons.memory_rounded)),
                onSubmitted: (_) => _saveHost(c),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _testing ? null : () => _test(c),
                    child: _testing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Test'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _saveHost(c),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.emerald, foregroundColor: Colors.black),
                    child: const Text('Save'),
                  ),
                ),
              ]),
              if (_testResult != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_testResult!, style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
                ),
              const SizedBox(height: 8),
              const Text(
                'Tip: the ESP32 hotspot has no internet. If your phone keeps jumping back to mobile data, choose "stay connected" when Android asks, or turn off the phone\'s smart/auto network switching.',
                style: TextStyle(color: AppColors.textDim, fontSize: 11.5, height: 1.3),
              ),
              _Slider(
                label: 'Refresh every',
                value: s.pollSeconds.toDouble(),
                min: 2,
                max: 30,
                suffix: 's',
                onEnd: (v) => set(s.copyWith(pollSeconds: v.round())),
              ),
            ]),
          ),
          const SectionTitle('Plant thresholds'),
          GlassCard(
            child: Column(children: [
              _Slider(
                label: 'Thirsty below moisture',
                value: s.dryThreshold.toDouble(),
                min: 10,
                max: 70,
                suffix: '%',
                onEnd: (v) => set(s.copyWith(dryThreshold: v.round())),
              ),
              _Slider(
                label: 'Tank low at',
                value: s.tankLowPercent.toDouble(),
                min: 10,
                max: 50,
                suffix: '%',
                onEnd: (v) => set(s.copyWith(tankLowPercent: v.round())),
              ),
            ]),
          ),
          const SectionTitle('Pump safety'),
          GlassCard(
            glow: AppColors.amber,
            child: Column(children: [
              _Slider(
                label: 'Max manual run time',
                value: s.maxPumpSeconds.toDouble(),
                min: 10,
                max: 300,
                suffix: 's',
                onEnd: (v) => set(s.copyWith(maxPumpSeconds: v.round())),
              ),
              _Slider(
                label: 'Cooldown between runs',
                value: s.cooldownSeconds.toDouble(),
                min: 0,
                max: 900,
                suffix: 's',
                onEnd: (v) => set(s.copyWith(cooldownSeconds: v.round())),
              ),
              _Slider(
                label: 'Block watering at tank ≤',
                value: s.tankEmptyPercent.toDouble(),
                min: 0,
                max: 20,
                suffix: '%',
                onEnd: (v) => set(s.copyWith(tankEmptyPercent: v.round())),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Stop manual watering when app is closed'),
                subtitle: const Text('Fail-safe if you leave the app mid-run',
                    style: TextStyle(color: AppColors.textDim, fontSize: 12)),
                value: s.stopOnBackground,
                onChanged: (v) => set(s.copyWith(stopOnBackground: v)),
              ),
            ]),
          ),
          const SectionTitle('Weather (Open-Meteo)'),
          GlassCard(
            glow: AppColors.water,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.location_on_rounded, color: AppColors.water, size: 20),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(s.hasLocation ? s.placeName : 'No location set',
                        style: const TextStyle(fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: _place,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Search city',
                  suffixIcon: IconButton(
                    onPressed: _searching ? null : () => _search(c),
                    icon: _searching
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.search_rounded),
                  ),
                ),
                onSubmitted: (_) => _search(c),
              ),
              if (_searchError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_searchError!, style: const TextStyle(color: AppColors.amber, fontSize: 12.5)),
                ),
              for (final p in _results)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.place_outlined, color: AppColors.textDim),
                  title: Text(p.label),
                  onTap: () async {
                    await set(s.copyWith(lat: p.lat, lon: p.lon, placeName: p.label), weather: true);
                    if (mounted) {
                      setState(() => _results = []);
                      _place.clear();
                    }
                  },
                ),
              _Slider(
                label: 'Rain alert window',
                value: s.rainLookaheadHours.toDouble(),
                min: 1,
                max: 12,
                suffix: 'h',
                onEnd: (v) => set(s.copyWith(rainLookaheadHours: v.round())),
              ),
              _Slider(
                label: 'Rain chance threshold',
                value: s.rainProbThreshold.toDouble(),
                min: 30,
                max: 100,
                suffix: '%',
                onEnd: (v) => set(s.copyWith(rainProbThreshold: v.round())),
              ),
            ]),
          ),
          const SectionTitle('Notifications'),
          GlassCard(
            child: Column(children: [
              _Switch('Water tank low', s.notifyTank, (v) => set(s.copyWith(notifyTank: v))),
              _Switch('Rain expected', s.notifyRain, (v) => set(s.copyWith(notifyRain: v))),
              _Switch('Plant thirsty', s.notifyThirsty, (v) => set(s.copyWith(notifyThirsty: v))),
              _Switch('Connection lost', s.notifyOffline, (v) => set(s.copyWith(notifyOffline: v))),
              _Switch('Watering complete', s.notifyWatering, (v) => set(s.copyWith(notifyWatering: v))),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Alerts are checked while Smart Track is open. Android may pause the app in the background.',
                  style: TextStyle(color: AppColors.textDim, fontSize: 11.5),
                ),
              ),
            ]),
          ),
          const SectionTitle('Data'),
          GlassCard(
            child: Row(children: [
              const Expanded(child: Text('Clear history, analytics and cached data')),
              TextButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear all data?'),
                      content: const Text('Readings, history and the offline cache will be deleted. Settings are kept.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Clear', style: TextStyle(color: AppColors.red))),
                      ],
                    ),
                  );
                  if (ok == true) await c.clearData();
                },
                child: const Text('Clear', style: TextStyle(color: AppColors.red)),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text('Smart Track 1.0.0 · Monitor · Automate · Grow',
                style: TextStyle(color: AppColors.textDim, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch(this.label, this.value, this.onChanged);
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(label),
        value: value,
        onChanged: onChanged,
      );
}

class _Slider extends StatefulWidget {
  const _Slider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onEnd,
  });
  final String label, suffix;
  final double value, min, max;
  final ValueChanged<double> onEnd;
  @override
  State<_Slider> createState() => _SliderState();
}

class _SliderState extends State<_Slider> {
  double? _drag;
  @override
  Widget build(BuildContext context) {
    final v = (_drag ?? widget.value).clamp(widget.min, widget.max).toDouble();
    return Column(children: [
      Row(children: [
        Expanded(child: Text(widget.label, style: const TextStyle(fontSize: 13.5))),
        Text('${v.round()}${widget.suffix}',
            style: const TextStyle(color: AppColors.lime, fontWeight: FontWeight.w800)),
      ]),
      Slider(
        value: v,
        min: widget.min,
        max: widget.max,
        divisions: (widget.max - widget.min).round(),
        onChanged: (x) => setState(() => _drag = x),
        onChangeEnd: (x) {
          widget.onEnd(x);
          setState(() => _drag = null);
        },
      ),
    ]);
  }
}
