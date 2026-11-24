import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/irrigation_design_models.dart';
import '../../services/irrigation_pipe_route_service.dart';

class IrrigationPipeRouteEditorScreen extends StatefulWidget {
  final String? zoneId;
  const IrrigationPipeRouteEditorScreen({super.key, this.zoneId});

  @override
  State<IrrigationPipeRouteEditorScreen> createState() =>
      _IrrigationPipeRouteEditorScreenState();
}

class _IrrigationPipeRouteEditorScreenState
    extends State<IrrigationPipeRouteEditorScreen> {
  final center = const LatLng(30.0444, 31.2357);
  final points = <LatLng>[];
  final routeService = const IrrigationPipeRouteService();
  String diameter = '100';
  String material = 'PE';
  String zoneId = 'zone-1';
  String flow = '60';

  @override
  void initState() {
    super.initState();
    zoneId = widget.zoneId ?? 'zone-1';
  }

  IrrigationPipeRoute? get route {
    if (points.length < 2) return null;
    return IrrigationPipeRoute(
      id: 'pipe-route-${DateTime.now().millisecondsSinceEpoch}',
      points: points
          .map((point) => GeoCoordinate.checked(
                latitude: point.latitude,
                longitude: point.longitude,
              ))
          .toList(growable: false),
      diameterMm: double.tryParse(diameter) ?? 100,
      material: material,
      zoneId: zoneId,
      designFlowLpm: double.tryParse(flow) ?? 0,
    );
  }

  void save() {
    final value = route;
    if (value == null) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = route;
    final result = currentRoute == null
        ? null
        : routeService.analyze(currentRoute);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('رسم مسار ماسورة'),
          actions: [
            IconButton(
              onPressed: points.isEmpty
                  ? null
                  : () => setState(points.removeLast),
              icon: const Icon(Icons.undo),
            ),
            TextButton(
              onPressed: currentRoute == null ? null : save,
              child: const Text('حفظ'),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 130,
                    child: DropdownButtonFormField<String>(
                      initialValue: diameter,
                      decoration: const InputDecoration(labelText: 'القطر mm'),
                      items: ['50', '75', '100', '150', '200']
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => diameter = value!),
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    child: DropdownButtonFormField<String>(
                      initialValue: material,
                      decoration: const InputDecoration(labelText: 'المادة'),
                      items: ['PE', 'PVC', 'HDPE', 'UPVC']
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => material = value!),
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    child: TextFormField(
                      initialValue: flow,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'التصرف L/min'),
                      onChanged: (value) => flow = value,
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    child: TextFormField(
                      initialValue: zoneId,
                      decoration: const InputDecoration(labelText: 'Zone'),
                      onChanged: (value) => zoneId = value,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(result == null
                    ? 'اضغط نقطتين أو أكثر لرسم المسار.'
                    : 'الطول: ${result.lengthM.toStringAsFixed(1)} م — السرعة: '
                        '${result.velocityMps.toStringAsFixed(2)} م/ث'),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 13,
                  onTap: (_, point) => setState(() => points.add(point)),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.agri.app',
                  ),
                  if (points.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: points,
                          color: Colors.blue,
                          strokeWidth: 5,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      for (var i = 0; i < points.length; i++)
                        Marker(
                          point: points[i],
                          width: 32,
                          height: 32,
                          child: CircleAvatar(
                            radius: 12,
                            child: Text('${i + 1}'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
