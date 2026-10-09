// ============= المناطق المناخية الزراعية =============
class ClimateZone {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final List<String> plantingNotes;

  const ClimateZone({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.plantingNotes,
  });
}

class EgyptData {
  // ============ المناطق المناخية ============
  static const List<ClimateZone> climateZones = [
    ClimateZone(
      id: 'north_coast',
      name: 'الساحل الشمالي',
      emoji: '🌊',
      description: 'مناخ متوسطي - أمطار شتوية - رطوبة عالية',
      plantingNotes: [
        'يتأخر فيه ميعاد الزراعة عن باقي المناطق',
        'المناخ مناسب لمحاصيل: الطماطم الشتوية، البطاطس الصيفية',
        'الأمطار الشتوية تساعد في نمو القمح بدون ري',
      ],
    ),
    ClimateZone(
      id: 'delta',
      name: 'الدلتا والوجه البحري',
      emoji: '🌾',
      description: 'مناخ معتدل - أراضٍ طينية خصبة - ري دائم',
      plantingNotes: [
        'أفضل ميعاد لزراعة القمح: 15 نوفمبر - 10 ديسمبر',
        'الأصناف الموصى بها: سخا 94، سخا 95، سخا 96',
        'مناسب لمعظم المحاصيل الشتوية والصيفية',
      ],
    ),
    ClimateZone(
      id: 'middle_egypt',
      name: 'مصر الوسطى',
      emoji: '🌱',
      description: 'مناخ جاف حار صيفاً - معتدل شتاءً',
      plantingNotes: [
        'ميعاد زراعة القمح: 15 - 30 نوفمبر',
        'الأصناف الموصى بها: مصر 1، مصر 3، جيزة 171',
        'مناسب لزراعة البصل والفول والشمام',
      ],
    ),
    ClimateZone(
      id: 'upper_egypt',
      name: 'مصر العليا (الصعيد)',
      emoji: '☀️',
      description: 'مناخ صحراوي - حرارة عالية صيفاً',
      plantingNotes: [
        'أبكر ميعاد زراعة القمح: 11 - 30 نوفمبر',
        'الأصناف الموصى بها: مصر 1، مصر 3، مصر 4',
        'مناسب لقصب السكر، الطماطم النيلية، المانجو',
      ],
    ),
    ClimateZone(
      id: 'sinai_oases',
      name: 'سيناء والواحات',
      emoji: '🏜️',
      description: 'مناخ صحراوي - أمطار قليلة - مياه جوفية',
      plantingNotes: [
        'يعتمد على الري بالآبار والجوفية',
        'مناسب لزراعة الزيتون، النخيل، الخضروات المكشوفة',
        'يحتاج معاملات زراعية خاصة للتعامل مع الملوحة',
      ],
    ),
  ];

  // ============ المحافظات مقسمة حسب المنطقة ============
  static const Map<String, List<String>> governoratesByZone = {
    'north_coast': [
      'الإسكندرية',
      'مطروح',
      'كفر الشيخ',
      'البحيرة',
      'دمياط',
      'بورسعيد',
    ],
    'delta': [
      'القاهرة',
      'الجيزة',
      'القليوبية',
      'المنوفية',
      'الغربية',
      'الدقهلية',
      'الشرقية',
      'الإسماعيلية',
      'السويس',
    ],
    'middle_egypt': [
      'الفيوم',
      'بني سويف',
      'المنيا',
      'أسيوط',
    ],
    'upper_egypt': [
      'سوهاج',
      'قنا',
      'الأقصر',
      'أسوان',
    ],
    'sinai_oases': [
      'شمال سيناء',
      'جنوب سيناء',
      'البحر الأحمر',
      'الوادي الجديد',
    ],
  };

  // كل المحافظات (قائمة مسطحة)
  static List<String> get allGovernorates {
    final list = <String>[];
    for (var govs in governoratesByZone.values) {
      list.addAll(govs);
    }
    return list;
  }

  // إيجاد المنطقة من اسم المحافظة
  static String? getZoneByGovernorate(String governorate) {
    for (var entry in governoratesByZone.entries) {
      if (entry.value.contains(governorate)) {
        return entry.key;
      }
    }
    return null;
  }

  // تفاصيل المنطقة
  static ClimateZone? getZoneDetails(String zoneId) {
    try {
      return climateZones.firstWhere((z) => z.id == zoneId);
    } catch (e) {
      return null;
    }
  }
}
