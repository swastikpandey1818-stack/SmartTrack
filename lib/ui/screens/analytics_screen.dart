import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../domain/plant_logic.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'alerts_screen.dart' show eventIcon, eventColor;

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _tab = 0; // 0 charts, 1 history
  int _rangeHours = 24;
  List<Reading> _readings = [];
  bool _loading = true;
  DateTime? _lastLoad;

  Future<void> _load(AppController c) async {
    final r = await c.loadReadings(Duration(hours: _rangeHours));
    if (!mounted) return;
    setState(() {
      _readings = r;
      _loading = false;
      _lastLoad = DateTime.now();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = ControllerScope.of(context);
    if (_lastLoad == null || DateTime.now().difference(_lastLoad!).inSeconds > 20) {
      _lastLoad = DateTime.now();
      _load(c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ControllerScope.of(context);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          Row(children: [
            const Expanded(
                child: Text('Analytics',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
            IconButton(
                onPressed: () => _load(c),
                icon: const Icon(Icons.refresh_rounded, color: AppColors.lime)),
          ]),
          const SizedBox(height: 6),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Charts'), icon: Icon(Icons.show_chart_rounded)),
              ButtonSegment(value: 1, label: Text('History'), icon: Icon(Icons.history_rounded)),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.emerald.withValues(alpha: 0.3),
              selectedForegroundColor: AppColors.lime,
            ),
          ),
          const SizedBox(height: 12),
          if (_tab == 0) ..._charts(c) else ..._history(c),
        ],
      ),
    );
  }

  List<Widget> _charts(AppController c) {
    final now = DateTime.now();
    final from = now.subtract(Duration(hours: _rangeHours));
    String lbl(DateTime t) => _rangeHours <= 24
        ? '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'
        : '${t.day}/${t.month}';
    final moisture = [for (final r in _readings) SeriesPoint(r.time, r.moisture.toDouble())];
    final tank = [for (final r in _readings) SeriesPoint(r.time, r.tank.toDouble())];

    var avg = 0.0, minM = 0, maxM = 0;
    if (_readings.isNotEmpty) {
      avg = _readings.map((r) => r.moisture).reduce((a, b) => a + b) / _readings.length;
      minM = _readings.map((r) => r.moisture).reduce((a, b) => a < b ? a : b);
      maxM = _readings.map((r) => r.moisture).reduce((a, b) => a > b ? a : b);
    }
    // Pump runs and runtime from the sampled readings.
    var runs = 0;
    var runSeconds = 0;
    for (var i = 0; i < _readings.length; i++) {
      final r = _readings[i];
      if (r.pump && (i == 0 || !_readings[i - 1].pump)) runs++;
      if (r.pump && i + 1 < _readings.length) {
        final gap = _readings[i + 1].time.difference(r.time).inSeconds;
        if (gap <= 120) runSeconds += gap;
      }
    }
    // Waterings per day for the last 7 days.
    final perDay = List<double>.filled(7, 0);
    final labels = <String>[];
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    for (var d = 6; d >= 0; d--) {
      labels.add(wd[now.subtract(Duration(days: d)).weekday - 1]);
    }
    for (final e in c.history.where((e) => e.type == 'watering')) {
      final days = DateTime(now.year, now.month, now.day)
          .difference(DateTime(e.time.year, e.time.month, e.time.day))
          .inDays;
      if (days >= 0 && days < 7) perDay[6 - days] += 1;
    }

    return [
      Row(children: [
        for (final h in [24, 72, 168]) ...[
          ChoiceChip(
            label: Text(h == 24 ? '24h' : (h == 72 ? '3 days' : '7 days')),
            selected: _rangeHours == h,
            selectedColor: AppColors.emerald.withValues(alpha: 0.35),
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.border),
            onSelected: (_) {
              setState(() => _rangeHours = h);
              _load(c);
            },
          ),
          const SizedBox(width: 8),
        ],
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _Stat('Avg moisture', _readings.isEmpty ? '--' : '${avg.round()}%', AppColors.lime)),
        const SizedBox(width: 10),
        Expanded(child: _Stat('Min / Max', _readings.isEmpty ? '--' : '$minM / $maxM%', AppColors.mint)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _Stat('Pump runs', '$runs', AppColors.cyan)),
        const SizedBox(width: 10),
        Expanded(child: _Stat('Pump time', fmtDuration(Duration(seconds: runSeconds)), AppColors.water)),
      ]),
      const SectionTitle('Soil moisture'),
      GlassCard(
        child: _loading
            ? const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()))
            : LineChart(points: moisture, from: from, to: now, color: AppColors.lime, timeLabel: lbl),
      ),
      const SectionTitle('Water tank'),
      GlassCard(
        glow: AppColors.water,
        child: LineChart(points: tank, from: from, to: now, color: AppColors.water, timeLabel: lbl),
      ),
      const SectionTitle('Waterings per day'),
      GlassCard(glow: AppColors.cyan, child: BarChart(values: perDay, labels: labels, color: AppColors.cyan)),
      const SizedBox(height: 8),
      Text(
        'Readings are saved about every 30 seconds while the app is open and kept for 30 days.',
        style: TextStyle(color: AppColors.textDim.withValues(alpha: 0.9), fontSize: 11.5),
      ),
    ];
  }

  List<Widget> _history(AppController c) {
    if (c.history.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Center(
              child: Text('No history yet. Pump runs and alerts will appear here.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDim))),
        ),
      ];
    }
    return [
      for (final e in c.history)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            glow: eventColor(e),
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Icon(eventIcon(e.type), color: eventColor(e)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (e.detail.isNotEmpty)
                    Text(e.detail, style: const TextStyle(color: AppColors.textDim, fontSize: 12.5)),
                ]),
              ),
              Text(ago(e.time), style: const TextStyle(color: AppColors.textDim, fontSize: 11.5)),
            ]),
          ),
        ),
    ];
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => GlassCard(
        glow: color,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 12.5)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
        ]),
      );
}
