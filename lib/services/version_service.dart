import 'dart:io';
import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import '../config/build_flags.dart';


// ---------------- VersionService ----------------
class VersionService {
  static const String versionUrl =
      "https://raw.githubusercontent.com/3linaser5-spec/agri-app/main/version.json";

  static Future<Map<String, dynamic>?> fetchVersionInfo() async {
    try {
      final response = await http
          .get(Uri.parse(versionUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint("خطأ في قراءة معلومات النسخة: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> checkUpdate() async {
    // نسخة المتجر: التحديث بتيجي من Google Play، وممنوع نعرض تنزيل APK.
    if (BuildFlags.storeBuild) return null;
    try {
      final info = await fetchVersionInfo();
      if (info == null) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final latestVersion = info['latest_version'] as String? ?? currentVersion;
      final minVersion = info['min_version'] as String? ?? currentVersion;

      final hasNewVersion = _compareVersions(latestVersion, currentVersion) > 0;
      final isMandatory = _compareVersions(currentVersion, minVersion) < 0;

      if (hasNewVersion || isMandatory) {
        return {
          'mandatory': isMandatory,
          'version': latestVersion,
          'downloadUrl': info['download_url'] ?? '',
          'changelog': info['changelog'] ?? '',
          'sha256': info['sha256'],
        };
      }
      return null;
    } catch (e) {
      debugPrint("خطأ في فحص التحديث: $e");
      return null;
    }
  }

  static int _compareVersions(String v1, String v2) {
    final a = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final b = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = a.length > b.length ? a.length : b.length;
    for (int i = 0; i < len; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x - y;
    }
    return 0;
  }

  static bool isTrustedDownloadUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return false;
    const allowed = {
      'github.com',
      'objects.githubusercontent.com',
      'release-assets.githubusercontent.com',
      'raw.githubusercontent.com',
    };
    return allowed.contains(uri.host);
  }

  static Future<String> _sha256Of(File file) async {
    final digest = await crypto.sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  static Future<void> downloadAndInstall({
    required String url,
    String? sha256,
    required Function(double progress) onProgress,
    required Function(String filePath) onComplete,
    required Function(String error) onError,
  }) async {
    try {
      // نسخة المتجر: لا تنزيل ولا تثبيت APK خارج Google Play.
      if (BuildFlags.storeBuild) {
        onError('التحديثات في نسخة المتجر بتتم من Google Play.');
        return;
      }
      if (!isTrustedDownloadUrl(url)) {
        onError('رابط التحميل غير موثوق');
        return;
      }
      final expected = sha256?.trim().toLowerCase();
      if (expected == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(expected)) {
        onError('بيانات التحديث لا تحتوي قيمة SHA-256 صالحة');
        return;
      }

      if (Platform.isAndroid) {
        final installStatus = await Permission.requestInstallPackages.status;
        if (!installStatus.isGranted) {
          await Permission.requestInstallPackages.request();
        }
      }

      final dir = await getExternalStorageDirectory() ??
          await getTemporaryDirectory();
      final filePath = "${dir.path}/app-release.apk";

      final oldFile = File(filePath);
      if (oldFile.existsSync()) {
        await oldFile.delete();
      }

      final dio = Dio();
      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress(received / total);
          }
        },
      );

      final actual = await _sha256Of(File(filePath));
      if (actual != expected) {
        await File(filePath).delete();
        onError('فشل التحقق من سلامة الملف');
        return;
      }

      onComplete(filePath);
      await OpenFilex.open(filePath);
    } catch (e) {
      onError(e.toString());
    }
  }
}
