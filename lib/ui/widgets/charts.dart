import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

class SeriesPoint {
  final DateTime t;
  final double v;
  const SeriesPoint(this.t, this.v);
}

/// Small dependency-free line chart (0..100 y-axis).
class LineChart extends StatelessWidget {
  const LineChart({
    super.key,
    required this.points,
    required this.from,
    required this.to,
    this.color = AppColors.emerald,
    this.height = 150,
    this.timeLabel,
  });
  final List<SeriesPoint> points;
  final DateTime from, to;
  final Color color;
  final double height;
  final String Function(DateTime)? timeLabel;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: CustomPaint(
          size: Size.infinite,
          painter: _LinePainter(points, from, to, color, timeLabel),
        ),
      );
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.pts, this.from, this.to, this.color, this.label);
  final List<SeriesPoint> pts;
  final DateTime from, to;
  final Color color;
  final String Function(DateTime)? label;

  void _text(Canvas c, String s, Offset o, {bool right = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    c.save();
    c.translate(right ? o.dx - tp.width : o.dx, o.dy - tp.height / 2);
    tp.paint(c, Offset.zero);
    c.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 30.0, bottom = 18.0, top = 6.0;
    final plot = Rect.fromLTRB(left, top, size.width - 4, size.height - bottom);
    final grid = Paint()
      ..color = AppColors.border.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (final g in [0, 25, 50, 75, 100]) {
      final y = plot.bottom - plot.height * g / 100;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _text(canvas, '$g', Offset(left - 6, y), right: true);
    }
    final span = math.max(1, to.difference(from).inMilliseconds);
    Offset map(SeriesPoint p) => Offset(
          plot.left + plot.width * (p.t.difference(from).inMilliseconds / span).clamp(0.0, 1.0),
          plot.bottom - plot.height * (p.v.clamp(0, 100) / 100),
        );
    if (label != null) {
      _text(canvas, label!(from), Offset(plot.left, size.height - 6));
      _text(canvas, label!(to), Offset(plot.right, size.height - 6), right: true);
    }
    if (pts.isEmpty) {
      _text(canvas, 'No data yet', Offset(plot.center.dx - 28, plot.center.dy));
      return;
    }
    final line = Path();
    final area = Path();
    for (var i = 0; i < pts.length; i++) {
      final o = map(pts[i]);
      if (i == 0) {
        line.moveTo(o.dx, o.dy);
        area.moveTo(o.dx, plot.bottom);
        area.lineTo(o.dx, o.dy);
      } else {
        // Break the line over data gaps (> 10 min).
        if (pts[i].t.difference(pts[i - 1].t).inMinutes > 10) {
          line.moveTo(o.dx, o.dy);
        } else {
          line.lineTo(o.dx, o.dy);
        }
        area.lineTo(o.dx, o.dy);
      }
    }
    area.lineTo(map(pts.last).dx, plot.bottom);
    area.close();
    canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.30), color.withValues(alpha: 0)],
          ).createShader(plot));
    canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeJoin = StrokeJoin.round
          ..color = color);
    canvas.drawCircle(map(pts.last), 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.pts != pts || old.color != color || old.from != from || old.to != to;
}

class BarChart extends StatelessWidget {
  const BarChart({super.key, required this.values, required this.labels, this.color = AppColors.water, this.height = 110});
  final List<double> values;
  final List<String> labels;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxV = values.isEmpty ? 1.0 : math.max(1.0, values.reduce(math.max));
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(values[i] == 0 ? '' : values[i].round().toString(),
                      style: const TextStyle(fontSize: 10, color: AppColors.textDim)),
                  const SizedBox(height: 2),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    height: math.max(3.0, (height - 36) * values[i] / maxV),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [color, color.withValues(alpha: 0.35)]),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(labels[i], style: const TextStyle(fontSize: 10, color: AppColors.textDim)),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
