import 'package:cloud_firestore/cloud_firestore.dart';

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
    final data = doc.data() as Map<String, dynamic>;
    return CalculatorSection(
      id: doc.id,
      name: data['name'] ?? '',
      emoji: data['emoji'] ?? '🌱',
      subtitle: data['subtitle'] ?? '',
      primaryColor: data['primary_color'] ?? '#047857',
      secondaryColor: data['secondary_color'] ?? '#10B981',
      order: (data['order'] as num?)?.toInt() ?? 0,
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
      id: m['id'] ?? '',
      label: m['label'] ?? '',
      type: m['type'] ?? 'text',
      unit: m['unit'],
      hint: m['hint'],
      required: m['required'] ?? true,
      options: (m['options'] as List<dynamic>? ?? [])
          .map((e) => Map<String, String>.from(e as Map))
          .toList(),
      min: (m['min'] as num?)?.toDouble(),
      max: (m['max'] as num?)?.toDouble(),
      defaultValue: (m['default'] as num?)?.toDouble(),
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
        title: m['title'] ?? '',
        description: m['description'] ?? '',
        dayFromStart: (m['day_from_start'] as num?)?.toInt() ?? 0,
        category: m['category'] ?? 'عام',
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
        name: m['name'] ?? '',
        category: m['category'] ?? 'عام',
        quantityPerUnit: (m['quantity_per_unit'] as num?)?.toDouble() ?? 0,
        unit: m['unit'] ?? 'كجم',
        estimatedPricePerUnit:
            (m['price_per_unit'] as num?)?.toDouble() ?? 0,
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
    if (m['cost_distribution'] != null) {
      (m['cost_distribution'] as Map<String, dynamic>).forEach((k, v) {
        dist[k] = (v as num).toDouble();
      });
    }
    return CalculatorFinancial(
      expectedYieldPerUnit: (m['expected_yield'] as num?)?.toDouble() ?? 0,
      yieldUnit: m['yield_unit'] ?? 'طن',
      expectedPricePerYieldUnit:
          (m['expected_price'] as num?)?.toDouble() ?? 0,
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
    final data = doc.data() as Map<String, dynamic>;
    return CalculatorTemplate(
      id: doc.id,
      sectionId: data['section_id'] ?? '',
      name: data['name'] ?? '',
      emoji: data['emoji'] ?? '🌱',
      description: data['description'] ?? '',
      areaUnit: data['area_unit'] ?? 'فدان',
      areaUnitLabel: data['area_unit_label'] ?? 'المساحة',
      fields: (data['fields'] as List<dynamic>? ?? [])
          .map((e) => FormFieldConfig.fromMap(e as Map<String, dynamic>))
          .toList(),
      tasks: (data['tasks'] as List<dynamic>? ?? [])
          .map((e) => CalculatorTask.fromMap(e as Map<String, dynamic>))
          .toList(),
      materials: (data['materials'] as List<dynamic>? ?? [])
          .map((e) => CalculatorMaterial.fromMap(e as Map<String, dynamic>))
          .toList(),
      financial: CalculatorFinancial.fromMap(
          data['financial'] as Map<String, dynamic>? ?? {}),
    );
  }
}
