import 'package:material_ui/material_ui.dart';

import '../../models/landscape_design_models.dart';
import '../../services/irrigation_bom_service.dart';
import '../../services/landscape_hydraulic_design_service.dart';
import '../calculators/irrigation_bom_screen.dart';
import 'landscape_3d_view_screen.dart';

/// نتيجة التصميم الهيدروليكي: المناطق ثم الخطوط الفرعية ثم الرئيسي ثم المضخة.
class LandscapeDesignResultScreen extends StatelessWidget {
  final LandscapePlan plan;
  final LandscapeHydraulicDesign design;
  final LandscapeDesignSettings settings;

  const LandscapeDesignResultScreen({
    super.key,
    required this.plan,
    required this.design,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('التصميم الهيدروليكي'),
              actions: [
                IconButton(
                  tooltip: 'معاينة 3D تفاعلية',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Landscape3DViewScreen(plan: plan, design: design),
                    ),
                  ),
                  icon: const Icon(Icons.view_in_ar_outlined),
                ),
              ],
              bottom: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'المناطق'),
                  Tab(text: 'الخطوط'),
                  Tab(text: 'المضخة'),
                  Tab(text: 'الخطوات والكميات'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _zonesTab(),
                _pipesTab(),
                _pumpTab(context),
                _stepsTab(context),
              ],
            ),
          ),
        ),
      );

  Widget _emptyNote(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );

  Widget _zonesTab() {
    if (design.zones.isEmpty) return _emptyNote('لا توجد مناطق صالحة للري.');
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _headerCard(),
        for (final zone in design.zones) _zoneCard(zone),
      ],
    );
  }

  Widget _headerCard() => Card(
        color: const Color(0xFFE8F5E9),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'إجمالي المساحة ${design.totalAreaM2.toStringAsFixed(0)} م² — '
                '${(design.totalAreaM2 / 4200).toStringAsFixed(2)} فدان',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('عدد المناطق: ${design.zones.length} — '
                  'مياه يومية تقديرية: ${design.totalDailyVolumeM3.toStringAsFixed(2)} م³'),
              if (design.simultaneousZones.isNotEmpty)
                Text('تعمل معًا: ${design.simultaneousZones.join('، ')}'),
              if (design.hasWarnings) ...[
                const SizedBox(height: 8),
                for (final warning in design.warnings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
                        const SizedBox(width: 6),
                        Expanded(child: Text(warning, style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      );

  Widget _zoneCard(LandscapeZoneDesign zone) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(zone.nameAr,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  Chip(
                    label: Text(zone.methodLabel, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _row('النبات', zone.plantName),
              _row('المساحة', '${zone.areaM2.toStringAsFixed(0)} م²'),
              _row('عدد النقّاطات/الرشاشات', zone.deviceCount.toStringAsFixed(0)),
              _row('التصرف التصميمي', '${zone.designFlowLpm.toStringAsFixed(0)} لتر/دقيقة'),
              _row('معدل التطبيق', '${zone.applicationRateMmH.toStringAsFixed(1)} مم/ساعة'),
              _row('الاحتياج اليومي', '${zone.dailyVolumeLitres.toStringAsFixed(0)} لتر'),
              _row('زمن الري اليومي', '${zone.runtimeMinutes.toStringAsFixed(0)} دقيقة'),
              _row('الخطوط الفرعية', '${zone.lateralCount} خط × '
                  '${zone.lateral.lengthM.toStringAsFixed(1)} م — '
                  'قطر ${zone.lateral.diameterMm.toStringAsFixed(0)} مم'),
              _row('يعمل في الدورة', '${zone.lateralsPerRun} خط (${zone.runsPerZone} دورة)'),
              _row('الضغط عند النقّاطة', '${zone.requiredPressureM.toStringAsFixed(0)} م'),
              _row('فرق الضغط داخل المنطقة',
                  '${zone.pressureVariationPercent.toStringAsFixed(1)}٪ من الضغط التشغيلي'),
            ],
          ),
        ),
      );

  Widget _pipesTab() {
    if (design.zones.isEmpty) return _emptyNote('لا توجد خطوط بعد حساب التصميم.');
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _segmentCard(design.main, isMain: true),
        for (final zone in design.zones) ...[
          _segmentCard(zone.submain, isMain: false),
          _segmentCard(zone.lateral, isMain: false, count: zone.lateralCount),
        ],
        Card(
          color: const Color(0xFFE3F2FD),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'القاعدة المطبّقة: اختيار أصغر قطر لا تتجاوز سرعته '
              '${settings.maxLateralVelocityMps} م/ث في الخطوط الفرعية و'
              '${settings.maxMainVelocityMps} م/ث في الرئيسي، '
              'وحساب الفاقد بمعادلة هازن-ويليامز (C = 140).',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _segmentCard(HydraulicPipeSegment segment, {required bool isMain, int count = 1}) => Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isMain ? const Color(0xFF1565C0) : const Color(0xFF64B5F6),
            child: Icon(isMain ? Icons.water : Icons.alt_route, size: 18, color: Colors.white),
          ),
          title: Text('${segment.roleLabelAr}: ${segment.fromAr} ← ${segment.toAr}'),
          subtitle: Text(
            'قطر ${segment.diameterMm.toStringAsFixed(0)} مم — '
            'طول ${segment.lengthM.toStringAsFixed(1)} م${count > 1 ? ' × $count' : ''} — '
            'تصرف ${segment.flowLpm.toStringAsFixed(0)} لتر/دقيقة\n'
            'سرعة ${segment.velocityMps.toStringAsFixed(2)} م/ث — '
            'فاقد ${segment.frictionHeadM.toStringAsFixed(2)} م',
          ),
          isThreeLine: true,
        ),
      );

  Widget _pumpTab(BuildContext context) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            color: const Color(0xFF0D47A1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('نقطة تشغيل المضخة',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(
                    '${design.pump.flowLpm.toStringAsFixed(0)} لتر/دقيقة  ×  '
                    '${design.pump.headM.toStringAsFixed(1)} متر',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'قدرة هيدروليكية ${design.pump.hydraulicPowerKw.toStringAsFixed(2)} ك.و — '
                    'موتور مقترح ${design.pump.motorPowerKw.toStringAsFixed(2)} ك.و '
                    '(${design.pump.recommendedHp.toStringAsFixed(0)} حصان)',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('كفاءة المضخة المفترضة', '${(design.pump.efficiency * 100).round()}٪'),
                  _row('فرق المنسوب', '${plan.staticLiftM.toStringAsFixed(1)} م'),
                  _row('فاقد الخط الرئيسي', '${design.main.frictionHeadM.toStringAsFixed(2)} م'),
                  _row('فاقد الفلتر', '${settings.filterLossM.toStringAsFixed(1)} م'),
                  _row('هامش الوصلات والمحابس', '${(settings.fittingsFactor * 100).round()}٪'),
                  const Divider(),
                  _row('المياه اليومية', '${design.totalDailyVolumeM3.toStringAsFixed(2)} م³'),
                  _row('إجمالي أطوال المواسير', '${design.totalPipeLengthM.toStringAsFixed(0)} م'),
                  _row('عدد محابس المناطق', '${design.mainValveCount}'),
                ],
              ),
            ),
          ),
          const Card(
            color: Color(0xFFFFF8E1),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'اختر مضخة من الكتالوج بنقطة تشغيل أعلى من أو تساوي هذه القيم، '
                'وتأكد من منحنى المضخة عند أقصى تصرف. الأرقام تقديرية للتصميم '
                'المبدئي وتحتاج مراجعة مهندس قبل الشراء.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Landscape3DViewScreen(plan: plan, design: design),
              ),
            ),
            icon: const Icon(Icons.view_in_ar_outlined),
            label: const Text('عرض التصميم ثلاثي الأبعاد'),
          ),
        ],
      );

  Widget _stepsTab(BuildContext context) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('ترتيب الحساب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          for (var i = 0; i < design.steps.length; i++)
            Card(
              child: ListTile(
                leading: CircleAvatar(radius: 14, child: Text('${i + 1}')),
                title: Text(design.steps[i], style: const TextStyle(fontSize: 13)),
              ),
            ),
          const SizedBox(height: 10),
          const Text('جدول الكميات التقديري',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final line in design.billOfMaterials)
                  ListTile(
                    dense: true,
                    title: Text(line.itemAr),
                    trailing: Text('${line.quantity.toStringAsFixed(line.quantity % 1 == 0 ? 0 : 1)} ${line.unitAr}'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              final bom = IrrigationBomService.buildFromLandscape(
                plan: plan,
                design: design,
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => IrrigationBomScreen(bom: bom),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long),
            label: const Text('قائمة مشتريات كاملة (كميات بدون أسعار)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54))),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
