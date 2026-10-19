import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../utils/dxf_export.dart';
import '../../utils/irrigation_calc.dart';
import '../../utils/number_utils.dart';

enum IrrigationType { drip, sprinkler, surface, pivot }

const _blue = Color(0xFF0284C7);

class _Line {
  final String label;
  final String value;
  final int kind; // 0 صف عادي، 1 سليم، 2 تحذير، 3 عنوان قسم

  const _Line.section(this.label)
      : value = '',
        kind = 3;
  const _Line.row(this.label, this.value)
      : kind = 0;
  const _Line.ok(this.label, this.value)
      : kind = 1;
  const _Line.warn(this.label, this.value)
      : kind = 2;
}

String _fmt(double v, [int digits = 2]) {
  if (!v.isFinite) return '-';
  var s = v.toStringAsFixed(digits);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

/// حاسبة تصميم شبكات الري: تنقيط، رش، سطحي، محوري.
class IrrigationCalculatorScreen extends StatefulWidget {
  const IrrigationCalculatorScreen({super.key});

  @override
  State<IrrigationCalculatorScreen> createState() =>
      _IrrigationCalculatorScreenState();
}

class _IrrigationCalculatorScreenState
    extends State<IrrigationCalculatorScreen> {
  static const _defaults = <String, String>{
    'area': '1',
    'eto': '5',
    'kc': '0.8',
    'eff': '90',
    'interval': '1',
    'hours': '12',
    'rowSp': '1',
    'plantSp': '0.5',
    'emitters': '1',
    'emitterLph': '4',
    'sectors': '1',
    'latLen': '50',
    'head': '10',
    'spr': '1.2',
    'sAlong': '12',
    'sAcross': '12',
    'stream': '20',
    'furrow': '0.75',
    'aspect': '1.5',
    'radius': '400',
    'rotation': '40',
    'mainLen': '200',
    'lift': '10',
    'equip': '5',
    'minor': '10',
    'pumpEff': '65',
    'motorEff': '90',
  };

  static const _labels = <String, String>{
    'area': 'المساحة',
    'eto': 'البخر-نتح المرجعي ETo',
    'kc': 'معامل المحصول Kc',
    'eff': 'كفاءة الري',
    'interval': 'عدد الأيام بين الريات',
    'hours': 'ساعات التشغيل المتاحة يوميًا',
    'rowSp': 'المسافة بين الخطوط',
    'plantSp': 'المسافة بين النباتات',
    'emitters': 'عدد النقاطات للنبات',
    'emitterLph': 'تصرف النقاط',
    'sectors': 'عدد القطاعات',
    'latLen': 'طول الخط الفرعي',
    'head': 'ضغط التشغيل',
    'spr': 'تصرف الرشاش',
    'sAlong': 'المسافة بين الرشاشات',
    'sAcross': 'المسافة بين الخطوط',
    'stream': 'تصرف المجرى',
    'furrow': 'المسافة بين الخطوط (الأتلام)',
    'aspect': 'نسبة طول/عرض الحقل',
    'radius': 'نصف قطر البيفوت',
    'rotation': 'زمن الدورة الكاملة',
    'mainLen': 'طول الماسورة الرئيسية',
    'lift': 'الارتفاع الاستاتيكي',
    'equip': 'فاقد الفلاتر والتركيبات',
    'minor': 'نسبة الفواقد الثانوية',
    'pumpEff': 'كفاءة المضخة',
    'motorEff': 'كفاءة المحرك',
  };

  IrrigationType _type = IrrigationType.drip;
  AreaUnit _unit = AreaUnit.feddan;
  double _lateralDia = 16;
  final Map<String, TextEditingController> _c = {};
  List<_Line> _results = const [];
  String? _dxf;
  bool _isExporting = false;

  TextEditingController _ctrl(String key) => _c.putIfAbsent(
      key, () => TextEditingController(text: _defaults[key] ?? ''));

  double _v(String key) => NumberUtils.tryParseDouble(_ctrl(key).text) ?? 0;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _needsPump => _type != IrrigationType.surface;

  List<String> get _requiredKeys => [
        'eto',
        'kc',
        'eff',
        'interval',
        if (_type != IrrigationType.pivot) 'area',
        if (_type == IrrigationType.drip) ...[
          'hours', 'rowSp', 'plantSp', 'emitters', 'emitterLph', 'sectors',
          'latLen', 'head',
        ],
        if (_type == IrrigationType.sprinkler) ...[
          'hours', 'spr', 'sAlong', 'sAcross', 'sectors', 'head', 'aspect',
        ],
        if (_type == IrrigationType.surface) ...[
          'hours', 'stream', 'furrow', 'aspect',
        ],
        if (_type == IrrigationType.pivot) ...['radius', 'rotation', 'head'],
        if (_needsPump) ...[
          'mainLen', 'lift', 'equip', 'minor', 'pumpEff', 'motorEff',
        ],
      ];

  void _selectType(IrrigationType t) {
    const eff = {
      IrrigationType.drip: '90',
      IrrigationType.sprinkler: '75',
      IrrigationType.surface: '60',
      IrrigationType.pivot: '85',
    };
    const interval = {
      IrrigationType.drip: '1',
      IrrigationType.sprinkler: '3',
      IrrigationType.surface: '7',
      IrrigationType.pivot: '2',
    };
    const head = {
      IrrigationType.drip: '10',
      IrrigationType.sprinkler: '30',
      IrrigationType.surface: '0',
      IrrigationType.pivot: '30',
    };
    setState(() {
      _type = t;
      _ctrl('eff').text = eff[t]!;
      _ctrl('interval').text = interval[t]!;
      _ctrl('head').text = head[t]!;
      _results = const [];
      _dxf = null;
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red,
    ));
  }

  // ───────────────────── الحساب ─────────────────────
  void _calculate() {
    FocusScope.of(context).unfocus();
    final missing = _requiredKeys
        .where((k) => NumberUtils.tryParseDouble(_ctrl(k).text) == null)
        .map((k) => _labels[k] ?? k)
        .toList();
    if (missing.isNotEmpty) {
      _snack('ادخل قيمة صالحة لـ: ${missing.take(4).join('، ')}');
      return;
    }

    if (_type != IrrigationType.pivot &&
        (!_v('area').isFinite || _v('area') <= 0)) {
      _snack('المساحة لازم تكون أكبر من صفر');
      return;
    }

    final integerKeys = <String>[
      if (_type == IrrigationType.drip || _type == IrrigationType.sprinkler)
        'sectors',
      if (_type == IrrigationType.drip) 'emitters',
    ];
    for (final key in integerKeys) {
      final value = _v(key);
      if (!value.isFinite || value < 1 || value != value.truncateToDouble()) {
        _snack('${_labels[key] ?? key} لازم يكون عددًا صحيحًا أكبر من صفر');
        return;
      }
    }
    if (_type == IrrigationType.sprinkler ||
        _type == IrrigationType.surface) {
      final aspect = _v('aspect');
      if (!aspect.isFinite || aspect <= 0) {
        _snack('نسبة طول/عرض الحقل لازم تكون أكبر من صفر');
        return;
      }
    }

    final etc = IrrigationCalc.etc(_v('eto'), _v('kc'));
    final eff = _v('eff') / 100;
    final interval = _v('interval');
    if (etc == null) {
      _snack('ETo و Kc لازم يكونوا أكبر من صفر');
      return;
    }

    final lines = <_Line>[];
    String? dxf;
    double? designFlow;
    double cost = 0;
    var bomCost = false;

    String? invalid;
    switch (_type) {
      case IrrigationType.drip: {
        final area = IrrigationCalc.areaToM2(_v('area'), _unit);
        final sectors = _v('sectors').round();
        final r = IrrigationCalc.drip(
          areaM2: area,
          rowSpacingM: _v('rowSp'),
          plantSpacingM: _v('plantSp'),
          emittersPerPlant: _v('emitters').round(),
          emitterLph: _v('emitterLph'),
          etcMmDay: etc,
          efficiency: eff,
          intervalDays: interval,
          availableHours: _v('hours'),
          sectors: sectors,
          lateralLengthM: _v('latLen'),
          lateralDiameterMm: _lateralDia,
          operatingHeadM: _v('head'),
        );
        if (r == null) {
          invalid = 'تأكد إن كل القيم أكبر من صفر والكفاءة بين 1 و100%';
          break;
        }
        _needLines(lines, r.need);
        lines
          ..add(const _Line.section('تصميم التنقيط'))
          ..add(_Line.row('عدد النباتات', _fmt(r.plants, 0)))
          ..add(_Line.row('عدد النقاطات', _fmt(r.totalEmitters, 0)))
          ..add(_Line.row('لتر/نبات/ريّة', _fmt(r.litersPerPlantPerIrrigation)))
          ..add(_Line.row(
              'زمن التشغيل لكل قطاع', '${_fmt(r.runtimeHoursPerSector)} ساعة'))
          ..add(_Line.row(
              'تصرف الشبكة كلها', '${_fmt(r.totalFlowM3h)} م³/ساعة'))
          ..add(_Line.row('تصرف القطاع',
              '${_fmt(r.sectorFlowM3h)} م³/ساعة (${_fmt(r.sectorFlowM3h / 3.6)} لتر/ث)'));
        if (r.sectorsOk) {
          lines.add(_Line.ok('القطاعات', 'تكفي (الحد الأقصى ${r.maxSectors})'));
        } else {
          lines.add(_Line.warn('القطاعات',
              'الوقت لا يكفي: أقصى عدد قطاعات ${r.maxSectors}، زوّد الساعات أو قلّل القطاعات'));
        }
        lines
          ..add(const _Line.section('الخطوط الفرعية'))
          ..add(_Line.row('تصرف الخط', '${_fmt(r.lateralFlowM3h, 3)} م³/ساعة'))
          ..add(_Line.row('تصرف آخر نقاط', '${_fmt(r.endEmitterFlowPct, 1)}%'));
        if (r.lateralOk) {
          lines.add(_Line.ok('فاقد الضغط في الخط',
              '${_fmt(r.lateralLossM)} م (المسموح ${_fmt(r.allowedLateralLossM)})'));
        } else {
          lines.add(_Line.warn('فاقد الضغط في الخط',
              '${_fmt(r.lateralLossM)} م أكبر من المسموح ${_fmt(r.allowedLateralLossM)} - قصّر الخط أو كبّر القطر'));
        }
        designFlow = r.sectorFlowM3h;
        lines
          ..add(const _Line.section('قائمة المواد'))
          ..add(_Line.row('إجمالي طول الخطوط الفرعية',
              '${_fmt(r.lateralTotalLengthM, 0)} م'))
          ..add(_Line.row('عدد النقاطات', _fmt(r.totalEmitters, 0)));
        bomCost = true;
        cost += r.lateralTotalLengthM * _v('p2') + r.totalEmitters * _v('p3');
        dxf = IrrigationDxf.drip(
          widthM: area / _v('latLen'),
          lengthM: _v('latLen'),
          rowSpacingM: _v('rowSp'),
          plantSpacingM: _v('plantSp'),
          emittersPerPlant: _v('emitters').round(),
        );
      }
      case IrrigationType.sprinkler: {
        final area = IrrigationCalc.areaToM2(_v('area'), _unit);
        final infil = NumberUtils.tryParseDouble(_ctrl('infil').text);
        final r = IrrigationCalc.sprinkler(
          areaM2: area,
          sprinklerM3h: _v('spr'),
          spacingAlongM: _v('sAlong'),
          spacingAcrossM: _v('sAcross'),
          etcMmDay: etc,
          efficiency: eff,
          intervalDays: interval,
          availableHours: _v('hours'),
          sectors: _v('sectors').round(),
          infiltrationMmH: infil,
        );
        if (r == null) {
          invalid = 'تأكد إن كل القيم أكبر من صفر والكفاءة بين 1 و100%';
          break;
        }
        _needLines(lines, r.need);
        lines
          ..add(const _Line.section('تصميم الرش'))
          ..add(_Line.row('معدل الإضافة', '${_fmt(r.applicationRateMmH)} مم/ساعة'))
          ..add(_Line.row('عدد الرشاشات', '${r.sprinklers}'))
          ..add(_Line.row(
              'زمن التشغيل لكل قطاع', '${_fmt(r.runtimeHoursPerSector)} ساعة'))
          ..add(_Line.row(
              'تصرف الشبكة كلها', '${_fmt(r.totalFlowM3h)} م³/ساعة'))
          ..add(_Line.row('تصرف القطاع',
              '${_fmt(r.sectorFlowM3h)} م³/ساعة (${_fmt(r.sectorFlowM3h / 3.6)} لتر/ث)'));
        if (r.sectorsOk) {
          lines.add(_Line.ok('القطاعات', 'تكفي (الحد الأقصى ${r.maxSectors})'));
        } else {
          lines.add(_Line.warn('القطاعات',
              'الوقت لا يكفي: أقصى عدد قطاعات ${r.maxSectors}'));
        }
        if (infil != null) {
          lines.add(r.infiltrationOk
              ? const _Line.ok('معدل الإضافة مقابل التسرب', 'مناسب')
              : const _Line.warn('معدل الإضافة مقابل التسرب',
                  'أعلى من معدل تسرب التربة - هيحصل جريان سطحي'));
        }
        designFlow = r.sectorFlowM3h;
        lines
          ..add(const _Line.section('قائمة المواد'))
          ..add(_Line.row('عدد الرشاشات', '${r.sprinklers}'));
        bomCost = true;
        cost += r.sprinklers * _v('p3');
        final dims = IrrigationDxf.fieldDims(area, _v('aspect'));
        dxf = IrrigationDxf.sprinkler(
          widthM: dims.width,
          lengthM: dims.length,
          spacingAlongM: _v('sAlong'),
          spacingAcrossM: _v('sAcross'),
        );
      }
      case IrrigationType.surface: {
        final area = IrrigationCalc.areaToM2(_v('area'), _unit);
        final r = IrrigationCalc.surface(
          areaM2: area,
          etcMmDay: etc,
          efficiency: eff,
          intervalDays: interval,
          streamLps: _v('stream'),
          availableHours: _v('hours'),
        );
        if (r == null) {
          invalid = 'تأكد إن كل القيم أكبر من صفر والكفاءة بين 1 و100%';
          break;
        }
        _needLines(lines, r.need);
        lines
          ..add(const _Line.section('الري السطحي'))
          ..add(_Line.row('تصرف المجرى', '${_fmt(r.flowM3h)} م³/ساعة'))
          ..add(_Line.row('زمن الري للمساحة', '${_fmt(r.irrigationHours)} ساعة'));
        lines.add(r.ok
            ? const _Line.ok('الوقت', 'يكفي في الساعات المتاحة')
            : const _Line.warn(
                'الوقت', 'أكبر من الساعات المتاحة - زوّد التصرف أو قسّم الحقل'));
        final dims = IrrigationDxf.fieldDims(area, _v('aspect'));
        dxf = IrrigationDxf.surface(
          widthM: dims.width,
          lengthM: dims.length,
          furrowSpacingM: _v('furrow'),
        );
      }
      case IrrigationType.pivot: {
        final r = IrrigationCalc.pivot(
          radiusM: _v('radius'),
          etcMmDay: etc,
          efficiency: eff,
          intervalDays: interval,
          hoursPerRotation: _v('rotation'),
        );
        if (r == null) {
          invalid = 'تأكد إن كل القيم أكبر من صفر والكفاءة بين 1 و100%';
          break;
        }
        _needLines(lines, r.need);
        lines
          ..add(const _Line.section('الري المحوري'))
          ..add(_Line.row('المساحة المغطاة',
              '${_fmt(r.areaM2 / IrrigationCalc.feddanM2)} فدان (${_fmt(r.areaM2, 0)} م²)'))
          ..add(_Line.row('تصرف البيفوت',
              '${_fmt(r.flowM3h)} م³/ساعة (${_fmt(r.flowLps)} لتر/ث)'))
          ..add(_Line.row(
              'سرعة آخر برج', '${_fmt(r.endTowerSpeedMh)} م/ساعة'));
        lines.add(r.fitsInterval
            ? const _Line.ok('الدورة', 'بتخلص قبل موعد الريّة اللي بعدها')
            : const _Line.warn(
                'الدورة', 'زمن الدورة أطول من الفترة بين الريات'));
        designFlow = r.flowM3h;
        dxf = IrrigationDxf.pivot(radiusM: _v('radius'));
      }
    }

    if (invalid != null) {
      _snack(invalid);
      return;
    }

    // الماسورة الرئيسية والمضخة
    if (_needsPump && designFlow != null) {
      final mainLen = _v('mainLen');
      final pipe = IrrigationCalc.pickDiameter(
          flowM3h: designFlow, lengthM: mainLen > 0 ? mainLen : 1);
      lines.add(const _Line.section('الماسورة الرئيسية'));
      if (pipe.ok) {
        lines.add(_Line.ok('القطر المقترح', '${_fmt(pipe.diameterMm, 0)} مم'));
      } else {
        lines.add(const _Line.warn('القطر المقترح',
            'التصرف أكبر من أكبر قطر تجاري - قسّم على أكتر من خط'));
      }
      lines
        ..add(_Line.row('السرعة', '${_fmt(pipe.velocityMs)} م/ث'))
        ..add(_Line.row('فاقد الاحتكاك', '${_fmt(pipe.lossM)} م'));
      if (bomCost) {
        lines.add(_Line.row('طول الماسورة الرئيسية', '${_fmt(mainLen, 0)} م'));
        cost += mainLen * _v('p1');
      }

      final pump = IrrigationCalc.pump(
        flowM3h: designFlow,
        staticLiftM: _v('lift'),
        operatingHeadM: _v('head'),
        frictionLossM: pipe.lossM,
        minorLossPct: _v('minor'),
        equipmentLossM: _v('equip'),
        pumpEfficiency: _v('pumpEff') / 100,
        motorEfficiency: _v('motorEff') / 100,
      );
      lines.add(const _Line.section('المضخة'));
      if (pump == null) {
        lines.add(const _Line.warn(
            'المضخة', 'تأكد من الكفاءات (1 إلى 100%) وإن الفواقد مش سالبة'));
      } else {
        lines
          ..add(_Line.row('الضغط الكلي المطلوب', '${_fmt(pump.totalHeadM)} م'))
          ..add(_Line.row('التصرف', '${_fmt(designFlow)} م³/ساعة'))
          ..add(_Line.row('القدرة الهيدروليكية', '${_fmt(pump.hydraulicKw)} كيلوواط'))
          ..add(_Line.row('قدرة عمود المضخة', '${_fmt(pump.shaftKw)} كيلوواط'))
          ..add(_Line.ok('المحرك المقترح (مع هامش 15%)',
              '${_fmt(pump.recommendedMotorKw)} كيلوواط ≈ ${_fmt(pump.recommendedMotorHp, 1)} حصان'));
      }
    }

    if (bomCost && cost > 0) {
      lines
        ..add(const _Line.section('التكلفة التقديرية'))
        ..add(_Line.ok('الإجمالي (مواسير ونقاطات/رشاشات)', '${_fmt(cost, 0)} جنيه'));
    }

    setState(() {
      _results = lines;
      _dxf = dxf;
    });
  }

  void _needLines(List<_Line> lines, WaterNeed n) {
    lines
      ..add(const _Line.section('احتياج المياه'))
      ..add(_Line.row('الاحتياج الإجمالي اليومي',
          '${_fmt(n.grossDailyMm)} مم/يوم (${_fmt(n.dailyVolumeM3)} م³/يوم)'))
      ..add(_Line.row('عمق الريّة الواحدة', '${_fmt(n.grossPerIrrigationMm)} مم'))
      ..add(_Line.row(
          'حجم الريّة الواحدة', '${_fmt(n.perIrrigationVolumeM3)} م³'));
  }

  // ───────────────────── التصدير ─────────────────────
  Future<void> _exportDxf() async {
    final dxf = _dxf;
    if (dxf == null) return;

    setState(() => _isExporting = true);

    // عرض رسالة تحميل
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20, 
              height: 20, 
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            ),
            SizedBox(width: 16),
            Text('جاري إنشاء الملف...'),
          ],
        ),
        duration: Duration(seconds: 5),
      ),
    );

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/irrigation_layout.dxf');
      await file.writeAsString(dxf);
      
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        subject: 'مخطط الري (DXF) - تطبيق نباتي',
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (mounted) _snack('تعذر إنشاء الملف');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ───────────────────── الواجهة ─────────────────────
  InputDecoration _dec(String label, {String? suffix}) => InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _field(String key, {String? suffix, String? label}) => TextField(
        controller: _ctrl(key),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.next, // يظهر زر Next في الكيبورد
        decoration: _dec(label ?? _labels[key] ?? key, suffix: suffix),
      );

  Widget _gap() => const SizedBox(height: 12);

  Widget _two(Widget a, Widget b) => Row(
        children: [
          Expanded(child: a),
          const SizedBox(width: 10),
          Expanded(child: b),
        ],
      );

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Text(t,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      );

  Widget _typeChips() {
    const names = {
      IrrigationType.drip: 'تنقيط',
      IrrigationType.sprinkler: 'رش',
      IrrigationType.surface: 'سطحي',
      IrrigationType.pivot: 'محوري',
    };
    return Wrap(
      spacing: 8,
      children: [
        for (final t in IrrigationType.values)
          ChoiceChip(
            label: Text(names[t]!),
            selected: _type == t,
            selectedColor: _blue.withValues(alpha: 0.2),
            onSelected: (_) => _selectType(t),
          ),
      ],
    );
  }

  Widget _areaRow() => _two(
        _field('area'),
        DropdownButtonFormField<AreaUnit>(
          initialValue: _unit,
          decoration: _dec('الوحدة'),
          items: const [
            DropdownMenuItem(value: AreaUnit.feddan, child: Text('فدان')),
            DropdownMenuItem(value: AreaUnit.hectare, child: Text('هكتار')),
            DropdownMenuItem(
                value: AreaUnit.squareMeter, child: Text('متر مربع')),
          ],
          onChanged: (v) => setState(() => _unit = v ?? AreaUnit.feddan),
        ),
      );

  List<Widget> _typeInputs() {
    switch (_type) {
      case IrrigationType.drip: {
        return [
          _title('بيانات التنقيط'),
          _two(_field('rowSp', suffix: 'م'), _field('plantSp', suffix: 'م')),
          _gap(),
          _two(_field('emitters'), _field('emitterLph', suffix: 'لتر/س')),
          _gap(),
          _two(_field('latLen', suffix: 'م'),
              DropdownButtonFormField<double>(
                initialValue: _lateralDia,
                decoration: _dec('قطر الخط الفرعي (مم)'),
                items: const [12.0, 16.0, 20.0, 25.0]
                    .map((d) => DropdownMenuItem(
                        value: d, child: Text(_fmt(d, 0))))
                    .toList(),
                onChanged: (v) => setState(() => _lateralDia = v ?? 16),
              )),
          _gap(),
          _two(_field('sectors'), _field('head', suffix: 'م')),
        ];
      }
      case IrrigationType.sprinkler: {
        return [
          _title('بيانات الرش'),
          _two(_field('spr', suffix: 'م³/س'), _field('head', suffix: 'م')),
          _gap(),
          _two(_field('sAlong', suffix: 'م'), _field('sAcross', suffix: 'م')),
          _gap(),
          _two(
            _field('sectors'),
            _field('infil',
                suffix: 'مم/س', label: 'تسرب التربة (اختياري)'),
          ),
          _gap(),
          _field('aspect'),
        ];
      }
      case IrrigationType.surface: {
        return [
          _title('بيانات الري السطحي'),
          _two(_field('stream', suffix: 'لتر/ث'),
              _field('furrow', suffix: 'م')),
          _gap(),
          _field('aspect'),
        ];
      }
      case IrrigationType.pivot: {
        return [
          _title('بيانات البيفوت'),
          _two(_field('radius', suffix: 'م'),
              _field('rotation', suffix: 'ساعة')),
          _gap(),
          _field('head', suffix: 'م', label: 'ضغط تشغيل البيفوت'),
        ];
      }
    }
  }

  Widget _resultCard() {
    return Card(
      margin: const EdgeInsets.only(top: 20),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in _results) _lineWidget(l),
            if (_dxf != null) ...[
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _isExporting ? null : _exportDxf,
                icon: _isExporting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.download),
                label: Text(_isExporting ? 'جاري التصدير...' : 'تصدير مخطط DXF (لـ RainCAD / AutoCAD)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'المخطط تخطيطي بسيط (حدود الحقل والخطوط والرشاشات) بالمتر، '
                'وبيتفتح في أي برنامج CAD. الحسابات استرشادية ولازم مراجعة '
                'مهندس ري قبل التنفيذ.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _lineWidget(_Line l) {
    if (l.kind == 3) {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(l.label,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: _blue, fontSize: 15)),
      );
    }
    final color = l.kind == 1
        ? Colors.green.shade700
        : l.kind == 2
            ? Colors.red.shade700
            : null;
    final icon = l.kind == 1
        ? Icons.check_circle
        : l.kind == 2
            ? Icons.warning_amber
            : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
          ],
          Expanded(flex: 4, child: Text(l.label)),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(l.value,
                style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حاسبة تصميم شبكات الري',
            style: TextStyle(color: Colors.white)),
        backgroundColor: _blue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _typeChips(),
            _title('المحصول والمساحة'),
            if (_type == IrrigationType.pivot)
              const Text('مساحة البيفوت بتتحسب من نصف القطر.',
                  style: TextStyle(color: Colors.grey))
            else
              _areaRow(),
            _gap(),
            _two(_field('eto', suffix: 'مم/يوم'), _field('kc')),
            _gap(),
            _two(_field('eff', suffix: '%'), _field('interval', suffix: 'يوم')),
            if (_type != IrrigationType.pivot) ...[
              _gap(),
              _field('hours', suffix: 'ساعة'),
            ],
            ..._typeInputs(),
            if (_needsPump) ...[
              _title('الماسورة الرئيسية والمضخة'),
              _two(_field('mainLen', suffix: 'م'), _field('lift', suffix: 'م')),
              _gap(),
              _two(_field('equip', suffix: 'م'), _field('minor', suffix: '%')),
              _gap(),
              _two(_field('pumpEff', suffix: '%'),
                  _field('motorEff', suffix: '%')),
            ],
            if (_type == IrrigationType.drip ||
                _type == IrrigationType.sprinkler) ...[
              _title('الأسعار (اختياري لحساب التكلفة)'),
              _field('p1', suffix: 'جنيه', label: 'سعر متر الماسورة الرئيسية'),
              _gap(),
              if (_type == IrrigationType.drip) ...[
                _field('p2', suffix: 'جنيه', label: 'سعر متر الخط الفرعي'),
                _gap(),
              ],
              _field('p3',
                  suffix: 'جنيه',
                  label: _type == IrrigationType.drip
                      ? 'سعر النقاط'
                      : 'سعر الرشاش'),
            ],
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _calculate,
              icon: const Icon(Icons.calculate),
              label: const Text('احسب', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_results.isNotEmpty) _resultCard(),
            const SizedBox(height: 100), // مسافة عشان الزر يبان فوق الكيبورد
          ],
        ),
      ),
    );
  }
}
