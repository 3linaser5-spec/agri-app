import 'package:flutter/material.dart';
import '../../models/my_farm_model.dart';
import '../../services/my_farm_service.dart';

class ProgramDetailsScreen extends StatefulWidget {
  final MyFarmProgram program;
  const ProgramDetailsScreen({super.key, required this.program});

  @override
  State<ProgramDetailsScreen> createState() => _ProgramDetailsScreenState();
}

class _ProgramDetailsScreenState extends State<ProgramDetailsScreen> {
  late MyFarmProgram _program;

  @override
  void initState() {
    super.initState();
    _program = widget.program;
  }

  Future<void> _deleteProgram() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف البرنامج'),
        content: const Text('هل أنت متأكد من حذف البرنامج من مزرعتك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await MyFarmService.deleteProgram(_program.id);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حذف البرنامج'),
            backgroundColor: Color(0xFF047857),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${_program.templateEmoji} ${_program.templateName}',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF047857),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              tooltip: 'حذف البرنامج',
              onPressed: _deleteProgram,
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.timeline), text: 'المهام'),
              Tab(icon: Icon(Icons.shopping_cart), text: 'المشتريات'),
            ],
          ),
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF047857).withOpacity(0.1),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Color(0xFF047857), size: 18),
                        const SizedBox(width: 6),
                        Text('المحافظة: ${_program.governorate}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'اليوم ${_program.daysSinceStart}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _program.progress,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        color: const Color(0xFF047857),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'التقدم: ${(_program.progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: TabBarView(
                  children: [
                    _buildTasksTab(),
                    _buildMaterialsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ تاب المهام ============
  Widget _buildTasksTab() {
    if (_program.tasks.isEmpty) {
      return const Center(child: Text('لا يوجد مهام'));
    }

    final tasks = List<Map<String, dynamic>>.from(_program.tasks);
    tasks.sort((a, b) => (a['day_from_start'] as int? ?? 0)
        .compareTo(b['day_from_start'] as int? ?? 0));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final day = task['day_from_start'] as int? ?? 0;
        final category = task['category'] as String? ?? '';
        final color = _getCategoryColor(category);

        // حالة المهمة
        final status = _getTaskStatus(day);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // دائرة اليوم
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: status.color,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text('$day',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task['title']?.toString() ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(task['description']?.toString() ?? '',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(category,
                                style: TextStyle(
                                    fontSize: 9,
                                    color: color,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: status.color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(status.label,
                                style: TextStyle(
                                    fontSize: 9,
                                    color: status.color,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _TaskStatus _getTaskStatus(int day) {
    if (day == _program.daysSinceStart) {
      return _TaskStatus('اليوم', Colors.orange);
    } else if (day < _program.daysSinceStart) {
      return _TaskStatus('انتهت', Colors.green);
    } else {
      return _TaskStatus('قادمة', Colors.blue);
    }
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
        return const Color(0xFF047857);
    }
  }

  // ============ تاب المشتريات ============
  Widget _buildMaterialsTab() {
    if (_program.materials.isEmpty) {
      return const Center(child: Text('لا يوجد مشتريات'));
    }

    double areaMultiplier = 1.0;
    final area = _program.inputValues['area'];
    if (area is num) areaMultiplier = area.toDouble();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: _program.materials.map((m) {
        final qty = (m['quantity_per_unit'] as num? ?? 0) * areaMultiplier;
        final price = m['price_per_unit'] as num? ?? 0;
        final totalCost = qty * price;
        final unit = m['unit']?.toString() ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.shopping_bag,
                color: Color(0xFF047857)),
            title: Text(m['name']?.toString() ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              '${m['category']} • ${qty.toStringAsFixed(2)} $unit',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Text('${totalCost.toStringAsFixed(0)} ج.م',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF047857))),
          ),
        );
      }).toList(),
    );
  }
}

class _TaskStatus {
  final String label;
  final Color color;
  _TaskStatus(this.label, this.color);
}
