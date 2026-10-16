import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/encyclopedia_service.dart';

class EncyclopediaImportScreen extends StatefulWidget {
  const EncyclopediaImportScreen({super.key});

  @override
  State<EncyclopediaImportScreen> createState() =>
      _EncyclopediaImportScreenState();
}

class _EncyclopediaImportScreenState
    extends State<EncyclopediaImportScreen> {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم لصق النص'),
          backgroundColor: Color(0xFF047857),
        ),
      );
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

    int successSections = 0;
    int successItems = 0;
    int failSections = 0;
    int failItems = 0;
    final List<String> errors = [];

    try {
      final dynamic parsed = json.decode(jsonText);

      // ✅ دعم صيغتين:
      // 1. object فيه sections
      // 2. array من الأقسام مباشرة
      List<dynamic> sectionsList;
      if (parsed is Map<String, dynamic> && parsed['sections'] is List) {
        sectionsList = parsed['sections'] as List;
      } else if (parsed is List) {
        sectionsList = parsed;
      } else {
        throw Exception(
            'الصيغة غير صحيحة. المتوقع: object فيه sections أو array');
      }

      for (var sectionData in sectionsList) {
        if (sectionData is! Map<String, dynamic>) {
          failSections++;
          errors.add('قسم ليس Object صحيح');
          continue;
        }

        try {
          final name = sectionData['name']?.toString();
          if (name == null || name.trim().isEmpty) {
            failSections++;
            errors.add('قسم بدون اسم');
            continue;
          }

          // ✅ إضافة القسم
          final sectionId = await EncyclopediaService.addSection(
            name: name.trim(),
            emoji: sectionData['emoji']?.toString() ?? '📚',
            color: sectionData['color']?.toString() ?? '#047857',
            description: sectionData['description']?.toString() ?? '',
          );

          if (sectionId == null) {
            failSections++;
            errors.add('فشل حفظ قسم "$name"');
            continue;
          }

          successSections++;

          // ✅ إضافة العناصر لو موجودة
          final items = sectionData['items'];
          if (items is List) {
            for (var itemData in items) {
              if (itemData is! Map<String, dynamic>) {
                failItems++;
                continue;
              }

              try {
                final title = itemData['title']?.toString();
                if (title == null || title.trim().isEmpty) {
                  failItems++;
                  errors.add('عنصر بدون عنوان في "$name"');
                  continue;
                }

                // ✅ معالجة الـ sections الداخلية
                List<Map<String, String>> innerSections = [];
                final rawSections = itemData['sections'];
                if (rawSections is List) {
                  for (var s in rawSections) {
                    if (s is Map) {
                      innerSections.add({
                        'title': s['title']?.toString() ?? '',
                        'content': s['content']?.toString() ?? '',
                      });
                    }
                  }
                }

                final itemId = await EncyclopediaService.addItem(
                  sectionId: sectionId,
                  title: title.trim(),
                  subtitle: itemData['subtitle']?.toString() ?? '',
                  icon: itemData['icon']?.toString() ?? 'eco',
                  content: itemData['content']?.toString() ?? '',
                  sections: innerSections,
                  imageUrl: itemData['image_url']?.toString(),
                );

                if (itemId != null) {
                  successItems++;
                } else {
                  failItems++;
                  errors.add('فشل حفظ عنصر "$title"');
                }
              } catch (e) {
                failItems++;
                errors.add('خطأ في عنصر: $e');
              }
            }
          }
        } catch (e) {
          failSections++;
          errors.add('خطأ في قسم: $e');
        }
      }

      if (mounted) {
        setState(() {
          _loading = false;
          _isSuccess = failSections == 0 && failItems == 0 &&
              (successSections > 0 || successItems > 0);
          _resultMessage =
              '📊 نتيجة الاستيراد:\n\n'
              '✅ أقسام ناجحة: $successSections\n'
              '❌ أقسام فاشلة: $failSections\n'
              '✅ عناصر ناجحة: $successItems\n'
              '❌ عناصر فاشلة: $failItems'
              '${errors.isNotEmpty ? "\n\n⚠️ التفاصيل:\n${errors.take(5).join("\n")}" : ""}';
        });

        if (successSections > 0 || successItems > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '✅ تم استيراد $successSections قسم و $successItems عنصر'),
              backgroundColor: const Color(0xFF047857),
              duration: const Duration(seconds: 3),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('استيراد JSON - الموسوعة',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF047857),
        iconTheme: const IconThemeData(color: Colors.white),
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
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.blue.shade700, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'الصق كود JSON لاستيراد أقسام الموسوعة\n'
                      '• يدعم صيغة { "sections": [...] } أو [ ... ]\n'
                      '• كل قسم ممكن يحتوي على items\n'
                      '• عناصر القسم ممكن تحتوي على sections داخلية',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ✅ حقل JSON
            TextField(
              controller: _jsonCtrl,
              maxLines: 18,
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 11, height: 1.4),
              decoration: InputDecoration(
                hintText: '{\n'
                    '  "sections": [\n'
                    '    {\n'
                    '      "name": "أمراض النبات",\n'
                    '      "emoji": "🐛",\n'
                    '      "color": "#047857",\n'
                    '      "description": "...",\n'
                    '      "items": [\n'
                    '        {\n'
                    '          "title": "البياض الدقيقي",\n'
                    '          "subtitle": "مرض فطري",\n'
                    '          "icon": "bug_report",\n'
                    '          "content": "...",\n'
                    '          "sections": [\n'
                    '            {"title": "الأعراض", "content": "..."}\n'
                    '          ]\n'
                    '        }\n'
                    '      ]\n'
                    '    }\n'
                    '  ]\n'
                    '}',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 16),

            // ✅ رسالة النتيجة
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
                          height: 1.6,
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
                _loading ? 'جاري الاستيراد...' : 'استيراد الموسوعة',
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

            // ✅ مثال
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
                        Text('مثال بسيط',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '[\n'
                        '  {\n'
                        '    "name": "أمراض النبات",\n'
                        '    "emoji": "🐛",\n'
                        '    "color": "#047857",\n'
                        '    "description": "كل أمراض النبات",\n'
                        '    "items": []\n'
                        '  }\n'
                        ']',
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            height: 1.5),
                      ),
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
