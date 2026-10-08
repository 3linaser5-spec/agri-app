import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/calculator_models.dart';

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

      int successCount = 0;
      int failCount = 0;
      final List<String> errors = [];

      for (var templateData in templates) {
        if (templateData is! Map<String, dynamic>) {
          failCount++;
          errors.add('عنصر ليس Object صحيح');
          continue;
        }

        try {
          // ✅ إضافة section_id تلقائياً
          templateData['section_id'] = widget.section.id;

          final name = templateData['name']?.toString();
          if (name == null || name.trim().isEmpty) {
            failCount++;
            errors.add('قالب بدون اسم');
            continue;
          }

          final id = await _saveTemplate(templateData);
          if (id != null) {
            successCount++;
          } else {
            failCount++;
            errors.add('فشل حفظ "$name"');
          }
        } catch (e) {
          failCount++;
          errors.add('خطأ في قالب: $e');
        }
      }

      if (mounted) {
        setState(() {
          _loading = false;
          _isSuccess = failCount == 0 && successCount > 0;
          _resultMessage =
              '✅ نجح: $successCount قالب\n❌ فشل: $failCount قالب'
              '${errors.isNotEmpty ? "\n\nالتفاصيل:\n${errors.take(5).join("\n")}" : ""}';
        });

        if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ تم استيراد $successCount قالب بنجاح'),
              backgroundColor: const Color(0xFF047857),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _isSuccess = false;
          _resultMessage = '❌ خطأ في صيغة JSON:\n$e';
        });
      }
    }
  }

  Future<String?> _saveTemplate(Map<String, dynamic> data) async {
    try {
      final ref = FirebaseFirestore.instance
          .collection('ai_queries')
          .doc('5vZIZWBYDYNRhOL6PwGc')
          .collection('calculator_templates');

      data['fields'] ??= [];
      data['tasks'] ??= [];
      data['materials'] ??= [];
      data['financial'] ??= {};
      data['created_at'] = FieldValue.serverTimestamp();

      final docRef = await ref.add(data);
      return docRef.id;
    } catch (e) {
      print('❌ خطأ في الحفظ: $e');
      return null;
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
