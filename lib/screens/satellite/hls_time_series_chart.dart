import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../models/satellite_monitoring_model.dart';

/// منحنى السلاسل الزمنية لمؤشرات HLS (NDVI/EVI/حرارة).
class HlsTimeSeriesChart extends StatelessWidget {
  final List<HlsObservation> observations;
  final String layer;
  final String label;

  const HlsTimeSeriesChart({
    super.key,
    required this.observations,
    required this.layer,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final points = <_ChartPoint>[];
    for (final observation in observations) {
      final value = observation.metrics[layer] ?? observation.bands[layer];
      if (value != null && value.isFinite) {
        points.add(_ChartPoint(observation.date, value));
      }
    }
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('تغير المؤشر عبر المشاهد المتاحة',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
            const SizedBox(height: 14),
            if (points.length < 2)
              const SizedBox(
                height: 130,
                child: Center(child: Text('يلزم مشهدان صالحان على الأقل لرسم المنحنى.')),
              )
            else
              SizedBox(
                height: 170,
                width: double.infinity,
                child: CustomPaint(
                  painter: _HlsChartPainter(
                    points: points,
                    color: const Color(0xFF047857),
                    textDirection: Directionality.of(context),
                  ),
                ),
              ),
            if (points.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5, bottom: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('yyyy/MM').format(points.first.date),
                        style: const TextStyle(fontSize: 10)),
                    Text(DateFormat('yyyy/MM').format(points.last.date),
                        style: const TextStyle(fontSize: 10)),
                    Text('آخر قيمة ${points.last.value.toStringAsFixed(3)}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChartPoint {
  final DateTime date;
  final double value;
  const _ChartPoint(this.date, this.value);
}

class _HlsChartPainter extends CustomPainter {
  final List<_ChartPoint> points;
  final Color color;
  final TextDirection textDirection;

  const _HlsChartPainter({
    required this.points,
    required this.color,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 42.0;
    const right = 8.0;
    const top = 8.0;
    const bottom = 12.0;
    final chart = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    final values = points.map((point) => point.value).toList();
    var minValue = values.reduce(math.min);
    var maxValue = values.reduce(math.max);
    if ((maxValue - minValue).abs() < 0.000001) {
      minValue -= 0.1;
      maxValue += 0.1;
    }
    final padding = (maxValue - minValue) * 0.08;
    minValue -= padding;
    maxValue += padding;

    final gridPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    final labelStyle = TextStyle(color: Colors.grey.shade600, fontSize: 9);
    for (var i = 0; i <= 3; i++) {
      final y = chart.top + chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final value = maxValue - (maxValue - minValue) * i / 3;
      final text = TextPainter(
        text: TextSpan(text: value.toStringAsFixed(2), style: labelStyle),
        textDirection: textDirection,
      )..layout(maxWidth: left - 6);
      text.paint(canvas, Offset(0, y - text.height / 2));
    }

    final first = points.first.date.millisecondsSinceEpoch.toDouble();
    final last = points.last.date.millisecondsSinceEpoch.toDouble();
    final span = math.max(1.0, last - first);
    final offsets = <Offset>[];
    for (final point in points) {
      final x = chart.left +
          (point.date.millisecondsSinceEpoch.toDouble() - first) / span * chart.width;
      final y = chart.bottom -
          (point.value - minValue) / (maxValue - minValue) * chart.height;
      offsets.add(Offset(x, y));
    }

    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final point in offsets.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final fill = Path.from(path)
      ..lineTo(offsets.last.dx, chart.bottom)
      ..lineTo(offsets.first.dx, chart.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          colors: [color.withValues(alpha: .24), color.withValues(alpha: .01)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(chart),
    );
    final dotPaint = Paint()..color = color;
    for (final point in offsets) {
      canvas.drawCircle(point, 3, Paint()..color = Colors.white);
      canvas.drawCircle(point, 2.1, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HlsChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}
