import 'package:material_ui/material_ui.dart';

import '../../models/calculator_models.dart';

/// تاب الجدول الزمني لمهام المحصول.
class CalculatorTimelineTab extends StatelessWidget {
  final List<CalculatorTask> tasks;
  final Color primaryColor;
  final bool isDark;

  const CalculatorTimelineTab({
    super.key,
    required this.tasks,
    required this.primaryColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const CalculatorEmptyState(
        icon: Icons.timeline,
        title: 'لا يوجد جدول زمني',
        subtitle: 'لم يتم إضافة مهام لهذا المحصول',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final categoryColor = calculatorCategoryColor(task.category, primaryColor);
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
                      color: index == tasks.length - 1
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
                    color: isDark
                        ? const Color(0xFF1E1E1E)
                        : Theme.of(context).cardColor,
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
}

Color calculatorCategoryColor(String category, Color primaryColor) {
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
      return primaryColor;
  }
}

/// تاب المشتريات والكميات.
class CalculatorMaterialsTab extends StatelessWidget {
  final List<CalculatorMaterial> materials;
  final double areaMultiplier;
  final bool hasExplicitArea;
  final String areaUnit;
  final Color primaryColor;
  final bool isDark;
  final double Function(CalculatorMaterial) quantityOf;
  final double totalCost;

  const CalculatorMaterialsTab({
    super.key,
    required this.materials,
    required this.areaMultiplier,
    required this.hasExplicitArea,
    required this.areaUnit,
    required this.primaryColor,
    required this.isDark,
    required this.quantityOf,
    required this.totalCost,
  });

  @override
  Widget build(BuildContext context) {
    if (materials.isEmpty) {
      return const CalculatorEmptyState(
        icon: Icons.shopping_cart,
        title: 'لا يوجد مشتريات',
        subtitle: 'لم يتم إضافة مواد لهذا المحصول',
      );
    }

    final grouped = <String, List<CalculatorMaterial>>{};
    for (final m in materials) {
      grouped.putIfAbsent(m.category, () => []).add(m);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.crop_free, color: primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasExplicitArea
                      ? 'الكميات محسوبة على مساحة ${areaMultiplier.toStringAsFixed(2)} $areaUnit'
                      : 'لم تُحدد مساحة، الكميات محسوبة لوحدة واحدة ($areaUnit)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primaryColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...grouped.entries.map((entry) {
          return Card(
            color: isDark ? const Color(0xFF1E1E1E) : null,
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
                      Icon(calculatorMaterialIcon(entry.key),
                          color: primaryColor, size: 20),
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
                    final totalQty = quantityOf(m);
                    final materialCost = totalQty * m.estimatedPricePerUnit;
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
                                        color: isDark
                                            ? Colors.grey[300]
                                            : Colors.black87)),
                                const SizedBox(height: 2),
                                Text(
                                  '${totalQty.toStringAsFixed(2)} ${m.unit} • ${materialCost.toStringAsFixed(0)} ج.م',
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
              colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
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
              Text('${totalCost.toStringAsFixed(0)} ج.م',
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
}

IconData calculatorMaterialIcon(String category) {
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

/// تاب التحليل المالي.
class CalculatorFinancialTab extends StatelessWidget {
  final CalculatorFinancial financial;
  final double totalYield;
  final double totalMaterialsCost;
  final Color primaryColor;
  final bool isDark;

  const CalculatorFinancialTab({
    super.key,
    required this.financial,
    required this.totalYield,
    required this.totalMaterialsCost,
    required this.primaryColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final totalRevenue = totalYield * financial.expectedPricePerYieldUnit;
    final netProfit = totalRevenue - totalMaterialsCost;
    final roi = totalMaterialsCost > 0
        ? (netProfit / totalMaterialsCost) * 100
        : 0.0;
    final hasCost = totalMaterialsCost > 0;

    if (financial.expectedYieldPerUnit == 0 &&
        financial.expectedPricePerYieldUnit == 0 &&
        financial.costDistribution.isEmpty) {
      return const CalculatorEmptyState(
        icon: Icons.attach_money,
        title: 'لا يوجد تحليل مالي',
        subtitle: 'لم يتم إضافة بيانات مالية لهذا المحصول',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: CalculatorMiniStat(
                icon: Icons.eco,
                label: 'الإنتاج المتوقع',
                value: '${totalYield.toStringAsFixed(1)} ${financial.yieldUnit}',
                color: Colors.green,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CalculatorMiniStat(
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
          color: isDark ? const Color(0xFF1E1E1E) : null,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CalculatorInfoRow('إجمالي تكلفة المشتريات',
                    '${totalMaterialsCost.toStringAsFixed(0)} ج.م',
                    color: Colors.red, isDark: isDark),
                Divider(height: 20, color: isDark ? Colors.grey[800] : null),
                CalculatorInfoRow('صافي الربح المتوقع',
                    '${netProfit.toStringAsFixed(0)} ج.م',
                    color: netProfit > 0 ? Colors.green : Colors.red,
                    isBold: true,
                    isDark: isDark),
                Divider(height: 20, color: isDark ? Colors.grey[800] : null),
                CalculatorInfoRow(
                    'نسبة العائد (ROI)',
                    hasCost ? '${roi.toStringAsFixed(1)}%' : 'غير محدد',
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
                color: isDark ? Colors.white : Colors.black87,
              )),
          const SizedBox(height: 12),
          Card(
            color: isDark ? const Color(0xFF1E1E1E) : null,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Builder(builder: (context) {
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
                                      color: isDark
                                          ? Colors.grey[300]
                                          : Colors.black87)),
                              Text('${e.value.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: primaryColor)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: ratio,
                            minHeight: 8,
                            backgroundColor:
                                isDark ? Colors.grey[800] : Colors.grey.shade200,
                            color: primaryColor,
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
}

/// صف «عنوان — قيمة» في بطاقة مالية.
class CalculatorInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool isBold;
  final bool isDark;

  const CalculatorInfoRow(
    this.label,
    this.value, {
    super.key,
    this.color,
    this.isBold = false,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
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
}

/// بطاقة رقم صغير مع أيقونة.
class CalculatorMiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const CalculatorMiniStat({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isDark ? const Color(0xFF1E1E1E) : null,
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
}

/// حالة فراغ موحّدة لتابات النتائج.
class CalculatorEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const CalculatorEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
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
