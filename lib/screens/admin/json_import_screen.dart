import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/calculator_models.dart';
import '../../utils/template_validator.dart';

class JsonImportScreen extends StatefulWidget {
  final CalculatorSection section;
  const JsonImportScreen({super.key, required this.section});

  @override
  State<JsonImportScreen> createState() => _JsonImportScreenState();
}

class _JsonImportScreenState extends State<JsonImportScreen> {
  final _jsonCtrl = TextEditingController();
  bool _loading = false;
  String? _resultMessage;
  bool _isSuccess = false;

  @override
  void dispose() {
    _jsonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (!mounted) return;
    if (data != null && data.text != null) {
      setState(() {
        _jsonCtrl.text = data.text!;
      });
    }
  }

  /// ✅ تطبيع JSON: تحويل علامات التنصيص الغريبة للعلامات العادية
  String _normalizeJson(String input) {
    return input
        .replaceAll('"', '"')
        .replaceAll('"', '"')
        .replaceAll(''', "'")
        .replaceAll(''', "'")
        .replaceAll('ʼ', "'");
  }

  Future<void> _importJson() async {
    final jsonText = _jsonCtrl.text.trim();
    if (jsonText.isEmpty) {
      setState(() {
        _resultMessage = '❌ الرجاء لصق كود JSON';
        _isSuccess = false;
      });
      return;
    }

    // ✅ تطبيع النص
    final normalizedText = _normalizeJson(jsonText);

    setState(() {
      _loading = true;
      _resultMessage = null;
    });

    try {
      final dynamic parsed = json.decode(normalizedText);
      final List<dynamic> templates = parsed is List ? parsed : [parsed];

      if (templates.isEmpty) {
        _finish(false, '❌ الملف فاضي: مفيش قوالب للاستيراد');
        return;
      }

      // 1) نتحقق من كل القوالب الأول
      final List<Map<String, dynamic>> valid = [];
      final List<String> errors = [];
      for (var i = 0; i < templates.length; i++) {
        final item = templates[i];
        if (item is! Map) {
          errors.add('قالب ${i + 1}: العنصر ليس Object');
          continue;
        }
        final data = Map<String, dynamic>.from(item);
        final label = data['name'] is String && (data['name'] as String).isNotEmpty
            ? '"${data['name']}"'
            : 'قالب ${i + 1}';
        final problems = TemplateValidator.validate(data, label: label);
        if (problems.isNotEmpty) {
          errors.addAll(problems);
        } else {
          valid.add(data);
        }
      }

      if (errors.isNotEmpty) {
        final shown = errors.take(8).join('\n');
        final more = errors.length > 8 ? '\n... و${errors.length - 8} خطأ آخر' : '';
        _finish(
          false,
          '❌ لم يتم حفظ أي قالب (${errors.length} خطأ)\n'
          'صحّح الأخطاء وأعد المحاولة:\n\n$shown$more',
        );
        return;
      }

      // ✅ تحذير قبل الاستيراد لو القوالب كتير
      if (valid.length > 5) {
        if (!mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : null,
              title: const Text('تأكيد الاستيراد'),
              content: Text('هيتم استيراد ${valid.length} قالب. هل أنت متأكد؟'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('استيراد'),
                ),
              ],
            );
          },
        );
        
        if (confirm != true) {
          if (mounted) setState(() => _loading = false);
          return;
        }
      }

      // 2) كتابة ذرية بـ WriteBatch
      const maxTemplates = 400;
      if (valid.length > maxTemplates) {
        _finish(
          false,
          '❌ الحد الأقصى $maxTemplates قالب في الاستيراد الواحد '
          '(الملف فيه ${valid.length}). قسّمه على أكثر من ملف.',
        );
        return;
      }

      final col =
          FirebaseFirestore.instance.collection('calculator_templates');
      final batch = FirebaseFirestore.instance.batch();
      for (final data in valid) {
        data['section_id'] = widget.section.id;
        data['fields'] ??= [];
        data['tasks'] ??= [];
        data['materials'] ??= [];
        data['financial'] ??= {};
        data['created_at'] = FieldValue.serverTimestamp();
        batch.set(col.doc(), data);
      }
      
      await batch.commit().timeout(const Duration(seconds: 25));

      _finish(true, '✅ تم استيراد ${valid.length} قالب بنجاح');
    } on FormatException catch (e) {
      _finish(false, '❌ خطأ في صيغة JSON:\n${e.message}');
    } on TimeoutException {
      _finish(
          false,
          '⏱️ انتهت مهلة الحفظ، تأكد من الاتصال.\n'
          'لو الاتصال رجع ممكن الاستيراد يكتمل لوحده، فراجع قائمة القوالب قبل إعادة المحاولة.');
    } catch (e) {
      debugPrint('❌ خطأ في الاستيراد: $e');
      _finish(false, '❌ تعذر الحفظ، تأكد من الاتصال وحاول مرة أخرى:\n$e');
    }
  }

  void _finish(bool success, String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _isSuccess = success;
      _resultMessage = message;
    });
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF047857),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('استيراد JSON - ${widget.section.name}',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF047857),
        actions: [
          IconButton(
            icon: const Icon(Icons.paste, color: Colors.white),
            tooltip: 'لصق من الحافظة',
            onPressed: _pasteFromClipboard,
          ),
          IconButton(
            icon: const Icon(Icons.clear, color: Colors.white),
            tooltip: 'مسح',
            onPressed: () => setState(() {
              _jsonCtrl.clear();
              _resultMessage = null;
            }),
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ✅ تعليمات
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                // ✅ دعم الوضع الليلي
                color: isDark 
                    ? Colors.blue.shade900.withValues(alpha: 0.3) 
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: isDark ? Colors.blue.shade300 : Colors.blue.shade700, 
                      size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'الصق كود JSON للقالب (أو عدة قوالب في مصفوفة [ ])\nسيتم ربط القالب تلقائياً بقسم: ${widget.section.name}',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ✅ حقل JSON
            TextField(
              controller: _jsonCtrl,
              maxLines: 15,
              style: TextStyle(
                  fontFamily: 'monospace', 
                  fontSize: 12, 
                  height: 1.4,
                  color: isDark ? Colors.white : null),
              decoration: InputDecoration(
                hintText: '{\n  "name": "قمح",\n  "emoji": "🌾",\n  ...\n}',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                // ✅ دعم الوضع الليلي
                fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 16),

            // ✅ رسالة النتيجة
            if (_resultMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  // ✅ دعم الوضع الليلي
                  color: _isSuccess
                      ? (isDark 
                          ? Colors.green.shade900.withValues(alpha: 0.3) 
                          : Colors.green.shade50)
                      : (isDark 
                          ? Colors.red.shade900.withValues(alpha: 0.3) 
                          : Colors.red.shade50),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isSuccess
                        ? (isDark ? Colors.green.shade700 : Colors.green.shade200)
                        : (isDark ? Colors.red.shade700 : Colors.red.shade200),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _isSuccess ? Icons.check_circle : Icons.error_outline,
                      color: _isSuccess 
                          ? (isDark ? Colors.green.shade300 : Colors.green) 
                          : (isDark ? Colors.red.shade300 : Colors.red),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _resultMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _isSuccess
                              ? (isDark ? Colors.green.shade200 : Colors.green.shade800)
                              : (isDark ? Colors.red.shade200 : Colors.red.shade800),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ✅ زر الاستيراد
            ElevatedButton.icon(
              onPressed: _loading ? null : _importJson,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(
                _loading ? 'جاري الاستيراد...' : 'استيراد القالب',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(55),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 24),

            // ✅ ملاحظات
            Card(
              color: isDark ? const Color(0xFF1E1E1E) : null, // ✅ دعم الوضع الليلي
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.help_outline,
                            color: Color(0xFF047857), size: 20),
                        SizedBox(width: 8),
                        Text('ملاحظات مهمة',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '• لازم يكون JSON صحيح (استخدم jsonlint.com للتحقق)\n'
                      '• الحقول الأساسية: name, emoji, description\n'
                      '• يدعم استيراد قالب واحد أو عدة قوالب [ ]\n'
                      '• section_id بيتضاف تلقائياً (مش محتاج تكتبه)\n'
                      '• لو حصل خطأ، هتلاقي التفاصيل فوق',
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.8,
                          color: isDark ? Colors.grey[400] : Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
