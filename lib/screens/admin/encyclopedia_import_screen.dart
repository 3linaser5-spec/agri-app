import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/encyclopedia_service.dart';
import '../../utils/color_utils.dart';

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
    if (!mounted) return;
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
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  bool _isHttpUrl(String s) {
    final u = Uri.tryParse(s);
    return u != null && (u.scheme == 'http' || u.scheme == 'https') && u.host.isNotEmpty;
  }

  /// يتحقق من كل الأقسام والعناصر ويطبّعها. أي خطأ بيتضاف لـ [errors].
  List<Map<String, dynamic>> _validate(List<dynamic> raw, List<String> errors) {
    final result = <Map<String, dynamic>>[];

    for (var i = 0; i < raw.length; i++) {
      final sec = raw[i];
      final secLabel = 'قسم ${i + 1}';
      if (sec is! Map) {
        errors.add('$secLabel: ليس Object');
        continue;
      }

      final name = sec['name'];
      if (name is! String || name.trim().isEmpty) {
        errors.add('$secLabel: الاسم مطلوب (نص)');
        continue;
      }
      final label = 'قسم "${name.trim()}"';

      var color = '#047857';
      final rawColor = sec['color'];
      if (rawColor != null) {
        final c = rawColor.toString().trim();
        if (!ColorUtils.isValidHex(c)) {
          errors.add('$label: اللون "$c" غير صالح (المطلوب #RRGGBB)');
        } else {
          color = c.startsWith('#') ? c : '#$c';
        }
      }

      final items = <Map<String, dynamic>>[];
      final rawItems = sec['items'];
      if (rawItems != null && rawItems is! List) {
        errors.add('$label: "items" لازم تكون قائمة');
      } else if (rawItems is List) {
        for (var j = 0; j < rawItems.length; j++) {
          final it = rawItems[j];
          final itLabel = '$label / عنصر ${j + 1}';
          if (it is! Map) {
            errors.add('$itLabel: ليس Object');
            continue;
          }
          final title = it['title'];
          if (title is! String || title.trim().isEmpty) {
            errors.add('$itLabel: العنوان مطلوب (نص)');
            continue;
          }

          final inner = <Map<String, String>>[];
          final rawInner = it['sections'];
          if (rawInner != null && rawInner is! List) {
            errors.add('$itLabel: "sections" لازم تكون قائمة');
          } else if (rawInner is List) {
            for (var k = 0; k < rawInner.length; k++) {
              final p = rawInner[k];
              if (p is! Map) {
                errors.add('$itLabel: فقرة ${k + 1} ليست Object');
                continue;
              }
              inner.add({
                'title': p['title']?.toString() ?? '',
                'content': p['content']?.toString() ?? '',
              });
            }
          }

          // نفس قاعدة محرر العنصر: لازم محتوى أساسي أو فقرة واحدة على الأقل
          final mainContent = it['content']?.toString() ?? '';
          if (mainContent.trim().isEmpty && inner.isEmpty) {
            errors.add('$itLabel: لازم محتوى أساسي أو فقرة واحدة على الأقل');
          }

          String? imageUrl;
          final rawImg = it['image_url'];
          if (rawImg != null && rawImg.toString().trim().isNotEmpty) {
            final u = rawImg.toString().trim();
            if (_isHttpUrl(u)) {
              imageUrl = u;
            } else {
              errors.add('$itLabel: رابط الصورة لازم يبدأ بـ http أو https');
            }
          }

          items.add({
            'title': title.trim(),
            'subtitle': it['subtitle']?.toString() ?? '',
            'icon': it['icon']?.toString() ?? 'eco',
            'content': it['content']?.toString() ?? '',
            'sections': inner,
            'image_url': imageUrl,
          });
        }
      }

      result.add({
        'name': name.trim(),
        'emoji': sec['emoji']?.toString() ?? '📚',
        'color': color,
        'description': sec['description']?.toString() ?? '',
        'items': items,
      });
    }
    return result;
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

      // ثلاث صيغ مدعومة: {sections:[...]} أو [..] أو قسم واحد {name:..}
      List<dynamic> raw;
      if (parsed is Map && parsed['sections'] is List) {
        raw = parsed['sections'] as List;
      } else if (parsed is List) {
        raw = parsed;
      } else if (parsed is Map && parsed['name'] != null) {
        raw = [parsed];
      } else {
        throw const FormatException(
            'الصيغة غير صحيحة. المتوقع: object فيه sections، أو array من الأقسام، أو قسم واحد');
      }

      if (raw.isEmpty) {
        _finish(false, '❌ الملف فاضي: مفيش أقسام للاستيراد');
        return;
      }

      // 1) نتحقق من كل حاجة الأول. لو فيه أي خطأ ما نحفظش أي حاجة
      final errors = <String>[];
      final sections = _validate(raw, errors);
      if (errors.isNotEmpty) {
        final shown = errors.take(8).join('\n');
        final more =
            errors.length > 8 ? '\n... و${errors.length - 8} خطأ آخر' : '';
        _finish(
          false,
          '❌ لم يتم حفظ أي شيء (${errors.length} خطأ)\n'
          'صحّح الأخطاء وأعد المحاولة:\n\n$shown$more',
        );
        return;
      }

      // 2) كتابة ذرية بـ WriteBatch
      final r = await EncyclopediaService.importSections(sections);
      _finish(true, '✅ تم استيراد ${r.sections} قسم و ${r.items} عنصر');
    } on FormatException catch (e) {
      _finish(false, '❌ خطأ في صيغة JSON:\n${e.message}');
    } on ArgumentError catch (e) {
      _finish(false, '❌ ${e.message}');
    } on TimeoutException {
      _finish(
          false,
          '⏱️ انتهت مهلة الحفظ، تأكد من الاتصال.\n'
          'لو الاتصال رجع ممكن الاستيراد يكتمل لوحده، فراجع قائمة الأقسام قبل إعادة المحاولة.');
    } catch (e) {
      debugPrint('❌ خطأ في الاستيراد: $e');
      _finish(false, '❌ تعذر الاستيراد:\n$e');
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
