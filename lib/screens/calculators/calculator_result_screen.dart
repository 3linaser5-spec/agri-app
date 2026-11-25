import 'package:material_ui/material_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/calculator_models.dart';
import '../../models/my_farm_model.dart';
import '../../services/my_farm_service.dart';
import '../../services/pdf_service.dart';
import '../../services/notification_service.dart';
import '../../utils/calc_engine.dart';
import '../../utils/safe_parse.dart'; // ✅ لضمان سلامة الأرقام
import 'calculator_result_tabs.dart';

class CalculatorResultScreen extends StatefulWidget {
  final CalculatorTemplate template;
  final Map<String, dynamic> inputValues;
  final Color primaryColor;
  final String? sectionName;

  const CalculatorResultScreen({
    super.key,
    required this.template,
    required this.inputValues,
    required this.primaryColor,
    this.sectionName,
  });

  @override
  State<CalculatorResultScreen> createState() =>
      _CalculatorResultScreenState();
}

class _CalculatorResultScreenState extends State<CalculatorResultScreen> {
  bool _saving = false;
  bool _saved = false;

  // المدخلات + القيم الافتراضية للحقول الرقمية اللي المستخدم سابها فاضية.
  late final Map<String, dynamic> _inputValues;

  // المهام مرتبة مرة واحدة (كانت بتتنسخ وتترتب مع كل عنصر بيترسم)
  late final List<CalculatorTask> _sortedTasks;

  @override
  void initState() {
    super.initState();
    final merged = Map<String, dynamic>.from(widget.inputValues);
    for (final f in widget.template.fields) {
      final isNumeric = f.type == 'number' || f.type == 'slider';
      if (isNumeric && merged[f.id] == null && f.defaultValue != null) {
        // ✅ استخدام SafeParse لضمان تحويل القيمة لرقم بأمان
        merged[f.id] = SafeParse.decimal(f.defaultValue);
      }
    }
    _inputValues = merged;
    _sortedTasks = List<CalculatorTask>.from(widget.template.tasks)
      ..sort((a, b) => a.dayFromStart.compareTo(b.dayFromStart));
  }

  double get _areaMultiplier => CalcEngine.areaMultiplier(_inputValues);

  double _materialQty(CalculatorMaterial m) => CalcEngine.quantity(
        perUnit: m.quantityPerUnit,
        formula: m.quantityFormula,
        inputs: _inputValues,
      );

  double get _totalYield => CalcEngine.totalYield(
        perUnit: widget.template.financial.expectedYieldPerUnit,
        yieldFormula: widget.template.financial.yieldFormula,
        inputs: _inputValues,
      );

  double get _totalMaterialsCost {
    double total = 0;
    for (var m in widget.template.materials) {
      total += _materialQty(m) * m.estimatedPricePerUnit;
    }
    return total;
  }

  // ✅ تحميل PDF — مع Loading Dialog
  Future<void> _downloadPdf() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF047857)),
                SizedBox(height: 16),
                Text('⏳ جاري تجهيز PDF...',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('قد يستغرق بضع ثوانٍ',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 500));

    try {
      await PdfService.generateAndSharePdf(
        programTitle: widget.template.name,
        programEmoji: widget.template.emoji,
        governorate: _inputValues['governorate']?.toString() ?? 'غير محدد',
        sectionName: widget.sectionName ?? widget.template.name,
        inputValues: _inputValues,
        tasks: widget.template.tasks.map((t) => t.toMap()).toList(),
        materials: widget.template.materials.map((m) => m.toMap()).toList(),
        financial: widget.template.financial.toMap(),
      );
    } catch (e) {
      debugPrint('❌ فشل إنشاء PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ فشل إنشاء PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  // ✅ حفظ في مزرعتي + جدولة الإشعارات
  Future<void> _saveToMyFarm() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ الرجاء تسجيل الدخول أولاً'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final startDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'اختر تاريخ بداية البرنامج',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );

    if (startDate == null) return;

    setState(() => _saving = true);

    final program = MyFarmProgram(
      id: '',
      userId: user.uid,
      templateId: widget.template.id,
      templateName: widget.template.name,
      templateEmoji: widget.template.emoji,
      sectionId: widget.template.sectionId,
      sectionName: widget.sectionName ?? widget.template.name,
      governorate: _inputValues['governorate']?.toString() ?? '',
      climateZone: _inputValues['climate_zone']?.toString() ?? '',
      areaUnit: widget.template.areaUnitLabel,
      inputValues: _inputValues,
      tasks: widget.template.tasks.map((t) => t.toMap()).toList(),
      materials: widget.template.materials.map((m) => m.toMap()).toList(),
      financial: widget.template.financial.toMap(),
      startDate: startDate,
      createdAt: DateTime.now(),
      status: 'active',
    );

    final id = await MyFarmService.saveProgram(program);

    if (!mounted) return;

    if (id != null) {
      int scheduledCount = 0;
      try {
        scheduledCount =
            await NotificationService.scheduleProgramNotifications(
          programId: id,
          programName: widget.template.name,
          startDate: startDate,
          tasks: widget.template.tasks
              .map((t) => {
                    'title': t.title,
                    'description': t.description,
                    'day_from_start': t.dayFromStart,
                    'category': t.category,
                  })
              .toList(),
        );
        debugPrint("✅ تم جدولة $scheduledCount إشعار");
      } catch (e) {
        debugPrint("⚠️ فشل جدولة الإشعارات: $e");
      }

      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
      });

      final remindersOk = scheduledCount > 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(remindersOk
              ? '✅ تم حفظ البرنامج وجدولة $scheduledCount تذكير'
              : '✅ تم حفظ البرنامج، لكن لم يتم تفعيل أي تذكير (راجع صلاحية الإشعارات)'),
          backgroundColor: const Color(0xFF047857),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ فشل الحفظ، حاول مرة أخرى'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('نتائج ${widget.template.name}',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: widget.primaryColor,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              tooltip: 'تحميل PDF',
              onPressed: _downloadPdf,
            ),
            IconButton(
              icon: Icon(
                _saved ? Icons.check_circle : Icons.save,
                color: Colors.white,
              ),
              tooltip: 'حفظ في مزرعتي',
              onPressed: _saving || _saved ? null : _saveToMyFarm,
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.timeline), text: 'الجدول'),
              Tab(icon: Icon(Icons.shopping_cart), text: 'المشتريات'),
              Tab(icon: Icon(Icons.attach_money), text: 'مالي'),
            ],
          ),
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              if (_inputValues['governorate'] != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: widget.primaryColor.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      Icon(Icons.location_on,
                          color: widget.primaryColor, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'المحافظة: ${_inputValues['governorate']}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: widget.primaryColor),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: TabBarView(
                  children: [
                    CalculatorTimelineTab(
                      tasks: _sortedTasks,
                      primaryColor: widget.primaryColor,
                      isDark: isDark,
                    ),
                    CalculatorMaterialsTab(
                      materials: widget.template.materials,
                      areaMultiplier: _areaMultiplier,
                      hasExplicitArea: CalcEngine.hasExplicitArea(_inputValues),
                      areaUnit: widget.template.areaUnit,
                      primaryColor: widget.primaryColor,
                      isDark: isDark,
                      quantityOf: _materialQty,
                      totalCost: _totalMaterialsCost,
                    ),
                    CalculatorFinancialTab(
                      financial: widget.template.financial,
                      totalYield: _totalYield,
                      totalMaterialsCost: _totalMaterialsCost,
                      primaryColor: widget.primaryColor,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              if (!_saved)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    // ✅ دعم الوضع الليلي
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveToMyFarm,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _saving ? 'جاري الحفظ...' : 'حفظ في مزرعتي',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
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
