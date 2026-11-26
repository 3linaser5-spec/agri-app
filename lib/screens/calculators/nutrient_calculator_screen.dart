import 'package:material_ui/material_ui.dart';

import '../../services/farm_share_service.dart';
import '../../services/nutrient_calculator.dart';

/// حاسبة محلول التغذية: تحويل أهداف ppm إلى جرامات سماد، تقدير EC، وجرعة الحمض.
class NutrientCalculatorScreen extends StatefulWidget {
  const NutrientCalculatorScreen({super.key});

  @override
  State<NutrientCalculatorScreen> createState() =>
      _NutrientCalculatorScreenState();
}

class _NutrientCalculatorScreenState extends State<NutrientCalculatorScreen> {
  static const Color _green = Color(0xFF047857);

  final _liters = TextEditingController(text: '1000');
  final _nitrogen = TextEditingController(text: '150');
  final _phosphorus = TextEditingController(text: '40');
  final _potassium = TextEditingController(text: '180');
  final _magnesium = TextEditingController(text: '30');
  final _alkalinity = TextEditingController(text: '120');
  final _currentPh = TextEditingController(text: '7.8');
  final _targetPh = TextEditingController(text: '6.0');
  String _acid = 'sulfuric';

  @override
  void dispose() {
    for (final controller in [
      _liters,
      _nitrogen,
      _phosphorus,
      _potassium,
      _magnesium,
      _alkalinity,
      _currentPh,
      _targetPh,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double _value(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  Map<NutrientElement, double> get _targets => {
        NutrientElement.nitrogen: _value(_nitrogen),
        NutrientElement.phosphorus: _value(_phosphorus),
        NutrientElement.potassium: _value(_potassium),
        NutrientElement.magnesium: _value(_magnesium),
      };

  @override
  Widget build(BuildContext context) {
    final liters = _value(_liters);
    final recipe = NutrientCalculator.recipeGramsPer1000L(
      targetsPpm: _targets,
      products: NutrientCalculator.commonProducts,
    );
    // الجرعة المعروضة لكل 1000 لتر، ثم تُحسب المساهمة على حجم الحلة الفعلي.
    final doses = <MapEntry<FertilizerProduct, double>>[];
    final scaled = <MapEntry<FertilizerProduct, double>>[];
    for (final product in NutrientCalculator.commonProducts) {
      final grams = recipe[product.name] ?? 0;
      if (grams <= 0) continue;
      doses.add(MapEntry(product, grams));
      scaled.add(MapEntry(product, grams * liters / 1000));
    }
    final result = NutrientCalculator.evaluate(liters: liters, doses: scaled);
    final acid = NutrientCalculator.estimateAcidDose(
      alkalinityMgL: _value(_alkalinity),
      currentPh: _value(_currentPh),
      targetPh: _value(_targetPh),
      acid: _acid,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('حاسبة التغذية والمحلول',
            style: TextStyle(color: Colors.white)),
        backgroundColor: _green,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'مشاركة النتيجة',
            icon: const Icon(Icons.share),
            onPressed: () => FarmShareService.shareText(
              _shareText(result, scaled, acid),
              subject: 'وصفة محلول التغذية',
            ),
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(
              isDark,
              title: 'حجم المحلول والأهداف',
              children: [
                _numberField(_liters, 'حجم الماء (لتر)'),
                Row(children: [
                  Expanded(child: _numberField(_nitrogen, 'N (ppm)')),
                  const SizedBox(width: 8),
                  Expanded(child: _numberField(_phosphorus, 'P (ppm)')),
                ]),
                Row(children: [
                  Expanded(child: _numberField(_potassium, 'K (ppm)')),
                  const SizedBox(width: 8),
                  Expanded(child: _numberField(_magnesium, 'Mg (ppm)')),
                ]),
              ],
            ),
            const SizedBox(height: 12),
            _card(
              isDark,
              title: 'الجرامات المطلوبة (لكل 1000 لتر)',
              children: [
                if (doses.isEmpty)
                  const Text('أدخل هدفًا واحدًا على الأقل.',
                      style: TextStyle(fontSize: 12, color: Colors.grey))
                else
                  ...doses.map((entry) => _row(
                        entry.key.name,
                        '${entry.value.toStringAsFixed(1)} جم',
                      )),
                const Divider(),
                _row('الكمية الفعلية للمحلول',
                    '${(liters).toStringAsFixed(0)} لتر'),
              ],
            ),
            const SizedBox(height: 12),
            _card(
              isDark,
              title: 'النتيجة المتوقعة',
              children: [
                _row('النيتروجين', '${result.nitrogenPpm.toStringAsFixed(1)} ppm'),
                _row('الفوسفور', '${result.phosphorusPpm.toStringAsFixed(1)} ppm'),
                _row('البوتاسيوم', '${result.potassiumPpm.toStringAsFixed(1)} ppm'),
                _row('المغنيسيوم', '${result.magnesiumPpm.toStringAsFixed(1)} ppm'),
                const Divider(),
                _row(
                  'الملوحة التقديرية (EC)',
                  '${result.estimatedEcDsM.toStringAsFixed(2)} dS/m',
                  bold: true,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final element in NutrientElement.values)
                      _statusChip(element, result, _targets[element] ?? 0),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'EC تقديري من مجموع الأملاح (≈640 ppm لكل dS/m) وليس قراءة جهاز.',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _card(
              isDark,
              title: 'ضبط pH',
              children: [
                Row(children: [
                  Expanded(child: _numberField(_currentPh, 'pH الحالي')),
                  const SizedBox(width: 8),
                  Expanded(child: _numberField(_targetPh, 'pH المستهدف')),
                ]),
                _numberField(_alkalinity, 'القلوية (مجم/لتر CaCO3)'),
                DropdownButtonFormField<String>(
                  initialValue: _acid,
                  decoration: const InputDecoration(
                    labelText: 'نوع الحمض',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'sulfuric', child: Text('كبريتيك 98%')),
                    DropdownMenuItem(
                        value: 'nitric', child: Text('نيتريك 68%')),
                    DropdownMenuItem(
                        value: 'phosphoric', child: Text('فوسفوريك 85%')),
                  ],
                  onChanged: (value) =>
                      setState(() => _acid = value ?? 'sulfuric'),
                ),
                const SizedBox(height: 8),
                _row(
                  acid.acidLabel,
                  '${acid.mlPer1000L.toStringAsFixed(1)} مل/1000 لتر',
                  bold: true,
                ),
                Text(acid.note,
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'الأرقام إرشادية وتعتمد على تحليل الماء والسماد الفعلي. '
                'ابدأ بنصف الجرعة وراقب النبات قبل التثبيت.',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(
    bool isDark, {
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      );

  Widget _statusChip(
    NutrientElement element,
    NutrientSolutionResult result,
    double target,
  ) {
    if (target <= 0) return const SizedBox.shrink();
    final status = result.statusFor(element, target);
    final (label, color) = switch (status) {
      'deficit' => ('${element.symbol}: أقل من الهدف', Colors.orange),
      'excess' => ('${element.symbol}: أعلى من الهدف', Colors.red),
      _ => ('${element.symbol}: مطابق', _green),
    };
    return Chip(
      label: Text(label, style: TextStyle(fontSize: 10, color: color)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      visualDensity: VisualDensity.compact,
    );
  }

  String _shareText(
    NutrientSolutionResult result,
    List<MapEntry<FertilizerProduct, double>> doses,
    AcidDose acid,
  ) {
    final buffer = StringBuffer()
      ..writeln('🌱 وصفة محلول التغذية')
      ..writeln('الحجم: ${result.liters.toStringAsFixed(0)} لتر');
    for (final entry in doses) {
      buffer.writeln(
          '• ${entry.key.name}: ${entry.value.toStringAsFixed(1)} جم');
    }
    buffer
      ..writeln(
          'N ${result.nitrogenPpm.toStringAsFixed(0)} · P ${result.phosphorusPpm.toStringAsFixed(0)} · K ${result.potassiumPpm.toStringAsFixed(0)} ppm')
      ..writeln('EC ≈ ${result.estimatedEcDsM.toStringAsFixed(2)} dS/m')
      ..writeln(
          '${acid.acidLabel}: ${acid.mlPer1000L.toStringAsFixed(1)} مل/1000 لتر');
    return buffer.toString();
  }
}
