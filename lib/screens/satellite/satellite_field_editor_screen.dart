import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/satellite_monitoring_model.dart';
import '../../services/satellite_monitoring_service.dart';

class SatelliteFieldEditorScreen extends StatefulWidget {
  final HlsField? field;

  const SatelliteFieldEditorScreen({super.key, this.field});

  @override
  State<SatelliteFieldEditorScreen> createState() =>
      _SatelliteFieldEditorScreenState();
}

class _SatelliteFieldEditorScreenState extends State<SatelliteFieldEditorScreen> {
  static const _green = Color(0xFF047857);
  final _formKey = GlobalKey<FormState>();
  final _mapController = MapController();
  late final TextEditingController _nameController;
  late final TextEditingController _cropController;
  late DateTime _plantingDate;
  late List<HlsCoordinate> _points;
  bool _saving = false;
  bool _locating = false;
  bool _useSatelliteImagery = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.field?.name ?? '');
    _cropController = TextEditingController(text: widget.field?.crop ?? '');
    _plantingDate = widget.field?.plantingDate ?? DateTime.now();
    _points = List<HlsCoordinate>.of(widget.field?.polygon ?? const []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cropController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _choosePlantingDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _plantingDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'اختر تاريخ الزراعة',
      confirmText: 'اختيار',
      cancelText: 'إلغاء',
    );
    if (selected != null) setState(() => _plantingDate = selected);
  }

  Future<void> _moveToMyLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('فعّل إذن الموقع أو حرّك الخريطة إلى موقع الحقل.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _mapController.move(LatLng(position.latitude, position.longitude), 15);
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_points.length < 3) {
      _showMessage('اضغط على الخريطة لإضافة 3 نقاط على الأقل حول حدود الحقل.');
      return;
    }
    setState(() => _saving = true);
    try {
      final field = HlsField(
        id: widget.field?.id ?? '',
        name: _nameController.text.trim(),
        crop: _cropController.text.trim(),
        linkedProgramId: widget.field?.linkedProgramId,
        plantingDate: _plantingDate,
        polygon: List.unmodifiable(_points),
        createdAt: widget.field?.createdAt,
        updatedAt: widget.field?.updatedAt,
      );
      final id = await SatelliteMonitoringService.saveField(field);
      if (mounted) Navigator.of(context).pop(id);
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  List<LatLng> get _latLngPoints =>
      _points.map((point) => LatLng(point.latitude, point.longitude)).toList();

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.field != null;
    final area = HlsField(
      id: '',
      name: '',
      crop: '',
      plantingDate: _plantingDate,
      polygon: _points,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'تعديل الحقل' : 'إضافة حقل للمراقبة'),
          backgroundColor: _green,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: _useSatelliteImagery
                  ? 'التبديل إلى خريطة الشوارع'
                  : 'التبديل إلى الصور الفضائية',
              onPressed: () => setState(
                () => _useSatelliteImagery = !_useSatelliteImagery,
              ),
              icon: Icon(
                _useSatelliteImagery ? Icons.map_outlined : Icons.satellite_alt,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _points.isNotEmpty
                        ? LatLng(_points.first.latitude, _points.first.longitude)
                        : const LatLng(26.8206, 30.8025),
                    initialZoom: _points.isNotEmpty ? 15 : 5.5,
                    minZoom: 4,
                    maxZoom: 19,
                    onTap: (_, point) {
                      if (_points.length >= 25) {
                        _showMessage('الحد الأقصى للرسم 25 نقطة.');
                        return;
                      }
                      setState(() => _points.add(HlsCoordinate(
                            latitude: point.latitude,
                            longitude: point.longitude,
                          )));
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _useSatelliteImagery
                          ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.nabati.agri',
                      maxNativeZoom: _useSatelliteImagery ? 23 : 19,
                    ),
                    if (_points.length >= 3)
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: _latLngPoints,
                            color: _green.withValues(alpha: 0.22),
                            borderColor: _green,
                            borderStrokeWidth: 3,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        for (var i = 0; i < _points.length; i++)
                          Marker(
                            point: LatLng(
                              _points[i].latitude,
                              _points[i].longitude,
                            ),
                            width: 32,
                            height: 32,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _green,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    RichAttributionWidget(
                      attributions: [
                        if (_useSatelliteImagery)
                          TextSourceAttribution(
                            'Source: Esri, Vantor, Earthstar Geographics, and the GIS User Community',
                            onTap: () => launchUrl(
                              Uri.parse('https://goto.arcgisonline.com/maps/World_Imagery'),
                              mode: LaunchMode.externalApplication,
                            ),
                          )
                        else
                          TextSourceAttribution(
                            'OpenStreetMap contributors',
                            onTap: () => launchUrl(
                              Uri.parse('https://www.openstreetmap.org/copyright'),
                              mode: LaunchMode.externalApplication,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x18000000),
                      blurRadius: 12,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _points.length < 3
                                  ? 'اضغط الخريطة وارسم محيط الحقل'
                                  : 'المساحة التقريبية: ${area.areaFeddans.toStringAsFixed(2)} فدان',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            tooltip: 'موقعي الحالي',
                            onPressed: _locating ? null : _moveToMyLocation,
                            icon: _locating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.my_location, color: _green),
                          ),
                          IconButton(
                            tooltip: 'تراجع عن آخر نقطة',
                            onPressed: _points.isEmpty
                                ? null
                                : () => setState(() => _points.removeLast()),
                            icon: const Icon(Icons.undo),
                          ),
                          IconButton(
                            tooltip: 'مسح الحدود',
                            onPressed: _points.isEmpty
                                ? null
                                : () => setState(_points.clear),
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _nameController,
                              maxLength: 100,
                              decoration: const InputDecoration(
                                labelText: 'اسم الحقل',
                                counterText: '',
                                prefixIcon: Icon(Icons.place_outlined),
                              ),
                              validator: (value) => value == null || value.trim().isEmpty
                                  ? 'اكتب اسم الحقل'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _cropController,
                              maxLength: 100,
                              decoration: const InputDecoration(
                                labelText: 'المحصول',
                                counterText: '',
                                prefixIcon: Icon(Icons.grass),
                              ),
                              validator: (value) => value == null || value.trim().isEmpty
                                  ? 'اكتب المحصول'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.event_outlined, color: _green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'تاريخ الزراعة: ${_plantingDate.day}/${_plantingDate.month}/${_plantingDate.year}',
                            ),
                          ),
                          TextButton(
                            onPressed: _choosePlantingDate,
                            child: const Text('تغيير'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: _green,
                              foregroundColor: Colors.white,
                            ),
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(isEditing ? 'حفظ' : 'إضافة الحقل'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'المساحة تقديرية من المضلع؛ انقر على الخريطة لإضافة الزوايا.',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
