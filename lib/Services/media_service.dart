import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'background_generation_service.dart';
import 'notification_service.dart';
import 'local_storage_service.dart';
import 'remote_config_service.dart';
import '../Models/generated_asset.dart';
import '../Widgets/themed_dialog.dart';

class MediaService {
  /// Downloads an image from a URL and saves it to the "VidZeon" gallery album.
  /// Returns the local File if successful.
  static Future<File?> downloadImage(
    BuildContext context,
    String imageUrl, {
    bool isLocal = false,
  }) async {
    try {
      String? filePath;

      if (!isLocal && imageUrl.startsWith('http')) {
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          final file = File(
            '${tempDir.path}/image_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          await file.writeAsBytes(response.bodyBytes);
          filePath = file.path;
        } else {
          throw Exception('Failed to download image from server');
        }
      } else {
        // Already a local path
        filePath = imageUrl;
      }

      final success = await GallerySaver.saveImage(
        filePath,
        albumName: 'VidZeon',
      );
      if (context.mounted && success == true) {
        showThemedDialog(
          context,
          title: 'Success',
          message: 'Saved to gallery!',
          icon: Icons.check_circle_outline,
          iconColor: Colors.green,
        );
        return File(filePath);
      } else if (context.mounted) {
        throw Exception('Failed to save to gallery');
      }
      return null;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed${e.toString()}')),
        );
      } else {
        // Fallback to global notification if context is lost
        BackgroundGenerationService().reportFailure(
          'Download failed${e.toString()}',
        );
      }
      return null;
    }
  }

  /// Downloads a video from a URL or local path and saves it to the gallery.
  /// Returns the local File if successful.
  static Future<File?> downloadVideo(
    BuildContext context,
    String videoUrl, {
    bool isLocal = false,
  }) async {
    try {
      String? filePath;

      if (!isLocal && videoUrl.startsWith('http')) {
        final response = await http.get(Uri.parse(videoUrl));
        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          final file = File(
            '${tempDir.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4',
          );
          await file.writeAsBytes(response.bodyBytes);
          filePath = file.path;
        } else {
          throw Exception('Failed to download video from server');
        }
      } else {
        filePath = videoUrl;
      }

      final success = await GallerySaver.saveVideo(
        filePath,
        albumName: 'VidZeon',
      );
      if (context.mounted && success == true) {
        showThemedDialog(
          context,
          title: 'Success',
          message: 'Video saved to gallery!',
          icon: Icons.check_circle_outline,
          iconColor: Colors.green,
        );
        return File(filePath);
      } else if (context.mounted) {
        throw Exception('Failed to save video to gallery');
      }
      return null;
    } catch (e) {
      if (context.mounted) {
        showThemedDialog(
          context,
          title: 'Error',
          message: 'Download failed${e.toString()}',
          icon: Icons.error_outline,
          iconColor: Colors.red,
        );
      } else {
        BackgroundGenerationService().reportFailure(
          'Download failed${e.toString()}',
        );
      }
      return null;
    }
  }

  /// Helper to append the app link to the shared text
  static Future<String> _getShareTextWithAppLink(String baseText) async {
    try {
      String url = "";
      if (url.isEmpty) {
        final PackageInfo packageInfo = await PackageInfo.fromPlatform();
        final String packageName = packageInfo.packageName;
        url = "https://play.google.com/store/apps/details?id=$packageName";
      }
      return "$baseText\n\nDownload this awesome app: $url";
    } catch (_) {
      return baseText;
    }
  }

  /// Downloads an image from a URL and opens the native share sheet.
  static Future<void> shareImage(
    BuildContext context,
    String imageUrl, {
    String? shareText,
    bool isLocal = false,
  }) async {
    try {
      String? filePath;

      if (!isLocal && imageUrl.startsWith('http')) {
        // Use cache manager to instantly retrieve if already downloaded
        final file = await DefaultCacheManager().getSingleFile(imageUrl);
        filePath = file.path;
      } else {
        filePath = imageUrl;
      }

      final String baseText = shareText ?? 'Check my AI outfit! ✨';
      final String finalText = await _getShareTextWithAppLink(baseText);

      await Share.shareXFiles([XFile(filePath)], text: finalText);
    } catch (e) {
      if (context.mounted) {
        showThemedDialog(
          context,
          title: 'Error',
          message: 'Share failed$e',
          icon: Icons.error_outline,
          iconColor: Colors.red,
        );
      } else {
        BackgroundGenerationService().reportFailure('Share failed$e');
      }
    }
  }

  /// Shares a video from a URL or local path.
  static Future<void> shareVideo(
    BuildContext context,
    String videoUrl, {
    String? shareText,
    bool isLocal = false,
  }) async {
    try {
      String? filePath;

      if (!isLocal && videoUrl.startsWith('http')) {
        // Use cache manager to instantly retrieve if already downloaded
        final file = await DefaultCacheManager().getSingleFile(videoUrl);
        filePath = file.path;
      } else {
        filePath = videoUrl;
      }

      final String baseText =
          shareText ?? 'Check out this video I generated with VidZeon!';
      final String finalText = await _getShareTextWithAppLink(baseText);

      await Share.shareXFiles([XFile(filePath)], text: finalText);
    } catch (e) {
      if (context.mounted) {
        showThemedDialog(
          context,
          title: 'Error',
          message: 'Share failed$e',
          icon: Icons.error_outline,
          iconColor: Colors.red,
        );
      } else {
        BackgroundGenerationService().reportFailure('Share failed$e');
      }
    }
  }

  /// Downloads an image from a URL and returns a [File] in the temporary directory.
  static Future<File?> downloadToTempFile(String imageUrl) async {
    if (!imageUrl.startsWith('http')) {
      return File(imageUrl);
    }
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File(
          '${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
      return null;
    } catch (e) {
      debugPrint('❌ [MediaService] downloadToTempFile failed: $e');
      return null;
    }
  }

  /// Attempts to get a file from cache first, otherwise downloads it.
  static Future<File?> getCachedOrDownloadFile(String imageUrl) async {
    if (!imageUrl.startsWith('http')) {
      return File(imageUrl);
    }
    try {
      // Check cache first
      final FileInfo? fileInfo = await DefaultCacheManager().getFileFromCache(
        imageUrl,
      );
      if (fileInfo != null) {
        debugPrint('✅ [MediaService] Serving image from cache: $imageUrl');
        return fileInfo.file;
      }

      // Fallback to download
      debugPrint(
        'ℹ️ [MediaService] Image not in cache, downloading: $imageUrl',
      );
      return await downloadToTempFile(imageUrl);
    } catch (e) {
      debugPrint('❌ [MediaService] getCachedOrDownloadFile failed: $e');
      return await downloadToTempFile(imageUrl);
    }
  }

  // ── Background Downloads with Progress Notifications ─────────────────────

  /// Downloads an image in the background with a progress notification,
  /// saves to app storage via LocalStorageService, and shows completion notification.
  /// Survives app termination by offloading to the background isolate.
  static void downloadImageInBackground(String imageUrl, {String prompt = ''}) {
    _queueBackgroundDownload(
      url: imageUrl,
      category: 'image',
      fileExtension: 'png',
      prompt: prompt,
    );
  }

  /// Downloads a video in the background with a progress notification,
  /// saves to app storage via LocalStorageService, and shows completion notification.
  /// Survives app termination by offloading to the background isolate.
  static void downloadVideoInBackground(String videoUrl, {String prompt = ''}) {
    _queueBackgroundDownload(
      url: videoUrl,
      category: 'video',
      fileExtension: 'mp4',
      prompt: prompt,
    );
  }

  static Future<void> _queueBackgroundDownload({
    required String url,
    required String category,
    required String fileExtension,
    required String prompt,
  }) async {
    try {
      if (!url.startsWith('http')) {
        // Already a local file — just register it
        final asset = GeneratedAsset(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          filePath: url,
          category: category,
          prompt: prompt,
          createdAt: DateTime.now(),
        );
        await LocalStorageService().saveAsset(asset);
        NotificationService().showGenerationCompleteNotification(
          title: 'VidZeon',
          body:
              '✅ ${category == 'video' ? 'Video' : 'Image'} saved successfully!',
          payload: asset.id,
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final List<String> pendingDownloads =
          prefs.getStringList('background_pending_downloads') ?? [];

      final downloadId = DateTime.now().millisecondsSinceEpoch.toString();
      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(
        100000,
      );

      pendingDownloads.add(
        jsonEncode({
          'id': downloadId,
          'url': url,
          'category': category,
          'fileExtension': fileExtension,
          'prompt': prompt,
          'notificationId': notificationId,
        }),
      );
      await prefs.setStringList(
        'background_pending_downloads',
        pendingDownloads,
      );

      debugPrint('📥 [MediaService] Queued background download: $url');

      // Start background service to process the download
      final service = FlutterBackgroundService();
      if (!await service.isRunning()) {
        await service.startService();
      }
    } catch (e) {
      debugPrint('❌ [MediaService] Failed to queue background download: $e');
      NotificationService().showGenerationCompleteNotification(
        title: 'VidZeon',
        body: 'Failed to start downloading $category.',
      );
    }
  }
}
