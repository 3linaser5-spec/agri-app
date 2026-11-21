import 'dart:math' as math;

/// طريقة حساب فاقد الاحتكاك في الأنبوب.
enum HydraulicFrictionMethod { hazenWilliams, darcyWeisbach }

/// نتيجة حساب هيدروليكي كاملة بوحدات SI.
class HydraulicResult {
  final HydraulicFrictionMethod method;
  final double velocityMps;
  final double reynoldsNumber;
  final double frictionFactor;
  final double pipeFrictionHeadM;
  final double fittingsHeadM;
  final double valvesHeadM;
  final double totalMinorHeadM;
  final double elevationHeadM;
  final double residualPressureHeadM;
  final double residualPressurePa;
  final double totalDynamicHeadM;
  final double totalDynamicPressurePa;
  final List<String> warnings;

  const HydraulicResult({
    required this.method,
    required this.velocityMps,
    required this.reynoldsNumber,
    required this.frictionFactor,
    required this.pipeFrictionHeadM,
    required this.fittingsHeadM,
    required this.valvesHeadM,
    required this.totalMinorHeadM,
    required this.elevationHeadM,
    required this.residualPressureHeadM,
    required this.residualPressurePa,
    required this.totalDynamicHeadM,
    required this.totalDynamicPressurePa,
    required this.warnings,
  });

  Map<String, dynamic> toJson() => {
        'method': method.name,
        'velocity_mps': velocityMps,
        'reynolds_number': reynoldsNumber,
        'friction_factor': frictionFactor,
        'pipe_friction_head_m': pipeFrictionHeadM,
        'fittings_head_m': fittingsHeadM,
        'valves_head_m': valvesHeadM,
        'total_minor_head_m': totalMinorHeadM,
        'elevation_head_m': elevationHeadM,
        'residual_pressure_head_m': residualPressureHeadM,
        'residual_pressure_pa': residualPressurePa,
        'total_dynamic_head_m': totalDynamicHeadM,
        'total_dynamic_pressure_pa': totalDynamicPressurePa,
        'warnings': warnings,
      };
}

/// محرك مستقل لحسابات الأنابيب الهيدروليكية.
///
/// كل المدخلات الهندسية SI: التدفق m³/s، الأقطار والأطوال m، اللزوجة
/// الحركية m²/s، وخشونة Hazen-Williams بوحدة m. الضغط الناتج Pa والرأس m.
class HydraulicEngine {
  HydraulicEngine._();

  static const double waterDensityKgM3 = 998.2;
  static const double gravityMps2 = 9.80665;
  static const double defaultKinematicViscosityM2s = 1.004e-6;
  static const double defaultHazenWilliamsC = 140;
  static const double defaultVelocityWarningMps = 2.0;
  static const double defaultMaximumVelocityMps = 3.0;
  static const double defaultMinimumResidualPressureHeadM = 10.0;

  /// يحسب السرعة فقط من التدفق والقطر.
  static double velocity({required num flowM3s, required num diameterM}) {
    final q = _positive(flowM3s, 'flowM3s');
    final d = _positive(diameterM, 'diameterM');
    return q / (math.pi * d * d / 4);
  }

  /// يحسب رقم Reynolds من السرعة والقطر واللزوجة الحركية.
  static double reynolds({required num velocityMps, required num diameterM, num kinematicViscosityM2s = defaultKinematicViscosityM2s}) {
    final v = _nonNegative(velocityMps, 'velocityMps');
    final d = _positive(diameterM, 'diameterM');
    final nu = _positive(kinematicViscosityM2s, 'kinematicViscosityM2s');
    return v * d / nu;
  }

  /// يحسب المعامل Darcy-Weisbach: لامينار 64/Re، ومضطربًا بصيغة Swamee-Jain.
  static double darcyFrictionFactor({required num reynoldsNumber, required num diameterM, required num roughnessM}) {
    final re = _positive(reynoldsNumber, 'reynoldsNumber');
    final d = _positive(diameterM, 'diameterM');
    final e = _nonNegative(roughnessM, 'roughnessM');
    if (re < 2300) return 64 / re;
    final value = e / (3.7 * d) + 5.74 / math.pow(re, 0.9);
    return 0.25 / math.pow(math.log(value) / math.ln10, 2);
  }

  /// يحسب فقد الأنبوب والوصلات والمحابس وفرق المنسوب وTDH.
  static HydraulicResult calculate({
    required num flowM3s,
    required num diameterM,
    required num lengthM,
    HydraulicFrictionMethod method = HydraulicFrictionMethod.darcyWeisbach,
    num hazenWilliamsC = defaultHazenWilliamsC,
    num roughnessM = 0.00015,
    num kinematicViscosityM2s = defaultKinematicViscosityM2s,
    num fittingsK = 0,
    num valvesK = 0,
    num elevationDifferenceM = 0,
    num residualPressureHeadM = 0,
    num velocityWarningMps = defaultVelocityWarningMps,
    num maximumVelocityMps = defaultMaximumVelocityMps,
    num minimumResidualPressureHeadM = defaultMinimumResidualPressureHeadM,
  }) {
    final q = _positive(flowM3s, 'flowM3s');
    final d = _positive(diameterM, 'diameterM');
    final l = _positive(lengthM, 'lengthM');
    final c = _positive(hazenWilliamsC, 'hazenWilliamsC');
    final e = _nonNegative(roughnessM, 'roughnessM');
    final nu = _positive(kinematicViscosityM2s, 'kinematicViscosityM2s');
    final fk = _nonNegative(fittingsK, 'fittingsK');
    final vk = _nonNegative(valvesK, 'valvesK');
    final elevation = _finite(elevationDifferenceM, 'elevationDifferenceM');
    final residual = _nonNegative(residualPressureHeadM, 'residualPressureHeadM');
    final velocityWarn = _positive(velocityWarningMps, 'velocityWarningMps');
    final velocityMax = _positive(maximumVelocityMps, 'maximumVelocityMps');
    final minimumResidual = _nonNegative(minimumResidualPressureHeadM, 'minimumResidualPressureHeadM');
    if (velocityMax < velocityWarn) throw ArgumentError.value(maximumVelocityMps, 'maximumVelocityMps', 'must be at least velocityWarningMps');

    final v = velocity(flowM3s: q, diameterM: d);
    final re = reynolds(velocityMps: v, diameterM: d, kinematicViscosityM2s: nu);
    final f = method == HydraulicFrictionMethod.darcyWeisbach
        ? darcyFrictionFactor(reynoldsNumber: re, diameterM: d, roughnessM: e)
        : double.nan;
    final pipeLoss = method == HydraulicFrictionMethod.darcyWeisbach
        ? f * l / d * v * v / (2 * gravityMps2)
        : 10.67 * l * math.pow(q, 1.852) / (math.pow(c, 1.852) * math.pow(d, 4.87));
    final dynamicHead = v * v / (2 * gravityMps2);
    final fittingsLoss = fk * dynamicHead;
    final valvesLoss = vk * dynamicHead;
    final minor = fittingsLoss + valvesLoss;
    final tdh = elevation + pipeLoss + minor + residual;
    final warnings = <String>[];
    if (v > velocityWarn) warnings.add('velocity_above_warning');
    if (v > velocityMax) warnings.add('velocity_above_maximum');
    if (residual < minimumResidual) warnings.add('residual_pressure_below_minimum');
    if (method == HydraulicFrictionMethod.darcyWeisbach && re >= 2300 && re < 4000) warnings.add('flow_in_transition_zone');
    if (tdh < 0) warnings.add('negative_tdh');

    return HydraulicResult(
      method: method,
      velocityMps: v,
      reynoldsNumber: re,
      frictionFactor: f,
      pipeFrictionHeadM: pipeLoss,
      fittingsHeadM: fittingsLoss,
      valvesHeadM: valvesLoss,
      totalMinorHeadM: minor,
      elevationHeadM: elevation,
      residualPressureHeadM: residual,
      residualPressurePa: residual * waterDensityKgM3 * gravityMps2,
      totalDynamicHeadM: tdh,
      totalDynamicPressurePa: tdh * waterDensityKgM3 * gravityMps2,
      warnings: List<String>.unmodifiable(warnings),
    );
  }

  static double _finite(num value, String field) {
    final result = value.toDouble();
    if (!result.isFinite) throw ArgumentError.value(value, field, 'must be finite');
    return result;
  }

  static double _positive(num value, String field) {
    final result = _finite(value, field);
    if (result <= 0) throw ArgumentError.value(value, field, 'must be greater than zero');
    return result;
  }

  static double _nonNegative(num value, String field) {
    final result = _finite(value, field);
    if (result < 0) throw ArgumentError.value(value, field, 'must not be negative');
    return result;
  }
}
