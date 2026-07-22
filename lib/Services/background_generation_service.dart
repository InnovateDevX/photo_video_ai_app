import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../Models/generated_asset.dart';
import 'local_storage_service.dart';
import 'replicate_service.dart';
import 'notification_service.dart';
import 'content_safety_service.dart';

class BackgroundGenerationService {
  static final BackgroundGenerationService _instance = BackgroundGenerationService._internal();
  factory BackgroundGenerationService() => _instance;
  BackgroundGenerationService._internal();

  static const String _pendingKey = 'pending_generations';

  final StreamController<GeneratedAsset> _completionController = StreamController<GeneratedAsset>.broadcast();
  Stream<GeneratedAsset> get onGenerationComplete => _completionController.stream;

  final StreamController<String> _failureController = StreamController<String>.broadcast();
  Stream<String> get onGenerationFailure => _failureController.stream;

  void reportFailure(String message) {
    _failureController.add(message);
  }

  Future<void> _savePendingGeneration({
    required String pollUrl,
    required String cancelUrl,
    required String category,
    required String prompt,
    required int notificationId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> pending = prefs.getStringList(_pendingKey) ?? [];
    pending.add(
      jsonEncode({
        'pollUrl': pollUrl,
        'cancelUrl': cancelUrl,
        'category': category,
        'prompt': prompt,
        'notificationId': notificationId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }),
    );
    await prefs.setStringList(_pendingKey, pending);
    debugPrint('💾 [BackgroundGeneration] Saved pending generation: $pollUrl (cancel: $cancelUrl)');
  }

  Future<void> _removePendingGeneration(String pollUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> pending = prefs.getStringList(_pendingKey) ?? [];
    pending.removeWhere((item) {
      try {
        final data = jsonDecode(item);
        return data['pollUrl'] == pollUrl;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_pendingKey, pending);
    debugPrint('🗑️ [BackgroundGeneration] Removed pending generation: $pollUrl');
  }

  /// Called on app startup to resume any pending generations that were
  /// interrupted when the app was killed.
  Future<void> resumePendingGenerations() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> pending = prefs.getStringList(_pendingKey) ?? [];

    if (pending.isEmpty) {
      debugPrint('✅ [BackgroundGeneration] No pending generations to resume.');
      return;
    }

    debugPrint('🔄 [BackgroundGeneration] Found ${pending.length} pending generation(s). Resuming...');

    for (final item in List<String>.from(pending)) {
      try {
        final data = jsonDecode(item);
        final String pollUrl = data['pollUrl'];
        final String category = data['category'];
        final String prompt = data['prompt'];
        final int notificationId = data['notificationId'];
        final int timestamp = data['timestamp'];

        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (age > 10 * 60 * 1000) {
          debugPrint('⏰ [BackgroundGeneration] Pending generation expired: $pollUrl');
          await _removePendingGeneration(pollUrl);
          await NotificationService().cancelNotification(notificationId);
          continue;
        }

        // Actively poll the pending generation in the foreground
        _pollActiveGeneration(pollUrl: pollUrl, category: category, prompt: prompt, notificationId: notificationId);

      } catch (e) {
        debugPrint('❌ [BackgroundGeneration] Error resuming pending generation: $e');
      }
    }
  }

  void _pollActiveGeneration({
    required String pollUrl,
    required String category,
    required String prompt,
    required int notificationId,
  }) {
    ReplicateService()
        .pollForResult(pollUrl, (double p) {
          final int percent = (p * 100).toInt();
          NotificationService().showProgressNotification(
            id: notificationId,
            title: 'VidZeon',
            body: 'Generating $category ($percent%)...',
            progress: percent,
            payload: 'OPEN_APP',
          );
        })
        .then((String url) async {
          await _removePendingGeneration(pollUrl);
          await NotificationService().cancelNotification(notificationId);
          await saveAndNotifyAsset(url: url, category: category, prompt: prompt);
        })
        .catchError((error) async {
          debugPrint('❌ [BackgroundGeneration] Foreground poll failed: $error');
          await _removePendingGeneration(pollUrl);
          await NotificationService().cancelNotification(notificationId);
          _failureController.add('Background $category generation failed.');
          NotificationService().showGenerationCompleteNotification(
            title: 'VidZeon',
            body: 'Background $category generation failed. Please try again.',
          );
        });
  }

  void takeOverGeneration({
    required int creditCost,
    required String pollUrl,
    required String category,
    required String prompt,
  }) async {
    final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _savePendingGeneration(
      pollUrl: pollUrl,
      cancelUrl: '', 
      category: category,
      prompt: prompt,
      notificationId: notificationId,
    );

    NotificationService().showProgressNotification(
      id: notificationId,
      title: 'VidZeon',
      body: 'Resuming $category generation...',
      progress: null,
      payload: 'OPEN_APP',
    );

    _pollActiveGeneration(pollUrl: pollUrl, category: category, prompt: prompt, notificationId: notificationId);
  }

  void startBackgroundGeneration({
    required int creditCost,
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
    final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    NotificationService().showProgressNotification(
      id: notificationId,
      title: 'VidZeon',
      body: 'Preparing your $category...',
      progress: null, 
      payload: 'OPEN_APP',
    );

    String? currentPollUrl;

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
              title: 'VidZeon',
              body: 'Generating $category ($percent%)...',
              progress: percent,
              payload: 'OPEN_APP',
            );
          },
          onPredictionStarted: (String pollUrl, String cancelUrl) async {
            currentPollUrl = pollUrl;
            await _savePendingGeneration(
              pollUrl: pollUrl,
              cancelUrl: cancelUrl,
              category: category,
              prompt: prompt,
              notificationId: notificationId,
            );
          },
        )
        .then((finalUrl) async {
          if (currentPollUrl != null) {
            await _removePendingGeneration(currentPollUrl!);
          }
          await NotificationService().cancelNotification(notificationId);
          await saveAndNotifyAsset(url: finalUrl, category: category, prompt: prompt);
        })
        .catchError((error) async {
          debugPrint('❌ [BackgroundGeneration] Generation failed: $error');
          if (currentPollUrl != null) {
            await _removePendingGeneration(currentPollUrl!);
          }
          await NotificationService().cancelNotification(notificationId);

          if (error.toString().contains('Generation canceled')) return '';

          String errorMessage = 'Failed to generate $category. Please try again.';
          if (error is NsfwContentException || error.toString().contains('generated_content_restricted')) {
            errorMessage = 'Your generated content was flagged as restricted and could not be saved.';
          }

          _failureController.add(errorMessage);
          NotificationService().showGenerationCompleteNotification(
            title: 'VidZeon',
            body: errorMessage,
          );
          return '';
        });
  }

  void startTwoStageBackgroundGeneration({
    required int creditCost,
    required AIModelConfig imageModel,
    required AIModelConfig videoModel,
    required String imagePrompt,
    required String videoPrompt,
    File? referenceImage,
    String? aspectRatio,
  }) {
    final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    NotificationService().showProgressNotification(
      id: notificationId,
      title: 'VidZeon',
      body: 'Stage 1/2: Editing your photo...',
      progress: null,
      payload: 'OPEN_APP',
    );

    ReplicateService()
        .generateContent(
          modelConfig: imageModel,
          prompt: imagePrompt,
          referenceImage: referenceImage,
          aspectRatio: imageModel.supportsAspectRatio ? aspectRatio : null,
        )
        .then((editedImageUrl) async {
          NotificationService().showProgressNotification(
            id: notificationId,
            title: 'VidZeon',
            body: 'Stage 2/2: Generating video...',
            progress: null,
            payload: 'OPEN_APP',
          );

          final tempFile = await _downloadToTempFile(editedImageUrl);

          return ReplicateService().generateContent(
            modelConfig: videoModel,
            prompt: videoPrompt,
            referenceImage: tempFile,
            aspectRatio: videoModel.supportsAspectRatio ? aspectRatio : null,
          );
        })
        .then((finalVideoUrl) async {
          await NotificationService().cancelNotification(notificationId);
          await saveAndNotifyAsset(
            url: finalVideoUrl,
            category: 'video',
            prompt: videoPrompt,
          );
        })
        .catchError((error) async {
          debugPrint('❌ [BackgroundTwoStage] Failed: $error');
          await NotificationService().cancelNotification(notificationId);

          if (error.toString().contains('Generation canceled')) return null;

          String errorMessage = 'Failed to generate video template. Please try again.';
          if (error is NsfwContentException || error.toString().contains('generated_content_restricted')) {
            errorMessage = 'Your generated content was flagged as restricted and could not be saved.';
          }

          reportFailure(errorMessage);
          NotificationService().showGenerationCompleteNotification(
            title: 'VidZeon',
            body: errorMessage,
          );
          return null;
        });
  }

  Future<File> _downloadToTempFile(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to download image: ${response.statusCode}');
    }
    final tempDir = await getTemporaryDirectory();
    final file = File('\${tempDir.path}/bg_stage1_\${DateTime.now().millisecondsSinceEpoch}.jpg');
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
      final fileName = 'generation_\${DateTime.now().millisecondsSinceEpoch}.$ext';
      final file = File('\${appDir.path}/$fileName');

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
          title: 'VidZeon',
          body: 'Your $category generation is complete!',
          payload: asset.id,
        );
      }
    } catch (e) {
      debugPrint('❌ [BackgroundGeneration] Save error: $e');
    }
  }
}
