import 'package:flutter/material.dart';
import '../../models/irrigation_design_models.dart';

class Irrigation3DPreviewScreen extends StatelessWidget {
  final IrrigationDesignProject project;
  const Irrigation3DPreviewScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('معاينة 3D مبسطة')),
        body: InteractiveViewer(
          minScale: .7,
          maxScale: 3,
          child: CustomPaint(
            size: const Size(double.infinity, double.infinity),
            painter: _Irrigation3DPainter(project),
          ),
        ),
      );
}

class _Irrigation3DPainter extends CustomPainter {
  final IrrigationDesignProject project;
  const _Irrigation3DPainter(this.project);

  @override
  void paint(Canvas canvas, Size size) {
    final points = project.siteBoundary.points;
    final origin = points.first;
    Offset projectPoint(GeoCoordinate point, double elevation) {
      final x = (point.longitude - origin.longitude) * 900000;
      final y = (point.latitude - origin.latitude) * -900000;
      return Offset(size.width / 2 + x - y * .45, size.height / 2 + y * .45 - elevation * 2);
    }
    final ground = Paint()..color = const Color(0xffdcefd2)..style = PaintingStyle.fill;
    final boundary = Path();
    for (var i = 0; i < points.length; i++) {
      final p = projectPoint(points[i], 0);
      if (i == 0) {
        boundary.moveTo(p.dx, p.dy);
      } else {
        boundary.lineTo(p.dx, p.dy);
      }
    }
    boundary.close();
    canvas.drawPath(boundary, ground);
    final outline = Paint()..color = Colors.green.shade800..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawPath(boundary, outline);
    final pipePaint = Paint()..color = Colors.blue..strokeWidth = 3;
    for (final route in project.pipeRoutes) {
      for (var i = 0; i < route.points.length - 1; i++) {
        canvas.drawLine(projectPoint(route.points[i], 0.2),
            projectPoint(route.points[i + 1], 0.2), pipePaint);
      }
    }
    for (final placement in project.placements) {
      final p = projectPoint(placement.coordinate, placement.kind == 'plant' ? 1 : .35);
      final isPlant = placement.kind == 'plant';
      final paint = Paint()..color = isPlant ? Colors.green.shade700 : Colors.orange.shade700;
      canvas.drawCircle(p, isPlant ? 10 : 6, paint);
      if (isPlant) canvas.drawLine(p, p + const Offset(0, 14), paint..strokeWidth = 3);
    }
    final text = TextPainter(textDirection: TextDirection.rtl, text: const TextSpan(text: 'عرض تقريبي — يحتاج معايرة ميدانية', style: TextStyle(color: Colors.black87, fontSize: 14)))..layout();
    text.paint(canvas, const Offset(16, 16));
  }

  @override
  bool shouldRepaint(covariant _Irrigation3DPainter oldDelegate) => oldDelegate.project != project;
}
