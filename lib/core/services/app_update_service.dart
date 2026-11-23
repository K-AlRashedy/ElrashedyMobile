import 'dart:io';
import 'package:flutter/material.dart';
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
  static const String currentVersion = "1.0.0";

  /// Checks if a newer version is available on the server.
  static Future<AppUpdateInfo?> checkForUpdate(ApiClient api) async {
    try {
      final res = await api.get('/api/v1/app/version/');
      if (res is Map<String, dynamic> && res['ok'] == true) {
        final latest = res['latest_version']?.toString() ?? currentVersion;
        final minV = res['min_version']?.toString() ?? currentVersion;
        final notes = res['release_notes']?.toString() ?? 'تحسينات عامة على النظام.';
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
                child: const Icon(Icons.system_update_rounded, color: AppColors.primary, size: 36),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  if (downloadUrl.isNotEmpty) {
                    final uri = Uri.parse(downloadUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                },
                icon: Icon(isIOS ? Icons.apple_rounded : Icons.android_rounded),
                label: Text(
                  isIOS ? 'تحديث التطبيق للآيفون (IPA)' : 'تحديث وتنزيل التطبيق (APK) ⚡',
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              if (!info.forceUpdate) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'تذكيري لاحقاً',
                    style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
