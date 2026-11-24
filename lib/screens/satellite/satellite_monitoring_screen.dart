import 'package:material_ui/material_ui.dart';

import '../../models/satellite_monitoring_model.dart';
import '../../services/satellite_monitoring_service.dart';
import 'satellite_field_detail_screen.dart';
import 'satellite_field_editor_screen.dart';

class SatelliteFieldsScreen extends StatelessWidget {
  const SatelliteFieldsScreen({super.key});

  static const _green = Color(0xFF047857);

  Future<void> _addField(BuildContext context) async {
    await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const SatelliteFieldEditorScreen()),
    );
  }

  Future<void> _openField(BuildContext context, HlsField field) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SatelliteFieldDetailScreen(field: field),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مراقبة المحاصيل بالأقمار'),
          backgroundColor: _green,
          foregroundColor: Colors.white,
        ),
        body: StreamBuilder<List<HlsField>>(
          stream: SatelliteMonitoringService.watchFields(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: _green));
            }
            if (snapshot.hasError) {
              return _ErrorState(
                message: 'تعذر تحميل الحقول. تأكد من تسجيل الدخول وقواعد Firestore.',
                onRetry: () => (context as Element).markNeedsBuild(),
              );
            }
            final fields = snapshot.data ?? const <HlsField>[];
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(child: _introCard()),
                ),
                if (fields.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(onAdd: () => _addField(context)),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'حقولي (${fields.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    sliver: SliverList.separated(
                      itemCount: fields.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _FieldCard(
                        field: fields[index],
                        onTap: () => _openField(context, fields[index]),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _addField(context),
          backgroundColor: _green,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('إضافة حقل'),
        ),
      ),
    );
  }

  Widget _introCard() => Card(
        elevation: 0,
        color: const Color(0xFFEAF6F0),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.satellite_alt, color: _green, size: 28),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'رصد زمني ومكاني لحقلك',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'ارسم الحدود مرة واحدة، ثم استخرج مؤشرات الغطاء النباتي والرطوبة والطيف والجودة من المشاهد المتاحة بدقة مناسبة.',
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'النتائج تعتمد على المشاهد الصافية المتاحة وليست تشخيصًا أو توصية ري تلقائية.',
                      style: TextStyle(fontSize: 10, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _FieldCard extends StatelessWidget {
  final HlsField field;
  final VoidCallback onTap;

  const _FieldCard({required this.field, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF047857).withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.grass, color: Color(0xFF047857)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(field.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        '${field.crop} · ${field.areaFeddans.toStringAsFixed(2)} فدان تقريبًا',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        field.polygon.length < 3
                            ? 'الحدود تحتاج إلى مراجعة'
                            : 'الحدود محفوظة · جاهز لطلب التحليل',
                        style: TextStyle(
                          color: field.polygon.length < 3
                              ? Colors.orange.shade800
                              : const Color(0xFF047857),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left, color: Colors.grey),
              ],
            ),
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 62, color: Colors.green.shade300),
              const SizedBox(height: 14),
              const Text(
                'ابدأ بأول حقل',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 7),
              Text(
                'أضف اسم الحقل والمحصول وتاريخ الزراعة، ثم ارسم حدوده على الخريطة. بعد ذلك يمكنك طلب المشاهد ومتابعة المؤشرات عبر الزمن.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, height: 1.45),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add),
                label: const Text('إضافة أول حقل'),
              ),
            ],
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.orange),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
}
