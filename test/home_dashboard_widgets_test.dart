import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:agri_app/models/my_farm_model.dart';
import 'package:agri_app/models/weather_forecast.dart';
import 'package:agri_app/screens/root/home_dashboard_widgets.dart';

void main() {
  testWidgets('كارت النصيحة والزر السريع يعرضان المحتوى ويستجيبان للنقر',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            const HomeTipCard(),
            HomeQuickActionCard(
              icon: Icons.calculate,
              color: const Color(0xFF047857),
              title: 'حاسبات ومخططات المزرعة',
              onTap: () => taps++,
            ),
          ],
        ),
      ),
    );

    expect(find.text('نصيحة اليوم 💡'), findsOneWidget);
    expect(find.text('حاسبات ومخططات المزرعة'), findsOneWidget);

    await tester.tap(find.text('حاسبات ومخططات المزرعة'));
    expect(taps, 1);
  });

  testWidgets('قائمة تنبيهات الطقس تعرض رسالة الفراغ أو التنبيهات',
      (tester) async {
    await tester.pumpWidget(_host(const WeatherAlertList(alerts: [])));
    expect(
      find.text('لا توجد تنبيهات جوية مهمة خلال الأيام الثلاثة القادمة'),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _host(
        const WeatherAlertList(
          alerts: [
            WeatherAlert(
              kind: WeatherAlertKind.heat,
              title: 'موجة حرارة',
              message: 'تجنب الري وقت الظهيرة.',
            ),
          ],
        ),
      ),
    );
    expect(find.text('تنبيهات الطقس القريبة'), findsOneWidget);
    expect(find.text('موجة حرارة'), findsOneWidget);
  });

  testWidgets('بطاقة اليوم الأول تظهر باسم اليوم', (tester) async {
    await tester.pumpWidget(
      _host(
        ForecastDayTile(
          day: WeatherForecastDay(
            date: DateTime(2026, 11, 25),
            minimumTemperatureC: 14,
            maximumTemperatureC: 27,
            precipitationMm: 0,
            weatherCode: 0,
            precipitationProbability: 10,
          ),
          index: 0,
        ),
      ),
    );

    expect(find.text('اليوم'), findsOneWidget);
    expect(find.text('27° / 14°'), findsOneWidget);
  });

  testWidgets('مفتاح إشعارات الطقس يبلّغ بالتفعيل', (tester) async {
    bool? changed;
    await tester.pumpWidget(
      _host(
        WeatherPushControl(
          enabled: false,
          busy: false,
          onChanged: (value) => changed = value,
        ),
      ),
    );

    await tester.tap(find.byType(Switch));
    expect(changed, isTrue);
  });

  testWidgets('بطاقة الإنذار المبكر تختفي بدون محاصيل نشطة', (tester) async {
    await tester.pumpWidget(
      _host(const EarlyWarningCard(forecast: null, programs: [])),
    );
    expect(find.byType(Card), findsNothing);

    await tester.pumpWidget(
      _host(
        EarlyWarningCard(
          forecast: [
            WeatherForecastDay(
              date: DateTime(2026, 11, 25),
              minimumTemperatureC: 14,
              maximumTemperatureC: 27,
              precipitationMm: 0,
              weatherCode: 0,
            ),
          ],
          programs: [_program()],
        ),
      ),
    );
    expect(find.text('لا توجد إشارة رطوبة مرتفعة حاليًا'), findsOneWidget);
  });

  testWidgets('بطاقة الطقس تعرض الحالة وتستدعي اختيار الموقع والتحديث',
      (tester) async {
    var picked = 0;
    var refreshed = 0;
    await tester.pumpWidget(
      _host(
        HomeWeatherCard(
          snapshot: null,
          locationName: '',
          statusText: 'جاري تحديد موقعك وجلب الطقس...',
          refreshing: false,
          signedIn: false,
          pushEnabled: false,
          pushBusy: false,
          onPickLocation: () => picked++,
          onRefresh: () => refreshed++,
          onTogglePush: (_) {},
        ),
      ),
    );

    expect(find.text('جاري تحديد موقعك وجلب الطقس...'), findsOneWidget);
    expect(find.text('التوقعات والتنبيهات'), findsNothing);

    await tester.tap(find.byTooltip('اختر المحافظة والمركز والقرية'));
    await tester.tap(find.byTooltip('تحديث طقس الموقع المختار'));
    expect(picked, 1);
    expect(refreshed, 1);
  });

  testWidgets('بطاقة الطقس تعرض التفاصيل عند توفر التوقعات', (tester) async {
    await tester.pumpWidget(
      _host(
        HomeWeatherCard(
          snapshot: WeatherSnapshot(
            currentTemperatureC: 24.4,
            currentHumidityPercent: 55,
            currentWeatherCode: 0,
            days: [
              WeatherForecastDay(
                date: DateTime(2026, 11, 25),
                minimumTemperatureC: 14,
                maximumTemperatureC: 27,
                precipitationMm: 0,
                weatherCode: 0,
              ),
            ],
          ),
          locationName: 'المنصورة',
          statusText: '',
          refreshing: false,
          signedIn: true,
          pushEnabled: false,
          pushBusy: false,
          onPickLocation: () {},
          onRefresh: () {},
          onTogglePush: (_) {},
        ),
      ),
    );

    expect(find.text('المنصورة · 24°م'), findsOneWidget);
    expect(find.text('التوقعات والتنبيهات'), findsOneWidget);
    expect(find.textContaining('رطوبة 55٪'), findsOneWidget);
  });
}

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

MyFarmProgram _program() => MyFarmProgram(
      id: 'program-1',
      userId: 'user-1',
      templateId: 'template-1',
      templateName: 'قمح',
      templateEmoji: '🌾',
      sectionId: 'field-crops',
      sectionName: 'محاصيل حقلية',
      governorate: 'الدقهلية',
      climateZone: 'دلتا',
      inputValues: const {},
      tasks: const [],
      materials: const [],
      financial: const {},
      startDate: DateTime(2026, 11, 1),
      createdAt: DateTime(2026, 11, 1),
    );
