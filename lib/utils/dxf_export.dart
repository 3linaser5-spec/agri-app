import 'dart:math' as math;

// =====================================================================
// DxfBuilder - أداة بناء ملفات DXF آمنة ومتوافقة مع برامج CAD
// =====================================================================
class DxfBuilder {
  final StringBuffer _buf = StringBuffer();
  final Set<String> _layers = {};

  DxfBuilder() {
    _setupHeader();
  }

  void _setupHeader() {
    _buf.writeln('0\nSECTION\n2\nHEADER');
    _buf.writeln('9\n\$ACADVER\n1\nAC1015'); // AutoCAD 2000
    _buf.writeln('0\nENDSEC');
    _buf.writeln('0\nSECTION\n2\nTABLES');
    _buf.writeln('0\nTABLE\n2\nLAYER');
  }

  /// دالة مساعدة لتنسيق الأرقام (تمنع الـ Scientific Notation)
  static String fmt(num? value) {
    if (value == null || value.isNaN || value.isInfinite) return '0';
    // تنسيق لأقرب 6 أرقام عشرية وإزالة الأصفار الزائدة
    final s = value.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
    return s.isEmpty ? '0' : s;
  }

  /// إضافة طبقة جديدة (مرة واحدة فقط)
  void _ensureLayer(String name, int color) {
    if (_layers.add(name)) {
      _buf.writeln('0\nLAYER\n2\n$name\n70\n0\n62\n$color\n6\nCONTINUOUS');
    }
  }

  /// رسم خط
  void line(String layer, int color, double x1, double y1, double x2, double y2) {
    _ensureLayer(layer, color);
    _buf.writeln('0\nLINE\n8\n$layer');
    _buf.writeln('10\n${fmt(x1)}\n20\n${fmt(y1)}\n30\n0');
    _buf.writeln('11\n${fmt(x2)}\n21\n${fmt(y2)}\n31\n0');
  }

  /// رسم دائرة
  void circle(String layer, int color, double cx, double cy, double r) {
    if (r <= 0) return;
    _ensureLayer(layer, color);
    _buf.writeln('0\nCIRCLE\n8\n$layer');
    _buf.writeln('10\n${fmt(cx)}\n20\n${fmt(cy)}\n30\n0');
    _buf.writeln('40\n${fmt(r)}');
  }

  /// رسم مستطيل (كمجموعة خطوط)
  void rect(String layer, int color, double x1, double y1, double x2, double y2) {
    line(layer, color, x1, y1, x2, y1);
    line(layer, color, x2, y1, x2, y2);
    line(layer, color, x2, y2, x1, y2);
    line(layer, color, x1, y2, x1, y1);
  }

  /// كتابة نص (يتم إزالة أي حروف غير ASCII لتجنب مشاكل الترميز)
  void text(String layer, int color, double x, double y, double height, String value) {
    // إزالة الحروف العربية والرموز غير الإنجليزية
    final safeText = value.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim();
    if (safeText.isEmpty) return;
    
    _ensureLayer(layer, color);
    _buf.writeln('0\nTEXT\n8\n$layer');
    _buf.writeln('10\n${fmt(x)}\n20\n${fmt(y)}\n30\n0');
    _buf.writeln('40\n${fmt(height)}');
    _buf.writeln('1\n$safeText');
  }

  /// إنهاء الملف وإرجاع النص
  String build() {
    // إغلاق جدول الطبقات
    _buf.writeln('0\nENDTAB');
    _buf.writeln('0\nENDSEC'); // END TABLES

    // بدء قسم الكيانات (ENTITIES)
    _buf.writeln('0\nSECTION\n2\nENTITIES');
    
    final content = _buf.toString();
    final entitiesStart = content.indexOf('0\nSECTION\n2\nENTITIES');
    
    if (entitiesStart == -1) {
      _buf.writeln('0\nSECTION\n2\nENTITIES');
    }
    
    _buf.writeln('0\nENDSEC'); // END ENTITIES
    _buf.writeln('0\nEOF');
    
    return _buf.toString();
  }
}

// =====================================================================
// IrrigationDxf - دوال توليد رسومات الري
// =====================================================================
class IrrigationDxf {
  static const int maxPoints = 5000;

  /// ✅ دالة جديدة لحساب أبعاد الحقل (الطول والعرض) من المساحة ونسبة الطول/العرض
  static ({double width, double length}) fieldDims(double areaM2, double aspectRatio) {
    final safeAspect = aspectRatio > 0 ? aspectRatio : 1.0;
    final width = math.sqrt(areaM2 / safeAspect);
    final length = width * safeAspect;
    return (width: width, length: length);
  }

  /// تنقيط: خطوط فرعية ومحاور ومضخة وحوش (Sectors) متوافقة مع RainCAD.
  static String drip({
    required double widthM,
    required double lengthM,
    required double rowSpacingM,
    required double plantSpacingM,
    required int emittersPerPlant,
    int sectors = 1,
    int? mainPipeMm,
    int? subMainPipeMm,
    double? sectorFlowM3h,
    double? pumpKw,
    double? requiredPumpHeadM,
    double? totalNetworkLossM,
    String? title,
  }) {
    final d = DxfBuilder();
    final safeSectors = sectors > 0 ? sectors : 1;

    // حدود الحقل
    d.rect('FIELD', 7, 0, 0, lengthM, widthM);

    // تسمية طبقات المواسير بناءً على الأقطار المحسوبة ليتعرف عليها RainCAD
    final mainLayer = mainPipeMm != null ? 'MAINLINE_${mainPipeMm}MM' : 'MAINLINE';
    final subMainLayer = subMainPipeMm != null ? 'SUBMAIN_${subMainPipeMm}MM' : 'SUBMAIN';

    // محطة المضخة والخط الرئيسي
    final midY = widthM / 2.0;
    d.circle('PUMP_STATION', 1, -3.0, midY, 1.5);
    
    if (sectorFlowM3h != null) {
      final kwText = pumpKw != null ? ' ${DxfBuilder.fmt(pumpKw)}kW' : '';
      final headText = requiredPumpHeadM != null ? ' H=${DxfBuilder.fmt(requiredPumpHeadM)}m' : '';
      final lossText = totalNetworkLossM != null ? ' (Loss=${DxfBuilder.fmt(totalNetworkLossM)}m)' : '';
      
      d.text('NOTES', 2, -12.0, midY + 2.5, 1.5,
          'PUMP Q=${DxfBuilder.fmt(sectorFlowM3h)}m3/h$kwText$headText$lossText');
    }

    final sectorLength = lengthM / safeSectors;
    final lastSubMainX = (safeSectors - 1) * sectorLength;
    d.line(mainLayer, 5, -1.5, midY, lastSubMainX, midY);

    final rows = math.max(1, (widthM / rowSpacingM).floor());
    final perRow = math.max(1, (lengthM / plantSpacingM).floor());
    final drawEmitters = rows * perRow * emittersPerPlant <= maxPoints;

    // رسم القطاعات والمحابس والخراطيم
    for (var s = 0; s < safeSectors; s++) {
      final subX = s * sectorLength;
      final endX = (s + 1) * sectorLength;

      // إضافة مستطيل خفيف لتحديد الحوشة (Sector)
      if (safeSectors > 1) {
        d.rect('SECTOR_BOUNDS', 8, subX, 0, endX, widthM);
      }

      // خط المشترك (Sub-main)
      d.line(subMainLayer, 4, subX, 0, subX, widthM);

      // محبس الحوشة (Zone Valve)
      d.circle('VALVES', 1, subX, midY, 0.8);
      d.text('NOTES', 2, subX + 1.0, midY + 1.5, 1.2, 'VALVE Z${s + 1}');

      for (var r = 0; r < rows; r++) {
        final y = rowSpacingM / 2 + r * rowSpacingM;
        d.line('LATERAL', 3, subX, y, endX, y);

        if (drawEmitters) {
          for (var p = 0; p < perRow; p++) {
            final x = subX + (plantSpacingM / 2 + p * plantSpacingM);
            if (x <= endX) {
              d.circle('EMITTER', 1, x, y, 0.05);
            }
          }
        }
      }
    }

    final titleText = title ?? 
        'Drip: $safeSectors sectors, $rows laterals, ${mainLayer} / ${subMainLayer}';
    d.text('NOTES', 7, 0, lengthM + 2, math.max(0.5, widthM / 40), titleText);
    
    return d.build();
  }

  /// رشاشات: توزيع الرشاشات على الشبكة، خطوط المواسير، ومحطة المضخة.
  static String sprinkler({
    required double widthM,
    required double lengthM,
    required double spacingAlongM,
    required double spacingAcrossM,
    int? mainPipeMm,
    double? sectorFlowM3h,
    double? pumpKw,
    double? requiredPumpHeadM,
    double? applicationRateMmH,
    String? title,
  }) {
    final d = DxfBuilder();
    
    // حدود الحقل
    d.rect('FIELD', 7, 0, 0, lengthM, widthM);

    final mainLayer = mainPipeMm != null ? 'MAINLINE_${mainPipeMm}MM' : 'MAINLINE';
    final midY = widthM / 2.0;
    
    // محطة المضخة والخط الرئيسي
    d.circle('PUMP_STATION', 1, -3.0, midY, 1.5);
    if (sectorFlowM3h != null) {
      final kwText = pumpKw != null ? ' ${DxfBuilder.fmt(pumpKw)}kW' : '';
      final headText = requiredPumpHeadM != null ? ' H=${DxfBuilder.fmt(requiredPumpHeadM)}m' : '';
      final rateText = applicationRateMmH != null ? ' Rate=${DxfBuilder.fmt(applicationRateMmH)}mm/h' : '';
      
      d.text('NOTES', 2, -12.0, midY + 2.5, 1.5,
          'PUMP Q=${DxfBuilder.fmt(sectorFlowM3h)}m3/h$kwText$headText$rateText');
    }

    // رسم الخط الرئيسي
    d.line(mainLayer, 5, -1.5, midY, lengthM, midY);

    final cols = math.max(1, (lengthM / spacingAlongM).floor());
    final rows = math.max(1, (widthM / spacingAcrossM).floor());
    
    // رسم الرشاشات وخطوط التوزيع
    for (var r = 0; r <= rows; r++) {
      final y = r * spacingAcrossM;
      
      // خط توزيع أفقي
      d.line('SUBLINE', 4, 0, y, lengthM, y);
      
      for (var c = 0; c <= cols; c++) {
        final x = c * spacingAlongM;
        // رشاش
        d.circle('SPRINKLER', 1, x, y, 0.5);
      }
    }

    final titleText = title ?? 
        'Sprinkler: $cols x $rows grid, spacing ${spacingAlongM}x${spacingAcrossM}m';
    d.text('NOTES', 7, 0, lengthM + 2, math.max(0.5, widthM / 40), titleText);
    
    return d.build();
  }

  /// بيفوت: رسم دائرتين (مسار العجلات والرشاشات) وخطوط التغذية.
  static String pivot({
    required double radiusM,
    int? mainPipeMm,
    double? flowM3h,
    double? pumpKw,
    double? requiredPumpHeadM,
    String? title,
  }) {
    final d = DxfBuilder();
    
    // نقطة الارتكاز (المحور)
    final cx = 0.0;
    final cy = 0.0;
    
    final mainLayer = mainPipeMm != null ? 'MAINLINE_${mainPipeMm}MM' : 'MAINLINE';

    // رسم دائرة المحيط (مسار العجلات الأخيرة)
    d.circle('PIVOT_TRACK', 7, cx, cy, radiusM);
    
    // رسم دائرة الرشاشات (أقل قليلاً من المحيط)
    d.circle('PIVOT_LATERAL', 3, cx, cy, radiusM - 1.0);
    
    // محطة المضخة المركزية
    d.circle('PUMP_STATION', 1, cx, cy, 2.0);
    if (flowM3h != null) {
      final kwText = pumpKw != null ? ' ${DxfBuilder.fmt(pumpKw)}kW' : '';
      final headText = requiredPumpHeadM != null ? ' H=${DxfBuilder.fmt(requiredPumpHeadM)}m' : '';
      d.text('NOTES', 2, cx + 3.0, cy + 3.0, 2.0,
          'PIVOT Q=${DxfBuilder.fmt(flowM3h)}m3/h$kwText$headText');
    }

    // الخط الرئيسي القادم للمحور
    d.line(mainLayer, 5, -radiusM - 10, cy, cx - 2.0, cy);

    final titleText = title ?? 'Center Pivot: R=${DxfBuilder.fmt(radiusM)}m';
    d.text('NOTES', 7, cx, cy + radiusM + 5, 2.0, titleText);
    
    return d.build();
  }

  /// ري سطحي: رسم مساقي وبوابات مياه.
  /// ✅ تم تعديل اسم الباراميتر لـ furrowSpacingM ليتوافق مع الشاشة
  static String surface({
    required double widthM,
    required double lengthM,
    required double furrowSpacingM,
    double? irrigationHours,
    double? streamLps,
    String? title,
  }) {
    final d = DxfBuilder();
    
    // حدود الحقل
    d.rect('FIELD', 7, 0, 0, lengthM, widthM);

    final numStreams = math.max(1, (widthM / furrowSpacingM).floor());
    final streamSpacing = widthM / numStreams;

    // رسم المساقي وبوابات المياه
    for (var i = 0; i < numStreams; i++) {
      final y = (i + 0.5) * streamSpacing;
      d.line('SURFACE_STREAM', 3, 0, y, lengthM, y);
      
      // بوابة مياه عند بداية المسقى
      d.rect('GATES', 1, -0.5, y - 0.5, 0.5, y + 0.5);
    }

    if (irrigationHours != null && streamLps != null) {
      d.text('NOTES', 2, 0, -5.0, 1.5,
          'SURFACE: Stream=${DxfBuilder.fmt(streamLps)}L/s, Time=${DxfBuilder.fmt(irrigationHours)}h');
    }

    final titleText = title ?? 
        'Surface Irrigation: $numStreams streams @ ${DxfBuilder.fmt(streamSpacing)}m';
    d.text('NOTES', 7, 0, lengthM + 2, math.max(0.5, widthM / 40), titleText);
    
    return d.build();
  }
}
