import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:localization/localization.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'background_generation_service.dart';
import 'notification_service.dart';
import 'local_storage_service.dart';
import '../Models/generated_asset.dart';

class MediaService {
  /// Downloads an image from a URL and saves it to the "Trail AI" gallery album.
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
        albumName: 'Trail AI',
      );
      if (context.mounted && success == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Saved to gallery!'),
            backgroundColor: Colors.green,
          ),
        );
        return File(filePath);
      } else if (context.mounted) {
        throw Exception('Failed to save to gallery');
      }
      return null;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'download_failed'.i18n()}${e.toString()}')),
        );
      } else {
        // Fallback to global notification if context is lost
        BackgroundGenerationService().reportFailure(
          '${'download_failed'.i18n()}${e.toString()}',
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
        albumName: 'Trail AI',
      );
      if (context.mounted && success == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Video saved to gallery!'),
            backgroundColor: Colors.green,
          ),
        );
        return File(filePath);
      } else if (context.mounted) {
        throw Exception('Failed to save video to gallery');
      }
      return null;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'download_failed'.i18n()}${e.toString()}')),
        );
      } else {
        BackgroundGenerationService().reportFailure(
          '${'download_failed'.i18n()}${e.toString()}',
        );
      }
      return null;
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

      await Share.shareXFiles([
        XFile(filePath),
      ], text: shareText ?? 'share_outfit_text'.i18n());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${'share_failed'.i18n()}$e')));
      } else {
        BackgroundGenerationService().reportFailure(
          '${'share_failed'.i18n()}$e',
        );
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

      await Share.shareXFiles(
        [XFile(filePath)],
        text:
            shareText ??
            'Check out this video I generated with Trail AI!'.i18n(),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${'share_failed'.i18n()}$e')));
      } else {
        BackgroundGenerationService().reportFailure(
          '${'share_failed'.i18n()}$e',
        );
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
          title: 'Trail AI Studio',
          body: '✅ ${category == 'video' ? 'Video' : 'Image'} saved successfully!',
          payload: asset.id,
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final List<String> pendingDownloads = prefs.getStringList('background_pending_downloads') ?? [];
      
      final downloadId = DateTime.now().millisecondsSinceEpoch.toString();
      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      
      pendingDownloads.add(jsonEncode({
        'id': downloadId,
        'url': url,
        'category': category,
        'fileExtension': fileExtension,
        'prompt': prompt,
        'notificationId': notificationId,
      }));
      await prefs.setStringList('background_pending_downloads', pendingDownloads);
      
      debugPrint('📥 [MediaService] Queued background download: $url');

      // Start background service to process the download
      final service = FlutterBackgroundService();
      if (!await service.isRunning()) {
        await service.startService();
      }
    } catch (e) {
      debugPrint('❌ [MediaService] Failed to queue background download: $e');
      NotificationService().showGenerationCompleteNotification(
        title: 'Trail AI Studio',
        body: 'Failed to start downloading $category.',
      );
    }
  }
}
