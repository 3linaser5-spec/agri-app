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

  Future<void> _importJson() async {
    final jsonText = _jsonCtrl.text.trim();
    if (jsonText.isEmpty) {
      setState(() {
        _resultMessage = '❌ الرجاء لصق كود JSON';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _resultMessage = null;
    });

    try {
      final dynamic parsed = json.decode(jsonText);
      final List<dynamic> templates = parsed is List ? parsed : [parsed];

      if (templates.isEmpty) {
        _finish(false, '❌ الملف فاضي: مفيش قوالب للاستيراد');
        return;
      }

      // 1) نتحقق من كل القوالب الأول. لو أي واحد غلط ما نحفظش حاجة
      //    (قبل كده كان بيحفظ جزء ويسيب الباقي، وإعادة الاستيراد تكرّر المحفوظ).
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

      // 2) كتابة بـ WriteBatch: كل دفعة (حتى 400 قالب) تنجح أو تفشل كلها
      //    (حد Firestore 500 عملية للدفعة الواحدة).
      final col =
          FirebaseFirestore.instance.collection('calculator_templates');
      const chunkSize = 400;
      int saved = 0;
      for (var i = 0; i < valid.length; i += chunkSize) {
        final batch = FirebaseFirestore.instance.batch();
        final chunk = valid.skip(i).take(chunkSize);
        for (final data in chunk) {
          data['section_id'] = widget.section.id;
          data['fields'] ??= [];
          data['tasks'] ??= [];
          data['materials'] ??= [];
          data['financial'] ??= {};
          data['created_at'] = FieldValue.serverTimestamp();
          batch.set(col.doc(), data);
        }
        await batch.commit();
        saved += chunk.length;
      }

      _finish(true, '✅ تم استيراد $saved قالب بنجاح');
    } on FormatException catch (e) {
      _finish(false, '❌ خطأ في صيغة JSON:\n${e.message}');
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
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.blue.shade700, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'الصق كود JSON للقالب (أو عدة قوالب في مصفوفة [ ])\nسيتم ربط القالب تلقائياً بقسم: ${widget.section.name}',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _jsonCtrl,
              maxLines: 15,
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 12, height: 1.4),
              decoration: InputDecoration(
                hintText: '{\n  "name": "قمح",\n  "emoji": "🌾",\n  ...\n}',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 16),

            if (_resultMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isSuccess
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isSuccess
                        ? Colors.green.shade200
                        : Colors.red.shade200,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _isSuccess ? Icons.check_circle : Icons.error_outline,
                      color: _isSuccess ? Colors.green : Colors.red,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _resultMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _isSuccess
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

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

            Card(
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
                          color: Colors.grey.shade700),
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
