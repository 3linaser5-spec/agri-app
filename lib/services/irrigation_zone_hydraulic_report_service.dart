import '../models/irrigation_design_models.dart';
import 'irrigation_route_hydraulics_service.dart';

class IrrigationZoneHydraulicReport {
  final String zoneId;
  final double designFlowLpm;
  final double requiredHeadM;
  final double pumpHeadM;
  final double pumpFlowLpm;
  final bool pumpAdequate;
  final List<String> recommendations;

  const IrrigationZoneHydraulicReport({
    required this.zoneId,
    required this.designFlowLpm,
    required this.requiredHeadM,
    required this.pumpHeadM,
    required this.pumpFlowLpm,
    required this.pumpAdequate,
    required this.recommendations,
  });
}

class IrrigationZoneHydraulicReportService {
  const IrrigationZoneHydraulicReportService();

  List<IrrigationZoneHydraulicReport> build(
    IrrigationDesignProject project,
  ) {
    final routeResults = const IrrigationRouteHydraulicsService()
        .analyze(project.pipeRoutes);
    return List.unmodifiable(project.zones.map((zone) {
      final zoneRoutes = routeResults.where((route) => project.pipeRoutes
          .firstWhere((candidate) => candidate.id == route.routeId)
          .zoneId == zone.id);
      final requiredHead = zoneRoutes.fold<double>(
        0,
        (maxHead, route) => route.hydraulic.totalDynamicHeadM > maxHead
            ? route.hydraulic.totalDynamicHeadM
            : maxHead,
      );
      final recommendations = <String>[];
      if (project.pump.flowRateLpm < zone.designFlowLpm) {
        recommendations.add('زيادة تصرف المضخة أو تقسيم المنطقة إلى دورات تشغيل.');
      }
      if (requiredHead > 0 && project.pump.headM < requiredHead * 1.1) {
        recommendations.add('اختيار مضخة برفع أعلى أو تقليل فواقد المسار.');
      }
      if (zoneRoutes.any((route) => route.hydraulic.warnings.contains('velocity_above_maximum'))) {
        recommendations.add('زيادة قطر الماسورة لتقليل السرعة والفقد.');
      }
      return IrrigationZoneHydraulicReport(
        zoneId: zone.id,
        designFlowLpm: zone.designFlowLpm,
        requiredHeadM: requiredHead,
        pumpHeadM: project.pump.headM,
        pumpFlowLpm: project.pump.flowRateLpm,
        pumpAdequate: recommendations.isEmpty,
        recommendations: List.unmodifiable(recommendations),
      );
    }));
  }
}
