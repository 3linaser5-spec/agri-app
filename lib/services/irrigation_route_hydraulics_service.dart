import '../engines/hydraulic_engine.dart';
import '../models/irrigation_design_models.dart';
import 'irrigation_pipe_route_service.dart';

class IrrigationRouteHydraulicResult {
  final String routeId;
  final HydraulicResult hydraulic;
  final double lengthM;

  const IrrigationRouteHydraulicResult({
    required this.routeId,
    required this.hydraulic,
    required this.lengthM,
  });
}

class IrrigationRouteHydraulicsService {
  const IrrigationRouteHydraulicsService();

  List<IrrigationRouteHydraulicResult> analyze(
    Iterable<IrrigationPipeRoute> routes,
  ) {
    return List.unmodifiable(routes.map(analyzeRoute));
  }

  IrrigationRouteHydraulicResult analyzeRoute(IrrigationPipeRoute route) {
    final geometry = const IrrigationPipeRouteService().analyze(route);
    final hydraulic = HydraulicEngine.calculate(
      flowM3s: (route.designFlowLpm ?? 0.001) / 60000,
      diameterM: route.diameterMm / 1000,
      lengthM: geometry.lengthM,
      residualPressureHeadM: 10,
    );
    return IrrigationRouteHydraulicResult(
      routeId: route.id,
      hydraulic: hydraulic,
      lengthM: geometry.lengthM,
    );
  }
}
