/// نماذج قائمة المشتريات (BOQ) الناتجة من تصميم الري أو اللاندسكيب.
///
/// قائمة كميات بدون أسعار: الصنف والمواصفات والوحدة والكمية فقط، عشان
/// المستخدم يبعتها للمورد وياخد منها عروض أسعار.
///
/// الملف نقي بدون Flutter أو قاعدة بيانات، عشان يتختبر بسهولة.
library;

/// أنواع البوليصة: أنظمة الحاسبة الأربعة، أو تصميم متكامل، أو لاندسكيب.
enum IrrigationSystemKind { drip, sprinkler, surface, pivot, mixed, landscape }

const Map<IrrigationSystemKind, String> irrigationSystemKindLabels = {
  IrrigationSystemKind.drip: 'تنقيط',
  IrrigationSystemKind.sprinkler: 'رش',
  IrrigationSystemKind.surface: 'سطحي',
  IrrigationSystemKind.pivot: 'محوري',
  IrrigationSystemKind.mixed: 'تصميم متكامل',
  IrrigationSystemKind.landscape: 'لاندسكيب',
};

/// بند واحد في القائمة: صنف بكمية ووحدة.
class IrrigationBomItem {
  /// كود ثابت للبند.
  final String code;
  final String category;
  final String name;
  final String spec;
  final String unit;
  final double quantity;

  const IrrigationBomItem({
    required this.code,
    required this.category,
    required this.name,
    this.spec = '',
    required this.unit,
    required this.quantity,
  });

  Map<String, Object?> toJson() => {
        'code': code,
        'category': category,
        'name': name,
        'spec': spec,
        'unit': unit,
        'quantity': quantity,
      };
}

/// قائمة المشتريات كاملة لنظام ري أو لتصميم.
class IrrigationBom {
  final IrrigationSystemKind system;

  /// اسم التصميم المحفوظ (لو القائمة جاية من تصميم المستخدم).
  final String name;
  final double areaFeddan;
  final List<IrrigationBomItem> items;
  final List<String> notes;

  const IrrigationBom({
    required this.system,
    this.name = '',
    required this.areaFeddan,
    required this.items,
    this.notes = const [],
  });

  String get systemLabel => irrigationSystemKindLabels[system] ?? '';

  int get lines => items.length;

  /// البنود مجمّعة حسب الفئة مع الحفاظ على ترتيب ظهورها.
  Map<String, List<IrrigationBomItem>> get grouped {
    final map = <String, List<IrrigationBomItem>>{};
    for (final item in items) {
      map.putIfAbsent(item.category, () => <IrrigationBomItem>[]).add(item);
    }
    return map;
  }

  IrrigationBom copyWith({
    List<IrrigationBomItem>? items,
    List<String>? notes,
    double? areaFeddan,
    String? name,
  }) =>
      IrrigationBom(
        system: system,
        name: name ?? this.name,
        areaFeddan: areaFeddan ?? this.areaFeddan,
        items: items ?? this.items,
        notes: notes ?? this.notes,
      );

  Map<String, Object?> toJson() => {
        'system': system.name,
        'name': name,
        'area_feddan': areaFeddan,
        'items': items.map((item) => item.toJson()).toList(growable: false),
        'notes': notes,
      };
}
