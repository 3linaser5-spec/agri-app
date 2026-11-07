import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/app_config.dart';
import '../../services/satellite_access_service.dart';
import 'satellite_block_editor_screen.dart';

const Color _sectionGreen = Color(0xFF047857);

/// تفاصيل قطعة واحدة: المؤشرات التسعة، توزيع الضعف داخل القطعة، والسجل الزمني.
class SatelliteBlockDetailScreen extends StatefulWidget {
  const SatelliteBlockDetailScreen({
    required this.uid,
    required this.field,
    required this.maxAnalysesPerMonth,
    super.key,
  });

  final String uid;
  final SatelliteField field;
  final int maxAnalysesPerMonth;

  @override
  State<SatelliteBlockDetailScreen> createState() =>
      _SatelliteBlockDetailScreenState();
}

class _SatelliteBlockDetailScreenState
    extends State<SatelliteBlockDetailScreen> {
  final SatelliteAccessService _service = SatelliteAccessService();
  String _selectedIndex = 'NDVI';
  bool _requesting = false;

  late SatelliteField _field = widget.field;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_field.name, style: const TextStyle(color: Colors.white)),
          backgroundColor: _sectionGreen,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'تعديل القطعة',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => SatelliteBlockEditorScreen(
                    uid: widget.uid,
                    field: _field,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'حذف القطعة',
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteField,
            ),
          ],
        ),
        body: StreamBuilder<SatelliteField?>(
          stream: _service.watchField(widget.field.id),
          builder: (context, fieldSnapshot) {
            _field = fieldSnapshot.data ?? widget.field;
            return StreamBuilder<List<SatelliteNdviSample>>(
              stream: _service.watchNdviHistory(_field.id),
              builder: (context, snapshot) {
                final samples = snapshot.data ?? const <SatelliteNdviSample>[];
                final latest = samples.isEmpty ? null : samples.first;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _headerCard(),
                    const SizedBox(height: 14),
                    _analysisCard(latest),
                    const SizedBox(height: 14),
                    if (latest == null)
                      _emptyCard()
                    else ...[
                      _indexSelector(latest),
                      const SizedBox(height: 12),
                      _indicesGrid(latest),
                      const SizedBox(height: 16),
                      _problemSection(latest),
                      const SizedBox(height: 16),
                      _historyChart(samples),
                    ],
                    const SizedBox(height: 18),
                    const Text(
                      'القراءات من NASA HLS-VI بدقة 30 متراً. التقسيم الداخلي تقريبي، وقد تتأثر القيم بالسحب '
                      'وبتوقيت مرور القمر وباختلاف مرحلة النمو. تُستخدم كمؤشر للفحص الحقلي لا كتشخيص نهائي.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        height: 1.6,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _headerCard() {
    final age = _field.cropAgeDays;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF047857), Color(0xFF10B981)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.grass, color: Colors.white, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_field.cropType} • ${_field.cultivar}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _headerChip(
                Icons.straighten,
                '${_field.areaFeddan.toStringAsFixed(2)} فدان',
              ),
              if (age != null)
                _headerChip(Icons.calendar_month, 'العمر $age يوم'),
              _headerChip(
                Icons.grid_on,
                '${_field.zones.isEmpty ? 1 : _field.zones.length} منطقة تحليل',
              ),
              if (_field.plantingDate != null)
                _headerChip(Icons.eco, 'زراعة ${_date(_field.plantingDate!)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      ],
    ),
  );

  Widget _analysisCard(SatelliteNdviSample? latest) {
    final status = _field.lastAnalysisStatus;
    final busy = _requesting || status == 'processing';
    final detail = switch (status) {
      'processing' =>
        'طلبك لدى NASA AppEEARS؛ قد تستغرق المعالجة ساعات وتظهر النتيجة تلقائياً.',
      'failed' =>
        _field.lastAnalysisError ?? 'لم يكتمل آخر تحليل، يمكنك إعادة المحاولة.',
      'no_valid_scenes' =>
        'لم توجد مشاهد صافية في الفترة المطلوبة (سحب أو غياب تغطية).',
      _ when latest != null =>
        'آخر قراءة ${_date(latest.from)} • ${widget.maxAnalysesPerMonth} تحليلات شهرياً',
      _ => 'لم تُطلب قراءة بعد لهذه القطعة.',
    };

    return Card(
      color: const Color(0xFFEAF6F0),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  status == 'failed'
                      ? Icons.error_outline
                      : status == 'processing'
                      ? Icons.satellite_alt_outlined
                      : Icons.verified_outlined,
                  color: status == 'failed' ? Colors.deepOrange : _sectionGreen,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    detail,
                    style: const TextStyle(fontSize: 12.5, height: 1.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : _requestAnalysis,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.analytics_outlined),
                label: Text(
                  _requesting
                      ? 'جارٍ إرسال الطلب...'
                      : status == 'processing'
                      ? 'بانتظار نتيجة NASA...'
                      : 'تحديث قراءات الأقمار',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _sectionGreen,
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard() => const Card(
    child: Padding(
      padding: EdgeInsets.all(18),
      child: Text(
        'لا توجد قراءات بعد لهذه القطعة. اضغط «تحديث قراءات الأقمار» لجلب المؤشرات التسعة '
        'لآخر 90 يوماً من NASA، ثم ستظهر هنا مع توزيعها المكاني داخل القطعة.',
        style: TextStyle(height: 1.6),
      ),
    ),
  );

  Widget _indexSelector(SatelliteNdviSample latest) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: satelliteIndexCatalog.map((info) {
        final value = latest.indices[info.key];
        final selected = info.key == _selectedIndex;
        return ChoiceChip(
          selected: selected,
          onSelected: (_) => setState(() => _selectedIndex = info.key),
          label: Text(
            value == null ? info.key : '${info.key} ${_format(value, info)}',
            style: TextStyle(
              fontSize: 12,
              color: selected ? Colors.white : Colors.black87,
            ),
          ),
          selectedColor: _sectionGreen,
          backgroundColor: Colors.grey.shade100,
          showCheckmark: false,
        );
      }).toList(),
    );
  }

  Widget _indicesGrid(SatelliteNdviSample latest) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.95,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: satelliteIndexCatalog.map((info) {
        final value = latest.indices[info.key];
        final level = value == null ? null : _level(info.key, value);
        return InkWell(
          onTap: () => setState(() => _selectedIndex = info.key),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (level?.color ?? Colors.grey).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (level?.color ?? Colors.grey).withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  info.key,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: level?.color ?? Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value == null ? '—' : _format(value, info),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  level?.label ?? 'لا توجد قراءة',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 9, color: Colors.black54),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _problemSection(SatelliteNdviSample latest) {
    final info = satelliteIndexCatalog.firstWhere(
      (item) => item.key == _selectedIndex,
    );
    final zoneValues = <String, double>{};
    for (final entry in latest.zoneIndices.entries) {
      final value = entry.value[_selectedIndex];
      if (value != null) zoneValues[entry.key] = value;
    }
    final fieldValue = latest.indices[_selectedIndex];
    final ranked = zoneValues.entries.toList()
      ..sort((left, right) => left.value.compareTo(right.value));
    final weakZones = ranked
        .where(
          (entry) =>
              fieldValue != null &&
              entry.value < fieldValue - _weakThreshold(_selectedIndex),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'توزيع ${info.key} داخل القطعة',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          info.purposeAr,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        if (_field.zones.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'لم تُحفظ مناطق التحليل لهذه القطعة. أعد حفظ حدودها لتوليد تقسيم مكاني.',
                style: TextStyle(fontSize: 12.5, height: 1.5),
              ),
            ),
          )
        else
          SizedBox(
            height: 240,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _zoneMap(latest, fieldValue),
            ),
          ),
        const SizedBox(height: 10),
        if (weakZones.isEmpty)
          const ListTile(
            leading: Icon(Icons.check_circle_outline, color: _sectionGreen),
            title: Text('لا توجد مناطق منخفضة بوضوح'),
            subtitle: Text(
              'توزيع المؤشر متقارب داخل القطعة في آخر قراءة. تابع السجل للتأكد من الاستمرارية.',
              style: TextStyle(fontSize: 12),
            ),
          )
        else
          ...weakZones.map((entry) {
            final difference = fieldValue == null
                ? 0.0
                : entry.value - fieldValue;
            return ListTile(
              dense: true,
              leading: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.deepOrange,
              ),
              title: Text('منطقة ${entry.key} أقل من متوسط القطعة'),
              subtitle: Text(
                '${info.key} ${_format(entry.value, info)} مقابل متوسط '
                '${fieldValue == null ? '—' : _format(fieldValue, info)} '
                '(${difference.toStringAsFixed(3)}) • راجع الري والتغذية والحشرات في هذا الجزء.',
                style: const TextStyle(fontSize: 11.5, height: 1.5),
              ),
            );
          }),
      ],
    );
  }

  Widget _zoneMap(SatelliteNdviSample latest, double? fieldValue) {
    final mapKey = AppConfig.mapTilerApiKey;
    final zones = _field.zones;
    final center = zones.isNotEmpty
        ? LatLng(zones.first.center['lat']!, zones.first.center['lng']!)
        : _field.vertices.isNotEmpty
        ? LatLng(_field.vertices.first['lat']!, _field.vertices.first['lng']!)
        : const LatLng(24.0889, 32.8998);

    if (mapKey.isEmpty) {
      return const ColoredBox(
        color: Color(0xFFE9ECE7),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'الخريطة الفضائية غير مُعدّة. يمكنك قراءة قيم المناطق من القائمة أدناه.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15,
        minZoom: 5,
        maxZoom: 20,
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://api.maptiler.com/maps/satellite-v4/{z}/{x}/{y}.jpg?key=$mapKey',
          userAgentPackageName: 'com.dahshory.agri.agri_app',
          maxZoom: 20,
        ),
        PolygonLayer(
          polygons: [
            if (_field.vertices.length >= 3)
              Polygon(
                points: _field.vertices
                    .map((point) => LatLng(point['lat']!, point['lng']!))
                    .toList(),
                color: Colors.transparent,
                borderColor: Colors.white,
                borderStrokeWidth: 2,
              ),
            for (final zone in zones)
              Polygon(
                points: zone.vertices
                    .map((point) => LatLng(point['lat']!, point['lng']!))
                    .toList(),
                color: _zoneColor(
                  zone.id,
                  latest,
                  fieldValue,
                ).withValues(alpha: 0.45),
                borderColor: _zoneColor(zone.id, latest, fieldValue),
                borderStrokeWidth: 2,
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            for (final zone in zones)
              Marker(
                point: LatLng(zone.center['lat']!, zone.center['lng']!),
                width: 46,
                height: 30,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    zone.id,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Color _zoneColor(
    String zoneId,
    SatelliteNdviSample latest,
    double? fieldValue,
  ) {
    final value = latest.zoneIndices[zoneId]?[_selectedIndex];
    if (value == null || fieldValue == null) return Colors.grey;
    final difference = value - fieldValue;
    final threshold = _weakThreshold(_selectedIndex);
    if (difference < -threshold) return Colors.red.shade600;
    if (difference < -threshold / 2) return Colors.orange.shade700;
    if (difference > threshold) return Colors.lightGreen.shade500;
    return Colors.green.shade700;
  }

  Widget _historyChart(List<SatelliteNdviSample> samples) {
    final points = samples.take(10).toList().reversed.toList();
    final info = satelliteIndexCatalog.firstWhere(
      (item) => item.key == _selectedIndex,
    );
    final values = points
        .map((sample) => sample.indices[_selectedIndex])
        .whereType<double>()
        .toList();
    if (values.isEmpty) return const SizedBox.shrink();
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final span = (maxValue - minValue).abs() < 0.01
        ? 0.01
        : maxValue - minValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'سجل ${info.key}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            child: SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: points.map((sample) {
                  final value = sample.indices[_selectedIndex];
                  final ratio = value == null
                      ? 0.0
                      : ((value - minValue) / span).clamp(0.0, 1.0);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            value == null ? '—' : _format(value, info),
                            style: const TextStyle(fontSize: 8),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            height: 12 + ratio * 70,
                            decoration: BoxDecoration(
                              color: _sectionGreen.withValues(
                                alpha: 0.35 + ratio * 0.55,
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${sample.from.month}/${sample.from.day}',
                            style: const TextStyle(fontSize: 8),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _weakThreshold(String index) {
    switch (index) {
      case 'NDMI':
      case 'NDWI':
        return 0.12;
      case 'TVI':
        return 0.08;
      default:
        return 0.07;
    }
  }

  _IndexLevel? _level(String key, double value) {
    switch (key) {
      case 'NDVI':
      case 'EVI':
      case 'SAVI':
      case 'MSAVI':
        if (value >= 0.6)
          return const _IndexLevel('غطاء كثيف', Color(0xFF15803D));
        if (value >= 0.4)
          return const _IndexLevel('غطاء جيد', Color(0xFF65A30D));
        if (value >= 0.2)
          return const _IndexLevel('غطاء متوسط', Color(0xFFCA8A04));
        if (value > 0) return const _IndexLevel('غطاء ضعيف', Color(0xFFEA580C));
        return const _IndexLevel('تربة أو ماء', Color(0xFFB91C1C));
      case 'NDMI':
        if (value >= 0.2)
          return const _IndexLevel('رطوبة جيدة', Color(0xFF15803D));
        if (value >= 0)
          return const _IndexLevel('رطوبة متوسطة', Color(0xFFCA8A04));
        return const _IndexLevel('إجهاد رطوبة', Color(0xFFEA580C));
      case 'NDWI':
        if (value >= 0.2)
          return const _IndexLevel('مياه ظاهرة', Color(0xFF0284C7));
        if (value >= 0)
          return const _IndexLevel('رطوبة سطحية', Color(0xFF0891B2));
        return const _IndexLevel('لا مياه', Color(0xFF6B7280));
      case 'NBR':
      case 'NBR2':
        if (value >= 0.4)
          return const _IndexLevel('غطاء سليم', Color(0xFF15803D));
        if (value >= 0.15)
          return const _IndexLevel('تغيّر محتمل', Color(0xFFCA8A04));
        return const _IndexLevel('تلف أو حرق', Color(0xFFB91C1C));
      default:
        if (value >= 0.5)
          return const _IndexLevel('كثافة عالية', Color(0xFF15803D));
        if (value >= 0.25)
          return const _IndexLevel('كثافة متوسطة', Color(0xFFCA8A04));
        return const _IndexLevel('كثافة منخفضة', Color(0xFFEA580C));
    }
  }

  String _format(double value, SatelliteIndexInfo info) =>
      value.toStringAsFixed(info.key == 'TVI' ? 3 : 2);

  String _date(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _requestAnalysis() async {
    setState(() => _requesting = true);
    try {
      final pending = await _service.requestNdviAnalysis(_field.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              pending
                  ? 'سُجل الطلب ونتحقق من ظهوره لدى NASA؛ لن تُخصم الحصة مرتين.'
                  : 'أُرسل الطلب إلى NASA HLS. قد تستغرق النتيجة ساعات، وستظهر هنا تلقائياً.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر إرسال الطلب: $error')));
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _deleteField() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف القطعة؟'),
        content: Text(
          'سيتم حذف «${_field.name}» بحدودها وسجل قراءاتها. لا يمكن التراجع.',
        ),
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
    if (confirmed != true) return;
    try {
      await _service.deleteField(_field.id);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر حذف القطعة: $error')));
      }
    }
  }
}

class _IndexLevel {
  const _IndexLevel(this.label, this.color);
  final String label;
  final Color color;
}
