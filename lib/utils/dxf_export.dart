import 'dart:math' as math;

/// منشئ ملفات DXF نصية بسيطة (صيغة R12) تفتح في أي برنامج CAD
/// (AutoCAD / BricsCAD / RainCAD ...). الوحدات بالمتر، والنصوص إنجليزي
/// عشان صيغة R12 ما بتدعمش العربي.
class DxfBuilder {
  final StringBuffer _entities = StringBuffer();
  final Map<String, int> _layers = <String, int>{};

  /// قيمة رقمية بدون تنسيق علمي (DXF مش بيقبل 1e-5).
  static String fmt(double v) {
    if (!v.isFinite) return '0';
    var s = v.toStringAsFixed(4);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '');
      s = s.replaceFirst(RegExp(r'\.$'), '');
    }
    return s == '-0' ? '0' : s;
  }

  void _pair(StringBuffer b, int code, String value) {
    b.writeln(code);
    b.writeln(value);
  }

  void _layer(String name, int color) => _layers.putIfAbsent(name, () => color);

  void line(String layer, int color, double x1, double y1, double x2, double y2) {
    _layer(layer, color);
    _pair(_entities, 0, 'LINE');
    _pair(_entities, 8, layer);
    _pair(_entities, 10, fmt(x1));
    _pair(_entities, 20, fmt(y1));
    _pair(_entities, 30, '0');
    _pair(_entities, 11, fmt(x2));
    _pair(_entities, 21, fmt(y2));
    _pair(_entities, 31, '0');
  }

  void circle(String layer, int color, double x, double y, double r) {
    _layer(layer, color);
    _pair(_entities, 0, 'CIRCLE');
    _pair(_entities, 8, layer);
    _pair(_entities, 10, fmt(x));
    _pair(_entities, 20, fmt(y));
    _pair(_entities, 30, '0');
    _pair(_entities, 40, fmt(r));
  }

  void text(String layer, int color, double x, double y, double height,
      String value) {
    _layer(layer, color);
    // R12 ما يدعمش غير ASCII، فنشيل أي حرف خارجه
    final safe = value.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    _pair(_entities, 0, 'TEXT');
    _pair(_entities, 8, layer);
    _pair(_entities, 10, fmt(x));
    _pair(_entities, 20, fmt(y));
    _pair(_entities, 30, '0');
    _pair(_entities, 40, fmt(height));
    _pair(_entities, 1, safe);
  }

  void rect(String layer, int color, double x, double y, double w, double h) {
    line(layer, color, x, y, x + w, y);
    line(layer, color, x + w, y, x + w, y + h);
    line(layer, color, x + w, y + h, x, y + h);
    line(layer, color, x, y + h, x, y);
  }

  String build() {
    final b = StringBuffer();
    _pair(b, 0, 'SECTION');
    _pair(b, 2, 'HEADER');
    _pair(b, 9, r'$ACADVER');
    _pair(b, 1, 'AC1009');
    _pair(b, 0, 'ENDSEC');

    _pair(b, 0, 'SECTION');
    _pair(b, 2, 'TABLES');
    _pair(b, 0, 'TABLE');
    _pair(b, 2, 'LAYER');
    _pair(b, 70, '${_layers.length + 1}');
    _pair(b, 0, 'LAYER');
    _pair(b, 2, '0');
    _pair(b, 70, '0');
    _pair(b, 62, '7');
    _pair(b, 6, 'CONTINUOUS');
    _layers.forEach((name, color) {
      _pair(b, 0, 'LAYER');
      _pair(b, 2, name);
      _pair(b, 70, '0');
      _pair(b, 62, color.toString());
      _pair(b, 6, 'CONTINUOUS');
    });
    _pair(b, 0, 'ENDTAB');
    _pair(b, 0, 'ENDSEC');

    _pair(b, 0, 'SECTION');
    _pair(b, 2, 'ENTITIES');
    b.write(_entities);
    _pair(b, 0, 'ENDSEC');
    _pair(b, 0, 'EOF');
    return b.toString();
  }
}

/// مخططات DXF لأنواع الري. الحقل مستطيل بعرض [widthM] وطول [lengthM]
/// والأصل (0,0) في الركن السفلي الأيسر.
class IrrigationDxf {
  IrrigationDxf._();

  /// أقصى عدد نقاط/عناصر بيترسم، عشان الملف ما يبقاش ضخم.
  static const int maxPoints = 5000;

  /// أبعاد حقل مستطيل بنسبة طول/عرض معينة من المساحة.
  static ({double width, double length}) fieldDims(
      double areaM2, double lengthToWidth) {
    final ratio = lengthToWidth <= 0 ? 1.0 : lengthToWidth;
    final width = math.sqrt(areaM2 / ratio);
    return (width: width, length: width * ratio);
  }

  /// تنقيط: خطوط فرعية (واحد لكل صف) بطول الحقل، وخط رئيسي على الحافة السفلية،
  /// وعلامات النقاطات لو العدد معقول.
  static String drip({
    required double widthM,
    required double lengthM,
    required double rowSpacingM,
    required double plantSpacingM,
    required int emittersPerPlant,
    String? title,
  }) {
    final d = DxfBuilder();
    d.rect('FIELD', 7, 0, 0, widthM, lengthM);
    d.line('MAIN', 5, 0, -2, widthM, -2); // مواسير رئيسية قدام الحقل
    final rows = math.max(1, (widthM / rowSpacingM).floor());
    final perRow = math.max(1, (lengthM / plantSpacingM).floor());
    final drawEmitters = rows * perRow * emittersPerPlant <= maxPoints;
    for (var r = 0; r < rows; r++) {
      final x = rowSpacingM / 2 + r * rowSpacingM;
      d.line('LATERAL', 3, x, 0, x, lengthM);
      d.line('MAIN', 5, x, -2, x, 0);
      if (drawEmitters) {
        for (var p = 0; p < perRow; p++) {
          final y = plantSpacingM / 2 + p * plantSpacingM;
          d.circle('EMITTER', 1, x, y, 0.05);
        }
      }
    }
    d.text('NOTES', 7, 0, lengthM + 2, math.max(0.5, widthM / 40),
        title ?? 'Drip layout: $rows laterals');
    return d.build();
  }

  /// رش: شبكة رشاشات مربعة/مستطيلة.
  static String sprinkler({
    required double widthM,
    required double lengthM,
    required double spacingAlongM,
    required double spacingAcrossM,
    double? radiusM,
    String? title,
  }) {
    final d = DxfBuilder();
    d.rect('FIELD', 7, 0, 0, widthM, lengthM);
    final cols = math.max(1, (widthM / spacingAcrossM).ceil());
    final rows = math.max(1, (lengthM / spacingAlongM).ceil());
    final count = cols * rows;
    final drawAll = count <= maxPoints;
    if (drawAll) {
      for (var c = 0; c < cols; c++) {
        final x = spacingAcrossM / 2 + c * spacingAcrossM;
        d.line('LATERAL', 3, x, 0, x, lengthM);
        for (var r = 0; r < rows; r++) {
          final y = spacingAlongM / 2 + r * spacingAlongM;
          d.circle('SPRINKLER', 1, x, y, 0.3);
          if (radiusM != null && radiusM > 0 && count <= 500) {
            d.circle('COVERAGE', 8, x, y, radiusM);
          }
        }
      }
    }
    d.line('MAIN', 5, 0, -2, widthM, -2);
    d.text('NOTES', 7, 0, lengthM + 2, math.max(0.5, widthM / 40),
        title ?? 'Sprinkler layout: $count sprinklers');
    return d.build();
  }

  /// سطحي: حقل وخطوط الخطوط (furrows) بمسافة معينة.
  static String surface({
    required double widthM,
    required double lengthM,
    required double furrowSpacingM,
    String? title,
  }) {
    final d = DxfBuilder();
    d.rect('FIELD', 7, 0, 0, widthM, lengthM);
    final n = math.min(maxPoints, math.max(1, (widthM / furrowSpacingM).floor()));
    for (var i = 0; i < n; i++) {
      final x = furrowSpacingM / 2 + i * furrowSpacingM;
      d.line('FURROW', 3, x, 0, x, lengthM);
    }
    d.line('MAIN', 5, 0, -2, widthM, -2);
    d.text('NOTES', 7, 0, lengthM + 2, math.max(0.5, widthM / 40),
        title ?? 'Surface irrigation: $n furrows');
    return d.build();
  }

  /// محوري: دائرة بنصف قطر الجهاز ومركزه وخط الذراع.
  static String pivot({required double radiusM, String? title}) {
    final d = DxfBuilder();
    d.circle('PIVOT', 3, 0, 0, radiusM);
    d.circle('CENTER', 1, 0, 0, math.max(1, radiusM / 100));
    d.line('SPAN', 5, 0, 0, radiusM, 0);
    d.text('NOTES', 7, -radiusM, radiusM + 10, math.max(2, radiusM / 40),
        title ?? 'Center pivot R=${DxfBuilder.fmt(radiusM)} m');
    return d.build();
  }
}
