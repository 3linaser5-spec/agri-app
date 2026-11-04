import 'package:flutter/material.dart';

import '../../models/my_farm_model.dart';
import '../../models/weather_forecast.dart';
import '../../services/egypt_locations_service.dart';
import '../../services/irrigation_planner_service.dart';
import '../../services/my_farm_service.dart';
import '../../services/weather_service.dart';
import '../../utils/calc_engine.dart';
import '../../utils/number_utils.dart';

class IrrigationPlanTab extends StatefulWidget {
  const IrrigationPlanTab({
    super.key,
    required this.program,
    required this.onPlanSaved,
  });

  final MyFarmProgram program;
  final ValueChanged<Map<String, dynamic>> onPlanSaved;

  @override
  State<IrrigationPlanTab> createState() => _IrrigationPlanTabState();
}

class _IrrigationPlanTabState extends State<IrrigationPlanTab> {
  late IrrigationCropProfile _crop;
  late IrrigationGrowthStage _stage;
  late String _method;
  late final TextEditingController _areaController;
  late final TextEditingController _kcController;
  late final TextEditingController _efficiencyController;
  late final TextEditingController _effectiveRainController;

  WeatherLocationSelection? _location;
  WeatherSnapshot? _weather;
  List<IrrigationDayEstimate> _estimates = const [];
  bool _loadingWeather = false;
  bool _saving = false;
  String? _error;

  static const _methods = <String, double>{
    'تنقيط': 90,
    'رش': 75,
    'سطحي': 60,
    'محوري': 85,
  };

  String get _areaUnit => widget.program.areaUnit.trim().isEmpty
      ? 'فدان'
      : widget.program.areaUnit;

  double get _squareMetersPerUnit {
    final unit = _normalize(_areaUnit);
    if (unit.contains('هكتار') || unit.contains('hectare')) return 10000;
    if (unit.contains('متر') || unit.contains('m2') || unit.contains('م²')) {
      return 1;
    }
    return 4200;
  }

  @override
  void initState() {
    super.initState();
    final saved = widget.program.irrigationPlan;
    final cropId = saved['crop_id']?.toString();
    final cropText = [
      widget.program.templateName,
      widget.program.sectionName,
      for (final entry in widget.program.inputValues.entries)
        if (_normalize(entry.key).contains('crop') || entry.key.contains('محصول'))
          entry.value?.toString() ?? '',
    ].join(' ');
    _crop = IrrigationCropProfile.profiles.firstWhere(
      (profile) => profile.id == cropId,
      orElse: () => IrrigationCropProfile.guess(cropText) ??
          IrrigationCropProfile.profiles.last,
    );
    _stage = IrrigationGrowthStage.values.firstWhere(
      (stage) => stage.name == saved['growth_stage']?.toString(),
      orElse: () => IrrigationGrowthStage.midSeason,
    );
    _method = _methods.containsKey(saved['irrigation_method']?.toString())
        ? saved['irrigation_method'].toString()
        : 'تنقيط';
    final storedArea = _number(saved['area_value']);
    final detectedArea = _detectProgramArea();
    _areaController = TextEditingController(
      text: storedArea?.toString() ?? detectedArea?.toString() ?? '',
    );
    _kcController = TextEditingController(
      text: (_number(saved['kc']) ?? _crop.kcFor(_stage)).toString(),
    );
    _efficiencyController = TextEditingController(
      text: (_number(saved['efficiency_percent']) ?? _methods[_method]!).toString(),
    );
    _effectiveRainController = TextEditingController(
      text: ((_number(saved['effective_rain_fraction']) ?? 0.7) * 100).toString(),
    );
    final rawLocation = saved['location'];
    if (rawLocation is Map) {
      try {
        _location = WeatherLocationSelection.fromJson(
          Map<String, dynamic>.from(rawLocation),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadWeather();
        });
      } catch (_) {
        _location = null;
      }
    }
  }

  @override
  void dispose() {
    _areaController.dispose();
    _kcController.dispose();
    _efficiencyController.dispose();
    _effectiveRainController.dispose();
    super.dispose();
  }

  double? _detectProgramArea() {
    if (!CalcEngine.hasExplicitArea(widget.program.inputValues)) return null;
    return CalcEngine.areaMultiplier(widget.program.inputValues);
  }

  static double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    return NumberUtils.tryParseDouble(value?.toString());
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
      .trim();

  List<IrrigationDayEstimate> _estimate() {
    if (_weather == null) return const [];
    final areaValue = NumberUtils.tryParseDouble(_areaController.text);
    final kc = NumberUtils.tryParseDouble(_kcController.text);
    final efficiency = NumberUtils.tryParseDouble(_efficiencyController.text);
    final effectiveRain = NumberUtils.tryParseDouble(_effectiveRainController.text);
    if (areaValue == null || kc == null || efficiency == null || effectiveRain == null) {
      return const [];
    }
    try {
      return IrrigationPlannerService.estimateWeek(
        forecast: _weather!.days,
        areaM2: areaValue * _squareMetersPerUnit,
        kc: kc,
        efficiencyPercent: efficiency,
        effectiveRainFraction: effectiveRain / 100,
      );
    } on ArgumentError catch (error) {
      _error = error.message?.toString() ?? 'راجع المدخلات.';
      return const [];
    }
  }

  void _recalculate() {
    _error = null;
    _estimates = _estimate();
  }

  Future<void> _pickLocation() async {
    try {
      final catalog = await EgyptLocationCatalog.load();
      if (!mounted) return;
      final location = await showModalBottomSheet<WeatherLocationSelection>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _FarmLocationPicker(
          catalog: catalog,
          initialGovernorate: widget.program.governorate,
        ),
      );
      if (location == null || !mounted) return;
      setState(() {
        _location = location;
        _weather = null;
        _estimates = const [];
        _error = null;
      });
      await _loadWeather();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحميل قائمة المواقع. حاول مرة أخرى.')),
      );
    }
  }

  Future<void> _loadWeather() async {
    final location = _location;
    if (location == null) return;
    setState(() {
      _loadingWeather = true;
      _error = null;
    });
    try {
      final weather = await WeatherService.fetch(
        latitude: location.latitude,
        longitude: location.longitude,
      );
      if (!mounted) return;
      setState(() {
        _weather = weather;
        _recalculate();
      });
      if (_estimates.isEmpty && _error == null) {
        setState(() => _error = 'بيانات ET0 غير متاحة حاليًا لهذا الموقع.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذر جلب توقعات الري. تحقق من الاتصال ثم أعد المحاولة.');
    } finally {
      if (mounted) setState(() => _loadingWeather = false);
    }
  }

  void _changeCrop(IrrigationCropProfile? crop) {
    if (crop == null) return;
    setState(() {
      _crop = crop;
      _kcController.text = crop.kcFor(_stage).toString();
      _recalculate();
    });
  }

  void _changeStage(IrrigationGrowthStage? stage) {
    if (stage == null) return;
    setState(() {
      _stage = stage;
      _kcController.text = _crop.kcFor(stage).toString();
      _recalculate();
    });
  }

  Future<void> _savePlan() async {
    if (_location == null || _weather == null || _estimates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر موقع المزرعة وحمّل توقعات الري أولًا.')),
      );
      return;
    }
    final areaValue = NumberUtils.tryParseDouble(_areaController.text);
    final kc = NumberUtils.tryParseDouble(_kcController.text);
    final efficiency = NumberUtils.tryParseDouble(_efficiencyController.text);
    final effectiveRain = NumberUtils.tryParseDouble(_effectiveRainController.text);
    if (areaValue == null || kc == null || efficiency == null || effectiveRain == null) return;

    final plan = <String, dynamic>{
      'schema_version': 1,
      'crop_id': _crop.id,
      'crop_name': _crop.name,
      'growth_stage': _stage.name,
      'growth_stage_label': _stage.label,
      'kc': kc,
      'area_value': areaValue,
      'area_unit': _areaUnit,
      'area_m2': areaValue * _squareMetersPerUnit,
      'irrigation_method': _method,
      'efficiency_percent': efficiency,
      'effective_rain_fraction': effectiveRain / 100,
      'location': _location!.toJson(),
      'location_name': _location!.displayName,
      'latitude': _location!.latitude,
      'longitude': _location!.longitude,
      'forecast_updated_at': DateTime.now().toIso8601String(),
      'daily_estimates': _estimates.map((item) => item.toMap()).toList(),
    };

    setState(() => _saving = true);
    final saved = await MyFarmService.saveIrrigationPlan(widget.program.id, plan);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ خطة الري في البرنامج. تحقق من الاتصال.')),
      );
      return;
    }
    widget.onPlanSaved(plan);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ تقدير الري داخل برنامج مزرعتك.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalM3 = _estimates.fold<double>(0, (sum, day) => sum + day.volumeM3);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('مخطط ري متجدد للأيام القادمة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 6),
                Text(
                  'يستخدم ET₀ المتوقع ومرحلة المحصول والمطر لتقدير الاحتياج. هذا تقدير إرشادي وليس بديلًا عن فحص رطوبة التربة أو توصية مهندس الحقل.',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _loadingWeather ? null : _pickLocation,
                  icon: const Icon(Icons.location_on_outlined),
                  label: Text(_location?.displayName ?? 'حدد موقع المزرعة'),
                ),
                if (_location != null) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _loadingWeather ? null : _loadWeather,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('تحديث توقعات الطقس'),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                DropdownButtonFormField<IrrigationCropProfile>(
                  initialValue: _crop,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'المحصول'),
                  items: IrrigationCropProfile.profiles
                      .map((profile) => DropdownMenuItem(
                            value: profile,
                            child: Text(profile.name, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: _changeCrop,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<IrrigationGrowthStage>(
                  initialValue: _stage,
                  decoration: const InputDecoration(labelText: 'مرحلة النمو الحالية'),
                  items: IrrigationGrowthStage.values
                      .map((stage) => DropdownMenuItem(
                            value: stage,
                            child: Text(stage.label),
                          ))
                      .toList(),
                  onChanged: _changeStage,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _areaController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'المساحة (${_areaUnit.isEmpty ? 'فدان' : _areaUnit})',
                    helperText: _detectProgramArea() == null
                        ? 'أدخل مساحة هذا البرنامج؛ لم تُحدد في بياناته.'
                        : 'قيمة مبدئية من بيانات البرنامج؛ راجعها قبل الاعتماد.',
                  ),
                  onChanged: (_) => setState(_recalculate),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _kcController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'معامل المحصول Kc',
                    helperText: 'القيمة المرجعية للمرحلة المختارة؛ يمكنك تعديلها.',
                  ),
                  onChanged: (_) => setState(_recalculate),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _method,
                  decoration: const InputDecoration(labelText: 'طريقة الري'),
                  items: _methods.keys
                      .map((method) => DropdownMenuItem(value: method, child: Text(method)))
                      .toList(),
                  onChanged: (method) {
                    if (method == null) return;
                    setState(() {
                      _method = method;
                      _efficiencyController.text = _methods[method]!.toString();
                      _recalculate();
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _efficiencyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'كفاءة الري (%)',
                    helperText: 'قيمة ابتدائية حسب الطريقة، قابلة للتعديل.',
                  ),
                  onChanged: (_) => setState(_recalculate),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _effectiveRainController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'نسبة المطر الفعال (%)',
                    helperText: 'تقدير قابل للتعديل؛ يعتمد فعليًا على التربة والصرف وشدة المطر.',
                  ),
                  onChanged: (_) => setState(_recalculate),
                ),
                if (_loadingWeather) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 6),
                  const Text('جاري تحميل ET₀ والمطر المتوقع...', textAlign: TextAlign.center),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _saving || _estimates.isEmpty ? null : _savePlan,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'جاري الحفظ...' : 'حفظ الخطة في مزرعتي'),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857)),
                ),
              ],
            ),
          ),
        ),
        if (_estimates.isNotEmpty) ...[
          Card(
            color: const Color(0xFF047857).withValues(alpha: isDark ? 0.22 : 0.08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.water_drop_outlined, color: Color(0xFF047857), size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('الاحتياج المائي الإجمالي المتوقع خلال 7 أيام',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('${totalM3.toStringAsFixed(1)} م³ تقريبًا',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ..._estimates.map(_buildDayCard),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'نسبة المطر الفعال هي افتراض قابل للتعديل وليست قياسًا ميدانيًا. لا تستخدم الكمية وحدها لتحديد موعد الري دون التحقق من رطوبة التربة والصرف ومعدل تصرف الشبكة.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDayCard(IrrigationDayEstimate estimate) {
    final date = '${estimate.date.day}/${estimate.date.month}';
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE0F2FE),
          child: Icon(Icons.water_drop, color: Color(0xFF0284C7)),
        ),
        title: Text('${estimate.date.dayName} $date',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          'ET₀ ${estimate.et0Mm.toStringAsFixed(1)} مم • مطر ${estimate.rainMm.toStringAsFixed(1)} مم • احتياج صافٍ ${estimate.netNeedMm.toStringAsFixed(1)} مم',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${estimate.volumeM3.toStringAsFixed(1)} م³',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF047857))),
            Text('${estimate.grossNeedMm.toStringAsFixed(1)} مم إجمالي',
                style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _FarmLocationPicker extends StatefulWidget {
  const _FarmLocationPicker({required this.catalog, required this.initialGovernorate});

  final EgyptLocationCatalog catalog;
  final String initialGovernorate;

  @override
  State<_FarmLocationPicker> createState() => _FarmLocationPickerState();
}

class _FarmLocationPickerState extends State<_FarmLocationPicker> {
  late String _governorateCode;
  String? _areaCode;
  String? _villageCode;

  EgyptAdministrativeVillage? _findVillage(
    List<EgyptAdministrativeVillage> villages,
    String? code,
  ) {
    if (code == null) return null;
    for (final village in villages) {
      if (village.code == code) return village;
    }
    return null;
  }

  EgyptAdministrativeGovernorate get _governorate => widget.catalog.governorates
      .firstWhere((item) => item.code == _governorateCode);

  EgyptAdministrativeArea? get _area {
    final areas = _governorate.areas;
    if (areas.isEmpty) return null;
    return areas.firstWhere(
      (item) => item.code == _areaCode,
      orElse: () => areas.first,
    );
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.catalog.findGovernorate(widget.initialGovernorate);
    final governorate = initial ?? widget.catalog.governorates.first;
    _governorateCode = governorate.code;
    _areaCode = governorate.areas.isEmpty ? null : governorate.areas.first.code;
  }

  @override
  Widget build(BuildContext context) {
    final areas = _governorate.areas;
    final area = _area;
    final villages = area?.villages ?? const <EgyptAdministrativeVillage>[];
    final village = _findVillage(villages, _villageCode);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('حدد موقع المزرعة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _governorateCode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'المحافظة'),
                items: widget.catalog.governorates
                    .map((item) => DropdownMenuItem(value: item.code, child: Text(item.name)))
                    .toList(),
                onChanged: (code) {
                  if (code == null) return;
                  final next = widget.catalog.governorates.firstWhere((item) => item.code == code);
                  setState(() {
                    _governorateCode = code;
                    _areaCode = next.areas.isEmpty ? null : next.areas.first.code;
                    _villageCode = null;
                  });
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: ValueKey('areas-$_governorateCode'),
                initialValue: areas.isEmpty ? null : (_area?.code),
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'المركز أو القسم'),
                items: areas
                    .map((item) => DropdownMenuItem(value: item.code, child: Text(item.name)))
                    .toList(),
                onChanged: areas.isEmpty
                    ? null
                    : (code) => setState(() {
                          _areaCode = code;
                          _villageCode = null;
                        }),
              ),
              if (villages.isNotEmpty) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: ValueKey('villages-${_area?.code}'),
                  initialValue: village?.code,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'القرية (اختياري)'),
                  items: [
                    const DropdownMenuItem<String>(value: '', child: Text('المركز بدون تحديد قرية')),
                    ...villages.map((item) => DropdownMenuItem(value: item.code, child: Text(item.name))),
                  ],
                  onChanged: (code) => setState(() => _villageCode = code == null || code.isEmpty ? null : code),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'الإحداثيات تقريبية حسب بيانات التقسيم الإداري؛ اختر أقرب قرية متاحة للمزرعة.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: area == null
                    ? null
                    : () {
                        final selectedVillage = _findVillage(villages, _villageCode);
                        final result = selectedVillage == null
                            ? WeatherLocationSelection.forArea(_governorate, area)
                            : WeatherLocationSelection.forVillage(_governorate, area, selectedVillage);
                        Navigator.pop(context, result);
                      },
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857)),
                child: const Text('استخدم هذا الموقع'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
