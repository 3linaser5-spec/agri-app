import 'package:flutter/material.dart';
import '../../models/calculator_models.dart';

class CalculatorResultScreen extends StatefulWidget {
  final CalculatorTemplate template;
  final Map<String, dynamic> inputValues;
  final Color primaryColor;

  const CalculatorResultScreen({
    super.key,
    required this.template,
    required this.inputValues,
    required this.primaryColor,
  });

  @override
  State<CalculatorResultScreen> createState() =>
      _CalculatorResultScreenState();
}

class _CalculatorResultScreenState extends State<CalculatorResultScreen> {
  double get _areaMultiplier {
    // لو المستخدم دخل مساحة، نضرب فيها
    final area = _inputValues['area'];
    if (area is num) return area.toDouble();
    // نجرب ندور على أي حقل اسمه فيه "area" أو "مساحة"
    for (var entry in _inputValues.entries) {
      if (entry.key.toLowerCase().contains('area') ||
          entry.key.contains('مساحة')) {
        if (entry.value is num) return (entry.value as num).toDouble();
      }
    }
    return 1.0;
  }

  Map<String, dynamic> get _inputValues => widget.inputValues;

  // ترتيب المهام حسب اليوم
  List<CalculatorTask> get _sortedTasks {
    final list = List<CalculatorTask>.from(widget.template.tasks);
    list.sort((a, b) => a.dayFromStart.compareTo(b.dayFromStart));
    return list;
  }

  // إجمالي تكلفة المواد
  double get _totalMaterialsCost {
    double total = 0;
    for (var m in widget.template.materials) {
      total += m.quantityPerUnit * m.estimatedPricePerUnit * _areaMultiplier;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('نتائج ${widget.template.name}',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: widget.primaryColor,
          iconTheme: const IconThemeData(color: Colors.white),
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
          child: TabBarView(
            children: [
              _buildTimelineTab(),
              _buildMaterialsTab(),
              _buildFinancialTab(),
            ],
          ),
        ),
      ),
    );
  }

  // ============ تاب 1: الجدول الزمني ============
  Widget _buildTimelineTab() {
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
              // الخط الزمني
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
                          : Colors.grey.shade300,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // المحتوى
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
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
                              color: categoryColor.withOpacity(0.15),
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
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(task.description,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
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
  Widget _buildMaterialsTab() {
    if (widget.template.materials.isEmpty) {
      return _buildEmptyState(Icons.shopping_cart, 'لا يوجد مشتريات',
          'لم يتم إضافة مواد لهذا المحصول');
    }

    // تجميع حسب الفئة
    final grouped = <String, List<CalculatorMaterial>>{};
    for (var m in widget.template.materials) {
      grouped.putIfAbsent(m.category, () => []).add(m);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // معلومات المساحة
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.crop_free, color: widget.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'الكميات محسوبة على مساحة ${_areaMultiplier.toStringAsFixed(2)} ${widget.template.areaUnit}',
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
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const Divider(height: 16),
                  ...entry.value.map((m) {
                    final totalQty = m.quantityPerUnit * _areaMultiplier;
                    final totalCost =
                        totalQty * m.estimatedPricePerUnit;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
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
        // الإجمالي
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.primaryColor,
                widget.primaryColor.withOpacity(0.7)
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.shopping_bag,
                  color: Colors.white, size: 28),
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
  Widget _buildFinancialTab() {
    final financial = widget.template.financial;

    // حساب الإنتاج الكلي والعائد
    final totalYield = financial.expectedYieldPerUnit * _areaMultiplier;
    final totalRevenue =
        totalYield * financial.expectedPricePerYieldUnit;
    final netProfit = totalRevenue - _totalMaterialsCost;
    final roi = _totalMaterialsCost > 0
        ? (netProfit / _totalMaterialsCost) * 100
        : 0.0;

    // لو مفيش بيانات مالية
    if (financial.expectedYieldPerUnit == 0 &&
        financial.expectedPricePerYieldUnit == 0 &&
        financial.costDistribution.isEmpty) {
      return _buildEmptyState(Icons.attach_money, 'لا يوجد تحليل مالي',
          'لم يتم إضافة بيانات مالية لهذا المحصول');
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // بطاقات الإنتاج والعائد
        Row(
          children: [
            Expanded(
              child: _buildMiniStat(
                icon: Icons.eco,
                label: 'الإنتاج المتوقع',
                value:
                    '${totalYield.toStringAsFixed(1)} ${financial.yieldUnit}',
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMiniStat(
                icon: Icons.trending_up,
                label: 'الإيراد المتوقع',
                value: '${totalRevenue.toStringAsFixed(0)} ج.م',
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // تكلفة + ربح
        Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildRow('إجمالي التكاليف',
                    '${_totalMaterialsCost.toStringAsFixed(0)} ج.م',
                    color: Colors.red),
                const Divider(height: 20),
                _buildRow('صافي الربح المتوقع',
                    '${netProfit.toStringAsFixed(0)} ج.م',
                    color: netProfit > 0 ? Colors.green : Colors.red,
                    isBold: true),
                const Divider(height: 20),
                _buildRow('نسبة العائد (ROI)',
                    '${roi.toStringAsFixed(1)}%',
                    color: roi > 0 ? Colors.green : Colors.red),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // توزيع التكاليف
        if (financial.costDistribution.isNotEmpty) ...[
          const Text('📊 توزيع التكاليف',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: financial.costDistribution.entries.map((e) {
                  final total = financial.costDistribution.values
                      .fold<double>(0, (a, b) => a + b);
                  final ratio = total > 0 ? e.value / total : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13)),
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
                          backgroundColor: Colors.grey.shade200,
                          color: widget.primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRow(String label, String value,
      {Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontWeight:
                    isBold ? FontWeight.bold : FontWeight.w500,
                fontSize: 14)),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isBold ? 16 : 14,
                color: color ?? Colors.black87)),
      ],
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey)),
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

  Widget _buildEmptyState(
      IconData icon, String title, String subtitle) {
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
