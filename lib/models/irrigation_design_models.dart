/// نماذج مستقلة لتصميم شبكات الري وتنسيق المواقع.
///
/// لا تعتمد هذه الطبقة على Flutter أو Firebase، ويمكن استخدامها في التخزين
/// المحلي، Firestore (بعد تحويل JSON)، أو واجهة التصميم.
library;

const double _epsilon = 1e-9;

Never _invalid(Object value, String message) =>
    throw ArgumentError.value(value, null, message);

String _requiredText(String value, String field) {
  if (value.trim().isEmpty) _invalid(value, 'يجب ألا يكون $field فارغًا');
  return value.trim();
}

double _finiteNumber(num value, String field, {double? min, double? max}) {
  final result = value.toDouble();
  if (!result.isFinite) _invalid(value, 'يجب أن تكون قيمة $field رقمًا منتهيًا');
  if (min != null && result < min) _invalid(value, '$field أصغر من الحد المسموح');
  if (max != null && result > max) _invalid(value, '$field أكبر من الحد المسموح');
  return result;
}

int _integer(num value, String field, {int? min, int? max}) {
  final result = value.toInt();
  if (value.toDouble() != result.toDouble()) _invalid(value, '$field يجب أن يكون عددًا صحيحًا');
  if (min != null && result < min) _invalid(value, '$field أصغر من الحد المسموح');
  if (max != null && result > max) _invalid(value, '$field أكبر من الحد المسموح');
  return result;
}

String? _optionalText(String? value) => value?.trim().isEmpty == true ? null : value?.trim();

double _jsonDouble(Object? value, String field) {
  if (value is num) return _finiteNumber(value, field);
  final parsed = double.tryParse(value?.toString() ?? '');
  if (parsed == null) _invalid(value ?? '', '$field غير صالح');
  return _finiteNumber(parsed, field);
}

Map<String, dynamic> _map(Object? value, String field) {
  if (value is! Map) _invalid(value ?? '', '$field يجب أن يكون كائن JSON');
  return Map<String, dynamic>.from(value);
}

List<T> _objects<T>(Object? value, String field, T Function(Map<String, dynamic>) parse) {
  if (value == null) return const [];
  if (value is! List) _invalid(value, '$field يجب أن تكون قائمة');
  return List<T>.unmodifiable(value.map((item) => parse(_map(item, field))));
}

Map<String, dynamic> _copyJson(Map<String, dynamic> value) =>
    Map<String, dynamic>.unmodifiable(value);

/// نقطة جغرافية، بصيغة WGS84 وبدرجات عشرية.
class GeoCoordinate {
  final double latitude;
  final double longitude;
  const GeoCoordinate({required this.latitude, required this.longitude})
      : assert(latitude >= -90 && latitude <= 90),
        assert(longitude >= -180 && longitude <= 180);

  factory GeoCoordinate.checked({required num latitude, required num longitude}) {
    final lat = _finiteNumber(latitude, 'latitude', min: -90, max: 90);
    final lon = _finiteNumber(longitude, 'longitude', min: -180, max: 180);
    return GeoCoordinate(latitude: lat, longitude: lon);
  }

  factory GeoCoordinate.fromJson(Map<String, dynamic> json) => GeoCoordinate.checked(
        latitude: _jsonDouble(json['latitude'] ?? json['lat'], 'latitude'),
        longitude: _jsonDouble(json['longitude'] ?? json['lng'] ?? json['lon'], 'longitude'),
      );

  Map<String, dynamic> toJson() => {'latitude': latitude, 'longitude': longitude};
}

/// حدود الموقع كحلقة مضلعة مغلقة منطقيًا (لا يلزم تكرار النقطة الأولى).
class SiteBoundary {
  final String id;
  final String nameAr;
  final String nameEn;
  final List<GeoCoordinate> points;
  final String areaUnit;
  final double? declaredArea;

  SiteBoundary({required this.id, this.nameAr = '', this.nameEn = '', required List<GeoCoordinate> points, this.areaUnit = 'm2', this.declaredArea})
      : points = List<GeoCoordinate>.unmodifiable(points) {
    _requiredText(id, 'معرّف الحدود');
    if (this.points.length < 3) _invalid(points, 'يجب أن تحتوي الحدود على ثلاث نقاط على الأقل');
    if (!{'m2', 'ha', 'feddan'}.contains(areaUnit)) _invalid(areaUnit, 'وحدة المساحة غير مدعومة');
    if (declaredArea != null) _finiteNumber(declaredArea!, 'المساحة', min: _epsilon);
  }

  factory SiteBoundary.fromJson(Map<String, dynamic> json) => SiteBoundary(
        id: _requiredText(json['id']?.toString() ?? '', 'معرّف الحدود'),
        nameAr: json['name_ar']?.toString() ?? '', nameEn: json['name_en']?.toString() ?? '',
        points: _objects(json['points'], 'points', GeoCoordinate.fromJson),
        areaUnit: json['area_unit']?.toString() ?? 'm2',
        declaredArea: json['declared_area'] == null ? null : _jsonDouble(json['declared_area'], 'declared_area'),
      );
  Map<String, dynamic> toJson() => {'id': id, 'name_ar': nameAr, 'name_en': nameEn, 'points': points.map((p) => p.toJson()).toList(growable: false), 'area_unit': areaUnit, 'declared_area': declaredArea};
}

class PlantSpecies {
  final String id; final String nameAr; final String nameEn;
  final double kc; final double salinityResistance; final double droughtResistance;
  final String? growthStage; final String? notes;
  PlantSpecies({required this.id, this.nameAr = '', this.nameEn = '', required num kc, required num salinityResistance, required num droughtResistance, this.growthStage, this.notes})
      : kc = _finiteNumber(kc, 'Kc', min: 0, max: 2.5),
        salinityResistance = _finiteNumber(salinityResistance, 'مقاومة الملوحة', min: 0, max: 1),
        droughtResistance = _finiteNumber(droughtResistance, 'مقاومة الجفاف', min: 0, max: 1) { _requiredText(id, 'معرّف النبات'); }
  factory PlantSpecies.fromJson(Map<String, dynamic> j) => PlantSpecies(id: _requiredText(j['id']?.toString() ?? '', 'معرّف النبات'), nameAr: j['name_ar']?.toString() ?? '', nameEn: j['name_en']?.toString() ?? '', kc: _jsonDouble(j['kc'], 'Kc'), salinityResistance: _jsonDouble(j['salinity_resistance'], 'مقاومة الملوحة'), droughtResistance: _jsonDouble(j['drought_resistance'], 'مقاومة الجفاف'), growthStage: _optionalText(j['growth_stage']?.toString()), notes: _optionalText(j['notes']?.toString()));
  Map<String, dynamic> toJson() => {'id': id, 'name_ar': nameAr, 'name_en': nameEn, 'kc': kc, 'salinity_resistance': salinityResistance, 'drought_resistance': droughtResistance, 'growth_stage': growthStage, 'notes': notes};
}

class IrrigationEquipment {
  final String id; final String nameAr; final String nameEn; final String type; final String manufacturer;
  final double flowRateLpm; final double operatingPressureBar; final int quantity;
  IrrigationEquipment({required this.id, this.nameAr = '', this.nameEn = '', required this.type, this.manufacturer = '', required num flowRateLpm, required num operatingPressureBar, int quantity = 1})
      : flowRateLpm = _finiteNumber(flowRateLpm, 'التصرف', min: _epsilon), operatingPressureBar = _finiteNumber(operatingPressureBar, 'ضغط التشغيل', min: 0), quantity = _integer(quantity, 'الكمية', min: 1) { _requiredText(id, 'معرّف المعدة'); _requiredText(type, 'نوع المعدة'); }
  factory IrrigationEquipment.fromJson(Map<String, dynamic> j) => IrrigationEquipment(id: j['id']?.toString() ?? '', nameAr: j['name_ar']?.toString() ?? '', nameEn: j['name_en']?.toString() ?? '', type: j['type']?.toString() ?? '', manufacturer: j['manufacturer']?.toString() ?? '', flowRateLpm: _jsonDouble(j['flow_rate_lpm'], 'flow_rate_lpm'), operatingPressureBar: _jsonDouble(j['operating_pressure_bar'], 'operating_pressure_bar'), quantity: (j['quantity'] as num?)?.toInt() ?? 1);
  Map<String, dynamic> toJson() => {'id': id, 'name_ar': nameAr, 'name_en': nameEn, 'type': type, 'manufacturer': manufacturer, 'flow_rate_lpm': flowRateLpm, 'operating_pressure_bar': operatingPressureBar, 'quantity': quantity};
}

class Pipe {
  final String id; final String nameAr; final String nameEn; final String material; final String diameterUnit;
  final double diameter; final double lengthM; final double? flowRateLpm; final double? pressureRatingBar;
  Pipe({required this.id, this.nameAr = '', this.nameEn = '', required this.material, this.diameterUnit = 'mm', required num diameter, required num lengthM, this.flowRateLpm, this.pressureRatingBar})
      : diameter = _finiteNumber(diameter, 'قطر الأنبوب', min: _epsilon), lengthM = _finiteNumber(lengthM, 'طول الأنبوب', min: _epsilon) {
    _requiredText(id, 'معرّف الأنبوب'); _requiredText(material, 'مادة الأنبوب');
    if (!{'mm', 'in'}.contains(diameterUnit)) _invalid(diameterUnit, 'وحدة القطر غير مدعومة');
    if (flowRateLpm != null) _finiteNumber(flowRateLpm!, 'تصرف الأنبوب', min: 0);
    if (pressureRatingBar != null) _finiteNumber(pressureRatingBar!, 'تصنيف ضغط الأنبوب', min: 0);
  }
  factory Pipe.fromJson(Map<String, dynamic> j) => Pipe(id: j['id']?.toString() ?? '', nameAr: j['name_ar']?.toString() ?? '', nameEn: j['name_en']?.toString() ?? '', material: j['material']?.toString() ?? '', diameterUnit: j['diameter_unit']?.toString() ?? 'mm', diameter: _jsonDouble(j['diameter'], 'diameter'), lengthM: _jsonDouble(j['length_m'], 'length_m'), flowRateLpm: j['flow_rate_lpm'] == null ? null : _jsonDouble(j['flow_rate_lpm'], 'flow_rate_lpm'), pressureRatingBar: j['pressure_rating_bar'] == null ? null : _jsonDouble(j['pressure_rating_bar'], 'pressure_rating_bar'));
  Map<String, dynamic> toJson() => {'id': id, 'name_ar': nameAr, 'name_en': nameEn, 'material': material, 'diameter_unit': diameterUnit, 'diameter': diameter, 'length_m': lengthM, 'flow_rate_lpm': flowRateLpm, 'pressure_rating_bar': pressureRatingBar};
}

class Valve {
  final String id; final String nameAr; final String nameEn; final String type; final String? zoneId;
  final double diameterMm; final double? flowRateLpm; final bool normallyOpen;
  Valve({required this.id, this.nameAr = '', this.nameEn = '', required this.type, this.zoneId, required num diameterMm, this.flowRateLpm, this.normallyOpen = false})
      : diameterMm = _finiteNumber(diameterMm, 'قطر المحبس', min: _epsilon) { _requiredText(id, 'معرّف المحبس'); _requiredText(type, 'نوع المحبس'); if (flowRateLpm != null) _finiteNumber(flowRateLpm!, 'تصرف المحبس', min: 0); }
  factory Valve.fromJson(Map<String, dynamic> j) => Valve(id: j['id']?.toString() ?? '', nameAr: j['name_ar']?.toString() ?? '', nameEn: j['name_en']?.toString() ?? '', type: j['type']?.toString() ?? '', zoneId: _optionalText(j['zone_id']?.toString()), diameterMm: _jsonDouble(j['diameter_mm'], 'diameter_mm'), flowRateLpm: j['flow_rate_lpm'] == null ? null : _jsonDouble(j['flow_rate_lpm'], 'flow_rate_lpm'), normallyOpen: j['normally_open'] == true);
  Map<String, dynamic> toJson() => {'id': id, 'name_ar': nameAr, 'name_en': nameEn, 'type': type, 'zone_id': zoneId, 'diameter_mm': diameterMm, 'flow_rate_lpm': flowRateLpm, 'normally_open': normallyOpen};
}

class IrrigationZone {
  final String id; final String nameAr; final String nameEn; final String method; final String? plantId;
  final List<String> equipmentIds; final List<String> pipeIds; final List<String> valveIds;
  final double areaM2; final double designFlowLpm; final double applicationRateMmH;
  IrrigationZone({required this.id, this.nameAr = '', this.nameEn = '', required this.method, this.plantId, List<String> equipmentIds = const [], List<String> pipeIds = const [], List<String> valveIds = const [], required num areaM2, required num designFlowLpm, required num applicationRateMmH})
      : areaM2 = _finiteNumber(areaM2, 'مساحة المنطقة', min: _epsilon), designFlowLpm = _finiteNumber(designFlowLpm, 'التصرف التصميمي', min: _epsilon), applicationRateMmH = _finiteNumber(applicationRateMmH, 'معدل التطبيق', min: _epsilon), equipmentIds = List<String>.unmodifiable(equipmentIds), pipeIds = List<String>.unmodifiable(pipeIds), valveIds = List<String>.unmodifiable(valveIds) { _requiredText(id, 'معرّف المنطقة'); _requiredText(method, 'طريقة الري'); }
  factory IrrigationZone.fromJson(Map<String, dynamic> j) => IrrigationZone(id: j['id']?.toString() ?? '', nameAr: j['name_ar']?.toString() ?? '', nameEn: j['name_en']?.toString() ?? '', method: j['method']?.toString() ?? '', plantId: _optionalText(j['plant_id']?.toString()), equipmentIds: List<String>.from(j['equipment_ids'] ?? const []), pipeIds: List<String>.from(j['pipe_ids'] ?? const []), valveIds: List<String>.from(j['valve_ids'] ?? const []), areaM2: _jsonDouble(j['area_m2'], 'area_m2'), designFlowLpm: _jsonDouble(j['design_flow_lpm'], 'design_flow_lpm'), applicationRateMmH: _jsonDouble(j['application_rate_mm_h'], 'application_rate_mm_h'));
  Map<String, dynamic> toJson() => {'id': id, 'name_ar': nameAr, 'name_en': nameEn, 'method': method, 'plant_id': plantId, 'equipment_ids': equipmentIds, 'pipe_ids': pipeIds, 'valve_ids': valveIds, 'area_m2': areaM2, 'design_flow_lpm': designFlowLpm, 'application_rate_mm_h': applicationRateMmH};
}

class Pump {
  final String id; final String nameAr; final String nameEn; final String type;
  final double flowRateLpm; final double headM; final double powerKw; final double efficiency;
  Pump({required this.id, this.nameAr = '', this.nameEn = '', required this.type, required num flowRateLpm, required num headM, required num powerKw, required num efficiency})
      : flowRateLpm = _finiteNumber(flowRateLpm, 'تصرف المضخة', min: _epsilon), headM = _finiteNumber(headM, 'رفع المضخة', min: _epsilon), powerKw = _finiteNumber(powerKw, 'قدرة المضخة', min: _epsilon), efficiency = _finiteNumber(efficiency, 'كفاءة المضخة', min: _epsilon, max: 1) { _requiredText(id, 'معرّف المضخة'); _requiredText(type, 'نوع المضخة'); }
  factory Pump.fromJson(Map<String, dynamic> j) => Pump(id: j['id']?.toString() ?? '', nameAr: j['name_ar']?.toString() ?? '', nameEn: j['name_en']?.toString() ?? '', type: j['type']?.toString() ?? '', flowRateLpm: _jsonDouble(j['flow_rate_lpm'], 'flow_rate_lpm'), headM: _jsonDouble(j['head_m'], 'head_m'), powerKw: _jsonDouble(j['power_kw'], 'power_kw'), efficiency: _jsonDouble(j['efficiency'], 'efficiency'));
  Map<String, dynamic> toJson() => {'id': id, 'name_ar': nameAr, 'name_en': nameEn, 'type': type, 'flow_rate_lpm': flowRateLpm, 'head_m': headM, 'power_kw': powerKw, 'efficiency': efficiency};
}

class ElevationPoint {
  final String id; final String? label; final GeoCoordinate coordinate; final double elevationM;
  ElevationPoint({required this.id, this.label, required this.coordinate, required num elevationM}) : elevationM = _finiteNumber(elevationM, 'الارتفاع', min: -11000, max: 9000) { _requiredText(id, 'معرّف نقطة الارتفاع'); }
  factory ElevationPoint.fromJson(Map<String, dynamic> j) => ElevationPoint(id: j['id']?.toString() ?? '', label: _optionalText(j['label']?.toString()), coordinate: GeoCoordinate.fromJson(_map(j['coordinate'], 'coordinate')), elevationM: _jsonDouble(j['elevation_m'], 'elevation_m'));
  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'coordinate': coordinate.toJson(), 'elevation_m': elevationM};
}

class DesignVersion {
  final int major; final int minor; final int patch; final String? label; final DateTime createdAt; final String? authorId;
  const DesignVersion({required this.major, required this.minor, required this.patch, this.label, required this.createdAt, this.authorId})
      : assert(major >= 0), assert(minor >= 0), assert(patch >= 0);
  factory DesignVersion.fromJson(Map<String, dynamic> j) => DesignVersion(major: _integer(j['major'] as num, 'major', min: 0), minor: _integer(j['minor'] as num, 'minor', min: 0), patch: _integer(j['patch'] as num, 'patch', min: 0), label: _optionalText(j['label']?.toString()), createdAt: DateTime.parse(j['created_at'] as String), authorId: _optionalText(j['author_id']?.toString()));
  Map<String, dynamic> toJson() => {'major': major, 'minor': minor, 'patch': patch, 'label': label, 'created_at': createdAt.toIso8601String(), 'author_id': authorId};
  @override String toString() => '$major.$minor.$patch${label == null ? '' : '-$label'}';
}

class IrrigationDesignProject {
  final String id; final String nameAr; final String nameEn; final String? description;
  final SiteBoundary siteBoundary; final List<PlantSpecies> plants; final List<IrrigationEquipment> equipment;
  final List<Pipe> pipes; final List<Valve> valves; final List<IrrigationZone> zones; final Pump pump;
  final List<ElevationPoint> elevationPoints; final DesignVersion version;
  IrrigationDesignProject({required this.id, this.nameAr = '', this.nameEn = '', this.description, required this.siteBoundary, List<PlantSpecies> plants = const [], List<IrrigationEquipment> equipment = const [], List<Pipe> pipes = const [], List<Valve> valves = const [], List<IrrigationZone> zones = const [], required this.pump, List<ElevationPoint> elevationPoints = const [], required this.version})
      : plants = List<PlantSpecies>.unmodifiable(plants), equipment = List<IrrigationEquipment>.unmodifiable(equipment), pipes = List<Pipe>.unmodifiable(pipes), valves = List<Valve>.unmodifiable(valves), zones = List<IrrigationZone>.unmodifiable(zones), elevationPoints = List<ElevationPoint>.unmodifiable(elevationPoints) { _requiredText(id, 'معرّف المشروع'); }
  factory IrrigationDesignProject.fromJson(Map<String, dynamic> j) => IrrigationDesignProject(id: j['id']?.toString() ?? '', nameAr: j['name_ar']?.toString() ?? '', nameEn: j['name_en']?.toString() ?? '', description: _optionalText(j['description']?.toString()), siteBoundary: SiteBoundary.fromJson(_map(j['site_boundary'], 'site_boundary')), plants: _objects(j['plants'], 'plants', PlantSpecies.fromJson), equipment: _objects(j['equipment'], 'equipment', IrrigationEquipment.fromJson), pipes: _objects(j['pipes'], 'pipes', Pipe.fromJson), valves: _objects(j['valves'], 'valves', Valve.fromJson), zones: _objects(j['zones'], 'zones', IrrigationZone.fromJson), pump: Pump.fromJson(_map(j['pump'], 'pump')), elevationPoints: _objects(j['elevation_points'], 'elevation_points', ElevationPoint.fromJson), version: DesignVersion.fromJson(_map(j['version'], 'version')));
  Map<String, dynamic> toJson() => _copyJson({'id': id, 'name_ar': nameAr, 'name_en': nameEn, 'description': description, 'site_boundary': siteBoundary.toJson(), 'plants': plants.map((x) => x.toJson()).toList(growable: false), 'equipment': equipment.map((x) => x.toJson()).toList(growable: false), 'pipes': pipes.map((x) => x.toJson()).toList(growable: false), 'valves': valves.map((x) => x.toJson()).toList(growable: false), 'zones': zones.map((x) => x.toJson()).toList(growable: false), 'pump': pump.toJson(), 'elevation_points': elevationPoints.map((x) => x.toJson()).toList(growable: false), 'version': version.toJson()});
}

// أسماء بديلة موجزة مناسبة للواجهات القديمة أو وحدات التكامل.
typedef Coordinate = GeoCoordinate;
typedef Plant = PlantSpecies;
typedef Equipment = IrrigationEquipment;
typedef DesignProject = IrrigationDesignProject;
