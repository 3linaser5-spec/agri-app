import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/irrigation_design_models.dart';
import '../../services/irrigation_geometry_service.dart';

class IrrigationMapEditResult {
  final List<GeoCoordinate> points;
  final double areaM2;
  final double areaFeddan;

  const IrrigationMapEditResult({
    required this.points,
    required this.areaM2,
    required this.areaFeddan,
  });
}

class IrrigationMapEditorScreen extends StatefulWidget {
  const IrrigationMapEditorScreen({super.key});

  @override
  State<IrrigationMapEditorScreen> createState() =>
      _IrrigationMapEditorScreenState();
}

class _IrrigationMapEditorScreenState
    extends State<IrrigationMapEditorScreen> {
  final points = <LatLng>[];
  final center = const LatLng(30.0444, 31.2357);
  final geometry = const IrrigationGeometryService();

  void addPoint(LatLng point) => setState(() => points.add(point));

  List<GeoCoordinate> get coordinates => points
      .map((point) => GeoCoordinate.checked(
            latitude: point.latitude,
            longitude: point.longitude,
          ))
      .toList(growable: false);

  double get approximateAreaM2 => geometry.areaM2(coordinates);
  double get approximateAreaFeddan => geometry.areaFeddan(coordinates);

  void save() {
    final result = IrrigationMapEditResult(
      points: coordinates,
      areaM2: approximateAreaM2,
      areaFeddan: approximateAreaFeddan,
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('رسم حدود موقع الري'),
          actions: [
            IconButton(
              onPressed: points.isEmpty
                  ? null
                  : () => setState(() => points.removeLast()),
              icon: const Icon(Icons.undo),
              tooltip: 'تراجع',
            ),
            IconButton(
              onPressed: () => setState(points.clear),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'مسح الحدود',
            ),
          ],
        ),
        body: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 13,
                onTap: (_, point) => addPoint(point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.agri.app',
                ),
                if (points.length >= 3)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: points,
                        color: Colors.green.withValues(alpha: .25),
                        borderColor: Colors.green,
                        borderStrokeWidth: 3,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (var i = 0; i < points.length; i++)
                      Marker(
                        point: points[i],
                        width: 36,
                        height: 36,
                        child: CircleAvatar(
                          radius: 14,
                          child: Text('${i + 1}'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          points.length < 3
                              ? 'اضغط على الخريطة لإضافة 3 نقاط على الأقل'
                              : 'المساحة: ${approximateAreaM2.toStringAsFixed(1)} م²\n'
                                  'أي ${approximateAreaFeddan.toStringAsFixed(3)} فدان',
                        ),
                      ),
                      FilledButton(
                        onPressed: points.length < 3 ? null : save,
                        child: const Text('حفظ الحدود'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
