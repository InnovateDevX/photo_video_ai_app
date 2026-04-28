import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:localization/localization.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'background_generation_service.dart';

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

      if (filePath != null) {
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

      if (filePath != null) {
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
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          final file = File(
            '${tempDir.path}/share_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          await file.writeAsBytes(response.bodyBytes);
          filePath = file.path;
        } else {
          throw Exception('Failed to download image for sharing');
        }
      } else {
        filePath = imageUrl;
      }

      if (filePath != null) {
        await Share.shareXFiles([
          XFile(filePath),
        ], text: shareText ?? 'share_outfit_text'.i18n());
      }
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
        final response = await http.get(Uri.parse(videoUrl));
        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          final file = File(
            '${tempDir.path}/share_video_${DateTime.now().millisecondsSinceEpoch}.mp4',
          );
          await file.writeAsBytes(response.bodyBytes);
          filePath = file.path;
        } else {
          throw Exception('Failed to download video for sharing');
        }
      } else {
        filePath = videoUrl;
      }

      if (filePath != null) {
        await Share.shareXFiles(
          [XFile(filePath)],
          text:
              shareText ??
              'Check out this video I generated with Trail AI!'.i18n(),
        );
      }
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
}
