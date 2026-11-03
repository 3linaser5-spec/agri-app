import 'dart:convert';

import 'package:flutter/services.dart';

class EgyptAdministrativeVillage {
  const EgyptAdministrativeVillage({
    required this.code,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String code;
  final String name;
  final double latitude;
  final double longitude;

  factory EgyptAdministrativeVillage.fromJson(Map<String, dynamic> json) {
    return EgyptAdministrativeVillage(
      code: _requiredString(json, 'code'),
      name: _requiredString(json, 'name'),
      latitude: _requiredDouble(json, 'latitude'),
      longitude: _requiredDouble(json, 'longitude'),
    );
  }
}

/// وحدات المستوى الإداري الثاني؛ وقد تكون مراكز أو أقسامًا أو مدنًا جديدة
/// بحسب التقسيم الإداري لكل محافظة.
class EgyptAdministrativeArea {
  const EgyptAdministrativeArea({
    required this.code,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.villages,
  });

  final String code;
  final String name;
  final double latitude;
  final double longitude;
  final List<EgyptAdministrativeVillage> villages;

  factory EgyptAdministrativeArea.fromJson(Map<String, dynamic> json) {
    final rawVillages = json['villages'];
    return EgyptAdministrativeArea(
      code: _requiredString(json, 'code'),
      name: _requiredString(json, 'name'),
      latitude: _requiredDouble(json, 'latitude'),
      longitude: _requiredDouble(json, 'longitude'),
      villages: rawVillages is List
          ? rawVillages
              .whereType<Map>()
              .map((item) => EgyptAdministrativeVillage.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList(growable: false)
          : const [],
    );
  }
}

class EgyptAdministrativeGovernorate {
  const EgyptAdministrativeGovernorate({
    required this.code,
    required this.name,
    required this.areas,
  });

  final String code;
  final String name;
  final List<EgyptAdministrativeArea> areas;

  factory EgyptAdministrativeGovernorate.fromJson(Map<String, dynamic> json) {
    final rawAreas = json['centers'];
    return EgyptAdministrativeGovernorate(
      code: _requiredString(json, 'code'),
      name: _requiredString(json, 'name'),
      areas: rawAreas is List
          ? rawAreas
              .whereType<Map>()
              .map((item) => EgyptAdministrativeArea.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList(growable: false)
          : const [],
    );
  }
}

class EgyptLocationCatalog {
  EgyptLocationCatalog({
    required this.governorates,
    required this.source,
    required this.license,
    required this.coverageNote,
  });

  static const assetPath = 'assets/data/egypt_admin_locations.json';
  static Future<EgyptLocationCatalog>? _cached;

  final List<EgyptAdministrativeGovernorate> governorates;
  final String source;
  final String license;
  final String coverageNote;

  static Future<EgyptLocationCatalog> load({AssetBundle? bundle}) {
    if (bundle != null) return _load(bundle);
    return _cached ??= _load(rootBundle);
  }

  static Future<EgyptLocationCatalog> _load(AssetBundle bundle) async {
    final raw = await bundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> || decoded['governorates'] is! List) {
      throw const FormatException('ملف المواقع الإدارية غير صالح.');
    }
    final list = (decoded['governorates'] as List)
        .whereType<Map>()
        .map((item) => EgyptAdministrativeGovernorate.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList(growable: false);
    return EgyptLocationCatalog(
      governorates: list,
      source: decoded['source']?.toString() ?? '',
      license: decoded['license']?.toString() ?? '',
      coverageNote: decoded['coverageNote']?.toString() ?? '',
    );
  }

  EgyptAdministrativeGovernorate? findGovernorate(String name) {
    final key = _normalizeArabic(name);
    for (final governorate in governorates) {
      if (_normalizeArabic(governorate.name) == key) return governorate;
    }

    // اسم الأقصر في نسخة الحدود الإدارية هو «مدينة الأقصر».
    if (key == _normalizeArabic('الأقصر')) {
      for (final governorate in governorates) {
        if (governorate.code == 'EG29') return governorate;
      }
    }
    return null;
  }

  static String _normalizeArabic(String value) {
    var normalized = value.trim().replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
    normalized = normalized
        .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'\s+'), '');
    if (normalized.startsWith('مدينه')) {
      normalized = normalized.substring('مدينه'.length);
    }
    return normalized;
  }
}

class WeatherLocationSelection {
  const WeatherLocationSelection({
    required this.governorateCode,
    required this.governorateName,
    required this.areaCode,
    required this.areaName,
    required this.latitude,
    required this.longitude,
    this.villageCode,
    this.villageName,
  });

  final String governorateCode;
  final String governorateName;
  final String areaCode;
  final String areaName;
  final double latitude;
  final double longitude;
  final String? villageCode;
  final String? villageName;

  String get displayName => villageName == null
      ? '$areaName، $governorateName'
      : '$villageName، $areaName، $governorateName';

  factory WeatherLocationSelection.fromJson(Map<String, dynamic> json) {
    return WeatherLocationSelection(
      governorateCode: _requiredString(json, 'governorateCode'),
      governorateName: _requiredString(json, 'governorateName'),
      areaCode: _requiredString(json, 'areaCode'),
      areaName: _requiredString(json, 'areaName'),
      latitude: _requiredDouble(json, 'latitude'),
      longitude: _requiredDouble(json, 'longitude'),
      villageCode: json['villageCode']?.toString(),
      villageName: json['villageName']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'governorateCode': governorateCode,
        'governorateName': governorateName,
        'areaCode': areaCode,
        'areaName': areaName,
        'latitude': latitude,
        'longitude': longitude,
        'villageCode': villageCode,
        'villageName': villageName,
      };

  factory WeatherLocationSelection.forArea(
    EgyptAdministrativeGovernorate governorate,
    EgyptAdministrativeArea area,
  ) =>
      WeatherLocationSelection(
        governorateCode: governorate.code,
        governorateName: governorate.name,
        areaCode: area.code,
        areaName: area.name,
        latitude: area.latitude,
        longitude: area.longitude,
      );

  factory WeatherLocationSelection.forVillage(
    EgyptAdministrativeGovernorate governorate,
    EgyptAdministrativeArea area,
    EgyptAdministrativeVillage village,
  ) =>
      WeatherLocationSelection(
        governorateCode: governorate.code,
        governorateName: governorate.name,
        areaCode: area.code,
        areaName: area.name,
        latitude: village.latitude,
        longitude: village.longitude,
        villageCode: village.code,
        villageName: village.name,
      );
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('حقل المواقع $key غير صالح.');
  }
  return value;
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num || !value.toDouble().isFinite) {
    throw FormatException('إحداثيات المواقع $key غير صالحة.');
  }
  return value.toDouble();
}
