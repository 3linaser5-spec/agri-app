import 'package:material_ui/material_ui.dart';

import '../../models/landscape_design_models.dart';
import '../../services/landscape_hydraulic_design_service.dart';

/// لوحة رسم اللاندسكيب: كل نقطة بالمتر، والرسم باللمس.
class LandscapePlanCanvas extends StatelessWidget {
  final LandscapePlan plan;
  final List<PlanPoint> draftPoints;
  final String? selectedShapeId;
  final LandscapeHydraulicDesign? design;
  final bool showPipes;
  final bool drawing;
  final ValueChanged<PlanPoint>? onAddPoint;
  final ValueChanged<String>? onSelectShape;

  const LandscapePlanCanvas({
    super.key,
    required this.plan,
    this.draftPoints = const [],
    this.selectedShapeId,
    this.design,
    this.showPipes = true,
    this.drawing = false,
    this.onAddPoint,
    this.onSelectShape,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        const padding = 18.0;
        final scale = ((size.width - padding * 2) / plan.plotWidthM)
            .clamp(0.0, (size.height - padding * 2) / plan.plotHeightM);
        final origin = Offset(padding, padding);
        final transform = _CanvasTransform(
          scale: scale <= 0 ? 1 : scale,
          origin: origin,
          size: size,
        );

        void handleTap(Offset local) {
          final point = transform.toPlan(local);
          if (drawing && onAddPoint != null) {
            onAddPoint!(point);
            return;
          }
          if (onSelectShape == null) return;
          for (final shape in plan.shapes.reversed) {
            if (_contains(shape.points, point)) {
              onSelectShape!(shape.id);
              return;
            }
          }
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => handleTap(details.localPosition),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CustomPaint(
              size: size,
              painter: _PlanPainter(
                plan: plan,
                draftPoints: draftPoints,
                selectedShapeId: selectedShapeId,
                design: showPipes ? design : null,
                transform: transform,
              ),
            ),
          ),
        );
      },
    );
  }

  static bool _contains(List<PlanPoint> polygon, PlanPoint point) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      final intersects = ((a.yM > point.yM) != (b.yM > point.yM)) &&
          (point.xM <
              (b.xM - a.xM) * (point.yM - a.yM) / ((b.yM - a.yM) == 0 ? 1e-9 : (b.yM - a.yM)) + a.xM);
      if (intersects) inside = !inside;
    }
    return inside;
  }
}

class _CanvasTransform {
  final double scale;
  final Offset origin;
  final Size size;
  const _CanvasTransform({required this.scale, required this.origin, required this.size});

  Offset toPixel(PlanPoint point) => Offset(
        origin.dx + point.xM * scale,
        size.height - origin.dy - point.yM * scale,
      );

  PlanPoint toPlan(Offset pixel) => PlanPoint(
        (pixel.dx - origin.dx) / scale,
        (size.height - origin.dy - pixel.dy) / scale,
      );
}

class _PlanPainter extends CustomPainter {
  final LandscapePlan plan;
  final List<PlanPoint> draftPoints;
  final String? selectedShapeId;
  final LandscapeHydraulicDesign? design;
  final _CanvasTransform transform;

  const _PlanPainter({
    required this.plan,
    required this.draftPoints,
    required this.selectedShapeId,
    required this.design,
    required this.transform,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);
    _paintGrid(canvas);
    for (final shape in plan.shapes) {
      _paintShape(canvas, shape);
    }
    if (design != null) _paintPipes(canvas, design!);
    _paintSource(canvas);
    _paintDraft(canvas);
    _paintLegend(canvas, size);
  }

  void _paintBackground(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF3F7EC), Color(0xFFE4EEDB)],
        ).createShader(rect),
    );
  }

  void _paintGrid(Canvas canvas) {
    final grid = Paint()
      ..color = const Color(0x14000000)
      ..strokeWidth = 1;
    final bold = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1.4;
    for (var x = 0.0; x <= plan.plotWidthM; x += 1) {
      final a = transform.toPixel(PlanPoint(x, 0));
      final b = transform.toPixel(PlanPoint(x, plan.plotHeightM));
      canvas.drawLine(a, b, x % 5 == 0 ? bold : grid);
    }
    for (var y = 0.0; y <= plan.plotHeightM; y += 1) {
      final a = transform.toPixel(PlanPoint(0, y));
      final b = transform.toPixel(PlanPoint(plan.plotWidthM, y));
      canvas.drawLine(a, b, y % 5 == 0 ? bold : grid);
    }
    final border = Paint()
      ..color = const Color(0xFF9DB39A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawRect(
      Rect.fromPoints(
        transform.toPixel(PlanPoint(0, plan.plotHeightM)),
        transform.toPixel(PlanPoint(plan.plotWidthM, 0)),
      ),
      border,
    );
  }

  void _paintShape(Canvas canvas, LandscapeShape shape) {
    final type = shape.plantType;
    final base = Color(type?.colorValue ?? 0xFF9E9E9E);
    final path = _pathOf(shape.points);
    if (path == null) return;
    canvas.drawPath(path, Paint()..color = base.withValues(alpha: 0.38));
    canvas.drawPath(
      path,
      Paint()
        ..color = selectedShapeId == shape.id ? Colors.deepOrange : base
        ..style = PaintingStyle.stroke
        ..strokeWidth = selectedShapeId == shape.id ? 3.2 : 2,
    );

    // رمز النبات داخل المسطح.
    final center = transform.toPixel(shape.centroid);
    if (type != null && type.heightM > 0) {
      _paintTree(canvas, center, type);
    }

    final label = '${shape.nameAr}\n${shape.areaM2.toStringAsFixed(0)} م²';
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.black.withValues(alpha: 0.78),
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: 110);
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  void _paintTree(Canvas canvas, Offset center, LandscapePlantType type) {
    final canopyRadius = (type.canopyDiameterM * transform.scale / 2).clamp(5.0, 40.0);
    final trunk = Paint()
      ..color = const Color(0xFF795548)
      ..strokeWidth = 2.2;
    canvas.drawLine(
      center + Offset(0, canopyRadius * .7),
      center,
      trunk,
    );
    final shade = Paint()..color = const Color(0x22000000);
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, canopyRadius * .85),
        width: canopyRadius * 1.9,
        height: canopyRadius * .6,
      ),
      shade,
    );
    final canopy = Paint()..color = Color(type.colorValue).withValues(alpha: .85);
    canvas.drawCircle(center, canopyRadius, canopy);
    canvas.drawCircle(
      center + Offset(-canopyRadius * .35, -canopyRadius * .35),
      canopyRadius * .45,
      Paint()..color = Colors.white.withValues(alpha: .22),
    );
  }

  LandscapeShape? _shapeById(String id) {
    for (final shape in plan.shapes) {
      if (shape.id == id) return shape;
    }
    return null;
  }

  void _paintPipes(Canvas canvas, LandscapeHydraulicDesign result) {
    final mainPaint = Paint()
      ..color = const Color(0xFF1565C0)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      transform.toPixel(plan.waterSourcePoint),
      transform.toPixel(_farthestZoneCenter(result)),
      mainPaint,
    );
    final subPaint = Paint()
      ..color = const Color(0xFF42A5F5)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final zone in result.zones) {
      final shape = _shapeById(zone.shapeId);
      if (shape == null) continue;
      canvas.drawLine(
        transform.toPixel(plan.waterSourcePoint),
        transform.toPixel(shape.centroid),
        subPaint,
      );
      final valve = transform.toPixel(shape.centroid);
      canvas.drawCircle(valve, 5, Paint()..color = const Color(0xFF6A1B9A));
    }
  }

  PlanPoint _farthestZoneCenter(LandscapeHydraulicDesign result) {
    var farthest = plan.waterSourcePoint;
    var best = 0.0;
    for (final zone in result.zones) {
      final shape = _shapeById(zone.shapeId);
      if (shape == null) continue;
      final distance = plan.waterSourcePoint.distanceTo(shape.centroid);
      if (distance > best) {
        best = distance;
        farthest = shape.centroid;
      }
    }
    return farthest;
  }

  void _paintSource(Canvas canvas) {
    final point = transform.toPixel(plan.waterSourcePoint);
    canvas.drawCircle(point, 13, Paint()..color = const Color(0xFF0D47A1));
    canvas.drawCircle(point, 13, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.5);
    final icon = TextPainter(
      text: const TextSpan(text: '💧', style: TextStyle(fontSize: 12)),
      textDirection: TextDirection.ltr,
    )..layout();
    icon.paint(canvas, point - Offset(icon.width / 2, icon.height / 2));
  }

  void _paintDraft(Canvas canvas) {
    if (draftPoints.isEmpty) return;
    final paint = Paint()
      ..color = const Color(0xFFEF6C00)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < draftPoints.length - 1; i++) {
      canvas.drawLine(transform.toPixel(draftPoints[i]), transform.toPixel(draftPoints[i + 1]), paint);
    }
    for (final point in draftPoints) {
      canvas.drawCircle(transform.toPixel(point), 5, Paint()..color = const Color(0xFFEF6C00));
    }
  }

  void _paintLegend(Canvas canvas, Size size) {
    final text = TextPainter(
      text: TextSpan(
        text: '${plan.plotWidthM.toStringAsFixed(0)} × ${plan.plotHeightM.toStringAsFixed(0)} م — '
            'كل مربع صغير = 1 م',
        style: const TextStyle(fontSize: 11, color: Color(0xFF4E5D4A)),
      ),
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: size.width - 24);
    text.paint(canvas, Offset(size.width - text.width - 12, size.height - text.height - 8));
  }

  Path? _pathOf(List<PlanPoint> points) {
    if (points.length < 3) return null;
    final path = Path()..moveTo(transform.toPixel(points.first).dx, transform.toPixel(points.first).dy);
    for (var i = 1; i < points.length; i++) {
      final pixel = transform.toPixel(points[i]);
      path.lineTo(pixel.dx, pixel.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _PlanPainter oldDelegate) =>
      oldDelegate.plan != plan ||
      oldDelegate.draftPoints.length != draftPoints.length ||
      oldDelegate.selectedShapeId != selectedShapeId ||
      oldDelegate.design != design;
}
