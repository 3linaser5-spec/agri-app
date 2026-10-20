import 'dart:math' as math;

/// مولّد مجسمات ري تخطيطية بصيغة DXF R12.
///
/// يستخدم 3DFACE لأسطح الأنابيب والمكونات وPOINT لعلامات النقاطات/الرشاشات.
/// كل الإحداثيات بالمتر. منسوب الأرض ثابت داخل كل مخطط، ولا يمثّل تضاريس حقيقية.
class IrrigationDxf3d {
  IrrigationDxf3d._();

  static const int _maxMarkers = 5000;
  static const int _pipeSides = 6;

  static String drip({
    required double widthM,
    required double lengthM,
    required double rowSpacingM,
    required double plantSpacingM,
    required int emittersPerPlant,
    required double emitterLph,
    required int sectors,
    required double mainLengthM,
    required double mainPipeMm,
    required double lateralPipeMm,
    double fieldZ = 0,
    double pumpZ = 0,
    double sectorFlowM3h = 0,
    double pumpKw = 0,
  }) {
    _positive('widthM', widthM);
    _positive('lengthM', lengthM);
    _positive('rowSpacingM', rowSpacingM);
    _positive('plantSpacingM', plantSpacingM);
    _positive('emitterLph', emitterLph);
    _positive('mainLengthM', mainLengthM);
    _positive('mainPipeMm', mainPipeMm);
    _positive('lateralPipeMm', lateralPipeMm);
    _finite('fieldZ', fieldZ);
    _finite('pumpZ', pumpZ);
    if (emittersPerPlant < 1 || sectors < 1) {
      throw ArgumentError('عدد النقاطات والقطاعات يجب أن يكون موجباً.');
    }

    final b = _Dxf3dBuilder();
    _drawField(b, widthM, lengthM, fieldZ);
    _drawPumpStation(b, mainLengthM, fieldZ, pumpZ, pumpKw);

    final pipeZ = fieldZ + 0.25;
    final diameter = mainPipeMm / 1000;
    _pipePath(
      b,
      'MAIN',
      5,
      [
        _V3(-mainLengthM, 0, pumpZ + 0.45),
        _V3(-mainLengthM / 2, 0, pumpZ + 0.45),
        _V3(0, 0, pipeZ),
      ],
      diameter,
    );
    b.box('FILTER', 4, _V3(-mainLengthM / 2, 0, pumpZ + 0.45),
        math.min(1.2, mainLengthM / 4).toDouble(), 1.1, 1.3);
    b.tube('SUBMAIN', 4, _V3(0, 0, pipeZ), _V3(widthM, 0, pipeZ),
        _diameter(mainPipeMm));

    final rows = _count(widthM, rowSpacingM, roundUp: false);
    final plants = _count(lengthM, plantSpacingM, roundUp: false);
    for (var row = 0; row < rows; row++) {
      final x = rowSpacingM / 2 + row * rowSpacingM;
      b.tube('CONNECTOR', 6, _V3(x, 0, pipeZ), _V3(x, 0.35, pipeZ),
          _diameter(lateralPipeMm * 1.5));
      b.tube('LATERAL', 3, _V3(x, 0.35, pipeZ), _V3(x, lengthM, pipeZ),
          _diameter(lateralPipeMm));
    }

    final markerCount = rows * plants * emittersPerPlant;
    var drawn = 0;
    if (markerCount <= _maxMarkers) {
      for (var row = 0; row < rows && drawn < _maxMarkers; row++) {
        final x = rowSpacingM / 2 + row * rowSpacingM;
        for (var plant = 0; plant < plants && drawn < _maxMarkers; plant++) {
          final y = plantSpacingM / 2 + plant * plantSpacingM;
          for (var emitter = 0;
              emitter < emittersPerPlant && drawn < _maxMarkers;
              emitter++) {
            final offset = (emitter - (emittersPerPlant - 1) / 2) * 0.06;
            b.point('EMITTER', 1,
                _V3(x + offset, y, pipeZ + lateralPipeMm / 1000 + 0.03));
            drawn++;
          }
        }
      }
    }

    b.text('NOTES', 7, _V3(0, lengthM + 2, fieldZ), '3D DRIP NETWORK - SCHEMATIC');
    b.text('NOTES', 7, _V3(0, lengthM + 3.5, fieldZ),
        'Ground Z=${_Dxf3dBuilder.fmt(fieldZ)} m; flat field elevation');
    b.text('NOTES', 7, _V3(0, lengthM + 5, fieldZ),
        'Pump Z=${_Dxf3dBuilder.fmt(pumpZ)} m; verify actual site levels');
    b.text('NOTES', 7, _V3(0, lengthM + 6.5, fieldZ),
        'Sectors: $sectors; emitters/plant: $emittersPerPlant; emitter flow: ${_Dxf3dBuilder.fmt(emitterLph)} L/h');
    b.text('NOTES', 7, _V3(0, lengthM + 8, fieldZ),
        'Sector flow: ${_Dxf3dBuilder.fmt(sectorFlowM3h)} m3/h; markers drawn: $drawn/$markerCount');
    b.text('NOTES', 7, _V3(0, lengthM + 9.5, fieldZ),
        'Pipe sizes are schematic; check hydraulic design before construction');
    return b.build();
  }

  static String sprinkler({
    required double widthM,
    required double lengthM,
    required double spacingAlongM,
    required double spacingAcrossM,
    required double sprinklerFlowM3h,
    required int sectors,
    required double mainLengthM,
    required double mainPipeMm,
    double lateralPipeMm = 50,
    double fieldZ = 0,
    double pumpZ = 0,
    double sectorFlowM3h = 0,
    double pumpKw = 0,
  }) {
    _positive('widthM', widthM);
    _positive('lengthM', lengthM);
    _positive('spacingAlongM', spacingAlongM);
    _positive('spacingAcrossM', spacingAcrossM);
    _positive('sprinklerFlowM3h', sprinklerFlowM3h);
    _positive('mainLengthM', mainLengthM);
    _positive('mainPipeMm', mainPipeMm);
    _positive('lateralPipeMm', lateralPipeMm);
    if (sectors < 1) throw ArgumentError.value(sectors, 'sectors');
    _finite('fieldZ', fieldZ);
    _finite('pumpZ', pumpZ);

    final b = _Dxf3dBuilder();
    _drawField(b, widthM, lengthM, fieldZ);
    _drawPumpStation(b, mainLengthM, fieldZ, pumpZ, pumpKw);
    final pipeZ = fieldZ + 0.3;
    b.tube('MAIN', 5, _V3(-mainLengthM, 0, pumpZ + 0.45),
        _V3(0, 0, pipeZ), _diameter(mainPipeMm));
    b.box('FILTER', 4, _V3(-mainLengthM / 2, 0, pumpZ + 0.45),
        math.min(1.2, mainLengthM / 4).toDouble(), 1.1, 1.3);
    b.tube('SUBMAIN', 4, _V3(0, 0, pipeZ), _V3(widthM, 0, pipeZ),
        _diameter(mainPipeMm));

    final columns = _count(widthM, spacingAcrossM, roundUp: true);
    final rows = _count(lengthM, spacingAlongM, roundUp: true);
    final markerCount = columns * rows;
    for (var col = 0; col < columns; col++) {
      final x = spacingAcrossM / 2 + col * spacingAcrossM;
      b.tube('LATERAL', 3, _V3(x, 0, pipeZ), _V3(x, lengthM, pipeZ),
          _diameter(lateralPipeMm));
      if (markerCount <= _maxMarkers) {
        for (var row = 0; row < rows; row++) {
          final y = spacingAlongM / 2 + row * spacingAlongM;
          b.tube('RISER', 6, _V3(x, y, pipeZ), _V3(x, y, pipeZ + 1), 0.025);
          b.point('SPRINKLER', 1, _V3(x, y, pipeZ + 1.05));
        }
      }
    }

    b.text('NOTES', 7, _V3(0, lengthM + 2, fieldZ), '3D SPRINKLER NETWORK - SCHEMATIC');
    b.text('NOTES', 7, _V3(0, lengthM + 3.5, fieldZ),
        'Ground Z=${_Dxf3dBuilder.fmt(fieldZ)} m; flat field elevation');
    b.text('NOTES', 7, _V3(0, lengthM + 5, fieldZ),
        'Pump Z=${_Dxf3dBuilder.fmt(pumpZ)} m; sectors: $sectors');
    b.text('NOTES', 7, _V3(0, lengthM + 6.5, fieldZ),
        'Sector flow: ${_Dxf3dBuilder.fmt(sectorFlowM3h)} m3/h; sprinkler flow: ${_Dxf3dBuilder.fmt(sprinklerFlowM3h)} m3/h');
    b.text('NOTES', 7, _V3(0, lengthM + 8, fieldZ),
        markerCount <= _maxMarkers
            ? 'Sprinkler markers: $markerCount; riser height: 1 m'
            : 'Sprinkler markers omitted: drawing limit exceeded');
    b.text('NOTES', 7, _V3(0, lengthM + 9.5, fieldZ),
        'Pipe sizes and riser heights are schematic; verify before construction');
    return b.build();
  }

  static String surface({
    required double widthM,
    required double lengthM,
    required double furrowSpacingM,
    required double streamLps,
    required double mainLengthM,
    double fieldZ = 0,
    double pumpZ = 0,
  }) {
    _positive('widthM', widthM);
    _positive('lengthM', lengthM);
    _positive('furrowSpacingM', furrowSpacingM);
    _positive('streamLps', streamLps);
    _positive('mainLengthM', mainLengthM);
    _finite('fieldZ', fieldZ);
    _finite('pumpZ', pumpZ);

    final b = _Dxf3dBuilder();
    _drawField(b, widthM, lengthM, fieldZ);
    _drawPumpStation(b, mainLengthM, fieldZ, pumpZ, 0);
    final channelWidth = math.min(0.35, furrowSpacingM * 0.2).toDouble();
    final channelDepth = math.min(0.25, channelWidth * 0.7).toDouble();
    final channelZ = fieldZ + 0.02;
    b.tube('SUPPLY', 5, _V3(-mainLengthM, 0, pumpZ + 0.3),
        _V3(0, 0, channelZ + channelDepth),
        math.max(0.1, channelWidth).toDouble());
    _channelX(b, 0, widthM, channelWidth, channelZ, channelDepth,
        'HEAD_CHANNEL', 4);

    final furrows = _count(widthM, furrowSpacingM, roundUp: false);
    for (var i = 0; i < furrows; i++) {
      final x = furrowSpacingM / 2 + i * furrowSpacingM;
      _channelY(b, x, 0, channelWidth, lengthM, channelZ,
          channelDepth, 'FURROW', 3);
      b.line('INLET', 6, _V3(0, 0, channelZ),
          _V3(x, 0, channelZ + channelDepth));
    }
    b.text('NOTES', 7, _V3(0, lengthM + 2, fieldZ), '3D SURFACE IRRIGATION - SCHEMATIC');
    b.text('NOTES', 7, _V3(0, lengthM + 3.5, fieldZ),
        'Open furrows: $furrows; stream: ${_Dxf3dBuilder.fmt(streamLps)} L/s');
    b.text('NOTES', 7, _V3(0, lengthM + 5, fieldZ),
        'Ground Z=${_Dxf3dBuilder.fmt(fieldZ)} m; pump Z=${_Dxf3dBuilder.fmt(pumpZ)} m');
    b.text('NOTES', 7, _V3(0, lengthM + 6.5, fieldZ),
        'Channel dimensions are schematic; survey and verify before construction');
    return b.build();
  }

  static String pivot({
    required double radiusM,
    required double mainLengthM,
    required double mainPipeMm,
    required double flowM3h,
    required double hoursPerRotation,
    double fieldZ = 0,
    double pumpZ = 0,
    double nozzleSpacingM = 20,
    double pumpKw = 0,
  }) {
    _positive('radiusM', radiusM);
    _positive('mainLengthM', mainLengthM);
    _positive('mainPipeMm', mainPipeMm);
    _positive('flowM3h', flowM3h);
    _positive('hoursPerRotation', hoursPerRotation);
    _positive('nozzleSpacingM', nozzleSpacingM);
    _finite('fieldZ', fieldZ);
    _finite('pumpZ', pumpZ);

    final b = _Dxf3dBuilder();
    b.circle('FIELD', 7, _V3(0, 0, fieldZ), radiusM);
    _drawPumpStation(b, mainLengthM, fieldZ, pumpZ, pumpKw);
    b.box('FILTER', 4, _V3(-mainLengthM / 2, 0, pumpZ + 0.45),
        math.min(1.2, mainLengthM / 4).toDouble(), 1.1, 1.3);
    b.tube('MAIN', 5, _V3(-mainLengthM, 0, pumpZ + 0.45),
        _V3(0, 0, fieldZ + 2), _diameter(mainPipeMm));
    b.box('PIVOT_BASE', 4, _V3(0, 0, fieldZ + 1), 2, 2, 2);

    final armZ = fieldZ + 2;
    b.tube('SPAN', 5, _V3(0, 0, armZ), _V3(radiusM, 0, armZ),
        _diameter(mainPipeMm));
    final towers = math.max(1, math.min(_maxMarkers, (radiusM / 40).floor())).toInt();
    for (var i = 1; i <= towers; i++) {
      final x = radiusM * i / (towers + 1);
      b.tube('TOWER', 6, _V3(x, 0, fieldZ), _V3(x, 0, armZ), 0.12);
      b.tube('WHEEL', 1, _V3(x, -0.8, fieldZ + 0.35),
          _V3(x, 0.8, fieldZ + 0.35), 0.45);
    }
    final nozzleCount = _count(radiusM, nozzleSpacingM, roundUp: false);
    for (var i = 1; i <= nozzleCount && i <= _maxMarkers; i++) {
      final x = math.min(radiusM, i * nozzleSpacingM).toDouble();
      b.tube('DROP', 3, _V3(x, 0, armZ), _V3(x, 0, armZ - 1), 0.025);
      b.point('NOZZLE', 1, _V3(x, 0, armZ - 1.05));
    }
    b.text('NOTES', 7, _V3(-radiusM, radiusM + 3, fieldZ),
        '3D CENTER PIVOT - SCHEMATIC');
    b.text('NOTES', 7, _V3(-radiusM, radiusM + 4.5, fieldZ),
        'Radius: ${_Dxf3dBuilder.fmt(radiusM)} m; flow: ${_Dxf3dBuilder.fmt(flowM3h)} m3/h');
    b.text('NOTES', 7, _V3(-radiusM, radiusM + 6, fieldZ),
        'Nozzle spacing assumed ${_Dxf3dBuilder.fmt(nozzleSpacingM)} m; add actual nozzle schedule for construction');
    b.text('NOTES', 7, _V3(-radiusM, radiusM + 7.5, fieldZ),
        'Ground Z=${_Dxf3dBuilder.fmt(fieldZ)} m; pump Z=${_Dxf3dBuilder.fmt(pumpZ)} m');
    b.text('NOTES', 7, _V3(-radiusM, radiusM + 9, fieldZ),
        'Rotation: ${_Dxf3dBuilder.fmt(hoursPerRotation)} h; terrain is not modeled');
    return b.build();
  }

  static void _drawField(_Dxf3dBuilder b, double width, double length, double z) {
    final points = [
      _V3(0, 0, z),
      _V3(width, 0, z),
      _V3(width, length, z),
      _V3(0, length, z),
    ];
    for (var i = 0; i < points.length; i++) {
      b.line('FIELD', 7, points[i], points[(i + 1) % points.length]);
    }
  }

  static void _drawPumpStation(
    _Dxf3dBuilder b,
    double distance,
    double fieldZ,
    double pumpZ,
    double pumpKw,
  ) {
    b.box('PUMP', 1, _V3(-distance - 1.1, 0, pumpZ + 0.7), 2.2, 1.5, 1.4);
    b.box('MOTOR', 2, _V3(-distance - 1.2, 0, pumpZ + 1.55), 1.1, 1.1, 0.6);
    b.text('NOTES', 7, _V3(-distance - 3, 1.5, pumpZ + 2.2),
        pumpKw > 0 ? 'PUMP ${_Dxf3dBuilder.fmt(pumpKw)} kW' : 'WATER SOURCE / PUMP');
    b.text('NOTES', 7, _V3(-distance - 3, 1.5, pumpZ + 3.2),
        'Schematic equipment geometry');
    // Vertical transition between pump and field levels is shown by the supply pipe.
    b.line('LEVEL_REFERENCE', 8, _V3(-distance - 2.5, -1, pumpZ),
        _V3(-distance - 2.5, -1, fieldZ));
  }

  static void _channelY(
    _Dxf3dBuilder b,
    double xStart,
    double yStart,
    double width,
    double length,
    double z,
    double depth,
    String layer,
    int color,
  ) {
    final x0 = xStart - width / 2;
    final x1 = xStart + width / 2;
    final y0 = yStart;
    final y1 = yStart + length;
    final bottomZ = z - depth;
    b.face(layer, color, _V3(x0, y0, bottomZ), _V3(x1, y0, bottomZ),
        _V3(x1, y1, bottomZ), _V3(x0, y1, bottomZ));
    b.face(layer, color, _V3(x0, y0, bottomZ), _V3(x0, y0, z),
        _V3(x0, y1, z), _V3(x0, y1, bottomZ));
    b.face(layer, color, _V3(x1, y0, bottomZ), _V3(x1, y0, z),
        _V3(x1, y1, z), _V3(x1, y1, bottomZ));
    b.line(layer, color, _V3(x0, y0, z), _V3(x1, y0, z));
    b.line(layer, color, _V3(x0, y1, z), _V3(x1, y1, z));
  }

  static void _channelX(
    _Dxf3dBuilder b,
    double xStart,
    double xEnd,
    double width,
    double z,
    double depth,
    String layer,
    int color,
  ) {
    final y0 = -width / 2;
    final y1 = width / 2;
    final bottomZ = z - depth;
    b.face(layer, color, _V3(xStart, y0, bottomZ), _V3(xEnd, y0, bottomZ),
        _V3(xEnd, y1, bottomZ), _V3(xStart, y1, bottomZ));
    b.face(layer, color, _V3(xStart, y0, bottomZ), _V3(xStart, y0, z),
        _V3(xEnd, y0, z), _V3(xEnd, y0, bottomZ));
    b.face(layer, color, _V3(xStart, y1, bottomZ), _V3(xStart, y1, z),
        _V3(xEnd, y1, z), _V3(xEnd, y1, bottomZ));
    b.line(layer, color, _V3(xStart, y0, z), _V3(xStart, y1, z));
    b.line(layer, color, _V3(xEnd, y0, z), _V3(xEnd, y1, z));
  }

  static void _pipePath(
    _Dxf3dBuilder b,
    String layer,
    int color,
    List<_V3> points,
    double diameter,
  ) {
    for (var i = 0; i < points.length - 1; i++) {
      b.tube(layer, color, points[i], points[i + 1], diameter);
    }
  }

  static int _count(double span, double spacing, {required bool roundUp}) {
    final ratio = span / spacing;
    if (!ratio.isFinite || ratio >= _maxMarkers) return _maxMarkers;
    final count = roundUp ? ratio.ceil() : ratio.floor();
    return count < 1 ? 1 : count;
  }

  static double _diameter(double mm) => math.max(mm / 1000, 0.005).toDouble();

  static void _finite(String name, double value) {
    if (!value.isFinite) throw ArgumentError.value(value, name, 'يجب أن تكون قيمة محدودة.');
  }

  static void _positive(String name, double value) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(value, name, 'يجب أن تكون القيمة موجبة ومحدودة.');
    }
  }
}

class _Dxf3dBuilder {
  final StringBuffer _entities = StringBuffer();
  final Map<String, int> _layers = <String, int>{};

  static String fmt(double value) {
    if (!value.isFinite) return '0';
    var result = value.toStringAsFixed(4);
    if (result.contains('.')) {
      result = result.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return result == '-0' ? '0' : result;
  }

  void _pair(StringBuffer out, int code, String value) {
    out.writeln(code);
    out.writeln(value);
  }

  void _register(String layer, int color) {
    _layers.putIfAbsent(layer, () => color);
  }

  void line(String layer, int color, _V3 a, _V3 b) {
    if ((b - a).length < 1e-9) return;
    _register(layer, color);
    _pair(_entities, 0, 'LINE');
    _pair(_entities, 8, layer);
    _pointGroups(_entities, 10, a);
    _pointGroups(_entities, 11, b);
  }

  void point(String layer, int color, _V3 p) {
    _register(layer, color);
    _pair(_entities, 0, 'POINT');
    _pair(_entities, 8, layer);
    _pointGroups(_entities, 10, p);
  }

  void circle(String layer, int color, _V3 center, double radius) {
    _register(layer, color);
    _pair(_entities, 0, 'CIRCLE');
    _pair(_entities, 8, layer);
    _pointGroups(_entities, 10, center);
    _pair(_entities, 40, fmt(radius));
  }

  void face(String layer, int color, _V3 a, _V3 b, _V3 c, _V3 d) {
    _register(layer, color);
    _pair(_entities, 0, '3DFACE');
    _pair(_entities, 8, layer);
    _pointGroups(_entities, 10, a);
    _pointGroups(_entities, 11, b);
    _pointGroups(_entities, 12, c);
    _pointGroups(_entities, 13, d);
    _pair(_entities, 70, '0');
  }

  void box(String layer, int color, _V3 center, double sx, double sy, double sz) {
    _register(layer, color);
    final x0 = center.x - sx / 2;
    final x1 = center.x + sx / 2;
    final y0 = center.y - sy / 2;
    final y1 = center.y + sy / 2;
    final z0 = center.z - sz / 2;
    final z1 = center.z + sz / 2;
    final p000 = _V3(x0, y0, z0);
    final p100 = _V3(x1, y0, z0);
    final p110 = _V3(x1, y1, z0);
    final p010 = _V3(x0, y1, z0);
    final p001 = _V3(x0, y0, z1);
    final p101 = _V3(x1, y0, z1);
    final p111 = _V3(x1, y1, z1);
    final p011 = _V3(x0, y1, z1);
    face(layer, color, p000, p100, p110, p010);
    face(layer, color, p001, p101, p111, p011);
    face(layer, color, p000, p100, p101, p001);
    face(layer, color, p100, p110, p111, p101);
    face(layer, color, p110, p010, p011, p111);
    face(layer, color, p010, p000, p001, p011);
  }

  void tube(String layer, int color, _V3 start, _V3 end, double diameter) {
    final axis = end - start;
    if (axis.length < 1e-9 || diameter <= 0 || !diameter.isFinite) return;
    final direction = axis.normalized();
    final reference = direction.z.abs() < 0.9 ? const _V3(0, 0, 1) : const _V3(0, 1, 0);
    final u = direction.cross(reference).normalized();
    final v = direction.cross(u).normalized();
    final radius = diameter / 2;
    for (var i = 0; i < IrrigationDxf3d._pipeSides; i++) {
      final a0 = 2 * math.pi * i / IrrigationDxf3d._pipeSides;
      final a1 = 2 * math.pi * (i + 1) / IrrigationDxf3d._pipeSides;
      final r0 = u * (math.cos(a0) * radius) + v * (math.sin(a0) * radius);
      final r1 = u * (math.cos(a1) * radius) + v * (math.sin(a1) * radius);
      face(layer, color, start + r0, end + r0, end + r1, start + r1);
    }
  }

  void text(String layer, int color, _V3 position, String value) {
    _register(layer, color);
    final safe = value.replaceAll(RegExp(r'[\r\n\t]'), ' ').replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    _pair(_entities, 0, 'TEXT');
    _pair(_entities, 8, layer);
    _pair(_entities, 7, 'STANDARD');
    _pointGroups(_entities, 10, position);
    _pair(_entities, 40, '0.8');
    _pair(_entities, 1, safe);
  }

  void _pointGroups(StringBuffer out, int code, _V3 p) {
    _pair(out, code, fmt(p.x));
    _pair(out, code + 10, fmt(p.y));
    _pair(out, code + 20, fmt(p.z));
  }

  String build() {
    final out = StringBuffer();
    _pair(out, 0, 'SECTION');
    _pair(out, 2, 'HEADER');
    _pair(out, 9, r'$ACADVER');
    _pair(out, 1, 'AC1009');
    _pair(out, 9, r'$PDMODE');
    _pair(out, 70, '34');
    _pair(out, 9, r'$PDSIZE');
    _pair(out, 40, '0.25');
    _pair(out, 0, 'ENDSEC');

    _pair(out, 0, 'SECTION');
    _pair(out, 2, 'TABLES');
    _pair(out, 0, 'TABLE');
    _pair(out, 2, 'LTYPE');
    _pair(out, 70, '1');
    _pair(out, 0, 'LTYPE');
    _pair(out, 2, 'CONTINUOUS');
    _pair(out, 70, '0');
    _pair(out, 3, 'Solid line');
    _pair(out, 72, '65');
    _pair(out, 73, '0');
    _pair(out, 40, '0');
    _pair(out, 0, 'ENDTAB');

    _pair(out, 0, 'TABLE');
    _pair(out, 2, 'STYLE');
    _pair(out, 70, '1');
    _pair(out, 0, 'STYLE');
    _pair(out, 2, 'STANDARD');
    _pair(out, 70, '0');
    _pair(out, 40, '0');
    _pair(out, 41, '1');
    _pair(out, 50, '0');
    _pair(out, 71, '0');
    _pair(out, 42, '2.5');
    _pair(out, 3, 'txt');
    _pair(out, 4, '');
    _pair(out, 0, 'ENDTAB');

    final entries = _layers.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    _pair(out, 0, 'TABLE');
    _pair(out, 2, 'LAYER');
    _pair(out, 70, '${entries.length + 1}');
    _layer(out, '0', 7);
    for (final entry in entries) {
      _layer(out, entry.key, entry.value);
    }
    _pair(out, 0, 'ENDTAB');
    _pair(out, 0, 'ENDSEC');

    _pair(out, 0, 'SECTION');
    _pair(out, 2, 'ENTITIES');
    out.write(_entities.toString());
    _pair(out, 0, 'ENDSEC');
    _pair(out, 0, 'EOF');
    return out.toString();
  }

  void _layer(StringBuffer out, String name, int color) {
    _pair(out, 0, 'LAYER');
    _pair(out, 2, name);
    _pair(out, 70, '0');
    _pair(out, 62, '$color');
    _pair(out, 6, 'CONTINUOUS');
  }
}

class _V3 {
  final double x;
  final double y;
  final double z;
  const _V3(this.x, this.y, this.z);

  double get length => math.sqrt(x * x + y * y + z * z);
  _V3 normalized() => length == 0 ? this : this * (1 / length);
  _V3 cross(_V3 b) => _V3(y * b.z - z * b.y, z * b.x - x * b.z, x * b.y - y * b.x);
  _V3 operator +(_V3 b) => _V3(x + b.x, y + b.y, z + b.z);
  _V3 operator -(_V3 b) => _V3(x - b.x, y - b.y, z - b.z);
  _V3 operator *(double s) => _V3(x * s, y * s, z * s);
}
