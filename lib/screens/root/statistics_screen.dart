import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../../services/offline_service.dart';


// ---------------- StatisticsScreen ----------------
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final items = await OfflineService.getAllDiagnoses();
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  Map<String, int> _getTopKeywords() {
    final Map<String, int> keywords = {
      'مرض فطري': 0,
      'حشرة': 0,
      'اصفرار': 0,
      'ذبول': 0,
      'بقع': 0,
      'عفن': 0,
      'نقص تغذية': 0,
    };
    for (var item in _items) {
      final text =
          "${item['question']} ${item['diagnosis']}".toLowerCase();
      keywords.forEach((key, value) {
        if (text.contains(key)) {
          keywords[key] = value + 1;
        }
      });
    }
    final sorted = keywords.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(5));
  }

  int _getSyncedCount() => _items.where((i) => i['isSynced'] == 1).length;
  int _getUnsyncedCount() => _items.where((i) => i['isSynced'] == 0).length;

  @override
  Widget build(BuildContext context) {
    final topKeywords = _getTopKeywords();
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإحصائيات',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF047857),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bar_chart, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('لا توجد إحصائيات بعد',
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey)),
                        SizedBox(height: 8),
                        Text('ابدأ بإجراء فحوصات لعرض الإحصائيات',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildStatCard(
                        icon: Icons.eco,
                        color: const Color(0xFF047857),
                        title: 'إجمالي التشخيصات',
                        value: _items.length.toString(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.cloud_done,
                              color: const Color(0xFF3B82F6),
                              title: 'مُزامن',
                              value: _getSyncedCount().toString(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.cloud_off,
                              color: const Color(0xFFF59E0B),
                              title: 'غير مُزامن',
                              value: _getUnsyncedCount().toString(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('📊 أكثر المشاكل تكراراً',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF047857))),
                      const SizedBox(height: 12),
                      Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: topKeywords.entries.map((e) {
                              final allValues = topKeywords.values.toList();
                              final max = allValues.isEmpty
                                  ? 1
                                  : (allValues.reduce(
                                              (a, b) => a > b ? a : b) ==
                                          0
                                      ? 1
                                      : allValues.reduce(
                                          (a, b) => a > b ? a : b));
                              final ratio = e.value / max;
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(e.key,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight:
                                                    FontWeight.w500)),
                                        Text('${e.value}',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight:
                                                    FontWeight.bold,
                                                color: Color(0xFF047857))),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: ratio,
                                      backgroundColor:
                                          Colors.grey.shade200,
                                      color: const Color(0xFF047857),
                                      minHeight: 6,
                                      borderRadius:
                                          BorderRadius.circular(3),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 4),
            Text(title,
                style:
                    const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
