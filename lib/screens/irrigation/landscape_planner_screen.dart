import 'package:material_ui/material_ui.dart';

import '../../models/landscape_design_models.dart';
import '../../services/landscape_hydraulic_design_service.dart';
import 'irrigation_map_editor_screen.dart';
import 'landscape_design_result_screen.dart';
import 'landscape_plan_canvas.dart';

/// مصمم اللاندسكيب: المهندس يرسم المسطحات بنفسه، يختار النباتات، ثم يطلب
/// التصميم الهيدروليكي (خطوط فرعية ← رئيسي ← مضخة).
class LandscapePlannerScreen extends StatefulWidget {
  final LandscapePlan? initialPlan;
  const LandscapePlannerScreen({super.key, this.initialPlan});

  @override
  State<LandscapePlannerScreen> createState() => _LandscapePlannerScreenState();
}

class _LandscapePlannerScreenState extends State<LandscapePlannerScreen> {
  late LandscapePlan plan;
  final List<PlanPoint> draftPoints = [];
  String? selectedShapeId;
  LandscapeHydraulicDesign? design;
  LandscapeDesignSettings settings = const LandscapeDesignSettings();
  int shapeCounter = 0;
  bool drawing = false;
  bool placingSource = false;

  final areaCtrl = TextEditingController();
  final widthCtrl = TextEditingController();
  final heightCtrl = TextEditingController();
  final flowCtrl = TextEditingController();
  final liftCtrl = TextEditingController();
  final etoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    plan = widget.initialPlan ??
        LandscapePlan(
          id: 'landscape-${DateTime.now().millisecondsSinceEpoch}',
          nameAr: 'تصميم لاندسكيب',
          plotWidthM: 24,
          plotHeightM: 16,
        );
    widthCtrl.text = plan.plotWidthM.toStringAsFixed(0);
    heightCtrl.text = plan.plotHeightM.toStringAsFixed(0);
    areaCtrl.text = plan.manualAreaM2 > 0 ? plan.manualAreaM2.toStringAsFixed(0) : '';
    flowCtrl.text = plan.availableFlowLpm.toStringAsFixed(0);
    liftCtrl.text = plan.staticLiftM.toStringAsFixed(1);
    etoCtrl.text = settings.etoMmDay.toStringAsFixed(1);
  }

  @override
  void dispose() {
    areaCtrl.dispose();
    widthCtrl.dispose();
    heightCtrl.dispose();
    flowCtrl.dispose();
    liftCtrl.dispose();
    etoCtrl.dispose();
    super.dispose();
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  void _updatePlan(LandscapePlan next) => setState(() {
        plan = next;
        design = null;
      });

  Future<LandscapePlantType?> _pickPlant({String? currentId}) async {
    return showModalBottomSheet<LandscapePlantType>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'اختر النبات — لكل نبات طبيعة ري مختلفة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: LandscapePlantType.catalog.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final type = LandscapePlantType.catalog[index];
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: Color(type.colorValue)),
                      title: Text(type.nameAr),
                      subtitle: Text(
                        '${type.method.labelAr} — Kc ${type.kc} — '
                        '${type.emitterFlowLpm >= 1 ? '${type.emitterFlowLpm.toStringAsFixed(0)} لتر/دقيقة' : '${(type.emitterFlowLpm * 60).toStringAsFixed(1)} لتر/ساعة'}',
                      ),
                      selected: type.id == currentId,
                      trailing: type.needsIrrigation ? null : const Text('بدون ري'),
                      onTap: () => Navigator.pop(context, type),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onCanvasTap(PlanPoint point) {
    if (placingSource) {
      setState(() {
        plan = plan.copyWith(waterSourcePoint: point);
        placingSource = false;
        design = null;
      });
      return;
    }
    if (!drawing) return;
    setState(() => draftPoints.add(point));
  }

  Future<void> _closeShape() async {
    if (draftPoints.length < 3) {
      _snack('أضف 3 نقاط على الأقل لإغلاق المسطح.');
      return;
    }
    final type = await _pickPlant();
    if (!mounted || type == null) return;
    shapeCounter += 1;
    final shape = LandscapeShape(
      id: 'shape-$shapeCounter',
      nameAr: '${type.nameAr} $shapeCounter',
      plantTypeId: type.id,
      points: List<PlanPoint>.from(draftPoints),
    );
    setState(() {
      draftPoints.clear();
      drawing = false;
      plan = plan.copyWith(shapes: [...plan.shapes, shape]);
      design = null;
      selectedShapeId = shape.id;
    });
  }

  Future<void> _changeSelectedPlant() async {
    LandscapeShape? shape;
    for (final item in plan.shapes) {
      if (item.id == selectedShapeId) shape = item;
    }
    if (shape == null) return;
    final type = await _pickPlant(currentId: shape.plantTypeId);
    if (!mounted || type == null) return;
    final shapeId = shape.id;
    setState(() {
      plan = plan.copyWith(
        shapes: [
          for (final item in plan.shapes)
            item.id == shapeId ? item.copyWith(plantTypeId: type.id) : item,
        ],
      );
      design = null;
    });
  }

  void _deleteSelected() {
    if (selectedShapeId == null) return;
    setState(() {
      plan = plan.copyWith(shapes: plan.shapes.where((s) => s.id != selectedShapeId).toList());
      selectedShapeId = null;
      design = null;
    });
  }

  Future<void> _pickAreaFromMap() async {
    final result = await Navigator.push<IrrigationMapEditResult>(
      context,
      MaterialPageRoute(builder: (_) => const IrrigationMapEditorScreen()),
    );
    if (!mounted || result == null) return;
    // لوحة الرسم مربعة تقريبًا بنفس مساحة الحدود المرسومة على الخريطة.
    final side = (result.areaM2 <= 0 ? 20.0 : (result.areaM2 / 1.5).clamp(6.0, 400.0));
    setState(() {
      plan = plan.copyWith(
        areaSource: LandscapeAreaSource.manual,
        manualAreaM2: result.areaM2,
        plotWidthM: side,
        plotHeightM: (result.areaM2 / side).clamp(4.0, 400.0),
      );
      areaCtrl.text = result.areaM2.toStringAsFixed(0);
      widthCtrl.text = plan.plotWidthM.toStringAsFixed(0);
      heightCtrl.text = plan.plotHeightM.toStringAsFixed(0);
      design = null;
    });
    _snack('تم أخذ المساحة من الخريطة: ${result.areaM2.toStringAsFixed(0)} م² '
        '(${result.areaFeddan.toStringAsFixed(2)} فدان)');
  }

  void _runDesign() {
    if (plan.areaM2 <= 0) {
      _snack('أدخل مساحة الموقع أو ارسم مسطحات على اللوحة.');
      return;
    }
    if (!plan.shapes.any((s) => s.plantType?.needsIrrigation == true)) {
      _snack('ارسم مسطحًا واحدًا على الأقل واختر له نباتًا يحتاج ريًا.');
      return;
    }
    final result = const LandscapeHydraulicDesignService().design(plan, settings: settings);
    setState(() => design = result);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LandscapeDesignResultScreen(
          plan: plan,
          design: result,
          settings: settings,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('مصمم اللاندسكيب والري'),
            actions: [
              IconButton(
                tooltip: 'تصميم جديد',
                onPressed: () {
                  setState(() {
                    draftPoints.clear();
                    selectedShapeId = null;
                    design = null;
                    drawing = false;
                  });
                },
                icon: const Icon(Icons.layers_clear_outlined),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _areaCard(),
              const SizedBox(height: 10),
              SizedBox(height: 330, child: _canvasCard()),
              const SizedBox(height: 8),
              _toolbar(),
              const SizedBox(height: 12),
              _summaryCard(),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _runDesign,
                icon: const Icon(Icons.engineering),
                label: const Text('توليد التصميم الهيدروليكي'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );

  Widget _areaCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('مساحة الموقع', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SegmentedButton<LandscapeAreaSource>(
                segments: const [
                  ButtonSegment(
                    value: LandscapeAreaSource.manual,
                    label: Text('كتابة يدوية'),
                    icon: Icon(Icons.keyboard_outlined),
                  ),
                  ButtonSegment(
                    value: LandscapeAreaSource.drawn,
                    label: Text('من الرسم'),
                    icon: Icon(Icons.draw_outlined),
                  ),
                ],
                selected: {plan.areaSource},
                onSelectionChanged: (selection) {
                  _updatePlan(plan.copyWith(areaSource: selection.first));
                },
              ),
              if (plan.areaSource == LandscapeAreaSource.manual) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: areaCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'المساحة (متر مربع)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          _updatePlan(plan.copyWith(manualAreaM2: double.tryParse(value) ?? 0));
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _pickAreaFromMap,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('من الخريطة'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'التحديد بالموقع اختياري؛ يمكنك كتابة المساحة فقط والرسم داخل اللوحة.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widthCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'عرض اللوحة (م)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) => _updatePlan(
                        plan.copyWith(plotWidthM: (double.tryParse(value) ?? 24).clamp(4, 500)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: heightCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'طول اللوحة (م)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) => _updatePlan(
                        plan.copyWith(plotHeightM: (double.tryParse(value) ?? 16).clamp(4, 500)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: flowCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'تصرف المصدر (لتر/دقيقة)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) => _updatePlan(
                        plan.copyWith(availableFlowLpm: double.tryParse(value) ?? 0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: liftCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'فرق المنسوب (م)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) => _updatePlan(
                        plan.copyWith(staticLiftM: double.tryParse(value) ?? 0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: etoCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ETo (مم/يوم)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) => setState(() {
                        settings = settings.copyWith(etoMmDay: double.tryParse(value) ?? 6);
                        design = null;
                      }),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _canvasCard() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                LandscapePlanCanvas(
                  plan: plan,
                  draftPoints: draftPoints,
                  selectedShapeId: selectedShapeId,
                  design: design,
                  drawing: drawing || placingSource,
                  onAddPoint: _onCanvasTap,
                  onSelectShape: (id) => setState(() => selectedShapeId = id),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Card(
                    color: Colors.white.withValues(alpha: .9),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Text(
                        placingSource
                            ? 'اضغط على مكان المضخة/المصدر'
                            : drawing
                                ? 'اضغط لإضافة نقاط المسطح (${draftPoints.length})'
                                : 'اضغط على مسطح لتحديده',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  drawing = !drawing;
                  placingSource = false;
                }),
                icon: Icon(drawing ? Icons.pan_tool : Icons.edit_outlined),
                label: Text(drawing ? 'إيقاف الرسم' : 'رسم مسطح'),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: draftPoints.isEmpty
                    ? null
                    : () => setState(() => draftPoints.removeLast()),
                icon: const Icon(Icons.undo),
                label: const Text('تراجع'),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  placingSource = true;
                  drawing = false;
                }),
                icon: const Icon(Icons.water_damage_outlined),
                label: const Text('مكان المضخة'),
              ),
            ],
          ),
        ],
      );

  Widget _toolbar() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonalIcon(
            onPressed: draftPoints.length >= 3 ? _closeShape : null,
            icon: const Icon(Icons.check_circle_outline),
            label: Text('إغلاق المسطح واختيار نباته (${draftPoints.length}/3)'),
          ),
          OutlinedButton.icon(
            onPressed: selectedShapeId == null ? null : _changeSelectedPlant,
            icon: const Icon(Icons.eco_outlined),
            label: const Text('تغيير نبات المسطح'),
          ),
          OutlinedButton.icon(
            onPressed: selectedShapeId == null ? null : _deleteSelected,
            icon: const Icon(Icons.delete_outline),
            label: const Text('حذف المسطح'),
          ),
          OutlinedButton.icon(
            onPressed: () => setState(() => draftPoints.clear()),
            icon: const Icon(Icons.close),
            label: const Text('إلغاء الرسم الحالي'),
          ),
        ],
      );

  Widget _summaryCard() {
    final irrigated = plan.shapes.where((s) => s.plantType?.needsIrrigation == true).length;
    return Card(
      color: const Color(0xFFF1F8E9),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.landscape_outlined, size: 20),
                const SizedBox(width: 6),
                Text(
                  'المساحة: ${plan.areaM2.toStringAsFixed(0)} م² '
                  '(${(plan.areaM2 / 4200).toStringAsFixed(2)} فدان)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('مسطحات: ${plan.shapes.length} — منها $irrigated تحتاج ريًا'),
            if (plan.areaSource == LandscapeAreaSource.drawn && plan.shapes.isNotEmpty)
              Text('المساحة المحسوبة من الرسم: ${plan.drawnAreaM2.toStringAsFixed(0)} م²'),
          ],
        ),
      ),
    );
  }
}
