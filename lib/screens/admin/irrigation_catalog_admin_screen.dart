import 'package:flutter/material.dart';
import '../../models/irrigation_catalog_models.dart';
import '../../services/irrigation_catalog_service.dart';

class IrrigationCatalogAdminScreen extends StatelessWidget {
  const IrrigationCatalogAdminScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('مكتبة النباتات والمعدات')), body: StreamBuilder<List<IrrigationCatalogItem>>(stream: IrrigationCatalogService().watchItems(), builder: (context, snapshot) {
    if (snapshot.hasError) return Center(child: Text('تعذر تحميل المكتبة: ${snapshot.error}'));
    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
    final items = snapshot.data!;
    if (items.isEmpty) return const Center(child: Text('لا توجد عناصر نشطة في المكتبة'));
    return ListView.builder(itemCount: items.length, itemBuilder: (_, i) { final x=items[i]; return ListTile(leading: Icon(x.kind == 'plant' ? Icons.local_florist : Icons.water_drop), title: Text(x.nameAr), subtitle: Text('${x.kind} ${x.manufacturer.isEmpty ? '' : '• ${x.manufacturer}'}'), trailing: const Icon(Icons.chevron_left)); });
  }));
}
