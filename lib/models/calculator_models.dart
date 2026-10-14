import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/safe_parse.dart';

// ============= قسم (الحقلية، البستانية، إلخ) =============
class CalculatorSection {
  final String id;
  final String name;
  final String emoji;
  final String subtitle;
  final String primaryColor;
  final String secondaryColor;
  final int order;

  CalculatorSection({
    required this.id,
    required this.name,
    required this.emoji,
    required this.subtitle,
    required this.primaryColor,
    required this.secondaryColor,
    required this.order,
  });

  factory CalculatorSection.fromFirestore(DocumentSnapshot doc) {
    final data = SafeParse.map(doc.data());
    return CalculatorSection(
      id: doc.id,
      name: SafeParse.string(data['name']),
      emoji: SafeParse.string(data['emoji'], '🌱'),
      subtitle: SafeParse.string(data['subtitle']),
      primaryColor: SafeParse.string(data['primary_color'], '#047857'),
      secondaryColor: SafeParse.string(data['secondary_color'], '#10B981'),
      order: SafeParse.integer(data['order']),
    );
  }
}

// ============= حقل إدخال (ديناميكي) =============
class FormFieldConfig {
  final String id;
  final String label;
  final String type;
  final String? unit;
  final String? hint;
  final bool required;
  final List<Map<String, String>> options;
  final double? min;
  final double? max;
  final double? defaultValue;

  FormFieldConfig({
    required this.id,
    required this.label,
    required this.type,
    this.unit,
    this.hint,
    this.required = true,
    this.options = const [],
    this.min,
    this.max,
    this.defaultValue,
  });

  factory FormFieldConfig.fromMap(Map<String, dynamic> m) {
    return FormFieldConfig(
      id: SafeParse.string(m['id']),
      label: SafeParse.string(m['label']),
      type: SafeParse.string(m['type'], 'text'),
      unit: SafeParse.stringOrNull(m['unit']),
      hint: SafeParse.stringOrNull(m['hint']),
      required: m['required'] is bool ? m['required'] as bool : true,
      options: SafeParse.stringMapList(m['options']),
      min: SafeParse.doubleOrNull(m['min']),
      max: SafeParse.doubleOrNull(m['max']),
      defaultValue: SafeParse.doubleOrNull(m['default']),
    );
  }
}

// ============= مهمة في الجدول الزمني =============
class CalculatorTask {
  final String title;
  final String description;
  final int dayFromStart;
  final String category;

  CalculatorTask({
    required this.title,
    required this.description,
    required this.dayFromStart,
    required this.category,
  });

  factory CalculatorTask.fromMap(Map<String, dynamic> m) => CalculatorTask(
        title: SafeParse.string(m['title']),
        description: SafeParse.string(m['description']),
        dayFromStart: SafeParse.integer(m['day_from_start']),
        category: SafeParse.string(m['category'], 'عام'),
      );
}

// ============= مادة في قائمة المشتريات =============
class CalculatorMaterial {
  final String name;
  final String category;
  final double quantityPerUnit;
  final String unit;
  final double estimatedPricePerUnit;

  CalculatorMaterial({
    required this.name,
    required this.category,
    required this.quantityPerUnit,
    required this.unit,
    required this.estimatedPricePerUnit,
  });

  factory CalculatorMaterial.fromMap(Map<String, dynamic> m) =>
      CalculatorMaterial(
        name: SafeParse.string(m['name']),
        category: SafeParse.string(m['category'], 'عام'),
        quantityPerUnit: SafeParse.decimal(m['quantity_per_unit']),
        unit: SafeParse.string(m['unit'], 'كجم'),
        estimatedPricePerUnit: SafeParse.decimal(m['price_per_unit']),
      );
}

// ============= التحليل المالي =============
class CalculatorFinancial {
  final double expectedYieldPerUnit;
  final String yieldUnit;
  final double expectedPricePerYieldUnit;
  final Map<String, double> costDistribution;

  CalculatorFinancial({
    required this.expectedYieldPerUnit,
    required this.yieldUnit,
    required this.expectedPricePerYieldUnit,
    required this.costDistribution,
  });

  factory CalculatorFinancial.fromMap(Map<String, dynamic> m) {
    final dist = <String, double>{};
    SafeParse.map(m['cost_distribution']).forEach((k, v) {
      final n = SafeParse.doubleOrNull(v);
      if (n != null) dist[k] = n;
    });
    return CalculatorFinancial(
      expectedYieldPerUnit: SafeParse.decimal(m['expected_yield']),
      yieldUnit: SafeParse.string(m['yield_unit'], 'طن'),
      expectedPricePerYieldUnit: SafeParse.decimal(m['expected_price']),
      costDistribution: dist,
    );
  }
}

// ============= القالب الكامل =============
class CalculatorTemplate {
  final String id;
  final String sectionId;
  final String name;
  final String emoji;
  final String description;
  final String areaUnit;
  final String areaUnitLabel;
  final List<FormFieldConfig> fields;
  final List<CalculatorTask> tasks;
  final List<CalculatorMaterial> materials;
  final CalculatorFinancial financial;

  CalculatorTemplate({
    required this.id,
    required this.sectionId,
    required this.name,
    required this.emoji,
    required this.description,
    required this.areaUnit,
    required this.areaUnitLabel,
    required this.fields,
    required this.tasks,
    required this.materials,
    required this.financial,
  });

  factory CalculatorTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = SafeParse.map(doc.data());
    return CalculatorTemplate(
      id: doc.id,
      sectionId: SafeParse.string(data['section_id']),
      name: SafeParse.string(data['name']),
      emoji: SafeParse.string(data['emoji'], '🌱'),
      description: SafeParse.string(data['description']),
      areaUnit: SafeParse.string(data['area_unit'], 'فدان'),
      areaUnitLabel: SafeParse.string(data['area_unit_label'], 'المساحة'),
      fields:
          SafeParse.mapList(data['fields']).map(FormFieldConfig.fromMap).toList(),
      tasks:
          SafeParse.mapList(data['tasks']).map(CalculatorTask.fromMap).toList(),
      materials: SafeParse.mapList(data['materials'])
          .map(CalculatorMaterial.fromMap)
          .toList(),
      financial: CalculatorFinancial.fromMap(SafeParse.map(data['financial'])),
    );
  }
}
