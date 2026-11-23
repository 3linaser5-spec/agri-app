import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/irrigation_design_models.dart';
import '../../models/map_alert_model.dart';
import '../../services/map_alert_service.dart';

class IrrigationNetworkMapScreen extends StatefulWidget {
  final List<IrrigationMapPlacement> initialPlacements;
  const IrrigationNetworkMapScreen({super.key, this.initialPlacements = const []});

  @override
  State<IrrigationNetworkMapScreen> createState() =>
      _IrrigationNetworkMapScreenState();
}

class _IrrigationNetworkMapScreenState
    extends State<IrrigationNetworkMapScreen> {
  final center = const LatLng(30.0444, 31.2357);
  late final List<IrrigationMapPlacement> placements;
  String kind = 'rotor';
  String zoneId = 'zone-1';

  static const kinds = <String, String>{
    'rotor': 'Rotor',
    'spray': 'Spray',
    'drip': 'Drip',
    'bubbler': 'Bubbler',
    'micro_spray': 'Micro-spray',
    'pipe': 'ماسورة',
    'valve': 'محبس',
    'plant': 'نبات',
  };

  @override
  void initState() {
    super.initState();
    placements = [...widget.initialPlacements];
  }

  void addPlacement(LatLng point) {
    setState(() {
      placements.add(IrrigationMapPlacement(
        id: '${kind}-${placements.length + 1}',
        kind: kind,
        coordinate: GeoCoordinate.checked(
          latitude: point.latitude,
          longitude: point.longitude,
        ),
        zoneId: kind == 'plant' || kind == 'pipe' ? null : zoneId,
        label: kinds[kind],
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('عناصر شبكة الري على الخريطة'),
          actions: [
            IconButton(
              onPressed: placements.isEmpty
                  ? null
                  : () => setState(placements.removeLast),
              icon: const Icon(Icons.undo),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, List.unmodifiable(placements)),
              child: const Text('حفظ'),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: kind,
                      decoration: const InputDecoration(labelText: 'نوع العنصر'),
                      items: kinds.entries
                          .map((entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => kind = value!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: zoneId,
                      decoration: const InputDecoration(labelText: 'معرّف Zone'),
                      onChanged: (value) => zoneId = value.trim().isEmpty ? 'zone-1' : value.trim(),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('اختار النوع ثم اضغط على الخريطة لوضع العنصر.'),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<MapAlert>>(
                stream: MapAlertService.watchAlerts(),
                builder: (context, snapshot) => FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 13,
                  onTap: (_, point) => addPlacement(point),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.agri.app',
                  ),
                  MarkerLayer(
                    markers: [
                      ...placements.map((placement) {
                      final point = LatLng(
                        placement.coordinate.latitude,
                        placement.coordinate.longitude,
                      );
                      return Marker(
                        point: point,
                        width: 64,
                        height: 42,
                        child: Column(
                          children: [
                            Icon(
                              placement.kind == 'plant'
                                  ? Icons.local_florist
                                  : Icons.water_drop,
                              color: placement.kind == 'valve'
                                  ? Colors.orange
                                  : Colors.blue,
                            ),
                            Text(placement.label ?? placement.kind,
                                style: const TextStyle(fontSize: 9)),
                          ],
                        ),
                      );
                    }),
                      ...(snapshot.data ?? const <MapAlert>[]).map((alert) => Marker(
                        point: LatLng(alert.latitude, alert.longitude),
                        width: 180,
                        height: 54,
                        child: GestureDetector(
                          onTap: () => showDialog<void>(context: context, builder: (_) => AlertDialog(
                            title: Text(alert.title),
                            content: Text('${alert.message}\n\nالإحداثيات: ${alert.latitude.toStringAsFixed(6)}, ${alert.longitude.toStringAsFixed(6)}\nيرجى الفحص الميداني.'),
                            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
                          )),
                          child: const Icon(Icons.warning_amber, color: Colors.red, size: 30),
                        ),
                      )),
                    ],
                  ),
                ],
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
