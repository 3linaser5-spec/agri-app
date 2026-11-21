library;

class IrrigationCatalogItem {
  final String id, kind, nameAr, nameEn, manufacturer;
  final Map<String, dynamic> specifications;
  final bool active;
  const IrrigationCatalogItem({required this.id, required this.kind, required this.nameAr, this.nameEn = '', this.manufacturer = '', this.specifications = const {}, this.active = true});
  Map<String, dynamic> toJson() => {'id':id,'kind':kind,'name_ar':nameAr,'name_en':nameEn,'manufacturer':manufacturer,'specifications':specifications,'active':active};
  factory IrrigationCatalogItem.fromJson(Map<String, dynamic> j) => IrrigationCatalogItem(id:j['id']?.toString() ?? '', kind:j['kind']?.toString() ?? '', nameAr:j['name_ar']?.toString() ?? '', nameEn:j['name_en']?.toString() ?? '', manufacturer:j['manufacturer']?.toString() ?? '', specifications:Map<String,dynamic>.from(j['specifications'] as Map? ?? const {}), active:j['active'] != false);
}

class IrrigationSatelliteLink {
  final String projectId, zoneId, fieldId;
  final List<String> alertIds;
  final DateTime updatedAt;
  const IrrigationSatelliteLink({required this.projectId, required this.zoneId, required this.fieldId, this.alertIds = const [], required this.updatedAt});
  Map<String, dynamic> toJson() => {'project_id':projectId,'zone_id':zoneId,'field_id':fieldId,'alert_ids':alertIds,'updated_at':updatedAt.toIso8601String()};
  factory IrrigationSatelliteLink.fromJson(Map<String,dynamic> j) => IrrigationSatelliteLink(projectId:j['project_id']?.toString() ?? '', zoneId:j['zone_id']?.toString() ?? '', fieldId:j['field_id']?.toString() ?? '', alertIds:List<String>.from(j['alert_ids'] ?? const []), updatedAt:DateTime.tryParse(j['updated_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0));
}
