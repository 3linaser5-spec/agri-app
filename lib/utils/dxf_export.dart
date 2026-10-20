import 'dart:math' as math;

/// منشئ DXF نصي متوافق مع AutoCAD R12.
///
/// تُكتب تعريفات الطبقات داخل TABLES، بينما تُكتب الأشكال الهندسية داخل
/// ENTITIES. الإحداثيات بوحدة المتر، والنصوص تُحوّل إلى ASCII للتوافق مع R12.
class DxfBuilder {
  final StringBuffer _entities = StringBuffer();
  final Map<String, int> _layers = <String, int>{};

  static final RegExp _validLayerName = RegExp(r'^[A-Za-z0-9_$-]{1,31}$');

  /// تنسيق عشري بلا صيغة علمية، مع أربع خانات عشرية كحد أقصى.
  static String fmt(double value) {
    if (!value.isFinite) return '0';
    var result = value.toStringAsFixed(4);
    if (result.contains('.')) {
      result = result.replaceFirst(RegExp(r'0+$'), '');
      result = result.replaceFirst(RegExp(r'\.$'), '');
    }
    return result == '-0' ? '0' : result;
  }

  static void _requireFinite(String name, double value) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, name, 'يجب أن تكون القيمة رقماً محدوداً.');
    }
  }

  static void _requirePositive(String name, double value) {
    _requireFinite(name, value);
    if (value <= 0) {
      throw ArgumentError.value(value, name, 'يجب أن تكون القيمة أكبر من صفر.');
    }
  }

  void _pair(StringBuffer buffer, int code, String value) {
    buffer.writeln(code);
    buffer.writeln(value);
  }

  String _registerLayer(String name, int color) {
    final normalized = name.trim();
    if (normalized != '0' && !_validLayerName.hasMatch(normalized)) {
      throw ArgumentError.value(
        name,
        'layer',
        'اسم الطبقة يجب أن يكون ASCII، من 1 إلى 31 محرفاً، ومن دون مسافات.',
      );
    }
    if (color < 1 || color > 255) {
      throw ArgumentError.value(color, 'color', 'لون DXF يجب أن يكون بين 1 و255.');
    }
    if (normalized != '0') {
      _layers.putIfAbsent(normalized, () => color);
    }
    return normalized;
  }

  void line(
    String layer,
    int color,
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    final safeLayer = _registerLayer(layer, color);
    _requireFinite('x1', x1);
    _requireFinite('y1', y1);
    _requireFinite('x2', x2);
    _requireFinite('y2', y2);

    _pair(_entities, 0, 'LINE');
    _pair(_entities, 8, safeLayer);
    _pair(_entities, 10, fmt(x1));
    _pair(_entities, 20, fmt(y1));
    _pair(_entities, 30, '0');
    _pair(_entities, 11, fmt(x2));
    _pair(_entities, 21, fmt(y2));
    _pair(_entities, 31, '0');
  }

  void circle(String layer, int color, double x, double y, double radius) {
    final safeLayer = _registerLayer(layer, color);
    _requireFinite('x', x);
    _requireFinite('y', y);
    _requirePositive('radius', radius);

    _pair(_entities, 0, 'CIRCLE');
    _pair(_entities, 8, safeLayer);
    _pair(_entities, 10, fmt(x));
    _pair(_entities, 20, fmt(y));
    _pair(_entities, 30, '0');
    _pair(_entities, 40, fmt(radius));
  }

  void text(
    String layer,
    int color,
    double x,
    double y,
    double height,
    String value,
  ) {
    final safeLayer = _registerLayer(layer, color);
    _requireFinite('x', x);
    _requireFinite('y', y);
    _requirePositive('height', height);

    // إزالة الأسطر ومحارف التحكم ثم الاقتصار على ASCII المتوافق مع R12.
    final safeText = value
        .replaceAll(RegExp(r'[\r\n\t]'), ' ')
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '');

    _pair(_entities, 0, 'TEXT');
    _pair(_entities, 8, safeLayer);
    _pair(_entities, 7, 'STANDARD');
    _pair(_entities, 10, fmt(x));
    _pair(_entities, 20, fmt(y));
    _pair(_entities, 30, '0');
    _pair(_entities, 40, fmt(height));
    _pair(_entities, 1, safeText);
  }

  void rect(String layer, int color, double x, double y, double width, double height) {
    _requirePositive('width', width);
    _requirePositive('height', height);
    _requireFinite('x', x);
    _requireFinite('y', y);

    line(layer, color, x, y, x + width, y);
    line(layer, color, x + width, y, x + width, y + height);
    line(layer, color, x + width, y + height, x, y + height);
    line(layer, color, x, y + height, x, y);
  }

  String build() {
    final output = StringBuffer();
    final sortedLayers = _layers.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // Header.
    _pair(output, 0, 'SECTION');
    _pair(output, 2, 'HEADER');
    _pair(output, 9, r'$ACADVER');
    _pair(output, 1, 'AC1009'); // AutoCAD R12
    _pair(output, 0, 'ENDSEC');

    // LTYPE table: يعرّف النمط المستخدم من الطبقات.
    _pair(output, 0, 'SECTION');
    _pair(output, 2, 'TABLES');
    _pair(output, 0, 'TABLE');
    _pair(output, 2, 'LTYPE');
    _pair(output, 70, '1');
    _pair(output, 0, 'LTYPE');
    _pair(output, 2, 'CONTINUOUS');
    _pair(output, 70, '0');
    _pair(output, 3, 'Solid line');
    _pair(output, 72, '65');
    _pair(output, 73, '0');
    _pair(output, 40, '0');
    _pair(output, 0, 'ENDTAB');

    // STYLE table: النمط القياسي المستخدم لعناصر TEXT.
    _pair(output, 0, 'TABLE');
    _pair(output, 2, 'STYLE');
    _pair(output, 70, '1');
    _pair(output, 0, 'STYLE');
    _pair(output, 2, 'STANDARD');
    _pair(output, 70, '0');
    _pair(output, 40, '0');
    _pair(output, 41, '1');
    _pair(output, 50, '0');
    _pair(output, 71, '0');
    _pair(output, 42, '2.5');
    _pair(output, 3, 'txt');
    _pair(output, 4, '');
    _pair(output, 0, 'ENDTAB');

    // LAYER table: لا تكتب أي LINE أو CIRCLE أو TEXT في هذا القسم.
    _pair(output, 0, 'TABLE');
    _pair(output, 2, 'LAYER');
    _pair(output, 70, '${sortedLayers.length + 1}');
    _writeLayer(output, '0', 7);
    for (final entry in sortedLayers) {
      _writeLayer(output, entry.key, entry.value);
    }
    _pair(output, 0, 'ENDTAB');
    _pair(output, 0, 'ENDSEC');

    // جميع عناصر الرسم في ENTITIES بعد إغلاق TABLES.
    _pair(output, 0, 'SECTION');
    _pair(output, 2, 'ENTITIES');
    output.write(_entities.toString());
    _pair(output, 0, 'ENDSEC');
    _pair(output, 0, 'EOF');

    return output.toString();
  }

  void _writeLayer(StringBuffer output, String name, int color) {
    _pair(output, 0, 'LAYER');
    _pair(output, 2, name);
    _pair(output, 70, '0');
    _pair(output, 62, color.toString());
    _pair(output, 6, 'CONTINUOUS');
  }
}

/// مخططات DXF تخطيطية لأنظمة الري.
/// الأصل (0,0) في الركن السفلي الأيسر، والأبعاد بالمتر.
class IrrigationDxf {
  IrrigationDxf._();

  /// حد أقصى لعلامات النقاطات/الرشاشات والخطوط المتكررة في المخطط.
  static const int maxPoints = 5000;

  static void _positive(String name, double value) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(value, name, 'يجب أن تكون القيمة موجبة ومحدودة.');
    }
  }

  static void _optionalPositive(String name, num? value, {bool allowZero = false}) {
    if (value == null) return;
    if (!value.isFinite || (allowZero ? value < 0 : value <= 0)) {
      throw ArgumentError.value(
        value,
        name,
        allowZero ? 'يجب ألا تكون القيمة سالبة.' : 'يجب أن تكون القيمة أكبر من صفر.',
      );
    }
  }

  static int _count(double span, double spacing, {required bool roundUp}) {
    final ratio = span / spacing;
    if (!ratio.isFinite || ratio >= maxPoints) return maxPoints;
    final raw = roundUp ? ratio.ceil() : ratio.floor();
    if (raw < 1) return 1;
    return raw > maxPoints ? maxPoints : raw;
  }

  static bool _withinPointLimit(int a, int b, int c) {
    if (a < 1 || b < 1 || c < 1 || c > maxPoints) return false;
    if (a > maxPoints ~/ c) return false;
    final firstProduct = a * c;
    return b <= maxPoints ~/ firstProduct;
  }

  static double _noteHeight(double widthM) => math.max(0.5, widthM / 40).toDouble();

  static void _addNotes(
    DxfBuilder builder, {
    required double widthM,
    required double lengthM,
    required String title,
    List<String> details = const <String>[],
  }) {
    final height = _noteHeight(widthM);
    final notes = <String>[title, ...details.where((line) => line.trim().isNotEmpty)];
    for (var i = 0; i < notes.length; i++) {
      builder.text(
        'NOTES',
        7,
        0,
        lengthM + 2 + i * (height + 0.4),
        height,
        notes[i],
      );
    }
  }

  static List<String> _dripDetails({
    required int sectors,
    required int emittersPerPlant,
    int? mainPipeMm,
    int? subMainPipeMm,
    double? sectorFlowM3h,
    double? pumpKw,
    double? requiredPumpHeadM,
    double? totalNetworkLossM,
    bool emittersOmitted = false,
  }) {
    final details = <String>['Sectors: $sectors', 'Emitters per plant: $emittersPerPlant'];
    if (mainPipeMm != null) details.add('Main pipe: $mainPipeMm mm');
    if (subMainPipeMm != null) details.add('Submain pipe: $subMainPipeMm mm');
    if (sectorFlowM3h != null) {
      details.add('Sector flow: ${DxfBuilder.fmt(sectorFlowM3h)} m3/h');
    }
    if (pumpKw != null) details.add('Pump motor: ${DxfBuilder.fmt(pumpKw)} kW');
    if (requiredPumpHeadM != null) {
      details.add('Required pump head: ${DxfBuilder.fmt(requiredPumpHeadM)} m');
    }
    if (totalNetworkLossM != null) {
      details.add('Network loss: ${DxfBuilder.fmt(totalNetworkLossM)} m');
    }
    if (emittersOmitted) details.add('Emitter symbols omitted: drawing limit exceeded');
    return details;
  }

  /// حساب أبعاد حقل مستطيل من المساحة ونسبة الطول إلى العرض.
  static ({double width, double length}) fieldDims(
    double areaM2,
    double lengthToWidth,
  ) {
    _positive('areaM2', areaM2);
    _positive('lengthToWidth', lengthToWidth);
    final width = math.sqrt(areaM2 / lengthToWidth);
    final length = width * lengthToWidth;
    _positive('calculated width', width);
    _positive('calculated length', length);
    return (width: width, length: length);
  }

  /// مخطط تنقيط تخطيطي.
  ///
  /// أقطار المواسير وبيانات المضخة تُكتب في الملاحظات فقط؛ لا تُرسم لها
  /// مسارات مكانية لأن مواضعها الفعلية غير مدخلة إلى هذه الدالة.
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
    _positive('widthM', widthM);
    _positive('lengthM', lengthM);
    _positive('rowSpacingM', rowSpacingM);
    _positive('plantSpacingM', plantSpacingM);
    if (emittersPerPlant < 1) {
      throw ArgumentError.value(emittersPerPlant, 'emittersPerPlant', 'يجب أن يكون واحداً أو أكثر.');
    }
    if (sectors < 1) {
      throw ArgumentError.value(sectors, 'sectors', 'يجب أن يكون عدد القطاعات واحداً أو أكثر.');
    }
    if (mainPipeMm != null && mainPipeMm < 1) {
      throw ArgumentError.value(mainPipeMm, 'mainPipeMm', 'يجب أن يكون القطر موجباً.');
    }
    if (subMainPipeMm != null && subMainPipeMm < 1) {
      throw ArgumentError.value(subMainPipeMm, 'subMainPipeMm', 'يجب أن يكون القطر موجباً.');
    }
    _optionalPositive('sectorFlowM3h', sectorFlowM3h);
    _optionalPositive('pumpKw', pumpKw);
    _optionalPositive('requiredPumpHeadM', requiredPumpHeadM);
    _optionalPositive('totalNetworkLossM', totalNetworkLossM, allowZero: true);

    final builder = DxfBuilder();
    builder.rect('FIELD', 7, 0, 0, widthM, lengthM);
    builder.line('MAIN', 5, 0, -2, widthM, -2);

    final rows = _count(widthM, rowSpacingM, roundUp: false);
    final plantsPerRow = _count(lengthM, plantSpacingM, roundUp: false);
    final drawEmitters = _withinPointLimit(rows, plantsPerRow, emittersPerPlant);
    final markerGap = math.min(0.2, rowSpacingM / (emittersPerPlant + 1)).toDouble();
    final markerRadius = math.min(0.05, markerGap * 0.3).toDouble();

    for (var row = 0; row < rows; row++) {
      final x = rowSpacingM / 2 + row * rowSpacingM;
      builder.line('LATERAL', 3, x, 0, x, lengthM);
      builder.line('MAIN', 5, x, -2, x, 0);

      if (!drawEmitters) continue;
      for (var plant = 0; plant < plantsPerRow; plant++) {
        final y = plantSpacingM / 2 + plant * plantSpacingM;
        for (var emitter = 0; emitter < emittersPerPlant; emitter++) {
          final offset = (emitter - (emittersPerPlant - 1) / 2) * markerGap;
          builder.circle('EMITTER', 1, x + offset, y, markerRadius);
        }
      }
    }

    final details = _dripDetails(
      sectors: sectors,
      emittersPerPlant: emittersPerPlant,
      mainPipeMm: mainPipeMm,
      subMainPipeMm: subMainPipeMm,
      sectorFlowM3h: sectorFlowM3h,
      pumpKw: pumpKw,
      requiredPumpHeadM: requiredPumpHeadM,
      totalNetworkLossM: totalNetworkLossM,
      emittersOmitted: !drawEmitters,
    );
    _addNotes(
      builder,
      widthM: widthM,
      lengthM: lengthM,
      title: title ?? 'Drip layout: $rows laterals',
      details: details,
    );
    return builder.build();
  }

  /// مخطط رشاشات مربع/مستطيل.
  static String sprinkler({
    required double widthM,
    required double lengthM,
    required double spacingAlongM,
    required double spacingAcrossM,
    double? radiusM,
    String? title,
  }) {
    _positive('widthM', widthM);
    _positive('lengthM', lengthM);
    _positive('spacingAlongM', spacingAlongM);
    _positive('spacingAcrossM', spacingAcrossM);
    if (radiusM != null) _optionalPositive('radiusM', radiusM);

    final builder = DxfBuilder();
    builder.rect('FIELD', 7, 0, 0, widthM, lengthM);
    final columns = _count(widthM, spacingAcrossM, roundUp: true);
    final rows = _count(lengthM, spacingAlongM, roundUp: true);
    final countWithinLimit = _withinPointLimit(columns, rows, 1);

    for (var column = 0; column < columns; column++) {
      final x = spacingAcrossM / 2 + column * spacingAcrossM;
      builder.line('LATERAL', 3, x, 0, x, lengthM);
      if (countWithinLimit) {
        for (var row = 0; row < rows; row++) {
          final y = spacingAlongM / 2 + row * spacingAlongM;
          builder.circle('SPRINKLER', 1, x, y, 0.3);
          if (radiusM != null && radiusM > 0 && columns * rows <= 500) {
            builder.circle('COVERAGE', 8, x, y, radiusM);
          }
        }
      }
    }

    builder.line('MAIN', 5, 0, -2, widthM, -2);
    _addNotes(
      builder,
      widthM: widthM,
      lengthM: lengthM,
      title: title ?? 'Sprinkler layout: ${columns * rows} sprinklers',
      details: countWithinLimit ? const <String>[] : const <String>['Sprinkler markers omitted: drawing limit exceeded'],
    );
    return builder.build();
  }

  /// مخطط ري سطحي بخطوط الأخاديد.
  static String surface({
    required double widthM,
    required double lengthM,
    required double furrowSpacingM,
    String? title,
  }) {
    _positive('widthM', widthM);
    _positive('lengthM', lengthM);
    _positive('furrowSpacingM', furrowSpacingM);

    final builder = DxfBuilder();
    builder.rect('FIELD', 7, 0, 0, widthM, lengthM);
    final furrows = _count(widthM, furrowSpacingM, roundUp: false);
    for (var index = 0; index < furrows; index++) {
      final x = furrowSpacingM / 2 + index * furrowSpacingM;
      builder.line('FURROW', 3, x, 0, x, lengthM);
    }
    builder.line('MAIN', 5, 0, -2, widthM, -2);
    _addNotes(
      builder,
      widthM: widthM,
      lengthM: lengthM,
      title: title ?? 'Surface irrigation: $furrows furrows',
    );
    return builder.build();
  }

  /// مخطط ري محوري: دائرة الجهاز وخط الذراع.
  static String pivot({required double radiusM, String? title}) {
    _positive('radiusM', radiusM);
    final builder = DxfBuilder();
    builder.circle('PIVOT', 3, 0, 0, radiusM);
    builder.circle('CENTER', 1, 0, 0, math.max(1, radiusM / 100).toDouble());
    builder.line('SPAN', 5, 0, 0, radiusM, 0);
    builder.text(
      'NOTES',
      7,
      -radiusM,
      radiusM + 10,
      math.max(2, radiusM / 40).toDouble(),
      title ?? 'Center pivot R=${DxfBuilder.fmt(radiusM)} m',
    );
    return builder.build();
  }
}
