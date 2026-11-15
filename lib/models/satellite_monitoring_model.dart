import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

class HlsCoordinate {
  final double latitude;
  final double longitude;

  const HlsCoordinate({required this.latitude, required this.longitude});

  factory HlsCoordinate.fromMap(dynamic value) {
    if (value is! Map) return const HlsCoordinate(latitude: 0, longitude: 0);
    return HlsCoordinate(
      latitude: _number(value['lat'] ?? value['latitude']),
      longitude: _number(value['lon'] ?? value['longitude']),
    );
  }

  Map<String, double> toMap() => {'lat': latitude, 'lon': longitude};

  static double _number(dynamic value) {
    if (value is num && value.isFinite) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class HlsField {
  final String id;
  final String name;
  final String crop;
  final String? linkedProgramId;
  final DateTime plantingDate;
  final List<HlsCoordinate> polygon;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const HlsField({
    required this.id,
    required this.name,
    required this.crop,
    required this.plantingDate,
    required this.polygon,
    this.linkedProgramId,
    this.createdAt,
    this.updatedAt,
  });

  factory HlsField.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawPolygon = data['polygon'];
    final polygon = rawPolygon is List
        ? rawPolygon.map(HlsCoordinate.fromMap).toList(growable: false)
        : const <HlsCoordinate>[];
    return HlsField(
      id: doc.id,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : 'حقل بدون اسم',
      crop: (data['crop'] as String?)?.trim() ?? '',
      linkedProgramId: data['linked_program_id'] as String?,
      plantingDate: _date(data['planting_date']) ?? DateTime.now(),
      polygon: polygon,
      createdAt: _date(data['created_at']),
      updatedAt: _date(data['updated_at']),
    );
  }

  Map<String, dynamic> toFirestore({bool creating = false}) => {
        'name': name.trim(),
        'crop': crop.trim(),
        'linked_program_id': linkedProgramId,
        'planting_date': Timestamp.fromDate(plantingDate),
        'polygon': polygon.map((point) => point.toMap()).toList(),
        'area_m2': areaSquareMeters,
        if (creating) 'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

  double get areaSquareMeters {
    if (polygon.length < 3) return 0;
    const earthRadius = 6371008.8;
    final averageLatitude = polygon.fold<double>(
          0,
          (sum, point) => sum + point.latitude,
        ) /
        polygon.length;
    final longitudeScale = _cosDegrees(averageLatitude);
    var area = 0.0;
    for (var i = 0; i < polygon.length; i++) {
      final current = polygon[i];
      final next = polygon[(i + 1) % polygon.length];
      final x1 = current.longitude * longitudeScale;
      final x2 = next.longitude * longitudeScale;
      area += x1 * next.latitude - x2 * current.latitude;
    }
    final degreesToMeters = earthRadius * 3.141592653589793 / 180;
    return (area.abs() / 2) * degreesToMeters * degreesToMeters;
  }

  double get areaHectares => areaSquareMeters / 10000;
  double get areaFeddans => areaSquareMeters / 4200;

  HlsField copyWith({
    String? id,
    String? name,
    String? crop,
    String? linkedProgramId,
    bool clearLinkedProgram = false,
    DateTime? plantingDate,
    List<HlsCoordinate>? polygon,
  }) =>
      HlsField(
        id: id ?? this.id,
        name: name ?? this.name,
        crop: crop ?? this.crop,
        linkedProgramId:
            clearLinkedProgram ? null : (linkedProgramId ?? this.linkedProgramId),
        plantingDate: plantingDate ?? this.plantingDate,
        polygon: polygon ?? this.polygon,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  static double _cosDegrees(double value) => math.cos(value * math.pi / 180);

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class HlsSamplePoint {
  final String id;
  final double latitude;
  final double longitude;
  final Map<String, double> indices;
  final Map<String, double> bands;
  final Map<String, Map<String, dynamic>> qa;
  final int? fmask;

  const HlsSamplePoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.indices = const {},
    this.bands = const {},
    this.qa = const {},
    this.fmask,
  });

  factory HlsSamplePoint.fromMap(dynamic value) {
    final map = value is Map ? value : const <String, dynamic>{};
    return HlsSamplePoint(
      id: map['id']?.toString() ?? '',
      latitude: _double(map['latitude']),
      longitude: _double(map['longitude']),
      indices: _doubleMap(map['indices']),
      bands: _doubleMap(map['bands']),
      qa: _qaMap(map['qa']),
      fmask: map['fmask'] is num ? (map['fmask'] as num).toInt() : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'indices': indices,
        'bands': bands,
        if (qa.isNotEmpty) 'qa': qa,
        if (fmask != null) 'fmask': fmask,
      };
}

class HlsObservation {
  final String id;
  final DateTime date;
  final Map<String, double> metrics;
  final Map<String, double> bands;
  final List<HlsSamplePoint> samples;
  final int validSampleCount;
  final int totalSampleCount;
  final List<String> sources;
  final Map<String, dynamic> quality;
  final List<String> alerts;

  const HlsObservation({
    required this.id,
    required this.date,
    required this.metrics,
    required this.bands,
    required this.samples,
    required this.validSampleCount,
    required this.totalSampleCount,
    required this.sources,
    required this.quality,
    required this.alerts,
  });

  factory HlsObservation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawSamples = data['samples'];
    return HlsObservation(
      id: doc.id,
      date: _parseDate(data['date']) ?? DateTime.now(),
      metrics: _doubleMap(data['metrics']),
      bands: _doubleMap(data['bands']),
      samples: rawSamples is List
          ? rawSamples.map(HlsSamplePoint.fromMap).toList(growable: false)
          : const [],
      validSampleCount: _int(data['valid_sample_count']),
      totalSampleCount: _int(data['total_sample_count']),
      sources: data['sources'] is List
          ? (data['sources'] as List).map((value) => value.toString()).toList()
          : const [],
      quality: data['quality'] is Map
          ? Map<String, dynamic>.from(data['quality'] as Map)
          : const {},
      alerts: data['alerts'] is List
          ? (data['alerts'] as List).map((value) => value.toString()).toList()
          : const [],
    );
  }
}

class HlsAnalysisRun {
  final String id;
  final String status;
  final DateTime? requestedAt;
  final DateTime? completedAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? errorMessage;
  final int samplePointCount;
  final int observationCount;
  final List<String> sources;

  const HlsAnalysisRun({
    required this.id,
    required this.status,
    this.requestedAt,
    this.completedAt,
    this.startDate,
    this.endDate,
    this.errorMessage,
    this.samplePointCount = 0,
    this.observationCount = 0,
    this.sources = const [],
  });

  factory HlsAnalysisRun.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return HlsAnalysisRun(
      id: doc.id,
      status: data['status']?.toString() ?? 'unknown',
      requestedAt: _parseDate(data['requested_at']),
      completedAt: _parseDate(data['completed_at']),
      startDate: _parseDate(data['start_date']),
      endDate: _parseDate(data['end_date']),
      errorMessage: data['error_message'] as String?,
      samplePointCount: _int(data['sample_point_count']),
      observationCount: _int(data['observation_count']),
      sources: data['sources'] is List
          ? (data['sources'] as List).map((value) => value.toString()).toList()
          : const [],
    );
  }
}

class HlsFieldNote {
  final String id;
  final String text;
  final String? category;
  final DateTime? createdAt;

  const HlsFieldNote({
    required this.id,
    required this.text,
    this.category,
    this.createdAt,
  });

  factory HlsFieldNote.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return HlsFieldNote(
      id: doc.id,
      text: data['text']?.toString() ?? '',
      category: data['category'] as String?,
      createdAt: _parseDate(data['created_at']),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

double _double(dynamic value) {
  if (value is num && value.isFinite) return value.toDouble();
  final parsed = double.tryParse(value?.toString() ?? '');
  return parsed != null && parsed.isFinite ? parsed : 0;
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, double> _doubleMap(dynamic value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      if (_finiteDouble(entry.value) != null)
        entry.key.toString(): _finiteDouble(entry.value)!,
  };
}

Map<String, Map<String, dynamic>> _qaMap(dynamic value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      if (entry.value is Map)
        entry.key.toString(): {
          for (final flag in (entry.value as Map).entries)
            flag.key.toString(): flag.value,
        },
  };
}

double? _finiteDouble(dynamic value) {
  if (value is num && value.isFinite) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null && parsed.isFinite) return parsed;
  }
  return null;
}
