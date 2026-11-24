import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/offline_service.dart';
import './ai_scanner_screen.dart';


// ---------------- HistoryScreen ----------------
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _searchCtrl.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final items = await OfflineService.getAllDiagnoses();
    if (mounted) {
      setState(() {
        _allItems = items;
        _loading = false;
      });
      _filterItems();
    }
  }

  Future<void> _retryDiagnosis(Map<String, dynamic> item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AiScannerScreen(
          userName: user.displayName ?? 'مزارع',
          userPhone: user.email?.split('@').first ?? '',
          initialQuestion: item['question']?.toString() ?? '',
          initialImagePath: item['imagePath']?.toString(),
          pendingDiagnosisId: item['id'] as int,
        ),
      ),
    );
    if (mounted) await _loadHistory();
  }

  void _filterItems() {
    if (!mounted) return;
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredItems = _allItems);
    } else {
      setState(() {
        _filteredItems = _allItems.where((item) {
          final question = (item['question'] ?? '').toString().toLowerCase();
          final diagnosis = (item['diagnosis'] ?? '').toString().toLowerCase();
          return question.contains(query) || diagnosis.contains(query);
        }).toList();
      });
    }
  }

  Future<void> _deleteOne(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسح التشخيص'),
        content: const Text('هل أنت متأكد من مسح هذا التشخيص؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('مسح', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await OfflineService.deleteDiagnosis(id);
      if (!mounted) return;
      await _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل التشخيصات',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF047857),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.white),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('مسح السجل'),
                  content: const Text('هل أنت متأكد من مسح كل السجل؟'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('إلغاء'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('مسح',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await OfflineService.clearAll();
                if (!mounted) return;
                await _loadHistory();
              }
            },
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'ابحث في السجل...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                  _allItems.isEmpty
                                      ? Icons.history
                                      : Icons.search_off,
                                  size: 80,
                                  color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                _allItems.isEmpty
                                    ? 'لا يوجد سجل حتى الآن'
                                    : 'لا توجد نتائج مطابقة للبحث',
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            final date = item['createdAt']?.toString() ?? '';
                            String dateFormatted = date;
                            try {
                              final dt = DateTime.parse(date).toLocal();
                              String two(int n) => n.toString().padLeft(2, '0');
                              dateFormatted =
                                  "${dt.day}/${dt.month}/${dt.year} - ${two(dt.hour)}:${two(dt.minute)}";
                            } catch (_) {}

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
                                        const Icon(Icons.eco,
                                            color: Color(0xFF047857)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            item['question']?.toString() ?? '',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    Text(
                                      item['diagnosis']?.toString() ?? '',
                                      style: const TextStyle(
                                          fontSize: 13, height: 1.5),
                                      maxLines: 5,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(dateFormatted,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey)),
                                        Row(
                                          children: [
                                            if (item['analysisPending'] == 1)
                                              IconButton(
                                                tooltip: 'إعادة إرسال الفحص',
                                                icon: const Icon(
                                                  Icons.replay,
                                                  color: Color(0xFF047857),
                                                  size: 20,
                                                ),
                                                onPressed: () =>
                                                    _retryDiagnosis(item),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                              ),
                                            if (item['analysisPending'] == 1)
                                              const Padding(
                                                padding:
                                                    EdgeInsets.only(left: 8),
                                                child: Text(
                                                  'لم يُحلل بعد',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.deepOrange,
                                                  ),
                                                ),
                                              )
                                            else if (item['isSynced'] == 0)
                                              const Padding(
                                                padding:
                                                    EdgeInsets.only(left: 8),
                                                child: Text(
                                                    '⏳ في انتظار المزامنة',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.orange)),
                                              ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  color: Colors.red, size: 20),
                                              onPressed: () => _deleteOne(
                                                  item['id'] as int),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
