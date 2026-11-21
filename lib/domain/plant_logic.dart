import 'models.dart';
import 'settings.dart';

enum PlantState { healthy, thirsty, waitingForRain, watering, tankEmpty, offline }

PlantState derivePlantState({
  required SensorStatus? status,
  required bool connected,
  required bool rainSoon,
  required AppSettings settings,
}) {
  if (status == null || !connected) return PlantState.offline;
  if (status.pump) return PlantState.watering;
  if (status.moisture < settings.dryThreshold) {
    if (rainSoon) return PlantState.waitingForRain;
    if (status.tankSensorValid && status.tank <= settings.tankEmptyPercent) {
      return PlantState.tankEmpty;
    }
    return PlantState.thirsty;
  }
  return PlantState.healthy;
}

class PumpDecision {
  final bool allowed;
  final String? blockReason;
  final List<String> warnings;
  const PumpDecision.allow([this.warnings = const []])
      : allowed = true,
        blockReason = null;
  const PumpDecision.block(String reason)
      : allowed = false,
        blockReason = reason,
        warnings = const [];
}

/// Safety rules for starting the pump manually. Stop and Auto are always allowed.
PumpDecision checkPumpStart({
  required SensorStatus? status,
  required bool connected,
  required HourlyPoint? rainOutlook,
  required AppSettings settings,
  required DateTime? lastStopAt,
  required DateTime now,
}) {
  if (status == null || !connected) {
    return const PumpDecision.block(
        'The ESP32 is not connected, so the pump state cannot be verified.');
  }
  if (status.pump) {
    return const PumpDecision.block('The pump is already running.');
  }
  if (status.tankSensorValid && status.tank <= settings.tankEmptyPercent) {
    return PumpDecision.block(
        'Water tank is nearly empty (${status.tank}%). Running the pump dry can damage it.');
  }
  if (lastStopAt != null) {
    final wait = settings.cooldownSeconds - now.difference(lastStopAt).inSeconds;
    if (wait > 0) {
      return PumpDecision.block('Cooldown active. Try again in ${wait}s.');
    }
  }
  final warnings = <String>[];
  if (!status.tankSensorValid) {
    warnings.add(
        'Tank level sensor has no valid reading. Make sure the tank has water.');
  }
  if (status.moisture >= settings.wetLimit) {
    warnings.add('Soil is already wet (${status.moisture}%).');
  }
  if (rainOutlook != null) {
    warnings.add('Rain is expected soon (${rainOutlook.precipProb.round()}% chance).');
  }
  return PumpDecision.allow(warnings);
}

String fmtDuration(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds}s';
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  if (m < 60) return s == 0 ? '${m}m' : '${m}m ${s}s';
  return '${d.inHours}h ${m % 60}m';
}

String ago(DateTime t, [DateTime? now]) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inSeconds < 45) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}
