import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:agri_app/models/calculator_models.dart';
import 'package:agri_app/screens/calculators/calculator_result_tabs.dart';

void main() {
  testWidgets('حالة الفراغ تظهر عند غياب المهام والمواد والبيانات المالية',
      (tester) async {
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            Expanded(
              child: CalculatorTimelineTab(
                tasks: const [],
                primaryColor: const Color(0xFF047857),
                isDark: false,
              ),
            ),
            Expanded(
              child: CalculatorMaterialsTab(
                materials: const [],
                areaMultiplier: 1,
                hasExplicitArea: false,
                areaUnit: 'فدان',
                primaryColor: const Color(0xFF047857),
                isDark: false,
                quantityOf: (_) => 0,
                totalCost: 0,
              ),
            ),
          ],
        ),
      ),
    );

    expect(find.text('لا يوجد جدول زمني'), findsOneWidget);
    expect(find.text('لا يوجد مشتريات'), findsOneWidget);
  });

  testWidgets('تاب الجدول يعرض المهام بأسمائها وتصنيفاتها', (tester) async {
    await tester.pumpWidget(
      _host(
        CalculatorTimelineTab(
          tasks: [
            CalculatorTask(
              title: 'رية المحاياة',
              description: 'ري خفيف بعد الزراعة',
              dayFromStart: 0,
              category: 'ري',
            ),
            CalculatorTask(
              title: 'تسميد أول',
              description: '',
              dayFromStart: 21,
              category: 'تسميد',
            ),
          ],
          primaryColor: const Color(0xFF047857),
          isDark: false,
        ),
      ),
    );

    expect(find.text('رية المحاياة'), findsOneWidget);
    expect(find.text('تسميد أول'), findsOneWidget);
    expect(find.text('اليوم 21'), findsOneWidget);
  });

  testWidgets('تاب المشتريات يعرض الكميات والتكلفة الإجمالية', (tester) async {
    await tester.pumpWidget(
      _host(
        CalculatorMaterialsTab(
          materials: [
            CalculatorMaterial(
              name: 'بذور قمح',
              category: 'تقاوي',
              quantityPerUnit: 60,
              unit: 'كجم',
              estimatedPricePerUnit: 20,
            ),
          ],
          areaMultiplier: 2.5,
          hasExplicitArea: true,
          areaUnit: 'فدان',
          primaryColor: const Color(0xFF047857),
          isDark: false,
          quantityOf: (material) => material.quantityPerUnit * 2.5,
          totalCost: 3000,
        ),
      ),
    );

    expect(find.textContaining('الكميات محسوبة على مساحة 2.50 فدان'),
        findsOneWidget);
    expect(find.text('بذور قمح'), findsOneWidget);
    expect(find.textContaining('150.00 كجم'), findsOneWidget);
    expect(find.text('إجمالي تكلفة المشتريات'), findsOneWidget);
    expect(find.text('3000 ج.م'), findsOneWidget);
  });

  testWidgets('تاب التحليل المالي يحسب الربح والعائد', (tester) async {
    await tester.pumpWidget(
      _host(
        CalculatorFinancialTab(
          financial: CalculatorFinancial(
            expectedYieldPerUnit: 3,
            yieldUnit: 'طن',
            expectedPricePerYieldUnit: 1000,
            costDistribution: const {'تقاوي': 40, 'سماد': 60},
          ),
          totalYield: 3,
          totalMaterialsCost: 1200,
          primaryColor: const Color(0xFF047857),
          isDark: false,
        ),
      ),
    );

    expect(find.text('3.0 طن'), findsOneWidget);
    expect(find.text('صافي الربح المتوقع'), findsOneWidget);
    expect(find.text('1800 ج.م'), findsOneWidget);
    expect(find.text('نسبة العائد (ROI)'), findsOneWidget);
    expect(find.textContaining('توزيع التكاليف'), findsOneWidget);
  });

  testWidgets('حالة الفراغ تعرض العنوان والوصف', (tester) async {
    await tester.pumpWidget(
      _host(
        const CalculatorEmptyState(
          icon: Icons.attach_money,
          title: 'لا يوجد تحليل مالي',
          subtitle: 'لم يتم إضافة بيانات مالية لهذا المحصول',
        ),
      ),
    );

    expect(find.text('لا يوجد تحليل مالي'), findsOneWidget);
    expect(
      find.text('لم يتم إضافة بيانات مالية لهذا المحصول'),
      findsOneWidget,
    );
  });
}

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );
