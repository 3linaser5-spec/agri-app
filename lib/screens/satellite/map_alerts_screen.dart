import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/map_alert_model.dart';
import '../../services/map_alert_service.dart';

class MapAlertsScreen extends StatelessWidget {
  const MapAlertsScreen({super.key, this.fieldId});
  final String? fieldId;
  static const green = Color(0xFF047857);

  @override Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(
    appBar: AppBar(title: const Text('تنبيهات الفحص على الخريطة'), backgroundColor: green, foregroundColor: Colors.white),
    body: StreamBuilder<List<MapAlert>>(stream: MapAlertService.watchAlerts(fieldId: fieldId), builder: (context, snapshot) {
      final alerts = snapshot.data ?? const <MapAlert>[];
      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator());
      if (alerts.isEmpty) return const Center(child: Text('لا توجد تنبيهات فحص نشطة.'));
      final center = LatLng(alerts.first.latitude, alerts.first.longitude);
      return ListView(padding: const EdgeInsets.all(16), children: [_map(alerts, center), const SizedBox(height: 14), for (final a in alerts) _alertCard(context, a)]);
    }),
  ));

  Widget _map(List<MapAlert> alerts, LatLng center) => ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(height: 260, child: FlutterMap(options: MapOptions(initialCenter: center, initialZoom: 14), children: [TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.nabati.agri'), MarkerLayer(markers: [for (final a in alerts) Marker(point: LatLng(a.latitude, a.longitude), width: 44, height: 44, child: const Icon(Icons.location_on, color: Colors.red, size: 38))])])));
  Widget _alertCard(BuildContext context, MapAlert a) => Card(child: Padding(padding: const EdgeInsets.all(13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.warning_amber, color: a.severity == 'high' ? Colors.red : Colors.orange), const SizedBox(width: 8), Expanded(child: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)))]), const SizedBox(height: 5), Text(a.message), const SizedBox(height: 5), SelectableText('الإحداثيات: ${a.latitude.toStringAsFixed(6)}, ${a.longitude.toStringAsFixed(6)}', style: const TextStyle(fontSize: 12)), Row(children: [TextButton.icon(onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=${a.latitude},${a.longitude}'), mode: LaunchMode.externalApplication), icon: const Icon(Icons.map_outlined), label: const Text('فتح الخرائط')), TextButton.icon(onPressed: () => _note(context, a), icon: const Icon(Icons.note_add_outlined), label: const Text('ملاحظة فحص'))])]));
  Future<void> _note(BuildContext context, MapAlert a) async { final c = TextEditingController(); final value = await showDialog<String>(context: context, builder: (_) => AlertDialog(title: const Text('ملاحظة الفحص'), content: TextField(controller: c, minLines: 3, maxLines: 5, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'ما الذي وجدته في الموقع؟')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('حفظ'))])); c.dispose(); if (value == null || value.trim().isEmpty) return; await MapAlertService.addInspectionNote(alertId: a.id, text: value); }
}
