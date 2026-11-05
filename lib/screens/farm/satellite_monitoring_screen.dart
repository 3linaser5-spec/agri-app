import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../services/satellite_access_service.dart';

const Color _satelliteGreen = Color(0xFF047857);

/// شاشة الخدمة التجارية: تُفتح للمزارع، أما التفعيل فيبقى بيد الأدمن.
class SatelliteMonitoringScreen extends StatefulWidget {
  const SatelliteMonitoringScreen({super.key});

  @override
  State<SatelliteMonitoringScreen> createState() =>
      _SatelliteMonitoringScreenState();
}

class _SatelliteMonitoringScreenState extends State<SatelliteMonitoringScreen> {
  final SatelliteAccessService _service = SatelliteAccessService();
  final Set<String> _analyzingFieldIds = <String>{};
  bool _requestBusy = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('سجل الدخول أولاً لاستخدام الخدمة.')),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مراقبة المحصول بالأقمار الصناعية'),
          backgroundColor: _satelliteGreen,
          foregroundColor: Colors.white,
        ),
        body: StreamBuilder<SatelliteEntitlement?>(
          stream: _service.watchEntitlement(user.uid),
          builder: (context, accessSnapshot) {
            if (accessSnapshot.hasError) {
              return _errorView('تعذر قراءة حالة الاشتراك. تحقق من اتصالك.');
            }
            if (!accessSnapshot.hasData &&
                accessSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final entitlement = accessSnapshot.data;
            if (entitlement == null || !entitlement.isActive) {
              return _activationView(user.uid, entitlement);
            }
            return _activeView(user.uid, entitlement);
          },
        ),
      ),
    );
  }

  Widget _activationView(String uid, SatelliteEntitlement? entitlement) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.satellite_alt, size: 72, color: _satelliteGreen),
        const SizedBox(height: 12),
        const Text(
          'خدمة تجارية تُفعّل يدوياً',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          'تواصل مع الإدارة للاتفاق على السعر والمدة. بعد التفعيل ستتمكن من تحديد حدود حقولك على الخريطة الفضائية.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.6),
        ),
        if (entitlement != null) ...[
          const SizedBox(height: 16),
          _statusCard(
            entitlement.status == 'active'
                ? 'انتهت مدة الاشتراك'
                : 'الخدمة غير مفعّلة لهذا الحساب',
            entitlement.expiresAt == null
                ? null
                : 'انتهى التفعيل في ${_date(entitlement.expiresAt!)}',
            Icons.lock_clock,
          ),
        ],
        const SizedBox(height: 22),
        StreamBuilder<Map<String, dynamic>?>(
          stream: _service.watchRequest(uid),
          builder: (context, snapshot) {
            final status = snapshot.data?['status'] as String?;
            if (status == 'pending') {
              return _statusCard(
                'طلبك قيد المراجعة',
                'سيتواصل معك المسؤول بعد مراجعة الطلب.',
                Icons.hourglass_top,
              );
            }
            return Column(
              children: [
                FilledButton.icon(
                  onPressed: _requestBusy ? null : () => _request(uid),
                  icon: _requestBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.mark_email_unread_outlined),
                  label: const Text('إرسال طلب تفعيل للأدمن'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _satelliteGreen,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _contactAdmin,
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('التواصل عبر واتساب'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        const Text(
          'ملاحظة: الخريطة الفضائية مخصصة لتحديد الحدود. تحليل NDVI يُنفّذ خادمياً من Sentinel‑2 بعد إعداد بيانات الاعتماد ونشر Cloud Functions.',
          style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.5),
        ),
      ],
    );
  }

  Widget _activeView(String uid, SatelliteEntitlement entitlement) {
    return StreamBuilder<List<SatelliteField>>(
      stream: _service.watchFields(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorView('تعذر تحميل الحقول المحفوظة.');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final fields = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _statusCard(
              'الاشتراك مفعّل',
              'ينتهي في ${entitlement.expiresAt == null ? 'غير محدد' : _date(entitlement.expiresAt!)} • ${entitlement.maxFields} حقول • ${entitlement.maxAreaFeddan} فدان لكل حقل • ${entitlement.maxAnalysesPerMonth} تحليلات شهرياً',
              Icons.verified_outlined,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'حقول المزرعة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton.icon(
                  onPressed: fields.length >= entitlement.maxFields
                      ? null
                      : () => _openEditor(uid, entitlement),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('تحديد حقل'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _satelliteGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (fields.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'لم تحفظ حدوداً بعد. اضغط «تحديد حقل»، ثم انقر نقاطاً حول الأرض لإغلاق المضلع وحفظه.',
                    style: TextStyle(height: 1.5),
                  ),
                ),
              )
            else
              ...fields.map((field) => _fieldCard(uid, entitlement, field)),
            const SizedBox(height: 14),
            const Text(
              'NDVI مؤشر نباتي عام وليس تشخيصاً للمرض. قد تؤثر السحب وتوقيت مرور القمر ونوع المحصول في القراءة، لذلك يجب تفسير النتائج مع الفحص الحقلي.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _fieldCard(
    String uid,
    SatelliteEntitlement entitlement,
    SatelliteField field,
  ) {
    return Card(
      child: ExpansionTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE7F5EF),
          child: Icon(Icons.grass, color: _satelliteGreen),
        ),
        title: Text(field.name),
        subtitle: Text(
          '${field.areaFeddan.toStringAsFixed(2)} فدان • ${field.vertices.length} نقاط',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') _openEditor(uid, entitlement, field);
            if (value == 'delete') _deleteField(field);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('تعديل الحدود')),
            PopupMenuItem(value: 'delete', child: Text('حذف الحقل')),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _analyzingFieldIds.contains(field.id)
                    ? null
                    : () => _analyzeField(field),
                icon: _analyzingFieldIds.contains(field.id)
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.analytics_outlined),
                label: Text(
                  _analyzingFieldIds.contains(field.id)
                      ? 'جارٍ تحليل صور Sentinel‑2...'
                      : 'تحليل NDVI الآن',
                ),
                style: FilledButton.styleFrom(backgroundColor: _satelliteGreen),
              ),
            ),
          ),
          StreamBuilder<List<SatelliteNdviSample>>(
            stream: _service.watchNdviHistory(field.id),
            builder: (context, historySnapshot) {
              if (historySnapshot.hasError) {
                return const ListTile(title: Text('تعذر تحميل سجل التحليلات.'));
              }
              if (!historySnapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(),
                );
              }
              final samples = historySnapshot.data!;
              if (samples.isEmpty) {
                return const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('لا توجد نتائج بعد'),
                  subtitle: Text(
                    'اطلب تحليلاً لجلب سجل Sentinel‑2 لآخر 90 يوماً.',
                  ),
                );
              }
              return Column(
                children: samples
                    .map(
                      (sample) => ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.eco_outlined,
                          color: _satelliteGreen,
                        ),
                        title: Text(
                          'متوسط NDVI: ${sample.mean.toStringAsFixed(3)}',
                        ),
                        subtitle: Text(
                          '${_date(sample.from)} – ${_date(sample.to)} • ${sample.sampleCount} عينة',
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _analyzeField(SatelliteField field) async {
    setState(() => _analyzingFieldIds.add(field.id));
    try {
      await _service.requestNdviAnalysis(field.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'اكتمل طلب تحليل NDVI وتُحدّث النتائج عند توفر مشاهد صافية.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر تحليل NDVI: $error')));
      }
    } finally {
      if (mounted) setState(() => _analyzingFieldIds.remove(field.id));
    }
  }

  Future<void> _request(String uid) async {
    setState(() => _requestBusy = true);
    try {
      await _service.requestActivation(uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال طلب التفعيل إلى الإدارة.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر إرسال الطلب: $error')));
      }
    } finally {
      if (mounted) setState(() => _requestBusy = false);
    }
  }

  Future<void> _contactAdmin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final message =
        'أرغب في تفعيل خدمة مراقبة المحصول بالأقمار الصناعية في نباتي. UID: $uid';
    final uri = Uri.parse(
      '${AppConfig.whatsappUrl}?text=${Uri.encodeComponent(message)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب.')));
    }
  }

  Future<void> _openEditor(
    String uid,
    SatelliteEntitlement entitlement, [
    SatelliteField? field,
  ]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SatelliteFieldEditorScreen(
          uid: uid,
          maxFields: entitlement.maxFields,
          field: field,
        ),
      ),
    );
  }

  Future<void> _deleteField(SatelliteField field) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الحقل؟'),
        content: Text('سيتم حذف حدود «${field.name}» المحفوظة.'),
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
      await _service.deleteField(field.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر حذف الحقل: $error')));
      }
    }
  }

  Widget _statusCard(String title, String? detail, IconData icon) => Card(
    color: const Color(0xFFEAF6F0),
    child: ListTile(
      leading: Icon(icon, color: _satelliteGreen),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: detail == null ? null : Text(detail),
    ),
  );

  Widget _errorView(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );

  String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class SatelliteFieldEditorScreen extends StatefulWidget {
  const SatelliteFieldEditorScreen({
    required this.uid,
    required this.maxFields,
    this.field,
    super.key,
  });

  final String uid;
  final int maxFields;
  final SatelliteField? field;

  @override
  State<SatelliteFieldEditorScreen> createState() =>
      _SatelliteFieldEditorScreenState();
}

class _SatelliteFieldEditorScreenState
    extends State<SatelliteFieldEditorScreen> {
  final SatelliteAccessService _service = SatelliteAccessService();
  final MapController _mapController = MapController();
  late final List<LatLng> _points;
  late final TextEditingController _nameController;
  bool _saving = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _points =
        widget.field?.vertices
            .map((point) => LatLng(point['lat']!, point['lng']!))
            .toList() ??
        <LatLng>[];
    _nameController = TextEditingController(text: widget.field?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapKey = AppConfig.mapTilerApiKey;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.field == null ? 'رسم حدود الحقل' : 'تعديل حدود الحقل',
          ),
          backgroundColor: _satelliteGreen,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'تراجع عن آخر نقطة',
              onPressed: _points.isEmpty || _saving
                  ? null
                  : () => setState(() => _points.removeLast()),
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: 'مسح النقاط',
              onPressed: _points.isEmpty || _saving
                  ? null
                  : () => setState(_points.clear),
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  if (mapKey.isEmpty)
                    const ColoredBox(
                      color: Color(0xFFE9ECE7),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'الخريطة غير مُعدّة بعد. يلزم ضبط MAPTILER_API_KEY في إعدادات البناء. لن يظهر المفتاح داخل المستودع.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  else
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _initialCenter,
                        initialZoom: 16,
                        minZoom: 5,
                        maxZoom: 20,
                        onTap: (_, point) {
                          if (_points.length >= 100) return;
                          setState(() => _points.add(point));
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://api.maptiler.com/maps/satellite-v4/{z}/{x}/{y}.jpg?key=$mapKey',
                          userAgentPackageName: 'com.dahshory.agri.agri_app',
                          maxZoom: 20,
                        ),
                        if (_points.length >= 3)
                          PolygonLayer(
                            polygons: [
                              Polygon(
                                points: _points,
                                color: const Color(0x5534D399),
                                borderColor: const Color(0xFF047857),
                                borderStrokeWidth: 3,
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            for (var i = 0; i < _points.length; i++)
                              Marker(
                                point: _points[i],
                                width: 32,
                                height: 32,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _satelliteGreen,
                                      width: 2,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      color: _satelliteGreen,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  Positioned(
                    right: 12,
                    left: 12,
                    top: 12,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          _points.length < 3
                              ? 'انقر على الخريطة لإضافة نقاط حول حدود الأرض (${_points.length}/3 على الأقل).'
                              : 'تم تحديد ${_points.length} نقاط • المساحة التقريبية ${SatelliteGeometry.areaFeddan(_pointMaps).toStringAsFixed(2)} فدان',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  if (mapKey.isNotEmpty)
                    Positioned(
                      right: 12,
                      bottom: 42,
                      child: FloatingActionButton.small(
                        heroTag: 'satellite-current-location',
                        onPressed: _locating ? null : _goToCurrentLocation,
                        tooltip: 'الانتقال إلى موقعي',
                        child: _locating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location),
                      ),
                    ),
                  const Positioned(
                    left: 8,
                    bottom: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white70,
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        child: Text(
                          '© MapTiler  © OpenStreetMap contributors',
                          style: TextStyle(fontSize: 9),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    textDirection: TextDirection.rtl,
                    decoration: const InputDecoration(
                      labelText: 'اسم الحقل (مثال: حقل القمح الشرقي)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving || _points.length < 3 || mapKey.isEmpty
                          ? null
                          : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ حدود الحقل'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _satelliteGreen,
                        minimumSize: const Size.fromHeight(46),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  LatLng get _initialCenter => _points.isNotEmpty
      ? _points.first
      : const LatLng(24.0889, 32.8998); // نقطة بدء افتراضية في أسوان

  List<Map<String, double>> get _pointMaps => _points
      .map(
        (point) => <String, double>{
          'lat': point.latitude,
          'lng': point.longitude,
        },
      )
      .toList(growable: false);

  Future<void> _goToCurrentLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('فعّل خدمة الموقع على الهاتف أولاً.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('اسمح للتطبيق باستخدام الموقع للانتقال إلى المزرعة.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      _mapController.move(LatLng(position.latitude, position.longitude), 17);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر تحديد الموقع: $error')));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('اكتب اسماً للحقل أولاً.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.saveField(
        uid: widget.uid,
        fieldId: widget.field?.id,
        name: name,
        vertices: _pointMaps,
      );
      if (mounted) Navigator.pop(context);
    } on FirebaseException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'رفضت قواعد Firebase الحفظ: ${error.message ?? error.code}',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر حفظ حدود الحقل: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
