import 'package:material_ui/material_ui.dart';

import '../../models/farm_workspace_models.dart';
import '../../services/farm_report_service.dart';
import '../../services/farm_share_service.dart';
import '../../services/farm_site_service.dart';
import '../../services/farm_task_service.dart';
import '../../services/offline_farm_store.dart';

/// شاشة مهام المزرعة: إضافة مهام متكررة، تذكيرات، وإنجاز سريع.
class FarmTasksScreen extends StatefulWidget {
  const FarmTasksScreen({super.key});

  @override
  State<FarmTasksScreen> createState() => _FarmTasksScreenState();
}

class _FarmTasksScreenState extends State<FarmTasksScreen> {
  static const Color _green = Color(0xFF047857);

  List<FarmTask> _tasks = const [];
  List<FarmPlot> _plots = const [];
  bool _loading = true;
  String? _error;
  int _pendingSync = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        FarmTaskService.loadTasks(),
        FarmSiteService.loadPlots(),
        OfflineFarmStore.pendingCount(),
      ]);
      if (!mounted) return;
      setState(() {
        _tasks = results[0] as List<FarmTask>;
        _plots = results[1] as List<FarmPlot>;
        _pendingSync = results[2] as int;
        _loading = false;
      });
      await FarmTaskService.rescheduleAll();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل المهام. تحقق من الاتصال ثم أعد المحاولة.';
        _loading = false;
      });
    }
  }

  Future<void> _addTask() async {
    final result = await showModalBottomSheet<_TaskDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TaskEditorSheet(plots: _plots),
    );
    if (result == null) return;
    final task = await FarmTaskService.addTask(FarmTask(
      id: '',
      ownerId: '',
      plotId: result.plotId,
      title: result.title,
      notes: result.notes,
      dueAt: result.dueAt,
      repeat: result.repeat,
      reminderEnabled: result.reminderEnabled,
    ));
    if (task == null || !mounted) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ المهمة وتذكيرها.')),
    );
  }

  Future<void> _toggle(FarmTask task) async {
    // تحديث متفائل حتى لا تنتظر الواجهة الشبكة.
    setState(() {
      _tasks = [
        for (final item in _tasks)
          if (item.id == task.id)
            task.done
                ? task.copyWith(done: false)
                : task.copyWith(done: true)
          else
            item
      ];
    });
    try {
      if (task.done) {
        await FarmTaskService.reopenTask(task);
      } else {
        await FarmTaskService.completeTask(task);
      }
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديث المهمة.')),
      );
      await _load();
    }
  }

  Future<void> _delete(FarmTask task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المهمة'),
        content: Text('هل تريد حذف «${task.title}»؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await FarmTaskService.deleteTask(task);
    await _load();
  }

  List<FarmTask> get _pending => _tasks.where((task) => !task.done).toList();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final overdue = _pending.where((task) => task.isOverdue(now)).toList();
    final today = _pending.where((task) => task.isDueToday(now)).toList();
    final later = _pending
        .where((task) => task.dueAt.isAfter(now) && !task.isDueToday(now))
        .toList();
    final done = _tasks.where((task) => task.done).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مهام المزرعة', style: TextStyle(color: Colors.white)),
        backgroundColor: _green,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'تصدير PDF',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _tasks.isEmpty
                ? null
                : () => FarmShareService.shareTasksPdf(_tasks),
          ),
          IconButton(
            tooltip: 'تصدير Excel',
            icon: const Icon(Icons.table_view),
            onPressed: _tasks.isEmpty
                ? null
                : () => FarmShareService.shareCsv(
                      fileName: 'مهام_المزرعة',
                      content: FarmReportService.csvForTasks(_tasks),
                      subject: 'مهام المزرعة',
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTask,
        backgroundColor: _green,
        icon: const Icon(Icons.add_task),
        label: const Text('مهمة جديدة'),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      children: [
                        _summaryHeader(overdue.length, today.length),
                        if (_pendingSync > 0) ...[
                          const SizedBox(height: 10),
                          _syncBanner(_pendingSync),
                        ],
                        if (_tasks.isEmpty) ...[
                          const SizedBox(height: 40),
                          _emptyState(),
                        ],
                        if (overdue.isNotEmpty)
                          _section(
                            title: 'متأخرة',
                            color: Colors.red,
                            tasks: overdue,
                            isDark: isDark,
                          ),
                        if (today.isNotEmpty)
                          _section(
                            title: 'اليوم',
                            color: _green,
                            tasks: today,
                            isDark: isDark,
                          ),
                        if (later.isNotEmpty)
                          _section(
                            title: 'قادمة',
                            color: Colors.blue,
                            tasks: later,
                            isDark: isDark,
                          ),
                        if (done.isNotEmpty)
                          _section(
                            title: 'منجزة',
                            color: Colors.grey,
                            tasks: done,
                            isDark: isDark,
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _summaryHeader(int overdue, int todayCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF047857), Color(0xFF10B981)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.task_alt, color: Colors.white, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_pending.length} مهمة قيد الانتظار',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'اليوم: $todayCount · متأخرة: $overdue · منجزة: ${_tasks.length - _pending.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _syncBanner(int count) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off, color: Colors.orange, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$count تغيير محفوظ على الجهاز وسيُزامن عند رجوع الإنترنت.',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );

  Widget _emptyState() => Column(
        children: [
          Icon(Icons.event_available, size: 90, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'لا توجد مهام بعد',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 6),
          const Text(
            'أضف مهام الري والتسميد والرش، وسنذكّرك بها في موعدها.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      );

  Widget _section({
    required String title,
    required Color color,
    required List<FarmTask> tasks,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                '$title (${tasks.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...tasks.map((task) => _taskTile(task, color, isDark)),
        ],
      ),
    );
  }

  Widget _taskTile(FarmTask task, Color color, bool isDark) {
    String? plotName;
    for (final plot in _plots) {
      if (plot.id == task.plotId) {
        plotName = plot.name;
        break;
      }
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        onTap: () => _toggle(task),
        onLongPress: () => _delete(task),
        leading: Checkbox(
          value: task.done,
          activeColor: _green,
          onChanged: (_) => _toggle(task),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: task.done ? TextDecoration.lineThrough : null,
            color: task.done ? Colors.grey : null,
          ),
        ),
        subtitle: Text(
          '${_date(task.dueAt)} · ${task.repeat.label}'
          '${plotName == null ? '' : ' · $plotName'}'
          '${task.notes.isEmpty ? '' : '\n${task.notes}'}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: task.reminderEnabled
            ? const Icon(Icons.notifications_active, size: 18, color: _green)
            : null,
      ),
    );
  }

  String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskDraft {
  final String title;
  final String notes;
  final DateTime dueAt;
  final TaskRepeat repeat;
  final bool reminderEnabled;
  final String? plotId;

  const _TaskDraft({
    required this.title,
    required this.notes,
    required this.dueAt,
    required this.repeat,
    required this.reminderEnabled,
    this.plotId,
  });
}

class _TaskEditorSheet extends StatefulWidget {
  final List<FarmPlot> plots;
  const _TaskEditorSheet({required this.plots});

  @override
  State<_TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<_TaskEditorSheet> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  DateTime _dueAt = DateTime.now().add(const Duration(days: 1));
  TaskRepeat _repeat = TaskRepeat.none;
  bool _reminder = true;
  String? _plotId;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(() {
      _dueAt = DateTime(picked.year, picked.month, picked.day, 8);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'مهمة جديدة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'عنوان المهمة',
                  hintText: 'مثال: ري القطعة الشمالية',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  'الموعد: ${_dueAt.day}/${_dueAt.month}/${_dueAt.year}',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TaskRepeat>(
                initialValue: _repeat,
                decoration: const InputDecoration(
                  labelText: 'التكرار',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final repeat in TaskRepeat.values)
                    DropdownMenuItem(value: repeat, child: Text(repeat.label)),
                ],
                onChanged: (value) =>
                    setState(() => _repeat = value ?? TaskRepeat.none),
              ),
              if (widget.plots.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _plotId,
                  decoration: const InputDecoration(
                    labelText: 'القطعة (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('كل المزرعة')),
                    for (final plot in widget.plots)
                      DropdownMenuItem(value: plot.id, child: Text(plot.name)),
                  ],
                  onChanged: (value) => setState(() => _plotId = value),
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _reminder,
                activeThumbColor: const Color(0xFF047857),
                title: const Text('تذكير في الموعد'),
                onChanged: (value) => setState(() => _reminder = value),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                  ),
                  onPressed: () {
                    final title = _title.text.trim();
                    if (title.isEmpty) return;
                    Navigator.pop(
                      context,
                      _TaskDraft(
                        title: title,
                        notes: _notes.text.trim(),
                        dueAt: _dueAt,
                        repeat: _repeat,
                        reminderEnabled: _reminder,
                        plotId: _plotId,
                      ),
                    );
                  },
                  child: const Text('حفظ المهمة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
