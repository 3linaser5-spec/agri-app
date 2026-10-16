/// مقيّم معادلات حسابية صغير وآمن لقوالب الحاسبات.
///
/// يسمح بـ: الأرقام، المتغيرات (أسماء حقول القالب مثل area و seed_rate)،
/// + - * / ، الأقواس، وعلامة السالب، والدوال min / max / round / ceil /
/// floor / abs.  مفيش أي تنفيذ كود: النص بيتحوّل لشجرة حسابية ويتحسب.
///
/// أمثلة:
///   area * 50
///   area * seed_rate / 1000
///   ceil(area * 2.5)
///   max(area, 1) * 12
///
/// أي خطأ (صيغة غلط، متغير غير معروف، قسمة على صفر) بيرجّع null من
/// [evaluate] وبيرجّع رسالة عربية من [validate]، ومش بيرمي استثناء للمستخدم.
class FormulaEvaluator {
  static const int maxLength = 200;
  static const int _maxDepth = 24;

  /// يحسب المعادلة. يرجّع null لو غير صالحة أو فيها متغير غير موجود في [vars]
  /// أو النتيجة مش رقم محدود.
  static double? evaluate(String formula, Map<String, double> vars) {
    try {
      final node = _Parser(formula).parse();
      final v = node.eval(vars);
      return v.isFinite ? v : null;
    } on FormulaException {
      return null;
    }
  }

  /// يتحقق من الصيغة. يرجّع رسالة خطأ بالعربي أو null لو سليمة.
  /// [knownVars] = أسماء المتغيرات المسموح بها (ids الحقول + area).
  static String? validate(String formula, Set<String> knownVars) {
    if (formula.trim().isEmpty) return null;
    try {
      final node = _Parser(formula).parse();
      final used = <String>{};
      node.collect(used);
      final unknown = used.where((v) => !knownVars.contains(v)).toList();
      if (unknown.isNotEmpty) {
        return 'متغير غير معروف: ${unknown.join('، ')} '
            '(المتاح: ${(knownVars.toList()..sort()).join('، ')})';
      }
      // تجربة حساب بعدة مجموعات قيم: لو نجحت أي مجموعة تبقى المعادلة سليمة.
      // قيمة واحدة ثابتة كانت بترفض معادلات سليمة زي x/(y-1) لأن (y-1) بتطلع
      // صفر. المعادلة اللي بتفشل مع كل المجموعات (مثل 5/0) هي اللي بنرفضها.
      final names = knownVars.toList()..sort();
      const bases = [1.0, 2.0, 3.5, 10.0];
      const steps = [0.0, 1.0, 1.5, 7.0];
      String? firstError;
      for (var k = 0; k < bases.length; k++) {
        final probe = <String, double>{
          for (var i = 0; i < names.length; i++) names[i]: bases[k] + i * steps[k],
        };
        try {
          if (node.eval(probe).isFinite) return null;
          firstError ??= 'نتيجة المعادلة غير صالحة';
        } on FormulaException catch (e) {
          firstError ??= e.message;
        }
      }
      return firstError ?? 'نتيجة المعادلة غير صالحة';
    } on FormulaException catch (e) {
      return e.message;
    }
  }
}

class FormulaException implements Exception {
  final String message;
  FormulaException(this.message);
  @override
  String toString() => message;
}

// ───────────────────────── شجرة الحساب ─────────────────────────

abstract class _Node {
  double eval(Map<String, double> vars);
  void collect(Set<String> out);
}

class _Num extends _Node {
  final double value;
  _Num(this.value);
  @override
  double eval(Map<String, double> vars) => value;
  @override
  void collect(Set<String> out) {}
}

class _Var extends _Node {
  final String name;
  _Var(this.name);
  @override
  double eval(Map<String, double> vars) {
    final v = vars[name];
    if (v == null) throw FormulaException('متغير غير معروف: $name');
    return v;
  }

  @override
  void collect(Set<String> out) => out.add(name);
}

class _Neg extends _Node {
  final _Node child;
  _Neg(this.child);
  @override
  double eval(Map<String, double> vars) => -child.eval(vars);
  @override
  void collect(Set<String> out) => child.collect(out);
}

class _Bin extends _Node {
  final String op;
  final _Node left;
  final _Node right;
  _Bin(this.op, this.left, this.right);

  @override
  double eval(Map<String, double> vars) {
    final a = left.eval(vars);
    final b = right.eval(vars);
    switch (op) {
      case '+':
        return a + b;
      case '-':
        return a - b;
      case '*':
        return a * b;
      case '/':
        if (b == 0) throw FormulaException('قسمة على صفر');
        return a / b;
    }
    throw FormulaException('عملية غير معروفة');
  }

  @override
  void collect(Set<String> out) {
    left.collect(out);
    right.collect(out);
  }
}

class _Call extends _Node {
  final String name;
  final List<_Node> args;
  _Call(this.name, this.args);

  static const _arity = {
    'min': 2,
    'max': 2,
    'round': 1,
    'ceil': 1,
    'floor': 1,
    'abs': 1,
  };

  static bool isKnown(String n) => _arity.containsKey(n);
  static int arityOf(String n) => _arity[n]!;

  @override
  double eval(Map<String, double> vars) {
    final v = args.map((a) => a.eval(vars)).toList();
    switch (name) {
      case 'min':
        return v[0] < v[1] ? v[0] : v[1];
      case 'max':
        return v[0] > v[1] ? v[0] : v[1];
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

// ───────────────────────── المحلّل ─────────────────────────

class _Parser {
  final String src;
  int _pos = 0;
  int _depth = 0;

  _Parser(String raw) : src = _normalize(raw) {
    if (raw.length > FormulaEvaluator.maxLength) {
      throw FormulaException(
          'المعادلة طويلة (الحد ${FormulaEvaluator.maxLength} حرف)');
    }
  }

  // الأرقام العربية والفاصلة العشرية العربية -> إنجليزي (الفاصلة "," تفضل كما هي
  // لأنها فاصل وسائط الدوال)
  static String _normalize(String s) {
    const ar = '٠١٢٣٤٥٦٧٨٩';
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final a = ar.indexOf(ch);
      final f = fa.indexOf(ch);
      if (a != -1) {
        b.write(a);
      } else if (f != -1) {
        b.write(f);
      } else if (ch == '٫') {
        b.write('.');
      } else if (ch == '×') {
        b.write('*');
      } else if (ch == '÷') {
        b.write('/');
      } else {
        b.write(ch);
      }
    }
    return b.toString();
  }

  _Node parse() {
    if (src.trim().isEmpty) throw FormulaException('المعادلة فاضية');
    final node = _expr();
    _skipSpaces();
    if (_pos < src.length) {
      throw FormulaException('رمز غير متوقع "${src[_pos]}"');
    }
    return node;
  }

  void _skipSpaces() {
    while (_pos < src.length && src[_pos].trim().isEmpty) {
      _pos++;
    }
  }

  bool _eat(String ch) {
    _skipSpaces();
    if (_pos < src.length && src[_pos] == ch) {
      _pos++;
      return true;
    }
    return false;
  }

  _Node _expr() {
    _enter();
    var left = _term();
    while (true) {
      if (_eat('+')) {
        left = _Bin('+', left, _term());
      } else if (_eat('-')) {
        left = _Bin('-', left, _term());
      } else {
        break;
      }
    }
    _depth--;
    return left;
  }

  _Node _term() {
    var left = _unary();
    while (true) {
      if (_eat('*')) {
        left = _Bin('*', left, _unary());
      } else if (_eat('/')) {
        left = _Bin('/', left, _unary());
      } else {
        break;
      }
    }
    return left;
  }

  _Node _unary() {
    if (_eat('-')) return _Neg(_unary());
    if (_eat('+')) return _unary();
    return _primary();
  }

  _Node _primary() {
    _skipSpaces();
    if (_pos >= src.length) throw FormulaException('المعادلة ناقصة');

    final ch = src[_pos];

    if (ch == '(') {
      _pos++;
      final inner = _expr();
      if (!_eat(')')) throw FormulaException('قوس ")" ناقص');
      return inner;
    }

    if (_isDigit(ch) || ch == '.') return _number();

    if (_isIdentStart(ch)) {
      final start = _pos;
      while (_pos < src.length && _isIdentPart(src[_pos])) {
        _pos++;
      }
      final name = src.substring(start, _pos);
      _skipSpaces();
      if (_pos < src.length && src[_pos] == '(') {
        return _call(name);
      }
      return _Var(name);
    }

    throw FormulaException('رمز غير متوقع "$ch"');
  }

  _Node _call(String name) {
    if (!_Call.isKnown(name)) {
      throw FormulaException('دالة غير معروفة: $name');
    }
    _pos++; // (
    final args = <_Node>[];
    if (!_eat(')')) {
      args.add(_expr());
      while (_eat(',')) {
        args.add(_expr());
      }
      if (!_eat(')')) throw FormulaException('قوس ")" ناقص');
    }
    if (args.length != _Call.arityOf(name)) {
      throw FormulaException(
          'الدالة $name تحتاج ${_Call.arityOf(name)} قيمة');
    }
    return _Call(name, args);
  }

  _Node _number() {
    final start = _pos;
    var dots = 0;
    while (_pos < src.length && (_isDigit(src[_pos]) || src[_pos] == '.')) {
      if (src[_pos] == '.') dots++;
      _pos++;
    }
    final text = src.substring(start, _pos);
    final v = dots > 1 ? null : double.tryParse(text);
    if (v == null) throw FormulaException('رقم غير صالح "$text"');
    return _Num(v);
  }

  void _enter() {
    if (++_depth > FormulaEvaluator._maxDepth) {
      throw FormulaException('المعادلة معقدة أكثر من اللازم');
    }
  }

  static bool _isDigit(String c) =>
      c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  static bool _isIdentStart(String c) {
    final u = c.codeUnitAt(0);
    return (u >= 65 && u <= 90) || (u >= 97 && u <= 122) || u == 95;
  }

  static bool _isIdentPart(String c) => _isIdentStart(c) || _isDigit(c);
}
