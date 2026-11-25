import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:agri_app/models/satellite_monitoring_model.dart';
import 'package:agri_app/screens/satellite/hls_time_series_chart.dart';

void main() {
  testWidgets('يطلب مشهدين على الأقل قبل رسم المنحنى', (tester) async {
    await tester.pumpWidget(
      _host(
        const HlsTimeSeriesChart(
          observations: <HlsObservation>[],
          layer: 'NDVI',
          label: 'NDVI · حيوية النبات',
        ),
      ),
    );

    expect(find.text('NDVI · حيوية النبات'), findsOneWidget);
    expect(
      find.text('يلزم مشهدان صالحان على الأقل لرسم المنحنى.'),
      findsOneWidget,
    );
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('يرسم المنحنى ويعرض تاريخ أول وآخر مشهد', (tester) async {
    await tester.pumpWidget(
      _host(
        HlsTimeSeriesChart(
          observations: [
            _observation('2026-09-01', 0.42),
            _observation('2026-10-01', 0.55),
            _observation('2026-11-01', 0.61),
          ],
          layer: 'NDVI',
          label: 'NDVI · حيوية النبات',
        ),
      ),
    );

    expect(find.text('تغير المؤشر عبر المشاهد المتاحة'), findsOneWidget);
    expect(find.text('2026/09'), findsOneWidget);
    expect(find.text('2026/11'), findsOneWidget);
    expect(find.text('آخر قيمة 0.610'), findsOneWidget);
    expect(
      find.text('يلزم مشهدان صالحان على الأقل لرسم المنحنى.'),
      findsNothing,
    );
  });
}

HlsObservation _observation(String date, double ndvi) => HlsObservation(
      id: date,
      date: DateTime.parse(date),
      metrics: {'NDVI': ndvi},
      bands: const {},
      samples: const [],
      validSampleCount: 1,
      totalSampleCount: 1,
      sources: const [],
      quality: const {},
      alerts: const [],
    );

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
