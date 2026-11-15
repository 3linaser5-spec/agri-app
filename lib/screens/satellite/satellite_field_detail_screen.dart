import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:intl/intl.dart' show DateFormat;
import 'package:url_launcher/url_launcher.dart';

import '../../models/satellite_monitoring_model.dart';
import '../../services/satellite_monitoring_service.dart';
import 'satellite_field_editor_screen.dart';

class SatelliteFieldDetailScreen extends StatefulWidget {
  final HlsField field;

  const SatelliteFieldDetailScreen({super.key, required this.field});

  @override
  State<SatelliteFieldDetailScreen> createState() =>
      _SatelliteFieldDetailScreenState();
}

class _SatelliteFieldDetailScreenState extends State<SatelliteFieldDetailScreen> {
  static const _green = Color(0xFF047857);
  static const _indexLabels = <String, String>{
    'NDVI': 'NDVI · حيوية النبات',
    'EVI': 'EVI · الغطاء النباتي',
    'SAVI': 'SAVI · تصحيح أثر التربة',
    'MSAVI': 'MSAVI · نباتات متناثرة',
    'NDMI': 'NDMI · رطوبة الغطاء النباتي',
    'NDWI': 'NDWI · الماء/الرطوبة',
    'NBR': 'NBR · استجابة النبات',
    'NBR2': 'NBR2 · رطوبة/احتراق',
    'TVI': 'TVI · مؤشر نباتي',
    'NDRE': 'NDRE · الحافة الحمراء',
  };

  String _selectedLayer = 'NDVI';
  String? _activeRunId;
  bool _requesting = false;
  bool _polling = false;
  bool _useSatelliteImagery = true;
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _requestAnalysis() async {
    final now = DateTime.now();
    final defaultStart = now.subtract(const Duration(days: 364));
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2013, 4, 11),
      lastDate: now,
      initialDateRange: DateTimeRange(start: defaultStart, end: now),
      helpText: 'الفترة الزمنية لمشاهد HLS',
      confirmText: 'طلب التحليل',
      cancelText: 'إلغاء',
      saveText: 'متابعة',
    );
    if (range == null) return;
    if (range.duration.inDays > 365) {
      _showMessage('اختر فترة لا تتجاوز 365 يومًا في كل تحليل.');
      return;
    }
    setState(() => _requesting = true);
    try {
      final response = await SatelliteMonitoringService.requestAnalysis(
        fieldId: widget.field.id,
        startDate: range.start,
        endDate: range.end,
      );
      final runId = response['runId']?.toString();
      if (runId == null || runId.isEmpty) {
        throw StateError('لم يرجع الخادم رقم مهمة التحليل.');
      }
      setState(() => _activeRunId = runId);
      _startPolling(runId);
      _showMessage(
        'أُرسل الطلب إلى NASA؛ سيتحدث التقدم تلقائيًا عند وصول النتائج.',
      );
    } catch (error) {
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  void _startPolling(String runId) {
    _pollTimer?.cancel();
    var attempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      attempts++;
      if (!mounted || attempts > 90) {
        timer.cancel();
        return;
      }
      await _pollStatus(runId);
    });
  }

  Future<void> _pollStatus(String runId) async {
    if (_polling || !mounted) return;
    setState(() => _polling = true);
    try {
      final response = await SatelliteMonitoringService.refreshAnalysis(
        fieldId: widget.field.id,
        runId: runId,
      );
      final status = response['status']?.toString();
      if (status == 'completed' || status == 'failed' || status == 'error') {
        _pollTimer?.cancel();
        _pollTimer = null;
        if (status != 'completed') {
          _showMessage(response['errorMessage']?.toString() ??
              'تعذر إكمال تحليل NASA؛ حاول لاحقًا.');
        }
      }
    } catch (error) {
      // Errors while a provider is temporarily unavailable do not erase a run.
      debugPrint('HLS status polling failed: $error');
    } finally {
      if (mounted) setState(() => _polling = false);
    }
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    if (raw.contains('failed-precondition') || raw.contains('Earthdata')) {
      return 'تكامل NASA لم يُعدّ بعد. يلزم أن يضبط مالك التطبيق أسرار NASA Earthdata على الخادم ثم ينشر وظائف التحليل.';
    }
    if (raw.contains('unauthenticated')) return 'انتهت جلسة الدخول؛ سجّل الدخول مجددًا.';
    return raw.replaceFirst('Bad state: ', '').replaceFirst('Exception: ', '');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
  }

  Future<void> _addNote() async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('ملاحظة ميدانية'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            decoration: const InputDecoration(
              hintText: 'مثال: ملاحظة اصفرار في الركن الجنوبي...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (note == null || note.trim().isEmpty) return;
    try {
      await SatelliteMonitoringService.addNote(
        fieldId: widget.field.id,
        text: note,
        category: 'field_visit',
      );
      _showMessage('تم حفظ الملاحظة.');
    } catch (error) {
      _showMessage(_friendlyError(error));
    }
  }

  Future<void> _editField() async {
    await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SatelliteFieldEditorScreen(field: widget.field),
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _deleteField() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الحقل؟'),
          content: const Text(
            'سيُحذف تعريف الحقل وملاحظاته ونتائج HLS المحفوظة له من حسابك.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await SatelliteMonitoringService.deleteField(widget.field.id);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _showMessage(_friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.field.name),
          backgroundColor: _green,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'تعديل الحقل',
              onPressed: _editField,
              icon: const Icon(Icons.edit_outlined),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') _deleteField();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text('حذف الحقل'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: StreamBuilder<List<HlsAnalysisRun>>(
          stream: SatelliteMonitoringService.watchRuns(widget.field.id),
          builder: (context, snapshot) {
            final runs = snapshot.data ?? const <HlsAnalysisRun>[];
            final latestComplete = runs.cast<HlsAnalysisRun?>().firstWhere(
                  (run) => run?.status == 'completed',
                  orElse: () => null,
                );
            final latestPending = runs.cast<HlsAnalysisRun?>().firstWhere(
                  (run) => run != null && _isActiveStatus(run.status),
                  orElse: () => null,
                );
            if (latestPending != null && _activeRunId != latestPending.id) {
              _activeRunId = latestPending.id;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _startPolling(latestPending.id);
              });
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _fieldSummaryCard(),
                const SizedBox(height: 12),
                _analysisActionCard(latestPending),
                if (snapshot.hasError) ...[
                  const SizedBox(height: 8),
                  _infoBanner('تعذر تحميل سجل التحليلات. تحقق من الاتصال.',
                      color: Colors.red.shade50),
                ],
                if (latestComplete != null) ...[
                  const SizedBox(height: 14),
                  _latestRunContent(latestComplete),
                ],
                const SizedBox(height: 14),
                _notesSection(),
                const SizedBox(height: 14),
                _operaSourcesCard(),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addNote,
          backgroundColor: _green,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.note_add_outlined),
          label: const Text('ملاحظة ميدانية'),
        ),
      ),
    );
  }

  Widget _fieldSummaryCard() {
    return Card(
      elevation: 0,
      color: const Color(0xFFEAF6F0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.satellite_alt, color: _green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.field.crop,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.field.areaFeddans.toStringAsFixed(2)} فدان تقريبًا · '
                    'زُرع ${DateFormat('yyyy/MM/dd').format(widget.field.plantingDate)}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _analysisActionCard(HlsAnalysisRun? pending) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تحليل بيانات NASA HLS',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'عينات مكانية من حدود الحقل، مؤشرات نباتية، نطاقات طيفية وطبقات جودة. قد لا تتوفر مشاهدة صافية في كل تاريخ.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
            if (pending != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                color: _green,
                backgroundColor: _green.withValues(alpha: .12),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'حالة المهمة: ${_statusLabel(pending.status)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _polling
                        ? null
                        : () => _pollStatus(pending.id),
                    icon: _polling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('تحقق الآن'),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _requesting ? null : _requestAnalysis,
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: _requesting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.satellite_alt),
                  label: Text(_requesting ? 'جارٍ إرسال الطلب...' : 'حلّل الحقل'),
                ),
              ),
            ],
            if (pending?.errorMessage != null &&
                pending!.errorMessage!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _infoBanner(pending.errorMessage!, color: Colors.red.shade50),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'queued':
      case 'submitted':
        return 'في قائمة NASA';
      case 'running':
      case 'processing':
      case 'starting':
        return 'قيد المعالجة';
      case 'completed':
        return 'اكتمل';
      case 'failed':
      case 'error':
        return 'تعذر التنفيذ';
      default:
        return status;
    }
  }

  bool _isActiveStatus(String status) => const {
        'pending', 'queued', 'submitted', 'running', 'processing', 'starting',
      }.contains(status.toLowerCase());

  Widget _latestRunContent(HlsAnalysisRun run) {
    return StreamBuilder<List<HlsObservation>>(
      stream: SatelliteMonitoringService.watchObservations(
        fieldId: widget.field.id,
        runId: run.id,
      ),
      builder: (context, snapshot) {
        final observations = snapshot.data ?? const <HlsObservation>[];
        final selected = _selectedLayer;
        final available = observations.any((item) =>
            item.metrics.containsKey(selected) || item.bands.containsKey(selected));
        if (!available && observations.isNotEmpty && selected == 'NDVI') {
          // Keep the preferred default; the empty-state below explains missing data.
        }
        final latest = observations.isNotEmpty ? observations.last : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('نتائج آخر تحليل',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
                if (run.completedAt != null)
                  Text(
                    DateFormat('yyyy/MM/dd').format(run.completedAt!),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (snapshot.hasError)
              _infoBanner('لم أستطع قراءة قياسات الحقل.', color: Colors.red.shade50)
            else if (observations.isEmpty)
              _infoBanner(
                'اكتمل الطلب دون نقاط صالحة أو أن البيانات لم تُحمّل بعد. تحقق من نطاق التواريخ والغطاء السحابي.',
                color: Colors.amber.shade50,
              )
            else ...[
              _metricPicker(),
              const SizedBox(height: 10),
              _fieldMap(latest!),
              const SizedBox(height: 8),
              _metricSummary(latest),
              const SizedBox(height: 16),
              HlsTimeSeriesChart(
                observations: observations,
                layer: selected,
                label: _indexLabels[selected] ?? _bandLabel(selected),
              ),
              const SizedBox(height: 10),
              _qualityInfo(latest),
              if (latest.alerts.isNotEmpty) ...[
                const SizedBox(height: 12),
                _alerts(latest.alerts),
              ],
              const SizedBox(height: 8),
              Text(
                '${observations.length} مشهد/تاريخ · تغطية صافية ${latest.validSampleCount}/${latest.totalSampleCount} نقاط في الأحدث',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _metricPicker() {
    final options = <String>[
      ..._indexLabels.keys,
      for (final band in [
        'B01', 'B02', 'B03', 'B04', 'B05', 'B06', 'B07', 'B09', 'B10', 'B11',
        'SAA', 'SZA', 'VAA', 'VZA',
      ])
        'HLSL30_$band',
      for (final band in [
        'B01', 'B02', 'B03', 'B04', 'B05', 'B06', 'B07', 'B08', 'B8A', 'B09',
        'B10', 'B11', 'B12', 'SAA', 'SZA', 'VAA', 'VZA',
      ])
        'HLSS30_$band',
    ];
    return SizedBox(
      height: 43,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final key = options[index];
          final selected = _selectedLayer == key;
          return ChoiceChip(
            label: Text(
              _indexLabels[key]?.split(' · ').first ??
                  key.replaceFirst('HLSL30_', 'L30 ').replaceFirst('HLSS30_', 'S30 '),
              style: TextStyle(fontSize: 12, color: selected ? Colors.white : null),
            ),
            selected: selected,
            selectedColor: _green,
            onSelected: (_) => setState(() => _selectedLayer = key),
          );
        },
      ),
    );
  }

  Widget _fieldMap(HlsObservation observation) {
    final polygon = widget.field.polygon
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
    final center = _centroid(polygon);
    final values = observation.samples
        .map((sample) => _valueFor(sample, _selectedLayer))
        .whereType<double>()
        .toList();
    final minValue = values.isEmpty ? 0.0 : values.reduce(math.min);
    final maxValue = values.isEmpty ? 1.0 : values.reduce(math.max);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 265,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: 16),
              children: [
                TileLayer(
                  urlTemplate: _useSatelliteImagery
                      ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.nabati.agri',
                  maxNativeZoom: _useSatelliteImagery ? 23 : 19,
                ),
                if (polygon.length >= 3)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: polygon,
                        color: _green.withValues(alpha: .12),
                        borderColor: _green,
                        borderStrokeWidth: 3,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (final sample in observation.samples)
                      Marker(
                        point: LatLng(sample.latitude, sample.longitude),
                        width: 38,
                        height: 38,
                        child: Tooltip(
                          message: _sampleTooltip(sample),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _sampleColor(
                                _valueFor(sample, _selectedLayer),
                                minValue,
                                maxValue,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 3),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              sample.id.replaceAll(RegExp(r'[^0-9]'), ''),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    if (_useSatelliteImagery)
                      TextSourceAttribution(
                        'Source: Esri, Vantor, Earthstar Geographics, and the GIS User Community',
                        onTap: () => launchUrl(
                          Uri.parse('https://goto.arcgisonline.com/maps/World_Imagery'),
                          mode: LaunchMode.externalApplication,
                        ),
                      )
                    else
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                        onTap: () => launchUrl(
                          Uri.parse('https://www.openstreetmap.org/copyright'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Material(
                color: Colors.white.withValues(alpha: .94),
                borderRadius: BorderRadius.circular(10),
                child: IconButton(
                  tooltip: _useSatelliteImagery
                      ? 'التبديل إلى خريطة الشوارع'
                      : 'التبديل إلى الصور الفضائية',
                  onPressed: () => setState(
                    () => _useSatelliteImagery = !_useSatelliteImagery,
                  ),
                  icon: Icon(
                    _useSatelliteImagery ? Icons.map_outlined : Icons.satellite_alt,
                    color: _green,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    _indexLabels[_selectedLayer] ?? _bandLabel(_selectedLayer),
                    style: const TextStyle(
                      color: _green,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: Text(
                    'الألوان للمقارنة بين نقاط العينة',
                    style: TextStyle(color: Colors.grey.shade800, fontSize: 10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricSummary(HlsObservation observation) {
    final value = observation.metrics[_selectedLayer] ??
        observation.bands[_selectedLayer];
    final date = DateFormat('yyyy/MM/dd').format(observation.date);
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.insights, color: _green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_indexLabels[_selectedLayer] ?? _bandLabel(_selectedLayer)} · $date',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
            Text(
              _formatValue(value, _selectedLayer),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: _green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qualityInfo(HlsObservation observation) {
    Object? count(String camelCase, String snakeCase) =>
        observation.quality[camelCase] ?? observation.quality[snakeCase];

    final clear = count('clearPointCount', 'clear_point_count');
    final flagged = count('flaggedPointCount', 'flagged_point_count');
    final cirrus = count('cirrusPointCount', 'cirrus_point_count');
    final cloudy = count('cloudPointCount', 'cloud_point_count');
    final adjacent = count('adjacentPointCount', 'adjacent_point_count');
    final shadows = count('shadowPointCount', 'shadow_point_count');
    final snow = count('snowIcePointCount', 'snow_ice_point_count');
    final water = count('waterPointCount', 'water_point_count');
    final aerosol = count('aerosolPointCount', 'aerosol_point_count');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.fact_check_outlined, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'جودة العينات — صافية: ${clear ?? '—'}، عليها أعلام جودة: ${flagged ?? '—'}. '
              'سحب رقيقة (Cirrus): ${cirrus ?? '—'}، سحب: ${cloudy ?? '—'}، سحب مجاورة: ${adjacent ?? '—'}، '
              'ظلال: ${shadows ?? '—'}، ثلج/جليد: ${snow ?? '—'}، ماء: ${water ?? '—'}، '
              'هباء جوي: ${aerosol ?? '—'}. '
              'القيم مؤشرات استشعار عن بعد وليست تشخيصًا زراعيًا مؤكدًا.',
              style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _alerts(List<String> alerts) => Card(
        elevation: 0,
        color: const Color(0xFFFFF7E6),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.notifications_active_outlined, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('مؤشرات تستحق التحقق الميداني',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              for (final alert in alerts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text('• $alert', style: const TextStyle(fontSize: 12)),
                ),
              const Text(
                'قد تتأثر المؤشرات بتغير مرحلة النمو أو نوع المحصول أو بقايا السحب؛ راجع الحقل قبل اتخاذ قرار.',
                style: TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ],
          ),
        ),
      );

  Widget _notesSection() => StreamBuilder<List<HlsFieldNote>>(
        stream: SatelliteMonitoringService.watchNotes(widget.field.id),
        builder: (context, snapshot) {
          final notes = snapshot.data ?? const <HlsFieldNote>[];
          return Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الملاحظات الميدانية',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  if (notes.isEmpty)
                    Text('سجّل ملاحظة لمقارنتها مع المؤشرات الفضائية.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12))
                  else
                    for (final note in notes.take(5))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.sticky_note_2_outlined, color: _green),
                        title: Text(note.text),
                        subtitle: note.createdAt == null
                            ? null
                            : Text(DateFormat('yyyy/MM/dd HH:mm').format(note.createdAt!)),
                      ),
                ],
              ),
            ),
          );
        },
      );

  Widget _operaSourcesCard() => Card(
        elevation: 0,
        color: const Color(0xFFF3F4F6),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('مصادر NASA الإضافية',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'منتجات OPERA المشتقة من HLS (التغيرات السنوية، التنبيه للتغير، والمياه السطحية) لا تظهر في واجهة AppEEARS المستخدمة للتحليل هنا؛ هذه روابط سجلاتها الرسمية لحين إضافة موصل NASA منفصل لها.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
              ),
              Wrap(
                spacing: 4,
                children: [
                  _sourceLink('DIST-ALERT', 'https://www.earthdata.nasa.gov/data/catalog/lpcloud-opera-l3-dist-alert-hls-v1-1'),
                  _sourceLink('DIST-ANN', 'https://www.earthdata.nasa.gov/data/catalog/lpcloud-opera-l3-dist-ann-hls-v1-1'),
                  _sourceLink('DSWx-HLS', 'https://www.earthdata.nasa.gov/data/catalog/pocloud-opera-l3-dswx-hls-v1-1.0'),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _sourceLink(String label, String url) => TextButton(
        onPressed: () => launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        ),
        child: Text(label),
      );

  Widget _infoBanner(String message, {required Color color}) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(message, style: const TextStyle(fontSize: 12)),
      );

  LatLng _centroid(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(26.8206, 30.8025);
    return LatLng(
      points.map((point) => point.latitude).reduce((a, b) => a + b) / points.length,
      points.map((point) => point.longitude).reduce((a, b) => a + b) / points.length,
    );
  }

  double? _valueFor(HlsSamplePoint sample, String layer) =>
      sample.indices[layer] ?? sample.bands[layer];

  String _sampleTooltip(HlsSamplePoint sample) {
    final lines = [
      '${sample.id}: ${_formatValue(_valueFor(sample, _selectedLayer), _selectedLayer)}',
    ];
    for (final source in const ['HLSS30', 'HLSL30']) {
      final qa = sample.qa[source];
      if (qa == null) continue;
      final label = source == 'HLSS30' ? 'Sentinel-2 Fmask' : 'Landsat Fmask';
      lines.add('$label: ${_qaDescription(qa)}');
    }
    if (sample.qa.isEmpty && sample.fmask != null) {
      lines.add('Fmask: ${_fmaskDescription(sample.fmask!)}');
    }
    return lines.join('\n');
  }

  String _qaDescription(Map<String, dynamic> qa) {
    final flags = <String>[];
    if (qa['cirrus'] == true) flags.add('سحب رقيقة (Cirrus)');
    if (qa['cloud'] == true) flags.add('سحب');
    if (qa['adjacent'] == true) flags.add('سحب مجاورة');
    if (qa['shadow'] == true) flags.add('ظل');
    if (qa['snowIce'] == true) flags.add('ثلج/جليد');
    if (qa['water'] == true) flags.add('ماء');
    final aerosolCode = qa['aerosolCode'];
    if (aerosolCode is num && aerosolCode > 0) {
      flags.add('هباء جوي ${aerosolCode.toInt()}');
    }
    if (flags.isEmpty && qa['clear'] == true) return 'صافية';
    return flags.isEmpty ? 'لا توجد أعلام مفككة' : flags.join('، ');
  }

  String _fmaskDescription(int bits) {
    if (bits == 255) return 'قيمة غير متاحة';
    final flags = <String>[];
    if ((bits & 1) != 0) flags.add('سحب رقيقة (Cirrus)');
    if ((bits & (1 << 1)) != 0) flags.add('سحب');
    if ((bits & (1 << 2)) != 0) flags.add('سحب مجاورة');
    if ((bits & (1 << 3)) != 0) flags.add('ظل');
    if ((bits & (1 << 4)) != 0) flags.add('ثلج/جليد');
    if ((bits & (1 << 5)) != 0) flags.add('ماء');
    final aerosolCode = (bits >> 6) & 3;
    if (aerosolCode > 0) flags.add('هباء جوي $aerosolCode');
    return flags.isEmpty ? 'صافية' : flags.join('، ');
  }

  Color _sampleColor(double? value, double min, double max) {
    if (value == null) return Colors.blueGrey;
    if (_indexLabels.containsKey(_selectedLayer) || _selectedLayer == 'NDRE') {
      if (value < 0) return Colors.red.shade700;
      if (value < 0.2) return Colors.orange.shade700;
      if (value < 0.4) return Colors.lightGreen.shade700;
      if (value < 0.6) return Colors.green.shade700;
      return const Color(0xFF14532D);
    }
    if (_selectedLayer == 'HLSL30_B10' || _selectedLayer == 'HLSL30_B11') {
      final normalized = ((value - 5) / 40).clamp(0.0, 1.0);
      return Color.lerp(Colors.blue, Colors.deepOrange, normalized)!;
    }
    final span = max - min;
    final normalized = span.abs() < 0.000001 ? 0.5 : ((value - min) / span).clamp(0.0, 1.0);
    return Color.lerp(Colors.blue, Colors.green, normalized)!;
  }

  String _bandLabel(String band) {
    if (band.startsWith('HLSL30_B10') || band.startsWith('HLSL30_B11')) {
      return '${band.replaceFirst('HLSL30_', 'Landsat ')} · حرارة السطح (°C)';
    }
    if (band.startsWith('HLSL30_')) return '${band.replaceFirst('HLSL30_', 'Landsat ')} · انعكاس/زاوية';
    if (band.startsWith('HLSS30_')) return '${band.replaceFirst('HLSS30_', 'Sentinel-2 ')} · انعكاس/زاوية';
    return '$band · قناة طيفية';
  }

  String _formatValue(double? value, String layer) {
    if (value == null) return 'لا توجد عينة صافية';
    if (layer == 'HLSL30_B10' || layer == 'HLSL30_B11') {
      return '${value.toStringAsFixed(1)} °C';
    }
    return value.toStringAsFixed(3);
  }
}

class HlsTimeSeriesChart extends StatelessWidget {
  final List<HlsObservation> observations;
  final String layer;
  final String label;

  const HlsTimeSeriesChart({
    super.key,
    required this.observations,
    required this.layer,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final points = <_ChartPoint>[];
    for (final observation in observations) {
      final value = observation.metrics[layer] ?? observation.bands[layer];
      if (value != null && value.isFinite) {
        points.add(_ChartPoint(observation.date, value));
      }
    }
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('تغير المؤشر عبر المشاهد المتاحة',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
            const SizedBox(height: 14),
            if (points.length < 2)
              const SizedBox(
                height: 130,
                child: Center(child: Text('يلزم مشهدان صالحان على الأقل لرسم المنحنى.')),
              )
            else
              SizedBox(
                height: 170,
                width: double.infinity,
                child: CustomPaint(
                  painter: _HlsChartPainter(
                    points: points,
                    color: const Color(0xFF047857),
                    textDirection: Directionality.of(context),
                  ),
                ),
              ),
            if (points.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5, bottom: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('yyyy/MM').format(points.first.date),
                        style: const TextStyle(fontSize: 10)),
                    Text(DateFormat('yyyy/MM').format(points.last.date),
                        style: const TextStyle(fontSize: 10)),
                    Text('آخر قيمة ${points.last.value.toStringAsFixed(3)}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChartPoint {
  final DateTime date;
  final double value;
  const _ChartPoint(this.date, this.value);
}

class _HlsChartPainter extends CustomPainter {
  final List<_ChartPoint> points;
  final Color color;
  final TextDirection textDirection;

  const _HlsChartPainter({
    required this.points,
    required this.color,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 42.0;
    const right = 8.0;
    const top = 8.0;
    const bottom = 12.0;
    final chart = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    final values = points.map((point) => point.value).toList();
    var minValue = values.reduce(math.min);
    var maxValue = values.reduce(math.max);
    if ((maxValue - minValue).abs() < 0.000001) {
      minValue -= 0.1;
      maxValue += 0.1;
    }
    final padding = (maxValue - minValue) * 0.08;
    minValue -= padding;
    maxValue += padding;

    final gridPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    final labelStyle = TextStyle(color: Colors.grey.shade600, fontSize: 9);
    for (var i = 0; i <= 3; i++) {
      final y = chart.top + chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final value = maxValue - (maxValue - minValue) * i / 3;
      final text = TextPainter(
        text: TextSpan(text: value.toStringAsFixed(2), style: labelStyle),
        textDirection: textDirection,
      )..layout(maxWidth: left - 6);
      text.paint(canvas, Offset(0, y - text.height / 2));
    }

    final first = points.first.date.millisecondsSinceEpoch.toDouble();
    final last = points.last.date.millisecondsSinceEpoch.toDouble();
    final span = math.max(1.0, last - first);
    final offsets = <Offset>[];
    for (final point in points) {
      final x = chart.left +
          (point.date.millisecondsSinceEpoch.toDouble() - first) / span * chart.width;
      final y = chart.bottom -
          (point.value - minValue) / (maxValue - minValue) * chart.height;
      offsets.add(Offset(x, y));
    }

    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final point in offsets.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final fill = Path.from(path)
      ..lineTo(offsets.last.dx, chart.bottom)
      ..lineTo(offsets.first.dx, chart.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          colors: [color.withValues(alpha: .24), color.withValues(alpha: .01)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(chart),
    );
    final dotPaint = Paint()..color = color;
    for (final point in offsets) {
      canvas.drawCircle(point, 3, Paint()..color = Colors.white);
      canvas.drawCircle(point, 2.1, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HlsChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}
