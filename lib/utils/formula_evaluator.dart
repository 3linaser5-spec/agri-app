class _Call extends _Node {
  final String name;
  final List<_Node> args;
  _Call(this.name, this.args);

  static const _arity = {
    'min': -1, // -1 تعني عدد لا نهائي (أو على الأقل 1)
    'max': -1,
    'round': 1,
    'ceil': 1,
    'floor': 1,
    'abs': 1,
  };

  static bool isKnown(String n) => _arity.containsKey(n);
  static int arityOf(String n) => _arity[n]!;

  @override
  double eval(Map<String, double> vars) {
    // الحماية موجودة بس في حالة إن الشجرة اتبنت غلط (Defensive)
    if (!isKnown(name)) {
      throw FormulaException('دالة غير معروفة: $name');
    }

    // لو الـ _Parser مسبقاً تحقق، السطر ده مش هيترمي فيه أخطاء أبداً
    final expectedArity = arityOf(name);
    if (expectedArity != -1 && args.length != expectedArity) {
      throw FormulaException('الدالة "$name" تتطلب $expectedArity وسيط بالضبط، وتم إرسال ${args.length}');
    }

    final v = args.map((a) => a.eval(vars)).toList();
    
    switch (name) {
      case 'min':
        if (v.isEmpty) throw FormulaException('الدالة "min" تحتاج إلى قيمة واحدة على الأقل');
        return v.reduce((a, b) => a < b ? a : b);
        
      case 'max':
        if (v.isEmpty) throw FormulaException('الدالة "max" تحتاج إلى قيمة واحدة على الأقل');
        return v.reduce((a, b) => a > b ? a : b);
        
      case 'round':
        return v[0].roundToDouble();
        
      case 'ceil':
        return v[0].ceilToDouble();
        
      case 'floor':
        return v[0].floorToDouble();
        
      case 'abs':
        return v[0].abs();
    }
    
    throw FormulaException('دالة غير معروفة: $name');
  }

  @override
  void collect(Set<String> out) {
    for (final a in args) {
      a.collect(out);
    }
  }
}
