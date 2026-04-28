import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../Models/generated_asset.dart';
import 'local_storage_service.dart';
import 'replicate_service.dart';
import 'notification_service.dart';

class BackgroundGenerationService {
  static final BackgroundGenerationService _instance =
      BackgroundGenerationService._internal();
  factory BackgroundGenerationService() => _instance;
  BackgroundGenerationService._internal();

  // Stream to notify the UI when a generation is complete
  final StreamController<GeneratedAsset> _completionController =
      StreamController<GeneratedAsset>.broadcast();
  Stream<GeneratedAsset> get onGenerationComplete =>
      _completionController.stream;

  // Stream to notify about failures
  final StreamController<String> _failureController =
      StreamController<String>.broadcast();
  Stream<String> get onGenerationFailure => _failureController.stream;

  /// Reports a failure manually (e.g. from MediaService when context is lost)
  void reportFailure(String message) {
    _failureController.add(message);
  }

  /// Starts the generation logic independently of the calling widget so that
  /// it can continue even if the widget is dismounted (the user navigates away).
  void startBackgroundGeneration({
    required String category,
    required AIModelConfig modelConfig,
    required String prompt,
    String? aspectRatio,
    int? width,
    int? height,
    File? referenceImage,
    List<File>? images,
    Map<String, dynamic>? extraVariables,
  }) {
    // Assign a unique notification ID for this generation
    final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(
      100000,
    );

    // Show initial progress notification
    NotificationService().showProgressNotification(
      id: notificationId,
      title: 'Trail AI Studio',
      body: 'Preparing your $category...',
      progress: null, // Indeterminate at first
      payload: 'OPEN_APP',
    );

    // We do NOT await this Future here. We let it run in the background.
    ReplicateService()
        .generateContent(
          modelConfig: modelConfig,
          prompt: prompt,
          aspectRatio: aspectRatio,
          width: width,
          height: height,
          referenceImage: referenceImage,
          images: images,
          extraVariables: extraVariables,
          onProgress: (double p) {
            final int percent = (p * 100).toInt();
            NotificationService().showProgressNotification(
              id: notificationId,
              title: 'Trail AI Studio',
              body: 'Generating $category ($percent%)...',
              progress: percent,
              payload: 'OPEN_APP',
            );
          },
        )
        .then((String url) async {
          debugPrint(
            '✅ [BackgroundGeneration] Generation completed! URL: $url',
          );

          // Cancel progress notification now that work is done
          await NotificationService().cancelNotification(notificationId);

          // Save to local storage and DB
          await saveAndNotifyAsset(
            url: url,
            category: category,
            prompt: prompt,
          );
        })
        .catchError((error) async {
          debugPrint('❌ [BackgroundGeneration] Generation failed: $error');

          // Cancel progress notification
          await NotificationService().cancelNotification(notificationId);

          _failureController.add(
            'Failed to generate $category. Please try again.',
          );
          NotificationService().showGenerationCompleteNotification(
            title: 'Trail AI Studio',
            body: 'Failed to generate $category. Please try again.',
          );
        });
  }

  /// Starts a two-stage generation (Image Edit -> Video Generation) in the background.
  void startTwoStageBackgroundGeneration({
    required AIModelConfig imageModel,
    required AIModelConfig videoModel,
    required String imagePrompt,
    required String videoPrompt,
    File? referenceImage,
    String? aspectRatio,
  }) {
    final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(
      100000,
    );

    NotificationService().showProgressNotification(
      id: notificationId,
      title: 'Trail AI Studio',
      body: 'Stage 1/2: Editing your photo...',
      progress: null,
      payload: 'OPEN_APP',
    );

    // ── Stage 1: Image Editing ──────────────────────────────────────────
    ReplicateService()
        .generateContent(
          modelConfig: imageModel,
          prompt: imagePrompt,
          referenceImage: referenceImage,
          aspectRatio:
              imageModel.supportsAspectRatio ? aspectRatio : null,
        )
        .then((editedImageUrl) async {
          debugPrint(
            '✅ [BackgroundTwoStage] Stage 1 complete: $editedImageUrl',
          );

          NotificationService().showProgressNotification(
            id: notificationId,
            title: 'Trail AI Studio',
            body: 'Stage 2/2: Generating video...',
            progress: null,
            payload: 'OPEN_APP',
          );

          // Download edited image to temp file
          final tempFile = await _downloadToTempFile(editedImageUrl);

          // ── Stage 2: Video Generation ─────────────────────────────────────
          return ReplicateService().generateContent(
            modelConfig: videoModel,
            prompt: videoPrompt,
            referenceImage: tempFile,
            aspectRatio:
                videoModel.supportsAspectRatio ? aspectRatio : null,
          );
        })
        .then((finalVideoUrl) async {
          debugPrint(
            '✅ [BackgroundTwoStage] Stage 2 complete! URL: $finalVideoUrl',
          );
          await NotificationService().cancelNotification(notificationId);

          // Save to local storage and DB (similar to single stage)
          await saveAndNotifyAsset(
            url: finalVideoUrl,
            category: 'video',
            prompt: videoPrompt,
          );
        })
        .catchError((error) async {
          debugPrint('❌ [BackgroundTwoStage] Failed: $error');
          await NotificationService().cancelNotification(notificationId);
          reportFailure('Failed to generate video template. Please try again.');
        });
  }

  Future<File> _downloadToTempFile(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to download image: ${response.statusCode}');
    }
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/bg_stage1_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  Future<void> saveAndNotifyAsset({
    required String url,
    required String category,
    required String prompt,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      String ext = category == 'video' ? 'mp4' : 'png';
      final fileName =
          'generation_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final file = File('${appDir.path}/$fileName');

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        final asset = GeneratedAsset(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          filePath: file.path,
          category: category,
          prompt: prompt,
          createdAt: DateTime.now(),
        );
        await LocalStorageService().saveAsset(asset);
        _completionController.add(asset);
        NotificationService().showGenerationCompleteNotification(
          title: 'Trail AI Studio',
          body: 'Your $category generation is complete!',
          payload: asset.id,
        );
      }
    } catch (e) {
      debugPrint('❌ [BackgroundGeneration] Save error: $e');
    }
  }
}
