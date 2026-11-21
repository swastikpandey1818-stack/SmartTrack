import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../domain/plant_logic.dart';
import '../widgets/common.dart';

IconData eventIcon(String type) => switch (type) {
      'tank' => Icons.water_drop_rounded,
      'rain' => Icons.cloudy_snowing,
      'thirsty' => Icons.local_florist_rounded,
      'offline' => Icons.wifi_off_rounded,
      'watering' => Icons.check_circle_rounded,
      'pump' => Icons.settings_rounded,
      'safety' => Icons.shield_rounded,
      _ => Icons.info_rounded,
    };

Color eventColor(EventRecord e) {
  if (e.severity >= 2) return AppColors.red;
  return switch (e.type) {
    'tank' => AppColors.water,
    'rain' => AppColors.water,
    'thirsty' => AppColors.amber,
    'watering' => AppColors.lime,
    'safety' => AppColors.amber,
    _ => e.severity == 1 ? AppColors.amber : AppColors.emerald,
  };
}

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = ControllerScope.of(context);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          const Row(children: [
            Icon(Icons.notifications_rounded, color: AppColors.lime),
            SizedBox(width: 10),
            Text('Notifications', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 14),
          if (c.alerts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset('assets/images/state_success.png', width: 150),
                ),
                const SizedBox(height: 16),
                const Text('All clear', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('No active alerts for your plant.',
                    style: TextStyle(color: AppColors.textDim)),
              ]),
            )
          else ...[
            for (final e in c.alerts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  glow: eventColor(e),
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: eventColor(e).withValues(alpha: 0.18)),
                      child: Icon(eventIcon(e.type), color: eventColor(e)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(e.detail,
                            style: const TextStyle(color: AppColors.textDim, fontSize: 12.5)),
                      ]),
                    ),
                    Text(ago(e.time),
                        style: const TextStyle(color: AppColors.textDim, fontSize: 11.5)),
                  ]),
                ),
              ),
            const SizedBox(height: 6),
            FilledButton(
              onPressed: c.clearAlerts,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.emerald.withValues(alpha: 0.35),
                foregroundColor: AppColors.lime,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Clear All'),
            ),
          ],
        ],
      ),
    );
  }
}
