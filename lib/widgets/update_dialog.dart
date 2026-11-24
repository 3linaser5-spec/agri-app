import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../services/version_service.dart';


// ---------------- UpdateDialog ----------------
class UpdateDialog extends StatefulWidget {
  final String version;
  final String changelog;
  final String downloadUrl;
  final String? sha256;
  final bool mandatory;

  const UpdateDialog({
    super.key,
    required this.version,
    required this.changelog,
    required this.downloadUrl,
    this.sha256,
    required this.mandatory,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double _progress = 0.0;
  String? _error;

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _progress = 0.0;
      _error = null;
    });

    await VersionService.downloadAndInstall(
      url: widget.downloadUrl,
      sha256: widget.sha256,
      onProgress: (progress) {
        if (mounted) setState(() => _progress = progress);
      },
      onComplete: (filePath) {
        if (mounted) {
          setState(() => _downloading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم التحميل! اتبع تعليمات التثبيت.'),
              backgroundColor: Color(0xFF047857),
              duration: Duration(seconds: 4),
            ),
          );
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _downloading = false;
            _error = "فشل التحميل. تأكد من الإنترنت وحاول مرة أخرى.";
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.mandatory && !_downloading,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF047857).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.system_update_alt,
                    color: Color(0xFF047857)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.mandatory ? 'تحديث إجباري متاح' : 'تحديث جديد متاح',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('الإصدار الجديد: ${widget.version}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF047857))),
                const SizedBox(height: 12),
                const Text('التغييرات:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(widget.changelog,
                    style: const TextStyle(fontSize: 13, height: 1.6)),
                const SizedBox(height: 16),
                if (_downloading) ...[
                  const Text('جاري التحميل...',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade200,
                      color: const Color(0xFF047857),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text('${(_progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.red)),
                        ),
                      ],
                    ),
                  ),
                ],
                if (widget.mandatory && !_downloading) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'هذا التحديث ضروري لاستمرار استخدام التطبيق',
                            style: TextStyle(fontSize: 12, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!widget.mandatory && !_downloading)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('لاحقاً',
                    style: TextStyle(color: Colors.grey)),
              ),
            if (!_downloading)
              ElevatedButton.icon(
                onPressed: _startDownload,
                icon: const Icon(Icons.download),
                label: const Text('تحميل وتثبيت'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
