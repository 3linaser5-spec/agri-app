import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:agri_app/screens/calculators/irrigation_calculator_widgets.dart';

void main() {
  testWidgets('شرائح نوع الري تبلّغ بالنوع المختار', (tester) async {
    IrrigationType? selected;
    await tester.pumpWidget(
      _host(
        IrrigationTypeChips(
          type: IrrigationType.drip,
          onSelected: (type) => selected = type,
        ),
      ),
    );

    expect(find.text('تنقيط'), findsOneWidget);
    await tester.tap(find.text('رش'));
    expect(selected, IrrigationType.sprinkler);
  });

  testWidgets('بطاقة النتائج تعرض السطور وأزرار التصدير المتاحة',
      (tester) async {
    var export2d = 0;
    var export3d = 0;
    await tester.pumpWidget(
      _host(
        IrrigationResultCard(
          lines: const [
            IrrigationResultLine.section('التصميم'),
            IrrigationResultLine.row('التصرف', '12 م³/س'),
            IrrigationResultLine.ok('السرعة', '1.2 م/ث'),
            IrrigationResultLine.warn('الفقد', 'مرتفع'),
          ],
          dxfReady: true,
          dxf3dReady: false,
          exporting: false,
          onExportDxf: () => export2d++,
          onExportDxf3d: () => export3d++,
        ),
      ),
    );

    expect(find.text('التصميم'), findsOneWidget);
    expect(find.text('12 م³/س'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);

    final button2d = find.text('تصدير مخطط 2D بصيغة DXF');
    await tester.ensureVisible(button2d);
    await tester.tap(button2d);
    expect(export2d, 1);
    expect(find.text('تصدير شبكة الري 3D بصيغة DXF'), findsNothing);
    expect(export3d, 0);
  });

  testWidgets('بطاقة النتائج تخفي التصدير عند غياب المخطط', (tester) async {
    await tester.pumpWidget(
      _host(
        IrrigationResultCard(
          lines: const [IrrigationResultLine.row('التصرف', '5 م³/س')],
          dxfReady: false,
          dxf3dReady: false,
          exporting: false,
          onExportDxf: () {},
          onExportDxf3d: () {},
        ),
      ),
    );

    expect(find.text('التصرف'), findsOneWidget);
    expect(find.textContaining('DXF'), findsNothing);
  });
}

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
