import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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

  void addPoint(LatLng point) => setState(() => points.add(point));

  double get approximateAreaM2 {
    if (points.length < 3) return 0;
    const metersPerDegree = 111320.0;
    var sum = 0.0;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      sum += (a.longitude * metersPerDegree) * (b.latitude * metersPerDegree) -
          (b.longitude * metersPerDegree) * (a.latitude * metersPerDegree);
    }
    return sum.abs() / 2;
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
            ),
            IconButton(
              onPressed: () => setState(points.clear),
              icon: const Icon(Icons.delete_outline),
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
                              : 'المساحة التقريبية: '
                                  '${approximateAreaM2.toStringAsFixed(1)} م²',
                        ),
                      ),
                      FilledButton(
                        onPressed: points.length < 3
                            ? null
                            : () => Navigator.pop(context, points),
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
