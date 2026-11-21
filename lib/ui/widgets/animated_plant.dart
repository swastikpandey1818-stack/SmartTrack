import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/plant_logic.dart';

class PlantVisual {
  final double droop; // 0 perky .. 1 wilted
  final Color leaf;
  final Color glow;
  final String title;
  final String subtitle;
  final IconData icon;
  final String asset;
  const PlantVisual(this.droop, this.leaf, this.glow, this.title, this.subtitle, this.icon, this.asset);

  static PlantVisual of(PlantState s) => switch (s) {
        PlantState.healthy => const PlantVisual(0, Color(0xFF4ADE80), AppColors.lime,
            'Plant Healthy', 'Everything is in balance.', Icons.check_circle_rounded,
            'assets/images/state_healthy.png'),
        PlantState.thirsty => const PlantVisual(0.85, Color(0xFFB8A23A), AppColors.amber,
            'Thirsty Plant', 'Soil is dry and needs water.', Icons.water_drop_outlined,
            'assets/images/state_thirsty.png'),
        PlantState.waitingForRain => const PlantVisual(0.45, Color(0xFF6BCB77), AppColors.water,
            'Waiting for Rain', 'Dry soil, but rain is on the way.', Icons.cloudy_snowing,
            'assets/images/state_rain.png'),
        PlantState.watering => const PlantVisual(0, Color(0xFF5CF08A), AppColors.cyan,
            'Watering…', 'The pump is running.', Icons.shower_rounded,
            'assets/images/state_watering.png'),
        PlantState.tankEmpty => const PlantVisual(0.75, Color(0xFFA8A040), AppColors.red,
            'Tank Empty', 'Dry soil and no water to give.', Icons.opacity_rounded,
            'assets/images/state_empty_tank.png'),
        PlantState.offline => const PlantVisual(0.3, Color(0xFF557A63), AppColors.red,
            'Connection Lost', 'Cannot reach the ESP32.', Icons.wifi_off_rounded,
            'assets/images/state_offline.png'),
      };
}

class AnimatedPlant extends StatefulWidget {
  const AnimatedPlant({super.key, required this.state, this.height = 250});
  final PlantState state;
  final double height;
  @override
  State<AnimatedPlant> createState() => _AnimatedPlantState();
}

class _AnimatedPlantState extends State<AnimatedPlant> with SingleTickerProviderStateMixin {
  late final AnimationController _loop =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = PlantVisual.of(widget.state);
    return SizedBox(
      height: widget.height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: v.droop),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeInOutCubic,
        builder: (context, droop, _) => TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: v.leaf),
          duration: const Duration(milliseconds: 900),
          builder: (context, leaf, _) => AnimatedBuilder(
            animation: _loop,
            builder: (context, _) => CustomPaint(
              size: Size.infinite,
              painter: _PlantPainter(
                t: _loop.value,
                droop: droop,
                leaf: leaf ?? v.leaf,
                glow: v.glow,
                state: widget.state,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlantPainter extends CustomPainter {
  _PlantPainter({
    required this.t,
    required this.droop,
    required this.leaf,
    required this.glow,
    required this.state,
  });
  final double t, droop;
  final Color leaf, glow;
  final PlantState state;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    final sway = math.sin(t * 2 * math.pi);

    // Glow
    canvas.drawCircle(
      Offset(cx, h * 0.58),
      h * 0.5,
      Paint()
        ..shader = RadialGradient(colors: [glow.withValues(alpha: 0.30), glow.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: Offset(cx, h * 0.58), radius: h * 0.5)),
    );

    // Pot
    final potTop = h * 0.74, potBottom = h * 0.97, potW = math.min(w * 0.36, h * 0.5);
    final pot = Path()
      ..moveTo(cx - potW / 2, potTop)
      ..lineTo(cx + potW / 2, potTop)
      ..lineTo(cx + potW * 0.38, potBottom)
      ..lineTo(cx - potW * 0.38, potBottom)
      ..close();
    canvas.drawPath(
        pot,
        Paint()
          ..shader = const LinearGradient(
                  colors: [Color(0xFF6B4A32), Color(0xFF3B2718)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter)
              .createShader(Rect.fromLTWH(cx - potW / 2, potTop, potW, potBottom - potTop)));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - potW / 2 - 4, potTop - 8, potW + 8, 14), const Radius.circular(7)),
        Paint()..color = const Color(0xFF7A573B));
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, potTop - 1), width: potW - 6, height: 12),
        Paint()..color = const Color(0xFF2A1A10));

    // Stem
    final base = Offset(cx, potTop - 3);
    final topY = h * (0.30 + droop * 0.16);
    final tip = Offset(cx + sway * 5 + droop * 14, topY);
    final ctrl = Offset(cx - 6 + sway * 3, (base.dy + topY) / 2);
    final stem = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy);
    canvas.drawPath(
        stem,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(const Color(0xFF3CB35A), const Color(0xFF8A8A3A), droop)!);

    Offset onStem(double u) {
      final a = Offset.lerp(base, ctrl, u)!;
      final b = Offset.lerp(ctrl, tip, u)!;
      return Offset.lerp(a, b, u)!;
    }

    final leafLen = math.min(w * 0.30, h * 0.34);
    final levels = [0.35, 0.58, 0.86];
    for (var i = 0; i < levels.length; i++) {
      final o = onStem(levels[i]);
      final len = leafLen * (1.0 - i * 0.18);
      final lift = -0.62 - i * 0.18;
      final a = lift + (0.95 - lift + i * 0.1) * droop + sway * 0.05 * (i + 1);
      _leaf(canvas, o, a, len);
      _leaf(canvas, o, math.pi - a, len * 0.96);
    }
    // Top bud
    _leaf(canvas, tip, -math.pi / 2 + sway * 0.1 + droop * 0.9, leafLen * 0.5);

    _effects(canvas, size, cx, h);
  }

  void _leaf(Canvas canvas, Offset o, double angle, double len) {
    final wid = len * 0.34;
    canvas.save();
    canvas.translate(o.dx, o.dy);
    canvas.rotate(angle);
    final p = Path()
      ..moveTo(0, 0)
      ..cubicTo(len * 0.25, -wid * 1.2, len * 0.75, -wid, len, 0)
      ..cubicTo(len * 0.75, wid * 0.9, len * 0.25, wid * 1.1, 0, 0);
    canvas.drawPath(
        p,
        Paint()
          ..shader = LinearGradient(colors: [
            Color.lerp(leaf, Colors.black, 0.25)!,
            Color.lerp(leaf, Colors.white, 0.18)!,
          ]).createShader(Rect.fromLTWH(0, -wid, len, wid * 2)));
    canvas.drawLine(
        Offset.zero,
        Offset(len * 0.92, 0),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.25)
          ..strokeWidth = 1.4);
    canvas.restore();
  }

  void _effects(Canvas canvas, Size size, double cx, double h) {
    switch (state) {
      case PlantState.waitingForRain:
        _cloud(canvas, Offset(cx, h * 0.12), h * 0.2);
        final rain = Paint()
          ..color = AppColors.water.withValues(alpha: 0.85)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 12; i++) {
          final f = (t * 1.2 + i / 12) % 1.0;
          final x = cx - h * 0.28 + (i / 11) * h * 0.56;
          final y = h * 0.2 + f * h * 0.5;
          canvas.drawLine(Offset(x, y), Offset(x - 3, y + 11), rain..color = rain.color.withValues(alpha: 1 - f * 0.7));
        }
      case PlantState.watering:
        final can = Offset(cx + h * 0.30, h * 0.16);
        canvas.save();
        canvas.translate(can.dx, can.dy);
        canvas.rotate(-0.5 + math.sin(t * 2 * math.pi) * 0.03);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(-26, -16, 52, 32), const Radius.circular(9)),
            Paint()..color = AppColors.water);
        canvas.drawRect(const Rect.fromLTWH(-48, -5, 24, 8), Paint()..color = AppColors.water);
        canvas.restore();
        final drop = Paint()..color = AppColors.cyan.withValues(alpha: 0.9);
        for (var i = 0; i < 14; i++) {
          final f = (t * 1.6 + i / 14) % 1.0;
          final x = can.dx - 44 - f * (h * 0.12) + math.sin(i * 1.7) * 6;
          final y = can.dy + 6 + f * f * (h * 0.55);
          canvas.drawCircle(Offset(x, y), 3.2 - f * 1.2, drop);
        }
      case PlantState.thirsty:
      case PlantState.tankEmpty:
        final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
        final c = state == PlantState.tankEmpty ? AppColors.red : AppColors.amber;
        final o = Offset(cx + h * 0.24, h * 0.18);
        final dropPath = Path()
          ..moveTo(o.dx, o.dy - 16)
          ..quadraticBezierTo(o.dx + 14, o.dy + 4, o.dx, o.dy + 12)
          ..quadraticBezierTo(o.dx - 14, o.dy + 4, o.dx, o.dy - 16);
        canvas.drawPath(dropPath, Paint()..color = c.withValues(alpha: 0.35 + 0.5 * pulse));
        canvas.drawPath(
            dropPath,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = c);
      case PlantState.offline:
        final wo = Offset(cx + h * 0.26, h * 0.16);
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..color = AppColors.red.withValues(alpha: 0.55 + 0.4 * math.sin(t * 2 * math.pi).abs());
        for (var i = 1; i <= 3; i++) {
          canvas.drawArc(Rect.fromCircle(center: wo, radius: 9.0 * i), -math.pi * 0.85,
              math.pi * 0.7, false, p);
        }
        canvas.drawCircle(wo, 3, Paint()..color = AppColors.red);
      case PlantState.healthy:
        final sp = Paint()..color = AppColors.lime;
        for (var i = 0; i < 6; i++) {
          final f = (t + i / 6) % 1.0;
          final x = cx + math.sin(i * 2.3) * h * 0.3;
          final y = h * 0.62 - f * h * 0.4;
          canvas.drawCircle(Offset(x, y), 2.2 * (1 - f), sp..color = AppColors.lime.withValues(alpha: 0.8 * (1 - f)));
        }
    }
  }

  void _cloud(Canvas canvas, Offset c, double r) {
    final p = Paint()..color = const Color(0xFF6B8FB5);
    canvas.drawCircle(c + Offset(-r * 0.55, r * 0.1), r * 0.5, p);
    canvas.drawCircle(c + Offset(r * 0.5, r * 0.12), r * 0.45, p);
    canvas.drawCircle(c + Offset(0, -r * 0.15), r * 0.62, p..color = const Color(0xFF86A9CF));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: c + Offset(0, r * 0.3), width: r * 2.1, height: r * 0.6),
            Radius.circular(r * 0.3)),
        p);
  }

  @override
  bool shouldRepaint(covariant _PlantPainter old) =>
      old.t != t || old.droop != droop || old.leaf != leaf || old.state != state;
}
