class AppSettings {
  final String host;
  final int pollSeconds;
  final int dryThreshold; // moisture % below which the plant is "thirsty"
  final int tankLowPercent;
  final int tankEmptyPercent; // pump is blocked at/below this level
  final int wetLimit; // manual watering warns at/above this moisture
  final int maxPumpSeconds;
  final int cooldownSeconds;
  final int rainProbThreshold;
  final int rainLookaheadHours;
  final bool stopOnBackground;
  final bool notifyTank;
  final bool notifyRain;
  final bool notifyThirsty;
  final bool notifyOffline;
  final bool notifyWatering;
  final double? lat;
  final double? lon;
  final String placeName;

  const AppSettings({
    this.host = '192.168.4.1',
    this.pollSeconds = 5,
    this.dryThreshold = 35,
    this.tankLowPercent = 20,
    this.tankEmptyPercent = 8,
    this.wetLimit = 85,
    this.maxPumpSeconds = 60,
    this.cooldownSeconds = 120,
    this.rainProbThreshold = 60,
    this.rainLookaheadHours = 2,
    this.stopOnBackground = true,
    this.notifyTank = true,
    this.notifyRain = true,
    this.notifyThirsty = true,
    this.notifyOffline = true,
    this.notifyWatering = true,
    this.lat,
    this.lon,
    this.placeName = '',
  });

  bool get hasLocation => lat != null && lon != null;

  AppSettings copyWith({
    String? host,
    int? pollSeconds,
    int? dryThreshold,
    int? tankLowPercent,
    int? tankEmptyPercent,
    int? wetLimit,
    int? maxPumpSeconds,
    int? cooldownSeconds,
    int? rainProbThreshold,
    int? rainLookaheadHours,
    bool? stopOnBackground,
    bool? notifyTank,
    bool? notifyRain,
    bool? notifyThirsty,
    bool? notifyOffline,
    bool? notifyWatering,
    double? lat,
    double? lon,
    String? placeName,
  }) =>
      AppSettings(
        host: host ?? this.host,
        pollSeconds: pollSeconds ?? this.pollSeconds,
        dryThreshold: dryThreshold ?? this.dryThreshold,
        tankLowPercent: tankLowPercent ?? this.tankLowPercent,
        tankEmptyPercent: tankEmptyPercent ?? this.tankEmptyPercent,
        wetLimit: wetLimit ?? this.wetLimit,
        maxPumpSeconds: maxPumpSeconds ?? this.maxPumpSeconds,
        cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
        rainProbThreshold: rainProbThreshold ?? this.rainProbThreshold,
        rainLookaheadHours: rainLookaheadHours ?? this.rainLookaheadHours,
        stopOnBackground: stopOnBackground ?? this.stopOnBackground,
        notifyTank: notifyTank ?? this.notifyTank,
        notifyRain: notifyRain ?? this.notifyRain,
        notifyThirsty: notifyThirsty ?? this.notifyThirsty,
        notifyOffline: notifyOffline ?? this.notifyOffline,
        notifyWatering: notifyWatering ?? this.notifyWatering,
        lat: lat ?? this.lat,
        lon: lon ?? this.lon,
        placeName: placeName ?? this.placeName,
      );

  Map<String, Object?> toMap() => {
        'host': host,
        'pollSeconds': pollSeconds,
        'dryThreshold': dryThreshold,
        'tankLowPercent': tankLowPercent,
        'tankEmptyPercent': tankEmptyPercent,
        'wetLimit': wetLimit,
        'maxPumpSeconds': maxPumpSeconds,
        'cooldownSeconds': cooldownSeconds,
        'rainProbThreshold': rainProbThreshold,
        'rainLookaheadHours': rainLookaheadHours,
        'stopOnBackground': stopOnBackground,
        'notifyTank': notifyTank,
        'notifyRain': notifyRain,
        'notifyThirsty': notifyThirsty,
        'notifyOffline': notifyOffline,
        'notifyWatering': notifyWatering,
        'lat': lat,
        'lon': lon,
        'placeName': placeName,
      };

  factory AppSettings.fromMap(Map<String, dynamic> m) {
    const d = AppSettings();
    int i(String k, int def) => (m[k] is num) ? (m[k] as num).toInt() : def;
    bool b(String k, bool def) => m[k] is bool ? m[k] as bool : def;
    return AppSettings(
      host: (m['host'] is String && (m['host'] as String).trim().isNotEmpty)
          ? (m['host'] as String).trim()
          : d.host,
      pollSeconds: i('pollSeconds', d.pollSeconds).clamp(2, 60),
      dryThreshold: i('dryThreshold', d.dryThreshold).clamp(5, 90),
      tankLowPercent: i('tankLowPercent', d.tankLowPercent).clamp(5, 60),
      tankEmptyPercent: i('tankEmptyPercent', d.tankEmptyPercent).clamp(0, 30),
      wetLimit: i('wetLimit', d.wetLimit).clamp(50, 100),
      maxPumpSeconds: i('maxPumpSeconds', d.maxPumpSeconds).clamp(5, 600),
      cooldownSeconds: i('cooldownSeconds', d.cooldownSeconds).clamp(0, 3600),
      rainProbThreshold: i('rainProbThreshold', d.rainProbThreshold).clamp(20, 100),
      rainLookaheadHours: i('rainLookaheadHours', d.rainLookaheadHours).clamp(1, 12),
      stopOnBackground: b('stopOnBackground', d.stopOnBackground),
      notifyTank: b('notifyTank', d.notifyTank),
      notifyRain: b('notifyRain', d.notifyRain),
      notifyThirsty: b('notifyThirsty', d.notifyThirsty),
      notifyOffline: b('notifyOffline', d.notifyOffline),
      notifyWatering: b('notifyWatering', d.notifyWatering),
      lat: (m['lat'] as num?)?.toDouble(),
      lon: (m['lon'] as num?)?.toDouble(),
      placeName: (m['placeName'] as String?) ?? '',
    );
  }
}
