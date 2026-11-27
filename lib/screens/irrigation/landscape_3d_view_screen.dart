import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../models/landscape_design_models.dart';
import '../../services/landscape_hydraulic_design_service.dart';

/// معاينة 3D تفاعلية للتصميم: اسحب بإصبع للدوران، بإصبعين للتقريب.
///
/// الرسم إسقاط منظوري حقيقي للارتفاعات وأحجام النباتات داخل التطبيق، بدون
/// ملفات خارجية. المسافات والأحجام بالمتر كما رُسمت على اللوحة.
class Landscape3DViewScreen extends StatefulWidget {
  final LandscapePlan plan;
  final LandscapeHydraulicDesign? design;

  const Landscape3DViewScreen({super.key, required this.plan, this.design});

  @override
  State<Landscape3DViewScreen> createState() => _Landscape3DViewScreenState();
}

class _Landscape3DViewScreenState extends State<Landscape3DViewScreen> {
  double azimuth = -0.55;
  double tilt = 0.95;
  double zoom = 1;
  bool showPipes = true;

  void _reset() => setState(() {
        azimuth = -0.55;
        tilt = 0.95;
        zoom = 1;
        showPipes = true;
      });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('معاينة ثلاثية الأبعاد تفاعلية'),
          actions: [
            IconButton(
              tooltip: showPipes ? 'إخفاء المواسير' : 'إظهار المواسير',
              onPressed: () => setState(() => showPipes = !showPipes),
              icon: Icon(showPipes ? Icons.water : Icons.water_outlined),
            ),
            IconButton(
              tooltip: 'إعادة الضبط',
              onPressed: _reset,
              icon: const Icon(Icons.restart_alt),
            ),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onScaleStart: (_) {},
                onScaleUpdate: (details) {
                  setState(() {
                    if (details.pointerCount >= 2) {
                      zoom = (zoom * (1 + (details.scale - 1) * 0.6)).clamp(0.5, 3.5);
                    } else {
                      azimuth += details.focalPointDelta.dx * 0.01;
                      tilt = (tilt - details.focalPointDelta.dy * 0.006).clamp(0.18, 1.5);
                    }
                  });
                },
                child: CustomPaint(
                  painter: _Landscape3DPainter(
                    plan: widget.plan,
                    design: widget.design,
                    azimuth: azimuth,
                    tilt: tilt,
                    zoom: zoom,
                    showPipes: showPipes,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Card(
                color: Colors.white.withValues(alpha: .92),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      const Icon(Icons.swipe, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'اسحب للدوران — استخدم إصبعين للتقريب',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      Text(
                        '${(tilt * 180 / math.pi).round()}°',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SceneProjector {
  final Size size;
  final LandscapePlan plan;
  final double azimuth;
  final double tilt;
  final double zoom;

  _SceneProjector({
    required this.size,
    required this.plan,
    required this.azimuth,
    required this.tilt,
    required this.zoom,
  });

  double get _scale {
    final width = math.max(plan.plotWidthM, 1);
    final height = math.max(plan.plotHeightM, 1);
    return math.min(size.width / (width * 1.35), size.height / (height * 1.35)) * zoom;
  }

  PlanPoint get _center =>
      PlanPoint(plan.plotWidthM / 2, plan.plotHeightM / 2);

  ({double x, double y, double depth}) _view(PlanPoint point) {
    final dx = point.xM - _center.xM;
    final dy = point.yM - _center.yM;
    final sinA = math.sin(azimuth);
    final cosA = math.cos(azimuth);
    final rx = dx * cosA - dy * sinA;
    final ry = dx * sinA + dy * cosA;
    return (x: rx, y: ry, depth: ry * math.cos(tilt));
  }

  double depthOf(PlanPoint point) => _view(point).depth;

  double pixelsPerMeter(PlanPoint point) {
    final view = _view(point);
    final depth = view.depth + 26;
    return _scale * (26 / math.max(depth, 8));
  }

  Offset project(PlanPoint point, [double zM = 0]) {
    final view = _view(point);
    final depth = view.depth + 26;
    final k = 26 / math.max(depth, 8);
    final scale = _scale;
    return Offset(
      size.width / 2 + view.x * k * scale,
      size.height * 0.62 + (view.y * math.sin(tilt) - zM * math.cos(tilt)) * k * scale,
    );
  }
}

class _Landscape3DPainter extends CustomPainter {
  final LandscapePlan plan;
  final LandscapeHydraulicDesign? design;
  final double azimuth;
  final double tilt;
  final double zoom;
  final bool showPipes;

  const _Landscape3DPainter({
    required this.plan,
    required this.design,
    required this.azimuth,
    required this.tilt,
    required this.zoom,
    required this.showPipes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final projector = _SceneProjector(
      size: size,
      plan: plan,
      azimuth: azimuth,
      tilt: tilt,
      zoom: zoom,
    );
    _paintSky(canvas, size);
    _paintGround(canvas, projector);

    final shapes = [...plan.shapes]
      ..sort((a, b) => projector.depthOf(b.centroid).compareTo(projector.depthOf(a.centroid)));

    for (final shape in shapes) {
      _paintShape(canvas, projector, shape);
    }
    if (showPipes && design != null) {
      _paintPipes(canvas, projector, design!);
    }
    for (final shape in shapes.reversed) {
      _paintPlant(canvas, projector, shape);
    }
    _paintSource(canvas, projector);
    _paintCaption(canvas, size);
  }

  void _paintSky(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB3E5FC), Color(0xFFF1F8E9)],
        ).createShader(rect),
    );
    canvas.drawCircle(
      Offset(size.width * .82, size.height * .12),
      34,
      Paint()..color = const Color(0xFFFFF59D).withValues(alpha: .7),
    );
  }

  void _paintGround(Canvas canvas, _SceneProjector projector) {
    final corners = [
      const PlanPoint(0, 0),
      PlanPoint(plan.plotWidthM, 0),
      PlanPoint(plan.plotWidthM, plan.plotHeightM),
      PlanPoint(0, plan.plotHeightM),
    ];
    final path = Path();
    for (var i = 0; i < corners.length; i++) {
      final p = projector.project(corners[i]);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFD7E8C8));
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF9EBD8A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    final grid = Paint()
      ..color = const Color(0x18000000)
      ..strokeWidth = 1;
    for (var x = 2.0; x < plan.plotWidthM; x += 2) {
      canvas.drawLine(
        projector.project(PlanPoint(x, 0)),
        projector.project(PlanPoint(x, plan.plotHeightM)),
        grid,
      );
    }
    for (var y = 2.0; y < plan.plotHeightM; y += 2) {
      canvas.drawLine(
        projector.project(PlanPoint(0, y)),
        projector.project(PlanPoint(plan.plotWidthM, y)),
        grid,
      );
    }
  }

  void _paintShape(Canvas canvas, _SceneProjector projector, LandscapeShape shape) {
    final type = shape.plantType;
    final color = Color(type?.colorValue ?? 0xFF9E9E9E);
    final path = Path();
    for (var i = 0; i < shape.points.length; i++) {
      final p = projector.project(shape.points[i], 0.05);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: .45));
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: .9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _paintPipes(Canvas canvas, _SceneProjector projector, LandscapeHydraulicDesign result) {
    final main = Paint()
      ..color = const Color(0xFF1565C0)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final sub = Paint()
      ..color = const Color(0xFF42A5F5)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    PlanPoint farthest = plan.waterSourcePoint;
    var best = 0.0;
    for (final zone in result.zones) {
      for (final shape in plan.shapes) {
        if (shape.id != zone.shapeId) continue;
        final distance = plan.waterSourcePoint.distanceTo(shape.centroid);
        if (distance > best) {
          best = distance;
          farthest = shape.centroid;
        }
      }
    }
    canvas.drawLine(
      projector.project(plan.waterSourcePoint, 0.12),
      projector.project(farthest, 0.12),
      main,
    );
    for (final zone in result.zones) {
      for (final shape in plan.shapes) {
        if (shape.id != zone.shapeId) continue;
        canvas.drawLine(
          projector.project(plan.waterSourcePoint, 0.1),
          projector.project(shape.centroid, 0.1),
          sub,
        );
        final valve = projector.project(shape.centroid, 0.1);
        canvas.drawCircle(valve, 4.5, Paint()..color = const Color(0xFF6A1B9A));
      }
    }
  }

  void _paintPlant(Canvas canvas, _SceneProjector projector, LandscapeShape shape) {
    final type = shape.plantType;
    if (type == null) return;
    final base = projector.project(shape.centroid);
    final ppm = projector.pixelsPerMeter(shape.centroid);

    if (type.kind == LandscapePlantKind.lawn) {
      // غطاء أخضر منخفض يعطي إحساس المسطح.
      canvas.drawOval(
        Rect.fromCenter(
          center: base,
          width: 18 * ppm.clamp(0.3, 2),
          height: 7 * ppm.clamp(0.3, 2),
        ),
        Paint()..color = Color(type.colorValue).withValues(alpha: .35),
      );
      return;
    }
    if (type.heightM <= 0) return;

    final canopyWidthPx = (type.canopyDiameterM * ppm).clamp(6.0, 90.0);
    final trunkHeightPx = (type.heightM * 0.55 * ppm).clamp(4.0, 110.0);

    canvas.drawOval(
      Rect.fromCenter(
        center: base,
        width: canopyWidthPx * 1.15,
        height: canopyWidthPx * .38,
      ),
      Paint()..color = const Color(0x33000000),
    );

    final trunkTop = base - Offset(0, trunkHeightPx);
    canvas.drawLine(
      base,
      trunkTop,
      Paint()
        ..color = const Color(0xFF6D4C41)
        ..strokeWidth = (canopyWidthPx * .09).clamp(1.5, 7.0),
    );

    final canopyColor = Color(type.colorValue);
    canvas.drawCircle(
      trunkTop,
      canopyWidthPx * .5,
      Paint()..color = canopyColor,
    );
    canvas.drawCircle(
      trunkTop + Offset(-canopyWidthPx * .28, -canopyWidthPx * .18),
      canopyWidthPx * .34,
      Paint()..color = canopyColor.withValues(alpha: .92),
    );
    canvas.drawCircle(
      trunkTop + Offset(canopyWidthPx * .3, -canopyWidthPx * .05),
      canopyWidthPx * .3,
      Paint()..color = canopyColor.withValues(alpha: .85),
    );
    canvas.drawCircle(
      trunkTop + Offset(-canopyWidthPx * .18, -canopyWidthPx * .32),
      canopyWidthPx * .2,
      Paint()..color = Colors.white.withValues(alpha: .18),
    );
  }

  void _paintSource(Canvas canvas, _SceneProjector projector) {
    final base = projector.project(plan.waterSourcePoint);
    final ppm = projector.pixelsPerMeter(plan.waterSourcePoint).clamp(0.2, 3.0);
    canvas.drawOval(
      Rect.fromCenter(center: base, width: 10 * ppm, height: 4 * ppm),
      Paint()..color = const Color(0x33000000),
    );
    final body = Rect.fromLTWH(base.dx - 7, base.dy - 14, 14, 14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(3)),
      Paint()..color = const Color(0xFF0D47A1),
    );
    canvas.drawRect(
      Rect.fromLTWH(base.dx - 2, base.dy - 20, 4, 7),
      Paint()..color = const Color(0xFF0D47A1),
    );
  }

  void _paintCaption(Canvas canvas, Size size) {
    final text = TextPainter(
      text: TextSpan(
        text: 'البلاطة ${plan.plotWidthM.toStringAsFixed(0)} × ${plan.plotHeightM.toStringAsFixed(0)} م — '
            '${plan.shapes.length} مسطح',
        style: const TextStyle(fontSize: 11, color: Color(0xFF37474F)),
      ),
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: size.width - 24);
    text.paint(canvas, const Offset(12, 12));
  }

  @override
  bool shouldRepaint(covariant _Landscape3DPainter oldDelegate) =>
      oldDelegate.azimuth != azimuth ||
      oldDelegate.tilt != tilt ||
      oldDelegate.zoom != zoom ||
      oldDelegate.showPipes != showPipes ||
      oldDelegate.plan != plan ||
      oldDelegate.design != design;
}
