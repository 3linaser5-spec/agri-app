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

// ✅ إحداثيات محافظة
class GovernorateInfo {
  final String name;
  final double lat;
  final double lon;
  final String zoneId;

  const GovernorateInfo({
    required this.name,
    required this.lat,
    required this.lon,
    required this.zoneId,
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

  // ============ كل المحافظات مع الإحداثيات ============
  static const List<GovernorateInfo> governorates = [
    // الساحل الشمالي
    GovernorateInfo(name: 'الإسكندرية', lat: 31.2001, lon: 29.9187, zoneId: 'north_coast'),
    GovernorateInfo(name: 'مطروح', lat: 31.3543, lon: 27.2373, zoneId: 'north_coast'),
    GovernorateInfo(name: 'كفر الشيخ', lat: 31.1097, lon: 30.9397, zoneId: 'north_coast'),
    GovernorateInfo(name: 'البحيرة', lat: 30.8481, lon: 30.3436, zoneId: 'north_coast'),
    GovernorateInfo(name: 'دمياط', lat: 31.4165, lon: 31.8133, zoneId: 'north_coast'),
    GovernorateInfo(name: 'بورسعيد', lat: 31.2653, lon: 32.3019, zoneId: 'north_coast'),

    // الدلتا
    GovernorateInfo(name: 'القاهرة', lat: 30.0444, lon: 31.2357, zoneId: 'delta'),
    GovernorateInfo(name: 'الجيزة', lat: 30.0131, lon: 31.2089, zoneId: 'delta'),
    GovernorateInfo(name: 'القليوبية', lat: 30.3612, lon: 31.2000, zoneId: 'delta'),
    GovernorateInfo(name: 'المنوفية', lat: 30.5972, lon: 30.9876, zoneId: 'delta'),
    GovernorateInfo(name: 'الغربية', lat: 30.8754, lon: 31.0335, zoneId: 'delta'),
    GovernorateInfo(name: 'الدقهلية', lat: 31.0409, lon: 31.3785, zoneId: 'delta'),
    GovernorateInfo(name: 'الشرقية', lat: 30.5877, lon: 31.5020, zoneId: 'delta'),
    GovernorateInfo(name: 'الإسماعيلية', lat: 30.5965, lon: 32.2715, zoneId: 'delta'),
    GovernorateInfo(name: 'السويس', lat: 29.9737, lon: 32.5263, zoneId: 'delta'),

    // مصر الوسطى
    GovernorateInfo(name: 'الفيوم', lat: 29.3084, lon: 30.8428, zoneId: 'middle_egypt'),
    GovernorateInfo(name: 'بني سويف', lat: 29.0661, lon: 31.0994, zoneId: 'middle_egypt'),
    GovernorateInfo(name: 'المنيا', lat: 28.1099, lon: 30.7503, zoneId: 'middle_egypt'),
    GovernorateInfo(name: 'أسيوط', lat: 27.1809, lon: 31.1837, zoneId: 'middle_egypt'),

    // الصعيد
    GovernorateInfo(name: 'سوهاج', lat: 26.5591, lon: 31.6957, zoneId: 'upper_egypt'),
    GovernorateInfo(name: 'قنا', lat: 26.1551, lon: 32.7160, zoneId: 'upper_egypt'),
    GovernorateInfo(name: 'الأقصر', lat: 25.6872, lon: 32.6396, zoneId: 'upper_egypt'),
    GovernorateInfo(name: 'أسوان', lat: 24.0889, lon: 32.8998, zoneId: 'upper_egypt'),

    // سيناء والواحات
    GovernorateInfo(name: 'شمال سيناء', lat: 31.1259, lon: 33.7983, zoneId: 'sinai_oases'),
    GovernorateInfo(name: 'جنوب سيناء', lat: 29.3196, lon: 34.0166, zoneId: 'sinai_oases'),
    GovernorateInfo(name: 'البحر الأحمر', lat: 26.4724, lon: 33.7686, zoneId: 'sinai_oases'),
    GovernorateInfo(name: 'الوادي الجديد', lat: 25.4395, lon: 30.5526, zoneId: 'sinai_oases'),
  ];

  // ============ المحافظات مقسمة حسب المنطقة ============
  static const Map<String, List<String>> governoratesByZone = {
    'north_coast': [
      'الإسكندرية', 'مطروح', 'كفر الشيخ', 'البحيرة', 'دمياط', 'بورسعيد',
    ],
    'delta': [
      'القاهرة', 'الجيزة', 'القليوبية', 'المنوفية', 'الغربية',
      'الدقهلية', 'الشرقية', 'الإسماعيلية', 'السويس',
    ],
    'middle_egypt': ['الفيوم', 'بني سويف', 'المنيا', 'أسيوط'],
    'upper_egypt': ['سوهاج', 'قنا', 'الأقصر', 'أسوان'],
    'sinai_oases': ['شمال سيناء', 'جنوب سيناء', 'البحر الأحمر', 'الوادي الجديد'],
  };

  // كل المحافظات (قائمة مسطحة)
  static List<String> get allGovernorates {
    return governorates.map((g) => g.name).toList();
  }

  // إيجاد المحافظة بالاسم
  static GovernorateInfo? getGovernorateInfo(String name) {
    try {
      return governorates.firstWhere((g) => g.name == name);
    } catch (e) {
      return null;
    }
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
