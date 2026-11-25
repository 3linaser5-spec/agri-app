import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/my_farm_model.dart';
import '../../models/weather_forecast.dart';
import '../../services/early_warning_service.dart';

/// أيقونة الطقس المقابلة لرمز WMO.
IconData weatherCodeIcon(int weatherCode) {
  if (weatherCode == 0) return Icons.wb_sunny;
  if (weatherCode >= 95) return Icons.thunderstorm;
  if ((weatherCode >= 51 && weatherCode <= 67) ||
      (weatherCode >= 80 && weatherCode <= 82)) {
    return Icons.umbrella;
  }
  if (weatherCode >= 71 && weatherCode <= 77) return Icons.ac_unit;
  return Icons.cloud_queue;
}

/// زر سريع في الصفحة الرئيسية.
class HomeQuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  const HomeQuickActionCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// كارت نصيحة اليوم.
class HomeTipCard extends StatelessWidget {
  const HomeTipCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade50,
            Colors.orange.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.lightbulb,
                color: Colors.amber.shade800, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'نصيحة اليوم 💡',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.amber.shade900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'تجنب رش المبيدات في وقت الظهيرة أو عند ارتفاع درجات الحرارة لتفادي احتراق الأوراق، وأفضل وقت للرش هو الصباح الباكر أو بعد كسر حدة الشمس عصراً.',
                  style: TextStyle(
                      fontSize: 12, height: 1.6, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// قائمة تنبيهات الطقس القريبة.
class WeatherAlertList extends StatelessWidget {
  final List<WeatherAlert> alerts;

  const WeatherAlertList({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF047857)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'لا توجد تنبيهات جوية مهمة خلال الأيام الثلاثة القادمة',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'تنبيهات الطقس القريبة',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        ...alerts.map((alert) {
          final color = switch (alert.kind) {
            WeatherAlertKind.rain => const Color(0xFF0369A1),
            WeatherAlertKind.heat => const Color(0xFFB45309),
            WeatherAlertKind.cold => const Color(0xFF4338CA),
          };
          final icon = switch (alert.kind) {
            WeatherAlertKind.rain => Icons.water_drop,
            WeatherAlertKind.heat => Icons.thermostat,
            WeatherAlertKind.cold => Icons.ac_unit,
          };
          return Container(
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.22)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert.title,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: color)),
                      const SizedBox(height: 3),
                      Text(alert.message,
                          style: const TextStyle(fontSize: 11, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// بطاقة يوم واحد من التوقعات.
class ForecastDayTile extends StatelessWidget {
  final WeatherForecastDay day;
  final int index;

  const ForecastDayTile({super.key, required this.day, required this.index});

  @override
  Widget build(BuildContext context) {
    final label = index == 0 ? 'اليوم' : (index == 1 ? 'غدًا' : day.dayName);
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1FAE5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Icon(weatherCodeIcon(day.weatherCode),
              color: day.weatherCode == 0
                  ? Colors.orange
                  : const Color(0xFF0284C7),
              size: 23),
          Text(day.conditionLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10)),
          Text(
            '${day.maximumTemperatureC.toStringAsFixed(0)}° / ${day.minimumTemperatureC.toStringAsFixed(0)}°',
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.water_drop, size: 13, color: Colors.blue),
              const SizedBox(width: 3),
              Text(
                day.precipitationProbability == null
                    ? '—'
                    : '${day.precipitationProbability}٪',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
          Text('${day.precipitationMm.toStringAsFixed(1)} مم',
              style: const TextStyle(fontSize: 10, color: Colors.black54)),
        ],
      ),
    );
  }
}

/// مفتاح تشغيل/إيقاف إشعارات الطقس.
class WeatherPushControl extends StatelessWidget {
  final bool enabled;
  final bool busy;
  final ValueChanged<bool> onChanged;

  const WeatherPushControl({
    super.key,
    required this.enabled,
    required this.busy,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1FAE5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_outlined,
              color: Color(0xFF047857), size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تنبيهات الطقس والإنذار المبكر',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                SizedBox(height: 3),
                Text(
                  'أمطار أو حر/برد، ومؤشرات رطوبة لمتابعة المحاصيل النشطة. الموقع تقريبي (نحو 1 كم).',
                  style: TextStyle(fontSize: 9, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          busy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF047857),
                  ),
                )
              : Switch.adaptive(
                  value: enabled,
                  activeTrackColor: const Color(0xFF047857),
                  onChanged: onChanged,
                ),
        ],
      ),
    );
  }
}

/// بطاقة الإنذار المبكر للمحاصيل النشطة.
class EarlyWarningCard extends StatelessWidget {
  final List<WeatherForecastDay>? forecast;
  final List<MyFarmProgram> programs;

  const EarlyWarningCard({
    super.key,
    required this.forecast,
    required this.programs,
  });

  @override
  Widget build(BuildContext context) {
    if (programs.isEmpty) return const SizedBox.shrink();
    final warnings = forecast == null
        ? const <CropWeatherWarning>[]
        : EarlyWarningService.evaluate(forecast: forecast!, programs: programs);
    final warning = warnings.isEmpty ? null : warnings.first;
    final color = warning?.level == CropWeatherRiskLevel.elevated
        ? const Color(0xFFB45309)
        : const Color(0xFF047857);
    final title = forecast == null
        ? 'الإنذار المبكر للمحصول'
        : warning?.title ?? 'لا توجد إشارة رطوبة مرتفعة حاليًا';
    final message = forecast == null
        ? 'جارٍ تحميل توقعات الطقس لحقولك.'
        : warning?.message ??
            'نراجع توقعات الأيام الثلاثة القادمة للمحاصيل النشطة. الإشارة تعتمد الطقس فقط ولا تعني وجود إصابة.';

    return Card(
      margin: EdgeInsets.zero,
      color: color.withValues(alpha: 0.07),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              warning?.level == CropWeatherRiskLevel.elevated
                  ? Icons.warning_amber_rounded
                  : Icons.eco_outlined,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                  const SizedBox(height: 3),
                  Text(message,
                      maxLines: warning == null ? 2 : 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة الطقس الحالية مع توقعات ٧ أيام وإعداد الإشعارات.
class HomeWeatherCard extends StatelessWidget {
  final WeatherSnapshot? snapshot;
  final String locationName;
  final String statusText;
  final bool refreshing;
  final bool signedIn;
  final bool pushEnabled;
  final bool pushBusy;
  final VoidCallback onPickLocation;
  final VoidCallback onRefresh;
  final ValueChanged<bool> onTogglePush;

  const HomeWeatherCard({
    super.key,
    required this.snapshot,
    required this.locationName,
    required this.statusText,
    required this.refreshing,
    required this.signedIn,
    required this.pushEnabled,
    required this.pushBusy,
    required this.onPickLocation,
    required this.onRefresh,
    required this.onTogglePush,
  });

  @override
  Widget build(BuildContext context) {
    final icon = snapshot == null
        ? Icons.cloud_outlined
        : weatherCodeIcon(snapshot!.currentWeatherCode);
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFFECFDF5),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 8, 6),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 20, color: const Color(0xFF0284C7)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        snapshot == null
                            ? 'الطقس · ${locationName.isEmpty ? 'موقع المزرعة' : locationName}'
                            : '$locationName · ${snapshot!.currentTemperatureC.toStringAsFixed(0)}°م',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        snapshot == null
                            ? statusText
                            : '${snapshot!.currentCondition} · رطوبة ${snapshot!.currentHumidityPercent}٪',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(fontSize: 10, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'اختر المحافظة والمركز والقرية',
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints.tightFor(width: 34, height: 34),
                  padding: EdgeInsets.zero,
                  onPressed: onPickLocation,
                  icon: const Icon(Icons.location_on_outlined,
                      size: 18, color: Color(0xFF047857)),
                ),
                refreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF047857)),
                      )
                    : IconButton(
                        tooltip: 'تحديث طقس الموقع المختار',
                        visualDensity: VisualDensity.compact,
                        constraints:
                            const BoxConstraints.tightFor(width: 34, height: 34),
                        padding: EdgeInsets.zero,
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh,
                            size: 18, color: Color(0xFF047857)),
                      ),
              ],
            ),
          ),
          if (snapshot != null)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding:
                    const EdgeInsetsDirectional.only(start: 12, end: 14),
                childrenPadding:
                    const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 12),
                visualDensity: VisualDensity.compact,
                leading: const Icon(Icons.calendar_month_outlined,
                    size: 17, color: Color(0xFF047857)),
                title: const Text('التوقعات والتنبيهات',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                subtitle: const Text('تفاصيل ٧ أيام وإعداد الإشعارات',
                    style: TextStyle(fontSize: 9)),
                children: [
                  if (signedIn) ...[
                    WeatherPushControl(
                      enabled: pushEnabled,
                      busy: pushBusy,
                      onChanged: onTogglePush,
                    ),
                    const SizedBox(height: 8),
                  ],
                  WeatherAlertList(alerts: snapshot!.alerts),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 118,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: snapshot!.days.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, index) =>
                          ForecastDayTile(day: snapshot!.days[index], index: index),
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => launchUrl(
                        Uri.https('open-meteo.com'),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new, size: 12),
                      label: const Text('مصدر البيانات: Open-Meteo',
                          style: TextStyle(fontSize: 10)),
                    ),
                  ),
                  const Text(
                    'التنبيهات تقديرية وليست تحذيرات رسمية أو تشخيصًا زراعيًا.',
                    style: TextStyle(fontSize: 9, color: Colors.black54),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
