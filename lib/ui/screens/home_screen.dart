import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../domain/plant_logic.dart';
import '../widgets/animated_plant.dart';
import '../widgets/common.dart';

IconData weatherIcon(int code) {
  if (code == 0) return Icons.wb_sunny_rounded;
  if (code <= 2) return Icons.wb_cloudy_outlined;
  if (code == 3) return Icons.cloud_rounded;
  if (code == 45 || code == 48) return Icons.foggy;
  if (isRainyCode(code)) return code >= 95 ? Icons.thunderstorm_rounded : Icons.grain_rounded;
  if (code >= 71 && code <= 86) return Icons.ac_unit_rounded;
  return Icons.cloud_queue_rounded;
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenAlerts, required this.onOpenSettings});
  final VoidCallback onOpenAlerts;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final c = ControllerScope.of(context);
    final v = PlantVisual.of(c.plantState);
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.lime,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          await Future.wait([c.refreshStatus(), c.refreshWeather()]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _Header(c: c, onOpenAlerts: onOpenAlerts),
            const SizedBox(height: 10),
            Center(child: _ConnectionPill(c: c)),
            if (c.status != null && !c.status!.tankSensorValid && c.connected)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: _Banner(
                  icon: Icons.sensors_off_rounded,
                  color: AppColors.amber,
                  text:
                      'Tank sensor has no valid echo (distance −1). Tank level is unknown, so check the ultrasonic wiring.',
                ),
              ),
            if (!c.connected)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _Banner(
                  icon: Icons.wifi_off_rounded,
                  color: AppColors.red,
                  text: c.lastSeen == null
                      ? 'No data yet. Join the ESP32 Wi-Fi network and pull down to refresh.'
                      : 'Showing saved readings from ${ago(c.lastSeen!)}. Join the ESP32 Wi-Fi to reconnect.',
                ),
              ),
            AnimatedPlant(state: c.plantState, height: 250),
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: Container(
                  key: ValueKey(c.plantState),
                  padding: const EdgeInsets.fromLTRB(8, 6, 18, 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    gradient: LinearGradient(colors: [
                      v.glow.withValues(alpha: 0.35),
                      v.glow.withValues(alpha: 0.15),
                    ]),
                    border: Border.all(color: v.glow.withValues(alpha: 0.7)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(v.asset, width: 38, height: 38, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 10),
                    Text(v.title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    Icon(v.icon, color: v.glow, size: 20),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(v.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textDim)),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _MoistureCard(c: c)),
              const SizedBox(width: 12),
              Expanded(child: _TankCard(c: c)),
            ]),
            const SizedBox(height: 12),
            _WeatherCard(c: c, onSetLocation: onOpenSettings),
            const SizedBox(height: 12),
            _PumpCard(c: c),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.c, required this.onOpenAlerts});
  final AppController c;
  final VoidCallback onOpenAlerts;
  @override
  Widget build(BuildContext context) => Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset('assets/icon/icon.png', width: 36, height: 36),
        ),
        const SizedBox(width: 10),
        const Expanded(
            child: Text('Smart Track',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
        IconButton(
          onPressed: onOpenAlerts,
          icon: Badge(
            isLabelVisible: c.alerts.isNotEmpty,
            label: Text('${c.alerts.length > 9 ? '9+' : c.alerts.length}'),
            backgroundColor: AppColors.lime,
            textColor: Colors.black,
            child: const Icon(Icons.notifications_rounded, color: AppColors.lime, size: 28),
          ),
        ),
      ]);
}

class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill({required this.c});
  final AppController c;
  @override
  Widget build(BuildContext context) {
    if (c.connected) {
      return Pill('ESP32 Online · ${c.settings.host}',
          icon: Icons.memory_rounded, color: AppColors.emerald);
    }
    return Pill('ESP32 Offline', icon: Icons.wifi_off_rounded, color: AppColors.red);
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.3))),
        ]),
      );
}

class _MeterCard extends StatelessWidget {
  const _MeterCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.progress,
    this.dim = false,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final double progress;
  final bool dim;
  @override
  Widget build(BuildContext context) => GlassCard(
        glow: color,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: dim ? AppColors.textDim : AppColors.text)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: progress.clamp(0.0, 1.0).toDouble()),
              duration: const Duration(milliseconds: 700),
              builder: (_, p, __) => LinearProgressIndicator(
                value: p,
                minHeight: 7,
                color: color,
                backgroundColor: AppColors.border,
              ),
            ),
          ),
        ]),
      );
}

class _MoistureCard extends StatelessWidget {
  const _MoistureCard({required this.c});
  final AppController c;
  @override
  Widget build(BuildContext context) {
    final s = c.status;
    final dry = s != null && s.moisture < c.settings.dryThreshold;
    return _MeterCard(
      icon: Icons.water_drop_rounded,
      color: dry ? AppColors.amber : AppColors.lime,
      label: 'Soil Moisture',
      value: s == null ? '--' : '${s.moisture}%',
      progress: (s?.moisture ?? 0) / 100,
      dim: s == null,
    );
  }
}

class _TankCard extends StatelessWidget {
  const _TankCard({required this.c});
  final AppController c;
  @override
  Widget build(BuildContext context) {
    final s = c.status;
    final int? tank = (s != null && s.tankSensorValid) ? s.tank : null;
    final low = tank != null && tank <= c.settings.tankLowPercent;
    return _MeterCard(
      icon: Icons.propane_tank_rounded,
      color: tank == null ? AppColors.textDim : (low ? AppColors.red : AppColors.water),
      label: 'Tank',
      value: s == null ? '--' : (tank == null ? 'No sensor' : '$tank%'),
      progress: tank == null ? 0 : tank / 100,
      dim: tank == null,
    );
  }
}

class _WeatherCard extends StatelessWidget {
  const _WeatherCard({required this.c, required this.onSetLocation});
  final AppController c;
  final VoidCallback onSetLocation;

  @override
  Widget build(BuildContext context) {
    final w = c.weather;
    if (!c.settings.hasLocation) {
      return GlassCard(
        glow: AppColors.water,
        onTap: onSetLocation,
        child: const Row(children: [
          Icon(Icons.location_searching_rounded, color: AppColors.water),
          SizedBox(width: 12),
          Expanded(
              child: Text('Set your location in Settings to get weather forecasts and rain-aware watering.')),
          Icon(Icons.chevron_right_rounded, color: AppColors.textDim),
        ]),
      );
    }
    if (w == null) {
      return GlassCard(
        glow: AppColors.water,
        child: Row(children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.textDim),
          const SizedBox(width: 12),
          Expanded(
              child: Text(c.weatherLoading
                  ? 'Loading forecast…'
                  : (c.weatherError ?? 'No forecast yet. Pull down to refresh.'))),
        ]),
      );
    }
    final rain = c.rainOutlook;
    final hours = rain == null ? null : rain.time.difference(DateTime.now()).inMinutes / 60;
    return GlassCard(
      glow: AppColors.water,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(weatherIcon(w.code), color: AppColors.water, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${w.temp.round()}°C · ${weatherLabel(w.code)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text(
                rain == null
                    ? 'No rain expected in the next ${c.settings.rainLookaheadHours}h'
                    : (hours! <= 0.5
                        ? 'Raining now'
                        : 'Rain likely in ~${hours.ceil()}h (${rain.precipProb.round()}%)'),
                style: TextStyle(
                    color: rain == null ? AppColors.textDim : AppColors.water, fontSize: 13),
              ),
              if (c.settings.placeName.isNotEmpty)
                Text(c.settings.placeName,
                    style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
            ]),
          ),
          if (c.weatherLoading)
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.water)),
        ]),
        if (c.weatherStale)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Pill('Saved forecast · ${ago(w.fetchedAt)}',
                color: AppColors.amber, icon: Icons.cloud_download_outlined),
          ),
        const SizedBox(height: 12),
        Row(children: [
          for (final d in w.daily.take(5))
            Expanded(
              child: Column(children: [
                Text(_weekdays[d.date.weekday - 1],
                    style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                const SizedBox(height: 4),
                Icon(weatherIcon(d.code),
                    size: 22,
                    color: isRainyCode(d.code) ? AppColors.water : AppColors.textDim),
                const SizedBox(height: 4),
                Text('${d.tMax.round()}°',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text('${d.precipProbMax.round()}%',
                    style: const TextStyle(color: AppColors.water, fontSize: 11)),
              ]),
            ),
        ]),
      ]),
    );
  }
}

class _PumpCard extends StatelessWidget {
  const _PumpCard({required this.c});
  final AppController c;

  String get _modeText {
    final s = c.status;
    if (s == null) return 'Unknown';
    return switch (s.mode) {
      PumpMode.auto => s.pump ? 'Auto · running' : 'Auto · idle',
      PumpMode.manualOn => 'Manual · running',
      PumpMode.manualOff => 'Manual · off',
    };
  }

  Future<void> _run(BuildContext context, PumpCommand cmd) async {
    final r = await c.sendPump(cmd);
    if (context.mounted) showSnack(context, r.message);
  }

  Future<void> _water(BuildContext context) async {
    final d = c.evaluatePumpOn();
    if (!d.allowed) {
      showSnack(context, d.blockReason ?? 'Blocked for safety.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start watering?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('The pump will run manually and stop automatically after ${c.settings.maxPumpSeconds} seconds.'),
          for (final w in d.warnings)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(w, style: const TextStyle(fontSize: 13))),
              ]),
            ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.emerald, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(d.warnings.isEmpty ? 'Water now' : 'Water anyway'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) await _run(context, PumpCommand.on);
  }

  @override
  Widget build(BuildContext context) {
    final s = c.status;
    final running = s?.pump ?? false;
    final enabled = c.connected && !c.pumpBusy;
    final remaining = c.pumpRunning == null
        ? null
        : (c.settings.maxPumpSeconds - c.pumpRunning!.inSeconds).clamp(0, 9999);
    return GlassCard(
      glow: running ? AppColors.cyan : AppColors.emerald,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.settings_rounded,
              color: running ? AppColors.cyan : AppColors.emerald, size: 22),
          const SizedBox(width: 8),
          const Expanded(
              child: Text('Pump control',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          Pill(_modeText,
              color: running ? AppColors.cyan : AppColors.emerald),
        ]),
        if (running && remaining != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Safety stop in ${remaining}s',
                style: const TextStyle(color: AppColors.textDim, fontSize: 12.5)),
          ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            flex: 3,
            child: FilledButton.icon(
              onPressed: enabled && !running ? () => _water(context) : null,
              icon: const Icon(Icons.water_drop_rounded),
              label: const Text('Water now'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: c.connected && !c.pumpBusy ? () => _run(context, PumpCommand.off) : null,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Stop'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: enabled && (s?.manual ?? false) ? () => _run(context, PumpCommand.auto) : null,
            icon: const Icon(Icons.autorenew_rounded),
            label: Text((s?.manual ?? false) ? 'Return to Auto' : 'Auto mode active'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.lime,
              side: const BorderSide(color: AppColors.emerald),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Stop works any time. Watering is blocked when the tank is empty, during cooldown, or when the ESP32 is offline.',
          style: TextStyle(color: AppColors.textDim.withValues(alpha: 0.9), fontSize: 11.5, height: 1.3),
        ),
      ]),
    );
  }
}
