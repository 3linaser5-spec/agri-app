import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/calculator_models.dart';
import '../../models/my_farm_model.dart';
import '../../services/my_farm_service.dart';
import '../../services/pdf_service.dart';
import '../../services/notification_service.dart';
import '../../utils/calc_engine.dart';
import '../../utils/safe_parse.dart'; // ✅ لضمان سلامة الأرقام

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
                    _buildTimelineTab(isDark),
                    _buildMaterialsTab(isDark),
                    _buildFinancialTab(isDark),
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

  // ============ تاب 1: الجدول الزمني ============
  Widget _buildTimelineTab(bool isDark) {
    if (_sortedTasks.isEmpty) {
      return _buildEmptyState(
          Icons.timeline, 'لا يوجد جدول زمني', 'لم يتم إضافة مهام لهذا المحصول');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sortedTasks.length,
      itemBuilder: (context, index) {
        final task = _sortedTasks[index];
        final categoryColor = _getCategoryColor(task.category);
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: categoryColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text('${task.dayFromStart}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      color: index == _sortedTasks.length - 1
                          ? Colors.transparent
                          : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(task.category,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: categoryColor)),
                          ),
                          const Spacer(),
                          Text('اليوم ${task.dayFromStart}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(task.title,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87)),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(task.description,
                            style: TextStyle(
                                fontSize: 12, 
                                color: isDark ? Colors.grey[400] : Colors.grey)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'ري':
        return Colors.blue;
      case 'تسميد':
        return Colors.green;
      case 'رش':
        return Colors.purple;
      case 'حصاد':
        return Colors.orange;
      case 'خدمة':
        return Colors.brown;
      default:
        return widget.primaryColor;
    }
  }

  // ============ تاب 2: المشتريات ============
  Widget _buildMaterialsTab(bool isDark) {
    if (widget.template.materials.isEmpty) {
      return _buildEmptyState(Icons.shopping_cart, 'لا يوجد مشتريات',
          'لم يتم إضافة مواد لهذا المحصول');
    }

    final grouped = <String, List<CalculatorMaterial>>{};
    for (var m in widget.template.materials) {
      grouped.putIfAbsent(m.category, () => []).add(m);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.crop_free, color: widget.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  CalcEngine.hasExplicitArea(_inputValues)
                      ? 'الكميات محسوبة على مساحة ${_areaMultiplier.toStringAsFixed(2)} ${widget.template.areaUnit}'
                      : 'لم تُحدد مساحة، الكميات محسوبة لوحدة واحدة (${widget.template.areaUnit})',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: widget.primaryColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...grouped.entries.map((entry) {
          return Card(
            color: isDark ? const Color(0xFF1E1E1E) : null, // ✅ دعم الوضع الليلي
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_getMaterialIcon(entry.key),
                          color: widget.primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Text(entry.key,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 15,
                              color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                  Divider(height: 16, color: isDark ? Colors.grey[800] : null),
                  ...entry.value.map((m) {
                    final totalQty = _materialQty(m);
                    final totalCost = totalQty * m.estimatedPricePerUnit;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: isDark ? Colors.grey[300] : Colors.black87)),
                                const SizedBox(height: 2),
                                Text(
                                  '${totalQty.toStringAsFixed(2)} ${m.unit} • ${totalCost.toStringAsFixed(0)} ج.م',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.primaryColor,
                widget.primaryColor.withValues(alpha: 0.7)
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.shopping_bag, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('إجمالي تكلفة المشتريات',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ),
              Text('${_totalMaterialsCost.toStringAsFixed(0)} ج.م',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getMaterialIcon(String category) {
    switch (category) {
      case 'تقاوي':
        return Icons.grass;
      case 'سماد':
        return Icons.science;
      case 'مبيد':
        return Icons.pest_control;
      case 'عمالة':
        return Icons.people;
      default:
        return Icons.shopping_bag;
    }
  }

  // ============ تاب 3: التحليل المالي ============
  Widget _buildFinancialTab(bool isDark) {
    final financial = widget.template.financial;

    final totalYield = _totalYield;
    final totalRevenue = totalYield * financial.expectedPricePerYieldUnit;
    final netProfit = totalRevenue - _totalMaterialsCost;
    
    // ✅ حماية من القسمة على صفر
    final roi = _totalMaterialsCost > 0 
        ? (netProfit / _totalMaterialsCost) * 100 
        : 0.0;
    final hasCost = _totalMaterialsCost > 0;

    if (financial.expectedYieldPerUnit == 0 &&
        financial.expectedPricePerYieldUnit == 0 &&
        financial.costDistribution.isEmpty) {
      return _buildEmptyState(Icons.attach_money, 'لا يوجد تحليل مالي',
          'لم يتم إضافة بيانات مالية لهذا المحصول');
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMiniStat(
                icon: Icons.eco,
                label: 'الإنتاج المتوقع',
                value:
                    '${totalYield.toStringAsFixed(1)} ${financial.yieldUnit}',
                color: Colors.green,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMiniStat(
                icon: Icons.trending_up,
                label: 'الإيراد المتوقع',
                value: '${totalRevenue.toStringAsFixed(0)} ج.م',
                color: Colors.blue,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          color: isDark ? const Color(0xFF1E1E1E) : null, // ✅ دعم الوضع الليلي
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildRow('إجمالي تكلفة المشتريات',
                    '${_totalMaterialsCost.toStringAsFixed(0)} ج.م',
                    color: Colors.red, isDark: isDark),
                Divider(height: 20, color: isDark ? Colors.grey[800] : null),
                _buildRow('صافي الربح المتوقع',
                    '${netProfit.toStringAsFixed(0)} ج.م',
                    color: netProfit > 0 ? Colors.green : Colors.red,
                    isBold: true, isDark: isDark),
                Divider(height: 20, color: isDark ? Colors.grey[800] : null),
                _buildRow(
                    'نسبة العائد (ROI)', 
                    hasCost ? '${roi.toStringAsFixed(1)}%' : 'غير محدد', // ✅ حماية
                    color: roi > 0 ? Colors.green : Colors.red,
                    isDark: isDark),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (financial.costDistribution.isNotEmpty) ...[
          Text('📊 توزيع التكاليف',
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black87)), // ✅ دعم الوضع الليلي
          const SizedBox(height: 12),
          Card(
            color: isDark ? const Color(0xFF1E1E1E) : null, // ✅ دعم الوضع الليلي
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Builder(builder: (context) {
                // ✅ حساب الإجمالي مرة واحدة قبل اللوب (تحسين الأداء)
                final total = financial.costDistribution.values
                    .fold<double>(0, (a, b) => a + b);
                
                return Column(
                  children: financial.costDistribution.entries.map((e) {
                    final ratio = total > 0 ? e.value / total : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e.key,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                      color: isDark ? Colors.grey[300] : Colors.black87)),
                              Text('${e.value.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: widget.primaryColor)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: ratio,
                            minHeight: 8,
                            backgroundColor: isDark ? Colors.grey[800] : Colors.grey.shade200,
                            color: widget.primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              }),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRow(String label, String value,
      {Color? color, bool isBold = false, bool isDark = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
                color: isDark ? Colors.grey[300] : Colors.black87)),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isBold ? 16 : 14,
                color: color ?? (isDark ? Colors.white : Colors.black87))),
      ],
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Card(
      color: isDark ? const Color(0xFF1E1E1E) : null, // ✅ دعم الوضع الليلي
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
