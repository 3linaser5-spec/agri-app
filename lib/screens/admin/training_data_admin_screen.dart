import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/training_data_service.dart';

class TrainingDataAdminScreen extends StatefulWidget {
  const TrainingDataAdminScreen({super.key});

  @override
  State<TrainingDataAdminScreen> createState() =>
      _TrainingDataAdminScreenState();
}

class _TrainingDataAdminScreenState extends State<TrainingDataAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cropController = TextEditingController();
  final _diseaseController = TextEditingController();
  final _picker = ImagePicker();

  late Future<bool> _authorization;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _samplesStream;
  File? _selectedImage;
  int? _selectedImageBytes;
  bool _labelConfirmed = false;
  bool _uploading = false;
  double? _uploadProgress;

  @override
  void initState() {
    super.initState();
    _authorization = TrainingDataService.currentUserIsAdmin();
    _samplesStream = TrainingDataService.watchRecentSamples();
  }

  @override
  void dispose() {
    _cropController.dispose();
    _diseaseController.dispose();
    super.dispose();
  }

  void _recheckAuthorization() {
    setState(() {
      _authorization = TrainingDataService.currentUserIsAdmin();
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2048,
      );
      if (picked == null) return;

      final file = File(picked.path);
      final size = await file.length();
      if (size <= 0 || size > TrainingDataService.maxImageBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حجم الصورة يجب أن يكون أقل من 10 ميجابايت.'),
          ),
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _selectedImage = file;
        _selectedImageBytes = size;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح الكاميرا أو معرض الصور.')),
      );
    }
  }

  Future<void> _saveSample() async {
    if (_uploading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final image = _selectedImage;
    if (image == null) {
      _showMessage('اختر صورة للنبات أولاً.');
      return;
    }
    if (!_labelConfirmed) {
      _showMessage('أكد مراجعة التشخيص قبل حفظ الصورة في بيانات التدريب.');
      return;
    }

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });

    try {
      await TrainingDataService.uploadLabeledImage(
        image: image,
        crop: _cropController.text,
        disease: _diseaseController.text,
        onProgress: (transferred, total) {
          if (!mounted || total <= 0) return;
          setState(() => _uploadProgress = transferred / total);
        },
      );
      if (!mounted) return;
      setState(() {
        _selectedImage = null;
        _selectedImageBytes = null;
        _cropController.clear();
        _diseaseController.clear();
        _labelConfirmed = false;
      });
      _showMessage('تم حفظ الصورة وتصنيفها ضمن مجموعة التدريب.');
    } on TrainingDataException catch (error) {
      if (mounted) _showMessage(error.message);
    } on FirebaseException catch (error) {
      if (mounted) _showMessage(_firebaseErrorMessage(error));
    } catch (_) {
      if (mounted) _showMessage('تعذر حفظ الصورة. تحقق من الاتصال وصلاحيات Firebase.');
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadProgress = null;
        });
      }
    }
  }

  String _firebaseErrorMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
      case 'unauthorized':
        return 'الرفع مرفوض. تأكد من وجود admins/<UID> ونشر قواعد Firestore وStorage.';
      case 'bucket-not-found':
        return 'لم يتم إعداد Firebase Storage لهذا المشروع بعد.';
      case 'network-request-failed':
        return 'تعذر الاتصال. افحص الإنترنت وحاول مرة أخرى.';
      case 'canceled':
        return 'تم إلغاء رفع الصورة.';
      default:
        return 'تعذر حفظ الصورة. رمز الخطأ: ${error.code}';
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatBytes(Object? value) {
    final bytes = value is int ? value : 0;
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} كيلوبايت';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} ميجابايت';
  }

  Widget _buildAuthorizationState(AsyncSnapshot<bool> snapshot) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final denied = snapshot.connectionState == ConnectionState.done &&
        !snapshot.hasError && snapshot.data != true;
    final message = denied
        ? 'هذا القسم للأدمن فقط. يلزم إنشاء مستند admins/<UID> في Firestore للحساب الحالي.'
        : 'تعذر التحقق من صلاحية الأدمن. تحقق من اتصال الإنترنت وقواعد قراءة مستند admins/<UID>.';

    return Scaffold(
      appBar: AppBar(
        title: const Text('بوابة بيانات التدريب'),
        backgroundColor: const Color(0xFF047857),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline,
                  size: 58, color: isDark ? Colors.white54 : Colors.grey),
              const SizedBox(height: 14),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _recheckAuthorization,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة التحقق'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryText = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      appBar: AppBar(
        title: const Text('بوابة بيانات تدريب النموذج'),
        backgroundColor: const Color(0xFF047857),
        foregroundColor: Colors.white,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildInfoCard(),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'إضافة صورة مصنفة',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _cropController,
                        maxLength: 80,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'المحصول',
                          hintText: 'مثال: طماطم',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.grass),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'اكتب اسم المحصول'
                                : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _diseaseController,
                        maxLength: 80,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'التشخيص / المرض',
                          hintText: 'اكتب التشخيص الذي راجعته',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.biotech),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'اكتب اسم المرض أو التشخيص'
                                : null,
                      ),
                      const SizedBox(height: 8),
                      if (_selectedImage == null)
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text('اختر صورة واضحة للأعراض'),
                          ),
                        )
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _selectedImage!,
                            height: 220,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const SizedBox(
                              height: 150,
                              child: Center(child: Text('تعذر عرض معاينة الصورة')),
                            ),
                          ),
                        ),
                      if (_selectedImageBytes != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'حجم الصورة: ${_formatBytes(_selectedImageBytes)}',
                          style: TextStyle(color: secondaryText, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _uploading
                                ? null
                                : () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('اختيار من المعرض'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _uploading
                                ? null
                                : () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('التقاط صورة'),
                          ),
                        ],
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _labelConfirmed,
                        onChanged: _uploading
                            ? null
                            : (value) => setState(
                                  () => _labelConfirmed = value ?? false,
                                ),
                        title: const Text(
                          'أؤكد أنني راجعت التشخيص والتصنيف الزراعي لهذه الصورة.',
                          style: TextStyle(fontSize: 13),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      if (_uploading) ...[
                        const SizedBox(height: 6),
                        LinearProgressIndicator(value: _uploadProgress),
                        const SizedBox(height: 6),
                        const Text('جارٍ رفع الصورة وحفظ التصنيف...'),
                      ],
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _uploading ? null : _saveSample,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('حفظ في مجموعة بيانات التدريب'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF047857),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'آخر الصور المحفوظة',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildRecentSamples(secondaryText),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: const Color(0xFFECFDF5),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF047857)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'أنت تحدد المحصول والمرض؛ تُحفظ الصورة مع التصنيف الذي راجعته.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'الحفظ يضيف عينة إلى مجموعة البيانات ولا يغيّر أوزان النموذج فورًا. يلزم ربط خدمة التدريب بالنسخة القابلة للتدريب قبل تفعيل إعادة التدريب والنشر.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSamples(Color secondaryText) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _samplesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'تعذر تحميل العينات. تأكد من نشر قواعد Firestore للأدمن.',
                style: TextStyle(color: secondaryText),
              ),
            ),
          );
        }

        final samples = snapshot.data?.docs ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        if (samples.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text('لم تُحفظ صور تدريب بعد.',
                  style: TextStyle(color: secondaryText)),
            ),
          );
        }

        return Column(
          children: samples.map((document) {
            final data = document.data();
            final crop = data['crop'] is String ? data['crop'] as String : 'محصول';
            final disease =
                data['disease'] is String ? data['disease'] as String : 'تشخيص';
            final status = data['status'] == 'pending_training'
                ? 'محفوظة للدفعة القادمة'
                : 'مسجلة';
            final uploadedAt = data['uploadedAt'];
            final dateText = uploadedAt is Timestamp
                ? '${uploadedAt.toDate().year}/${uploadedAt.toDate().month.toString().padLeft(2, '0')}/${uploadedAt.toDate().day.toString().padLeft(2, '0')}'
                : 'الآن';

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFECFDF5),
                  child: Icon(Icons.local_florist, color: Color(0xFF047857)),
                ),
                title: Text('$crop — $disease',
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('$status • $dateText'),
                trailing: Text(_formatBytes(data['sizeBytes']),
                    style: TextStyle(fontSize: 11, color: secondaryText)),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _authorization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data != true) {
          return _buildAuthorizationState(snapshot);
        }
        return _buildPortal();
      },
    );
  }
}
