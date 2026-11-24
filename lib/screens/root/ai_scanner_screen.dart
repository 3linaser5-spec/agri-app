import 'dart:io';
import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/app_config.dart';
import '../../services/offline_service.dart';
import '../../services/plant_disease_service.dart';
import '../../services/plant_health_service.dart';
import '../../models/my_farm_model.dart';
import '../../services/my_farm_service.dart';
import './history_screen.dart';


// ---------------- AiScannerScreen ----------------
class AiScannerScreen extends StatefulWidget {
  final String userName;
  final String userPhone;
  final String? initialQuestion;
  final String? initialImagePath;
  final int? pendingDiagnosisId;
  const AiScannerScreen(
      {super.key,
      required this.userName,
      required this.userPhone,
      this.initialQuestion,
      this.initialImagePath,
      this.pendingDiagnosisId});

  @override
  State<AiScannerScreen> createState() => _AiScannerScreenState();
}

class _AiScannerScreenState extends State<AiScannerScreen> {
  final _questionCtrl = TextEditingController();
  bool _loading = false;
  String _diagnosis = "";
  PlantDiseaseResult? _latestPlantResult;
  bool _savingToFarm = false;
  String? _autoLinkedProgramId;
  String? _farmLinkMessage;
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlayingVoice = false;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _questionCtrl.text = widget.initialQuestion ?? '';
    final path = widget.initialImagePath;
    if (path != null && File(path).existsSync()) {
      _imageFile = File(path);
    }
    _initVoiceSettings();
  }

  void _initVoiceSettings() async {
    await _flutterTts.setLanguage("ar-EG");
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setPitch(1.0);
    void reset() {
      if (mounted) setState(() => _isPlayingVoice = false);
    }

    _flutterTts.setCompletionHandler(reset);
    _flutterTts.setCancelHandler(reset);
    _flutterTts.setErrorHandler((_) => reset());
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('اختر مصدر الصورة',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt,
                  color: Color(0xFF047857), size: 30),
              title: const Text('التقاط صورة بالكاميرا'),
              onTap: () async {
                Navigator.pop(context);
                await _pickFromSource(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library,
                  color: Color(0xFF047857), size: 30),
              title: const Text('اختيار من المعرض'),
              onTap: () async {
                Navigator.pop(context);
                await _pickFromSource(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromSource(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (pickedFile != null && mounted) {
        setState(() => _imageFile = File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الكاميرا أو المعرض')),
        );
      }
    }
  }

  Future<void> _toggleVoicePlayback(String text) async {
    if (_isPlayingVoice) {
      await _flutterTts.stop();
      if (!mounted) return;
      setState(() => _isPlayingVoice = false);
    } else {
      if (text.isNotEmpty) {
        setState(() => _isPlayingVoice = true);
        await _flutterTts.speak(text);
      }
    }
  }

  Future<void> _sendToEngineerWhatsApp() async {
    const engineerPhone = AppConfig.engineerPhone;
    final message = """
السلام عليكم يا بشمهندس علي، معي استشارة زراعية:
🌱 *اسم المزارع:* ${widget.userName}
❓ *المشكلة الزراعية:* ${_questionCtrl.text.trim()}
📋 *تشخيص المستشار الذكي:*
$_diagnosis
""";
    final uri = Uri.parse(
        "https://wa.me/$engineerPhone?text=${Uri.encodeComponent(message)}");
    try {
      final opened =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر فتح تطبيق الواتساب')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح تطبيق الواتساب')));
    }
  }

  Future<void> _shareDiagnosis() async {
    final text = """
🌱 *تشخيص نباتي - المستشار الزراعي الذكي*
━━━━━━━━━━━━━━━━━━
🌿 *السؤال:* ${_questionCtrl.text.trim()}

📋 *التشخيص:*
$_diagnosis

━━━━━━━━━━━━━━━━━━
📱 تطبيق نباتي - مستشارك الزراعي الذكي
""";
    await SharePlus.instance.share(
        ShareParams(text: text, subject: 'تشخيص نباتي'));
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _questionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final question = _questionCtrl.text.trim();
    if (question.isEmpty && _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برجاء كتابة سؤالك أو إرفاق صورة أولاً')),
      );
      return;
    }
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مصنف الأمراض يحتاج صورة واضحة لورقة النبات.')),
      );
      return;
    }

    final hasInternet = await OfflineService.hasInternet();
    if (!hasInternet) {
      if (mounted) {
        setState(() {
          _diagnosis =
              'لا يوجد اتصال بالإنترنت حاليًا. حُفظ الطلب محليًا، وأعد إرساله بعد عودة الاتصال للحصول على تحليل المصنف.';
        });
      }
      if (widget.pendingDiagnosisId == null) {
        await OfflineService.saveDiagnosis(
          userName: widget.userName,
          userPhone: widget.userPhone,
          question: question,
          imagePath: _imageFile?.path,
          diagnosis: 'لم يُحلل بعد: لا يوجد اتصال بالإنترنت',
          analysisPending: true,
        );
      }
      return;
    }

    setState(() {
      _loading = true;
      _diagnosis = '';
      _latestPlantResult = null;
      _autoLinkedProgramId = null;
      _farmLinkMessage = null;
    });

    try {
      final result = await PlantDiseaseService.instance.classify(image: _imageFile!);
      final report = StringBuffer()
        ..writeln('أقرب فئات المصنف إلى الصورة:')
        ..writeln();
      for (var index = 0; index < result.predictions.length; index++) {
        final prediction = result.predictions[index];
        report.writeln(
          '${index + 1}) ${prediction.cropAr}: ${prediction.nameAr} — '
          'درجة النموذج ${(prediction.confidence * 100).toStringAsFixed(1)}%',
        );
      }
      final treatment = result.treatment;
      report.writeln();
      report.writeln('معلومات المكافحة من قاعدة العلاج المرفقة:');
      if (treatment == null || !treatment.matched) {
        report.writeln(
          'لا توجد مطابقة دقيقة في قاعدة العلاج لهذه الفئة؛ لن أقترح مبيدًا أو جرعة.',
        );
      } else {
        if (treatment.diseaseAr != null) {
          report.writeln('السجل المطابق: ${treatment.diseaseAr}');
        }
        if (treatment.symptomsAr != null) {
          report.writeln('الأعراض الواردة في السجل: ${treatment.symptomsAr}');
        }
        if (treatment.controlTimingAr != null) {
          report.writeln('توقيت المكافحة المذكور: ${treatment.controlTimingAr}');
        }
        if (treatment.approvedPesticides.isEmpty) {
          report.writeln(
            treatment.noticeAr ??
                'لا توجد توصية مبيد موثقة مفعّلة في قاعدة التشغيل؛ لا تستخدم جرعة بالتخمين.',
          );
        } else {
          for (final product in treatment.approvedPesticides) {
            final productName = product['product_name_ar'] ??
                product['name_ar'] ??
                product['product_name'];
            if (productName != null) report.writeln('المنتج المسجل: $productName');
          }
        }
      }
      if (treatment?.source != null) {
        report.writeln('المصدر المذكور في الملف: ${treatment!.source}');
      }
      if (treatment?.section != null) {
        report.writeln('القسم: ${treatment!.section}');
      }
      if (treatment?.sourceVerificationNoteAr != null) {
        report.writeln(treatment!.sourceVerificationNoteAr);
      }
      report
        ..writeln()
        ..writeln('تنبيه: هذه احتمالات آلية أولية وليست تشخيصًا مؤكدًا.')
        ..writeln(result.disclaimer)
        ..writeln('لا تستخدم النتيجة لاختيار مبيد أو جرعة؛ اعرض النبات على مهندس زراعي محلي.');
      final diagnosisText = report.toString().trim();

      if (!mounted) return;
      setState(() {
        _diagnosis = diagnosisText;
        _latestPlantResult = result;
      });

      try {
        await OfflineService.saveDiagnosis(
          userName: widget.userName,
          userPhone: widget.userPhone,
          question: question,
          imagePath: _imageFile?.path,
          diagnosis: diagnosisText,
        );
        final oldPendingId = widget.pendingDiagnosisId;
        if (oldPendingId != null) {
          await OfflineService.deleteDiagnosis(oldPendingId);
        }
      } catch (_) {
        debugPrint('تعذر حفظ نتيجة المصنف محليًا');
      }
      await _autoLinkDiagnosisToFarm(result);
    } on PlantDiseaseException catch (error) {
      if (mounted) setState(() => _diagnosis = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _diagnosis = 'تعذر تحليل الصورة الآن. تحقق من اتصالك وحاول مرة أخرى لاحقًا.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _farmCropLabel(MyFarmProgram program) {
    for (final entry in program.inputValues.entries) {
      final key = entry.key.toLowerCase();
      if (key.contains('crop') ||
          key.contains('plant') ||
          key.contains('variety') ||
          key.contains('محصول') ||
          key.contains('نبات') ||
          key.contains('صنف')) {
        final value = entry.value?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    }
    if (program.templateName.trim().isNotEmpty) return program.templateName;
    return 'غير محدد';
  }

  Future<void> _autoLinkDiagnosisToFarm(PlantDiseaseResult result) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || result.predictions.isEmpty) return;

    try {
      final programs = await MyFarmService.getUserPrograms(user.uid).first;
      final prediction = result.predictions.first;
      final program = PlantHealthService.findUniqueMatchingProgram(
        programs: programs,
        className: prediction.className,
      );
      if (program == null) {
        if (mounted) {
          setState(() {
            _farmLinkMessage =
                'لم يُحفظ تلقائيًا: لم يُعثر على برنامج نشط واحد واضح للمحصول. اختر البرنامج يدويًا للمراجعة.';
          });
        }
        return;
      }

      await PlantHealthService.saveDiagnosisToProgram(
        programId: program.id,
        farmCrop: _farmCropLabel(program),
        predictedCrop: prediction.cropAr,
        disease: prediction.nameAr,
        className: prediction.className,
        confidence: prediction.confidence,
        modelVersion: result.modelVersion,
      );
      if (mounted) {
        setState(() {
          _autoLinkedProgramId = program.id;
          _farmLinkMessage =
              'تم حفظ التشخيص تلقائيًا في برنامج «${program.templateName}» للمراجعة.';
        });
      }
    } on PlantHealthException catch (error) {
      if (mounted) setState(() => _farmLinkMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _farmLinkMessage =
              'تعذر الحفظ التلقائي في مزرعتي. تحقق من اتصال الإنترنت وقواعد Firestore.';
        });
      }
    }
  }

  Future<void> _saveDiagnosisToFarm() async {
    final result = _latestPlantResult;
    final user = FirebaseAuth.instance.currentUser;
    if (result == null || result.predictions.isEmpty) return;
    if (user == null) {
      _showFarmMessage('سجّل الدخول أولاً لحفظ التشخيص في مزرعتك.');
      return;
    }
    if (_savingToFarm) return;

    setState(() => _savingToFarm = true);
    try {
      final programs = await MyFarmService.getUserPrograms(user.uid).first;
      if (!mounted) return;
      if (programs.isEmpty) {
        _showFarmMessage('لا توجد برامج في مزرعتي. احفظ برنامج المحصول أولاً.');
        return;
      }

      final selectedProgram = await showDialog<MyFarmProgram>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('اختر برنامج المحصول'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: programs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final program = programs[index];
                final crop = _farmCropLabel(program);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Text(program.templateEmoji,
                      style: const TextStyle(fontSize: 24)),
                  title: Text(program.templateName),
                  subtitle: Text(
                    crop == 'غير محدد'
                        ? 'المحصول غير محدد في بيانات البرنامج'
                        : 'المحصول: $crop',
                  ),
                  onTap: () => Navigator.pop(dialogContext, program),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      );
      if (!mounted || selectedProgram == null) return;

      final prediction = result.predictions.first;
      final farmCrop = _farmCropLabel(selectedProgram);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('حفظ كسجل متابعة'),
          content: Text(
            'برنامج المزرعة: ${selectedProgram.templateName}\n'
            'المحصول المسجل: $farmCrop\n'
            'أقرب نتيجة للنموذج: ${prediction.cropAr} — ${prediction.nameAr} '
            '(${(prediction.confidence * 100).toStringAsFixed(1)}٪).\n\n'
            'المصنف الحالي يغطي 38 فئة ولا يشمل القمح. سيُحفظ التشخيص كملاحظة تحتاج مراجعة، ولن يغيّر جدول الري أو يوصي بزيادة/خفض كمية المياه.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('رجوع'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('حفظ للمراجعة'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;

      await PlantHealthService.saveDiagnosisToProgram(
        programId: selectedProgram.id,
        farmCrop: farmCrop,
        predictedCrop: prediction.cropAr,
        disease: prediction.nameAr,
        className: prediction.className,
        confidence: prediction.confidence,
        modelVersion: result.modelVersion,
      );
      if (mounted) {
        setState(() {
          _autoLinkedProgramId = selectedProgram.id;
          _farmLinkMessage =
              'تم حفظ التشخيص في برنامج «${selectedProgram.templateName}» للمراجعة.';
        });
        _showFarmMessage(
          'تم ربط التشخيص ببرنامج مزرعتك. افتح تبويب «صحة النبات» للمراجعة.',
        );
      }
    } on PlantHealthException catch (error) {
      if (mounted) _showFarmMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showFarmMessage('تعذر حفظ التشخيص. تحقق من الاتصال وصلاحيات Firestore.');
      }
    } finally {
      if (mounted) setState(() => _savingToFarm = false);
    }
  }

  void _showFarmMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفحص الذكي للآفات',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF047857),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _questionCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'اكتب مشكلة النبات أو الآفة اللي بتواجهك...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('إرفاق صورة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_imageFile != null)
                    const Text('تم إرفاق صورة ✅',
                        style: TextStyle(color: Colors.green)),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('إرسال للاستشارة الزراعية',
                        style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
              const SizedBox(height: 24),
              if (_diagnosis.isNotEmpty) ...[
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  color: const Color(0xFFECFDF5),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle, color: Color(0xFF047857)),
                            SizedBox(width: 8),
                            Text('تشخيص وتوصية المستشار الزراعي:',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF047857))),
                          ],
                        ),
                        const Divider(),
                        SelectableText(
                          _diagnosis,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.9,
                            fontFamily: 'Cairo',
                          ),
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                        ),
                        if (_latestPlantResult != null && _farmLinkMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _autoLinkedProgramId != null
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _farmLinkMessage!,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                color: _autoLinkedProgramId != null
                                    ? const Color(0xFF166534)
                                    : const Color(0xFF9A3412),
                              ),
                            ),
                          ),
                        ],
                        if (_latestPlantResult != null &&
                            _autoLinkedProgramId == null) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _savingToFarm ? null : _saveDiagnosisToFarm,
                              icon: _savingToFarm
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.agriculture),
                              label: Text(_savingToFarm
                                  ? 'جارٍ الحفظ في مزرعتي...'
                                  : 'اختيار برنامج يدويًا للمراجعة'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF047857),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'يُحفظ كسجل يحتاج مراجعة؛ لا يغيّر كمية أو جدول الري تلقائيًا.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _toggleVoicePlayback(_diagnosis),
                                icon: Icon(_isPlayingVoice
                                    ? Icons.stop
                                    : Icons.volume_up),
                                label: Text(_isPlayingVoice
                                    ? 'إيقاف الصوت'
                                    : 'استمع للتشخيص'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF047857),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _shareDiagnosis,
                                icon: const Icon(Icons.share),
                                label: const Text('مشاركة'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(45),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _sendToEngineerWhatsApp,
                                icon: const Icon(Icons.chat),
                                label: const Text('للمهندس'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(45),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
