import 'package:material_ui/material_ui.dart';

import '../../data/egypt_data.dart';
import '../../models/farm_workspace_models.dart';
import '../../models/weekly_irrigation_schedule_model.dart';
import '../../services/farm_site_service.dart';
import '../../services/irrigation_planner_service.dart';
import '../../services/weekly_irrigation_schedule_service.dart';
import '../../services/weather_service.dart';

/// جدول ري أسبوعي مقترح من توقعات الطقس لمحصول القطعة المختارة.
class WeeklyIrrigationScheduleScreen extends StatefulWidget {
  const WeeklyIrrigationScheduleScreen({super.key});

  @override
  State<WeeklyIrrigationScheduleScreen> createState() =>
      _WeeklyIrrigationScheduleScreenState();
}

class _WeeklyIrrigationScheduleScreenState
    extends State<WeeklyIrrigationScheduleScreen> {
  static const Color _green = Color(0xFF047857);

  final TextEditingController _areaController =
      TextEditingController(text: '1');
  final TextEditingController _flowController = TextEditingController();

  List<FarmPlot> _plots = const [];
  List<FarmSite> _sites = const [];
  String? _selectedPlotId;
  String _governorate = '';
  IrrigationCropProfile _crop = IrrigationCropProfile.profiles.first;
  IrrigationGrowthStage _stage = IrrigationGrowthStage.midSeason;
  String _method = 'تنقيط';

  WeeklyIrrigationSchedule? _schedule;
  bool _loadingPlots = true;
  bool _loadingSchedule = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _governorate = EgyptData.governorates.first.name;
    _loadPlots();
  }

  @override
  void dispose() {
    _areaController.dispose();
    _flowController.dispose();
    super.dispose();
  }

  Future<void> _loadPlots() async {
    try {
      final plots = await FarmSiteService.loadPlots();
      final sites = await FarmSiteService.loadSites();
      if (!mounted) return;
      setState(() {
        _plots = plots;
        _sites = sites;
        _loadingPlots = false;
      });
      if (plots.isNotEmpty) {
        _applyPlot(plots.first, refresh: false);
      }
      await _refreshSchedule();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingPlots = false;
        _error = 'تعذر تحميل قطع الأرض. تحقق من الإنترنت وحاول تاني.';
      });
    }
  }

  void _applyPlot(FarmPlot plot, {bool refresh = true}) {
    FarmSite? site;
    for (final candidate in _sites) {
      if (candidate.id == plot.siteId) {
        site = candidate;
        break;
      }
    }
    final crop = IrrigationCropProfile.guess(plot.crop);
    final method = _matchMethod(plot.irrigationMethod);
    final governorate = _matchGovernorate(site?.governorate ?? '');
    setState(() {
      _selectedPlotId = plot.id;
      if (crop != null) _crop = crop;
      if (plot.areaFeddan > 0) {
        _areaController.text =
            plot.areaFeddan == plot.areaFeddan.roundToDouble()
                ? plot.areaFeddan.toStringAsFixed(0)
                : plot.areaFeddan.toStringAsFixed(2);
      }
      if (method != null) _method = method;
      if (governorate != null) _governorate = governorate;
    });
    if (refresh) _refreshSchedule();
  }

  static String? _matchMethod(String value) {
    if (value.trim().isEmpty) return null;
    for (final method in WeeklyIrrigationScheduleService.methodEfficiency.keys) {
      if (value.contains(method)) return method;
    }
    return null;
  }

  static String? _matchGovernorate(String value) {
    if (value.trim().isEmpty) return null;
    for (final governorate in EgyptData.governorates) {
      if (value.contains(governorate.name) ||
          governorate.name.contains(value.trim())) {
        return governorate.name;
      }
    }
    return null;
  }

  Future<void> _refreshSchedule() async {
    final areaFeddan = double.tryParse(_areaController.text.trim());
    if (areaFeddan == null || areaFeddan <= 0) {
      setState(() {
        _schedule = null;
        _error = 'أدخل مساحة صحيحة بالفدان.';
      });
      return;
    }
    GovernorateInfo governorate = EgyptData.governorates.first;
    for (final candidate in EgyptData.governorates) {
      if (candidate.name == _governorate) {
        governorate = candidate;
        break;
      }
    }
    setState(() {
      _loadingSchedule = true;
      _error = null;
    });
    try {
      final snapshot = await WeatherService.fetch(
        latitude: governorate.lat,
        longitude: governorate.lon,
      );
      final schedule = WeeklyIrrigationScheduleService.build(
        forecast: snapshot.days,
        areaM2:
            areaFeddan * WeeklyIrrigationScheduleService.squareMetersPerFeddan,
        crop: _crop,
        stage: _stage,
        efficiencyPercent:
            WeeklyIrrigationScheduleService.efficiencyFor(_method),
        pumpFlowM3PerHour: double.tryParse(_flowController.text.trim()),
      );
      if (!mounted) return;
      setState(() {
        _schedule = schedule;
        _loadingSchedule = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingSchedule = false;
        _error = 'تعذر جلب توقعات الطقس. تحقق من الإنترنت وحاول تاني.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final schedule = _schedule;
    return Scaffold(
      appBar: AppBar(
        title: const Text('جدول الري الأسبوعي',
            style: TextStyle(color: Colors.white)),
        backgroundColor: _green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loadingPlots
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildControls(isDark),
                  const SizedBox(height: 16),
                  if (_loadingSchedule)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_error != null) _buildError(isDark),
                  if (!_loadingSchedule && schedule != null) ...[
                    _buildSummary(schedule, isDark),
                    const SizedBox(height: 12),
                    for (final day in schedule.days) ...[
                      _buildDayCard(day, isDark),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'الأرقام إرشادية ومحسوبة بمعاملات FAO-56 النموذجية. قِس رطوبة التربة قبل الري الفعلي.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildControls(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _green.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_plots.isNotEmpty) ...[
            _label('القطعة'),
            DropdownButton<String>(
              value: _selectedPlotId,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              hint: const Text('اختر القطعة'),
              items: [
                for (final plot in _plots)
                  DropdownMenuItem(
                    value: plot.id,
                    child: Text(plot.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                for (final plot in _plots) {
                  if (plot.id == value) {
                    _applyPlot(plot);
                    break;
                  }
                }
              },
            ),
            const SizedBox(height: 10),
          ],
          _label('المحصول'),
          DropdownButton<String>(
            value: _crop.id,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: [
              for (final profile in IrrigationCropProfile.profiles)
                DropdownMenuItem(
                  value: profile.id,
                  child: Text(profile.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              for (final profile in IrrigationCropProfile.profiles) {
                if (profile.id == value) {
                  setState(() => _crop = profile);
                  break;
                }
              }
              _refreshSchedule();
            },
          ),
          const SizedBox(height: 10),
          _label('مرحلة النمو'),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final stage in IrrigationGrowthStage.values)
                ChoiceChip(
                  label: Text(stage.label, style: const TextStyle(fontSize: 12)),
                  selected: _stage == stage,
                  selectedColor: _green.withValues(alpha: 0.18),
                  onSelected: (_) {
                    setState(() => _stage = stage);
                    _refreshSchedule();
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          _label('نظام الري'),
          DropdownButton<String>(
            value: _method,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: [
              for (final method
                  in WeeklyIrrigationScheduleService.methodEfficiency.keys)
                DropdownMenuItem(value: method, child: Text(method)),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _method = value);
              _refreshSchedule();
            },
          ),
          const SizedBox(height: 10),
          _label('المحافظة'),
          DropdownButton<String>(
            value: _governorate,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: [
              for (final governorate in EgyptData.governorates)
                DropdownMenuItem(
                  value: governorate.name,
                  child: Text(governorate.name),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _governorate = value);
              _refreshSchedule();
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _areaController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'المساحة',
                    suffixText: 'فدان',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _refreshSchedule(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _flowController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'تصريف المضخة (اختياري)',
                    suffixText: 'م³/ساعة',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _refreshSchedule(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loadingSchedule ? null : _refreshSchedule,
              style: FilledButton.styleFrom(backgroundColor: _green),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('تحديث الجدول'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );

  Widget _buildError(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Text(
        _error ?? '',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.red.shade200 : Colors.red.shade800,
        ),
      ),
    );
  }

  Widget _buildSummary(WeeklyIrrigationSchedule schedule, bool isDark) {
    final minutes = schedule.totalMinutes;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _green.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ملخص الأسبوع',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isDark ? Colors.white : _green,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${schedule.cropName} • ${schedule.methodName} • ${schedule.stageLabel}',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metric('إجمالي المياه',
                  '${schedule.totalVolumeM3.toStringAsFixed(0)} م³'),
              _metric('أيام الري', '${schedule.irrigationDays} من ${schedule.days.length}'),
              _metric('إجمالي العمق',
                  '${schedule.totalGrossMm.toStringAsFixed(1)} مم'),
              if (minutes != null) _metric('زمن الري', '~$minutes دقيقة'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.black54)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF064E3B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(WeeklyIrrigationDay day, bool isDark) {
    final color = switch (day.decision) {
      IrrigationDayDecision.irrigate => _green,
      IrrigationDayDecision.reduce => const Color(0xFFD97706),
      IrrigationDayDecision.skip => const Color(0xFF6B7280),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  day.dayName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  day.dateLabel,
                  style: TextStyle(fontSize: 10, color: color),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      day.decision.label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${day.grossNeedMm.toStringAsFixed(1)} مم',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  day.reason,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${day.volumeM3.toStringAsFixed(0)} م³'
                  '${day.minutes != null ? ' • ~${day.minutes} دقيقة' : ''}'
                  '${day.rainMm > 0 ? ' • مطر ${day.rainMm.toStringAsFixed(1)} مم' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
