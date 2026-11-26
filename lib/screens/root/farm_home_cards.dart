import 'package:material_ui/material_ui.dart';

import '../../models/farm_workspace_models.dart';
import '../../models/weather_forecast.dart';
import '../../services/farm_task_service.dart';
import '../../services/smart_weather_advice.dart';
import '../farm/farm_tasks_screen.dart';

/// بطاقة التوصيات الذكية المبنية على الطقس (قرار الري، الحرارة، الرطوبة).
class SmartWeatherAdviceCard extends StatelessWidget {
  final WeatherSnapshot? snapshot;

  const SmartWeatherAdviceCard({super.key, this.snapshot});

  static const Color _green = Color(0xFF047857);

  @override
  Widget build(BuildContext context) {
    final data = snapshot;
    if (data == null) return const SizedBox.shrink();
    final advice = SmartWeatherAdvisor.build(data);
    if (advice.isEmpty) return const SizedBox.shrink();
    final top = advice.first;
    final color = switch (top.severity) {
      3 => Colors.red,
      2 => Colors.orange,
      _ => _green,
    };
    final icon = switch (top.kind) {
      FarmAdviceKind.irrigation => Icons.water_drop,
      FarmAdviceKind.heat => Icons.thermostat,
      FarmAdviceKind.cold => Icons.ac_unit,
      FarmAdviceKind.fungal => Icons.coronavirus,
      FarmAdviceKind.spray => Icons.spa,
      FarmAdviceKind.harvest => Icons.agriculture,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  top.title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (top.waterSavingMm != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'توفير ~${top.waterSavingMm!.toStringAsFixed(0)} مم',
                    style: TextStyle(fontSize: 9, color: color),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(top.message, style: const TextStyle(fontSize: 12)),
          if (advice.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in advice.skip(1).take(3))
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.title,
                      style: const TextStyle(fontSize: 9),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// بطاقة «مهام اليوم» في الصفحة الرئيسية؛ تسمح بالإنجاز بضغطة واحدة.
class FarmTodayCard extends StatefulWidget {
  const FarmTodayCard({super.key});

  @override
  State<FarmTodayCard> createState() => _FarmTodayCardState();
}

class _FarmTodayCardState extends State<FarmTodayCard> {
  static const Color _green = Color(0xFF047857);
  List<FarmTask> _tasks = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tasks = await FarmTaskService.loadTasks();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _complete(FarmTask task) async {
    setState(() {
      _tasks = [
        for (final item in _tasks)
          if (item.id == task.id)
            task.copyWith(done: true)
          else
            item
      ];
    });
    try {
      await FarmTaskService.completeTask(task);
    } catch (_) {
      // لا نعطّل الواجهة لو الشبكة ضعيفة؛ الحالة ستُزامن لاحقًا.
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final now = DateTime.now();
    final pending = _tasks.where((task) => !task.done).toList();
    final due = pending
        .where((task) => task.isDueToday(now) || task.isOverdue(now))
        .take(3)
        .toList(growable: false);
    if (due.isEmpty && pending.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _green.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FarmTasksScreen()),
              );
              await _load();
            },
            child: Row(
              children: [
                const Icon(Icons.task_alt, color: _green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'مهام اليوم — ${pending.length} قيد الانتظار',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: _green,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_left, color: _green, size: 18),
              ],
            ),
          ),
          if (due.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'لا مهام مستحقة اليوم؛ المهام القادمة في شاشة المهام.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ),
            )
          else
            ...due.map(
              (task) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: _green,
                value: false,
                onChanged: (_) => _complete(task),
                title: Text(task.title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text(
                  '${task.isOverdue(now) ? 'متأخرة' : 'اليوم'} · ${task.repeat.label}'
                  '${task.notes.isEmpty ? '' : ' · ${task.notes}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
