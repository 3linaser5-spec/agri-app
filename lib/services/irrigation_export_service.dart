import 'dart:convert';

import '../models/irrigation_design_models.dart';

/// الطبقات المعتمدة في ملف التصدير.
class IrrigationExportLayers {
  IrrigationExportLayers._();
  static const pumpStation = 'PUMP_STATION';
  static const mainlinePipes = 'MAINLINE_PIPES';
  static const valvesManifold = 'VALVES_MANIFOLD';
  static const lateralsPipes = 'LATERALS_PIPES';
  static const spraysPopup = 'SPRAYS_POPUP';
  static const rotorsSaroukh = 'ROTORS_SAROUKH';
  static const plantsTrees = 'PLANTS_TREES';
  static const plantsShrubsTurf = 'PLANTS_SHRUBS_TURF';
  static const boundary = 'BOUNDARY';
  static const elevation3d = 'ELEVATION_3D';

  static const all = <String>[
    pumpStation,
    mainlinePipes,
    valvesManifold,
    lateralsPipes,
    spraysPopup,
    rotorsSaroukh,
    plantsTrees,
    plantsShrubsTurf,
    boundary,
    elevation3d,
  ];
}

/// يُرمى عندما لا يمكن تصدير مشروع غير صالح أو غير مكتمل.
class IrrigationExportValidationException implements Exception {
  final List<String> errors;
  const IrrigationExportValidationException(this.errors);
  @override
  String toString() => 'لا يمكن تصدير المشروع: ${errors.join('; ')}';
}

class IrrigationBoqLine {
  final String category;
  final String code;
  final String description;
  final String unit;
  final num quantity;
  final String sourceId;

  const IrrigationBoqLine({
    required this.category,
    required this.code,
    required this.description,
    required this.unit,
    required this.quantity,
    this.sourceId = '',
  });

  Map<String, dynamic> toJson() => {
        'category': category,
        'code': code,
        'description': description,
        'unit': unit,
        'quantity': quantity,
        'source_id': sourceId,
      };
}

class IrrigationScheduleLine {
  final String zoneId;
  final String zoneName;
  final String method;
  final num flowLpm;
  final num areaM2;
  final num runtimeMinutes;
  final String notes;

  const IrrigationScheduleLine({
    required this.zoneId,
    required this.zoneName,
    required this.method,
    required this.flowLpm,
    required this.areaM2,
    required this.runtimeMinutes,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'zone_id': zoneId,
        'zone_name': zoneName,
        'method': method,
        'flow_lpm': flowLpm,
        'area_m2': areaM2,
        'runtime_minutes': runtimeMinutes,
        'notes': notes,
      };
}

class IrrigationExportBundle {
  final String dxf;
  final String boqCsv;
  final String boqJson;
  final List<IrrigationBoqLine> boq;
  final List<IrrigationScheduleLine> schedule;
  final String scheduleCsv;

  const IrrigationExportBundle({
    required this.dxf,
    required this.boqCsv,
    required this.boqJson,
    required this.boq,
    required this.schedule,
    required this.scheduleCsv,
  });

  Map<String, dynamic> toJson() => {
        'dxf': dxf,
        'boq': boq.map((x) => x.toJson()).toList(growable: false),
        'schedule': schedule.map((x) => x.toJson()).toList(growable: false),
      };
}

/// مُصدّر مستقل: DXF ASCII قياسي قابل للاستيراد، وليس ملف RainCAD أصليًا.
class IrrigationExportService {
  const IrrigationExportService();

  IrrigationExportBundle export(IrrigationDesignProject project,
      {double dailyNetRequirementMm = 5}) {
    validate(project, dailyNetRequirementMm: dailyNetRequirementMm);
    final boq = _boq(project);
    final schedule = _schedule(project, dailyNetRequirementMm);
    return IrrigationExportBundle(
      dxf: _dxf(project),
      boq: boq,
      boqCsv: _csv(boq.map((x) => x.toJson()).toList()),
      boqJson: jsonEncode(boq.map((x) => x.toJson()).toList(growable: false)),
      schedule: schedule,
      scheduleCsv: _csv(schedule.map((x) => x.toJson()).toList()),
    );
  }

  static IrrigationExportBundle exportProject(IrrigationDesignProject project,
          {double dailyNetRequirementMm = 5}) =>
      const IrrigationExportService().export(project,
          dailyNetRequirementMm: dailyNetRequirementMm);

  static void validate(IrrigationDesignProject project,
      {double dailyNetRequirementMm = 5}) {
    final errors = <String>[];
    if (!dailyNetRequirementMm.isFinite || dailyNetRequirementMm <= 0) {
      errors.add('dailyNetRequirementMm must be finite and greater than zero');
    }
    if (project.siteBoundary.points.length < 3) {
      errors.add('site boundary must contain at least three points');
    }
    final ids = <String>{};
    void unique(String id, String kind) {
      if (!ids.add(id)) errors.add('duplicate $kind id: $id');
    }
    for (final x in project.pipes) {
      unique(x.id, 'pipe');
      if (!x.lengthM.isFinite || x.lengthM <= 0) errors.add('invalid pipe length: ${x.id}');
    }
    for (final x in project.valves) unique(x.id, 'valve');
    for (final x in project.equipment) unique(x.id, 'equipment');
    for (final x in project.plants) unique(x.id, 'plant');
    for (final x in project.zones) {
      unique(x.id, 'zone');
      for (final id in x.pipeIds) {
        if (!project.pipes.any((p) => p.id == id)) errors.add('zone ${x.id} references missing pipe $id');
      }
      for (final id in x.valveIds) {
        if (!project.valves.any((v) => v.id == id)) errors.add('zone ${x.id} references missing valve $id');
      }
      for (final id in x.equipmentIds) {
        if (!project.equipment.any((e) => e.id == id)) errors.add('zone ${x.id} references missing equipment $id');
      }
      if (x.plantId != null && !project.plants.any((p) => p.id == x.plantId)) {
        errors.add('zone ${x.id} references missing plant ${x.plantId}');
      }
    }
    final elevationIds = <String>{};
    for (final point in project.elevationPoints) {
      if (!elevationIds.add(point.id)) errors.add('duplicate elevation point id: ${point.id}');
      if (!point.elevationM.isFinite) errors.add('invalid elevation: ${point.id}');
    }
    if (errors.isNotEmpty) throw IrrigationExportValidationException(errors);
  }

  List<IrrigationBoqLine> _boq(IrrigationDesignProject p) {
    final lines = <IrrigationBoqLine>[
      IrrigationBoqLine(category: 'pump', code: p.pump.type, description: p.pump.nameEn.isEmpty ? p.pump.type : p.pump.nameEn, unit: 'ea', quantity: 1, sourceId: p.pump.id),
    ];
    for (final x in p.pipes) {
      final category = x.id.toLowerCase().contains('main') ? 'mainline' : 'lateral';
      lines.add(IrrigationBoqLine(category: category, code: x.material, description: '${x.diameter}${x.diameterUnit} ${x.material} pipe', unit: 'm', quantity: x.lengthM, sourceId: x.id));
    }
    for (final x in p.valves) lines.add(IrrigationBoqLine(category: 'valve', code: x.type, description: '${x.diameterMm} mm ${x.type}', unit: 'ea', quantity: 1, sourceId: x.id));
    for (final x in p.equipment) lines.add(IrrigationBoqLine(category: 'equipment', code: x.type, description: x.nameEn.isEmpty ? x.type : x.nameEn, unit: 'ea', quantity: x.quantity, sourceId: x.id));
    for (final x in p.plants) lines.add(IrrigationBoqLine(category: 'plant', code: x.id, description: x.nameEn.isEmpty ? x.id : x.nameEn, unit: 'ea', quantity: 1, sourceId: x.id));
    return lines;
  }

  List<IrrigationScheduleLine> _schedule(IrrigationDesignProject p, double dailyMm) => p.zones
      .map((z) => IrrigationScheduleLine(
            zoneId: z.id,
            zoneName: z.nameEn.isEmpty ? z.id : z.nameEn,
            method: z.method,
            flowLpm: z.designFlowLpm,
            areaM2: z.areaM2,
            runtimeMinutes: (z.areaM2 * dailyMm / z.designFlowLpm).clamp(0, double.infinity),
            notes: 'Calculated from design flow; verify field conditions',
          ))
      .toList(growable: false);

  String _dxf(IrrigationDesignProject p) {
    final b = _DxfBuilder();
    for (final layer in IrrigationExportLayers.all) b.layer(layer);
    b.comment('STANDARD ASCII DXF IMPORT EXPORT - NOT AN ORIGINAL RAINCAD FILE');
    final origin = p.siteBoundary.points.first;
    _Point xy(GeoCoordinate c, double z) => _Point(c.longitude - origin.longitude, c.latitude - origin.latitude, z);
    final boundary = p.siteBoundary.points.map((c) => xy(c, 0)).toList();
    for (var i = 0; i < boundary.length; i++) b.line(IrrigationExportLayers.boundary, boundary[i], boundary[(i + 1) % boundary.length]);
    b.block('PUMP_STATION_BLOCK');
    b.circle(IrrigationExportLayers.pumpStation, _Point(-2, 0, p.pump.headM), 0.5);
    b.insert(IrrigationExportLayers.pumpStation, 'PUMP_STATION_BLOCK', _Point(-2, 0, p.pump.headM));
    var x = 0.0;
    for (final pipe in p.pipes) {
      final layer = pipe.id.toLowerCase().contains('main') ? IrrigationExportLayers.mainlinePipes : IrrigationExportLayers.lateralsPipes;
      b.line(layer, _Point(x, 0, 0), _Point(x + pipe.lengthM, 0, 0.05));
      x += 1.5;
    }
    for (var i = 0; i < p.valves.length; i++) b.circle(IrrigationExportLayers.valvesManifold, _Point(i * 1.5, 1, 0), 0.18);
    for (var i = 0; i < p.equipment.length; i++) {
      final layer = p.equipment[i].type.toLowerCase().contains('rotor') ? IrrigationExportLayers.rotorsSaroukh : IrrigationExportLayers.spraysPopup;
      b.circle(layer, _Point(i * 1.5, 2, 0), 0.12);
    }
    for (var i = 0; i < p.plants.length; i++) {
      final layer = p.plants[i].nameEn.toLowerCase().contains('tree') ? IrrigationExportLayers.plantsTrees : IrrigationExportLayers.plantsShrubsTurf;
      b.circle(layer, _Point(i * 1.5, 3, 0), 0.2);
    }
    for (final point in p.elevationPoints) b.point(IrrigationExportLayers.elevation3d, xy(point.coordinate, point.elevationM));
    b.text(IrrigationExportLayers.elevation3d, _Point(0, 4, 0), 'DXF standard import; not original RainCAD');
    return b.build();
  }

  String _csv(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return '';
    final keys = rows.first.keys.toList();
    String cell(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
    return '${keys.join(',')}\n${rows.map((r) => keys.map((k) => cell(r[k])).join(',')).join('\n')}\n';
  }
}

class _Point {
  final double x, y, z;
  const _Point(this.x, this.y, this.z);
}

class _DxfBuilder {
  final _sections = <String>[];
  final _layers = <String>[];
  final _blocks = <String>[];
  void layer(String name) => _layers.add(name);
  void comment(String value) => text('0', const _Point(0, 0, 0), value);
  void line(String layer, _Point a, _Point b) { _sections.add(_entity('LINE', layer, {'10': a.x, '20': a.y, '30': a.z, '11': b.x, '21': b.y, '31': b.z})); }
  void circle(String layer, _Point c, double radius) { _sections.add(_entity('CIRCLE', layer, {'10': c.x, '20': c.y, '30': c.z, '40': radius})); }
  void point(String layer, _Point p) { _sections.add(_entity('POINT', layer, {'10': p.x, '20': p.y, '30': p.z})); }
  void text(String layer, _Point p, String value) { _sections.add(_entity('TEXT', layer, {'10': p.x, '20': p.y, '30': p.z, '40': 0.25, '1': value})); }
  void block(String name) => _blocks.add('0\nBLOCK\n2\n$name\n70\n0\n10\n0\n20\n0\n30\n0\n0\nENDBLK\n');
  void insert(String layer, String blockName, _Point p) { _sections.add(_entity('INSERT', layer, {'2': blockName, '10': p.x, '20': p.y, '30': p.z})); }
  String _entity(String type, String layer, Map<String, Object> values) => '0\n$type\n8\n$layer\n${values.entries.map((e) => '${e.key}\n${_fmt(e.value)}\n').join()}';
  String build() => '0\nSECTION\n2\nHEADER\n9\n\$ACADVER\n1\nAC1009\n0\nENDSEC\n0\nSECTION\n2\nTABLES\n0\nTABLE\n2\nLAYER\n70\n${_layers.length}\n${_layers.map((x) => '0\nLAYER\n2\n$x\n70\n0\n62\n7\n6\nCONTINUOUS\n').join()}0\nENDTAB\n0\nENDSEC\n0\nSECTION\n2\nBLOCKS\n${_blocks.join()}0\nENDSEC\n0\nSECTION\n2\nENTITIES\n${_sections.join()}0\nENDSEC\n0\nEOF\n';
  static String _fmt(Object value) => value is num ? value.toStringAsFixed(6) : value.toString();
}
