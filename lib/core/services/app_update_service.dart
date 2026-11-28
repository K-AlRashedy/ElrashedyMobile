import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../network/api_client.dart';

class AppUpdateInfo {
  final String latestVersion;
  final String minVersion;
  final String releaseNotes;
  final String androidUrl;
  final String iosUrl;
  final bool hasUpdate;
  final bool forceUpdate;

  AppUpdateInfo({
    required this.latestVersion,
    required this.minVersion,
    required this.releaseNotes,
    required this.androidUrl,
    required this.iosUrl,
    required this.hasUpdate,
    required this.forceUpdate,
  });
}

class AppUpdateService {
  static const String currentVersion = "1.2.0";

  /// Checks if a newer version is available on the server.
  static Future<AppUpdateInfo?> checkForUpdate(ApiClient api) async {
    try {
      final res = await api.get('/api/v1/app/version/');
      if (res is Map<String, dynamic> && res['ok'] == true) {
        final latest = res['latest_version']?.toString() ?? currentVersion;
        final minV = res['min_version']?.toString() ?? currentVersion;
        final notes =
            res['release_notes']?.toString() ?? 'تحسينات عامة على النظام.';
        final aUrl = res['android_url']?.toString() ?? '';
        final iUrl = res['ios_url']?.toString() ?? '';

        final hasUpdate = _isVersionGreater(latest, currentVersion);
        final forceUpdate = _isVersionGreater(minV, currentVersion);

        return AppUpdateInfo(
          latestVersion: latest,
          minVersion: minV,
          releaseNotes: notes,
          androidUrl: aUrl,
          iosUrl: iUrl,
          hasUpdate: hasUpdate,
          forceUpdate: forceUpdate,
        );
      }
    } catch (_) {
      // Fail silently if offline or error
    }
    return null;
  }

  static bool _isVersionGreater(String newV, String currentV) {
    try {
      final newParts = newV.split('.').map(int.parse).toList();
      final currParts = currentV.split('.').map(int.parse).toList();
      for (int i = 0; i < newParts.length && i < currParts.length; i++) {
        if (newParts[i] > currParts[i]) return true;
        if (newParts[i] < currParts[i]) return false;
      }
      return newParts.length > currParts.length;
    } catch (_) {
      return newV != currentV;
    }
  }

  /// Shows the update bottom sheet or dialog to the user.
  static void showUpdatePrompt(BuildContext context, AppUpdateInfo info) {
    final isIOS = Platform.isIOS;
    final downloadUrl = isIOS ? info.iosUrl : info.androidUrl;

    showModalBottomSheet(
      context: context,
      isDismissible: !info.forceUpdate,
      enableDrag: !info.forceUpdate,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.system_update_rounded,
                    color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 14),
              Text(
                'تحديث جديد متوفر: الإصدار ${info.latestVersion}',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  info.releaseNotes,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (isIOS) {
                    _launchExternalUrl(downloadUrl);
                  } else {
                    startInAppDownloadAndInstall(
                        context, downloadUrl, info.latestVersion);
                  }
                },
                icon: Icon(isIOS ? Icons.apple_rounded : Icons.android_rounded),
                label: Text(
                  isIOS
                      ? 'تحديث التطبيق للآيفون (IPA)'
                      : 'تحديث وتنزيل التطبيق (APK) ⚡',
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
              if (!info.forceUpdate) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'تذكيري لاحقاً',
                    style: TextStyle(
                        fontFamily: 'Cairo', color: AppColors.textMuted),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static Future<void> _launchExternalUrl(String url) async {
    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  /// Downloads APK in-app with a live progress dialog and automatically launches Android installer.
  static void startInAppDownloadAndInstall(
      BuildContext context, String url, String targetVersion) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return _DownloadProgressDialog(
          downloadUrl: url,
          targetVersion: targetVersion,
        );
      },
    );
  }
}

class _DownloadProgressDialog extends StatefulWidget {
  final String downloadUrl;
  final String targetVersion;

  const _DownloadProgressDialog({
    required this.downloadUrl,
    required this.targetVersion,
  });

  @override
  State<_DownloadProgressDialog> createState() =>
      _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String _statusText = 'جاري الاتصال بالسيرفر...';
  bool _isError = false;
  String _errorMessage = '';
  http.Client? _httpClient;
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  @override
  void dispose() {
    _isCancelled = true;
    _httpClient?.close();
    super.dispose();
  }

  Future<void> _startDownload() async {
    try {
      _httpClient = http.Client();
      Uri currentUri = Uri.parse(widget.downloadUrl);

      // Follow redirects manually up to 5 times (GitHub Releases -> S3)
      http.StreamedResponse? streamedResponse;
      int redirects = 0;
      while (redirects < 5) {
        final request = http.Request('GET', currentUri);
        final response = await _httpClient!.send(request);

        if (response.statusCode >= 300 &&
            response.statusCode < 400 &&
            response.headers.containsKey('location')) {
          final location = response.headers['location']!;
          currentUri = Uri.parse(location);
          redirects++;
          continue;
        }

        if (response.statusCode == 200) {
          streamedResponse = response;
          break;
        } else {
          throw Exception(
              'خطأ في التحميل من السيرفر (كود: ${response.statusCode})');
        }
      }

      if (streamedResponse == null) {
        throw Exception('تعذر الوصول إلى رابط ملف التحديث');
      }

      final contentLength = streamedResponse.contentLength ?? 0;
      setState(() {
        _totalBytes = contentLength;
        _statusText = 'جاري تنزيل ملف التحديث...';
      });

      // Prepare target file in app cache directory
      final cacheDir = await getTemporaryDirectory();
      final apkFile = File(
          '${cacheDir.path}/ElrashedyERP_v${widget.targetVersion}.apk');
      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      final sink = apkFile.openWrite();
      await streamedResponse.stream.listen((chunk) {
        if (_isCancelled) return;
        sink.add(chunk);
        _receivedBytes += chunk.length;
        if (_totalBytes > 0) {
          setState(() {
            _progress = _receivedBytes / _totalBytes;
          });
        }
      }).asFuture();

      await sink.flush();
      await sink.close();

      if (_isCancelled) return;

      // Also copy to public Download folder so it is accessible in user's APK files
      try {
        final publicDownloadDir = Directory('/sdcard/Download');
        if (await publicDownloadDir.exists()) {
          final publicFile = File(
              '${publicDownloadDir.path}/ElrashedyERP_v${widget.targetVersion}.apk');
          await apkFile.copy(publicFile.path);
        }
      } catch (_) {
        // Fallback silently if Scoped Storage blocks raw /sdcard/Download
      }

      setState(() {
        _statusText = 'اكتمل التنزيل! جاري فتح التثبيت...';
        _progress = 1.0;
      });

      await Future.delayed(const Duration(milliseconds: 400));

      // Close download dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Launch native Android installer
      await _installApk(apkFile.path);
    } catch (e) {
      if (!_isCancelled && mounted) {
        setState(() {
          _isError = true;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _statusText = 'فشل تنزيل التحديث';
        });
      }
    }
  }

  Future<void> _installApk(String filePath) async {
    try {
      const platform = MethodChannel('com.alrashedy.erp/app_installer');
      final res = await platform.invokeMethod('installApk', {
        'filePath': filePath,
      });

      if (res == false) {
        // App redirected to settings for unknown sources permission
        debugPrint('Redirected to Unknown Sources settings');
        throw Exception(
          'يرجى تفعيل إذن "تثبيت التطبيقات غير المعروفة" من الإعدادات ثم إعادة المحاولة.',
        );
      }
    } catch (e) {
      debugPrint('Install APK error: $e');
      if (e is Exception) rethrow;
      throw Exception('تعذر تشغيل مُثبّت النظام: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mbReceived = (_receivedBytes / (1024 * 1024)).toStringAsFixed(1);
    final mbTotal = (_totalBytes / (1024 * 1024)).toStringAsFixed(1);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isError ? Colors.red.shade50 : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _isError ? Icons.error_outline : Icons.cloud_download_rounded,
              color: _isError ? Colors.red : AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isError ? 'خطأ في التنزيل' : 'تحديث التطبيق تلقائياً',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isError) ...[
            Text(
              _statusText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _totalBytes > 0 ? _progress : null,
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _totalBytes > 0 ? '$mbReceived MB / $mbTotal MB' : '',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  _totalBytes > 0
                      ? '${(_progress * 100).toStringAsFixed(0)}%'
                      : 'جاري التحميل...',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _isCancelled = true;
            _httpClient?.close();
            Navigator.of(context).pop();
          },
          child: Text(
            _isError ? 'إغلاق' : 'إلغاء التنزيل',
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: AppColors.textMuted,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
