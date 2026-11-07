import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../config/app_config.dart';
import '../../services/satellite_access_service.dart';

const Color _sectionGreen = Color(0xFF047857);

/// شاشة إضافة أو تعديل قطعة أرض: رسم الحدود على خريطة فضائية مع بيانات المحصول.
class SatelliteBlockEditorScreen extends StatefulWidget {
  const SatelliteBlockEditorScreen({
    required this.uid,
    required this.field,
    super.key,
  });

  final String uid;
  final SatelliteField? field;

  @override
  State<SatelliteBlockEditorScreen> createState() =>
      _SatelliteBlockEditorScreenState();
}

class _SatelliteBlockEditorScreenState
    extends State<SatelliteBlockEditorScreen> {
  final SatelliteAccessService _service = SatelliteAccessService();
  final MapController _mapController = MapController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cropController = TextEditingController();
  final TextEditingController _cultivarController = TextEditingController();
  late final List<LatLng> _points;
  DateTime? _plantingDate;
  bool _saving = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final field = widget.field;
    _points =
        field?.vertices
            .map((point) => LatLng(point['lat']!, point['lng']!))
            .toList() ??
        <LatLng>[];
    _nameController.text = field?.name ?? '';
    _cropController.text = field?.cropType ?? '';
    _cultivarController.text = field?.cultivar ?? '';
    _plantingDate = field?.plantingDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cropController.dispose();
    _cultivarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapKey = AppConfig.mapTilerApiKey;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.field == null ? 'إضافة قطعة أرض' : 'تعديل القطعة',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: _sectionGreen,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'تراجع عن آخر نقطة',
              onPressed: _points.isEmpty || _saving
                  ? null
                  : () => setState(() => _points.removeLast()),
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: 'مسح النقاط',
              onPressed: _points.isEmpty || _saving
                  ? null
                  : () => setState(_points.clear),
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  if (mapKey.isEmpty)
                    const ColoredBox(
                      color: Color(0xFFE9ECE7),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'الخريطة الفضائية غير مُعدّة بعد. يلزم ضبط MAPTILER_API_KEY في إعدادات البناء.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  else
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _initialCenter,
                        initialZoom: _points.isNotEmpty ? 16 : 12,
                        minZoom: 5,
                        maxZoom: 20,
                        onTap: (_, point) {
                          if (_points.length >= 100) return;
                          setState(() => _points.add(point));
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://api.maptiler.com/maps/satellite-v4/{z}/{x}/{y}.jpg?key=$mapKey',
                          userAgentPackageName: 'com.dahshory.agri.agri_app',
                          maxZoom: 20,
                        ),
                        if (_points.length >= 3)
                          PolygonLayer(
                            polygons: [
                              Polygon(
                                points: _points,
                                color: const Color(0x5534D399),
                                borderColor: _sectionGreen,
                                borderStrokeWidth: 3,
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            for (var i = 0; i < _points.length; i++)
                              Marker(
                                point: _points[i],
                                width: 30,
                                height: 30,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _sectionGreen,
                                      width: 2,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      color: _sectionGreen,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  Positioned(
                    right: 12,
                    left: 12,
                    top: 12,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          _points.length < 3
                              ? 'انقر على الخريطة لإضافة نقاط حول حدود القطعة (${_points.length}/3 على الأقل).'
                              : '${_points.length} نقاط • المساحة التقريبية ${SatelliteGeometry.areaFeddan(_pointMaps).toStringAsFixed(2)} فدان',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  if (mapKey.isNotEmpty)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: FloatingActionButton.small(
                        heroTag: 'satellite-block-location',
                        onPressed: _locating ? null : _goToCurrentLocation,
                        tooltip: 'الانتقال إلى موقعي',
                        child: _locating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location),
                      ),
                    ),
                ],
              ),
            ),
            _detailsForm(mapKey.isEmpty),
          ],
        ),
      ),
    );
  }

  Widget _detailsForm(bool mapMissing) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم القطعة (مثال: قطعة القمح الشمالية)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cropController,
                    decoration: const InputDecoration(
                      labelText: 'نوع المحصول',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _cultivarController,
                    decoration: const InputDecoration(
                      labelText: 'الصنف',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _saving ? null : _pickPlantingDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'تاريخ الزراعة',
                  border: OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: Icon(Icons.event_outlined),
                ),
                child: Text(
                  _plantingDate == null
                      ? 'اختر تاريخ الزراعة'
                      : _date(_plantingDate!),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving || _points.length < 3 || mapMissing
                    ? null
                    : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ القطعة'),
                style: FilledButton.styleFrom(
                  backgroundColor: _sectionGreen,
                  minimumSize: const Size.fromHeight(46),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LatLng get _initialCenter =>
      _points.isNotEmpty ? _points.first : const LatLng(24.0889, 32.8998);

  List<Map<String, double>> get _pointMaps => _points
      .map(
        (point) => <String, double>{
          'lat': point.latitude,
          'lng': point.longitude,
        },
      )
      .toList(growable: false);

  String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _pickPlantingDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _plantingDate ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      helpText: 'تاريخ الزراعة',
    );
    if (picked != null) setState(() => _plantingDate = picked);
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('فعّل خدمة الموقع على الهاتف أولاً.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('اسمح للتطبيق باستخدام الموقع للانتقال إلى القطعة.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      _mapController.move(LatLng(position.latitude, position.longitude), 17);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر تحديد الموقع: $error')));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final crop = _cropController.text.trim();
    final cultivar = _cultivarController.text.trim();
    final plantingDate = _plantingDate;
    String? error;
    if (name.isEmpty) error = 'اكتب اسماً للقطعة أولاً.';
    if (crop.isEmpty) error = 'اكتب نوع المحصول.';
    if (cultivar.isEmpty) error = 'اكتب صنف المحصول.';
    if (plantingDate == null) error = 'اختر تاريخ الزراعة.';
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.saveField(
        uid: widget.uid,
        fieldId: widget.field?.id,
        name: name,
        cropType: crop,
        cultivar: cultivar,
        plantingDate: plantingDate!,
        vertices: _pointMaps,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر حفظ القطعة: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
