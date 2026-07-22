import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../Models/generated_asset.dart';
import 'local_storage_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:vidzeon/Services/foreground_task_handler.dart';
import 'replicate_service.dart';
import 'notification_service.dart';
import 'content_safety_service.dart';

class BackgroundGenerationService {
  static final BackgroundGenerationService _instance =
      BackgroundGenerationService._internal();
  factory BackgroundGenerationService() => _instance;
  BackgroundGenerationService._internal();

  static const String _pendingKey = 'pending_generations';

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

  // ── Pending Generation Persistence ──────────────────────────────────────────

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
        'authToken':
            ReplicateService().authToken, // Passed for the background isolate
      }),
    );
    await prefs.setStringList(_pendingKey, pending);
    debugPrint(
      '💾 [BackgroundGeneration] Saved pending generation: $pollUrl (cancel: $cancelUrl)',
    );
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
    debugPrint(
      '🗑️ [BackgroundGeneration] Removed pending generation: $pollUrl',
    );
  }

  Future<void> initializeBackgroundService() async {
    try {
      final service = FlutterBackgroundService();

      try {
        final bool alreadyRunning = await service.isRunning();
        if (alreadyRunning) {
          debugPrint(
            '✅ [BackgroundService] Already running from a previous session — '
            'skipping configure() to avoid re-entrancy hang',
          );
          return;
        }
      } catch (e) {
        debugPrint(
          '⚠️ [BackgroundService] isRunning() check failed (continuing): $e',
        );
      }

      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: 'ai_generation_channel',
          initialNotificationTitle: 'VidZeon',
          initialNotificationContent: 'Processing...',
          foregroundServiceNotificationId: 888,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStart,
          onBackground: (ServiceInstance service) {
            return true;
          },
        ),
      );
    } catch (e) {
      debugPrint('⚠️ [BackgroundService] Service init bypassed gracefully: $e');
    }
  }

  /// Called on app startup to resume any pending generations that were
  /// interrupted when the app was killed.
  Future<void> resumePendingGenerations() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Sync any assets completed by the background isolate while the UI was killed
    final List<String> completed =
        prefs.getStringList('background_completed_assets') ?? [];
    if (completed.isNotEmpty) {
      for (final item in completed) {
        try {
          final data = jsonDecode(item);
          final asset = GeneratedAsset(
            id: data['id'],
            filePath: data['filePath'],
            category: data['category'],
            prompt: data['prompt'],
            createdAt: DateTime.parse(data['createdAt']),
          );
          await LocalStorageService().saveAsset(asset);
          _completionController.add(asset);
        } catch (e) {
          debugPrint(
            '❌ [BackgroundGeneration] Failed to sync completed asset: $e',
          );
        }
      }
      await prefs.setStringList('background_completed_assets', []);
    }

    final List<String> pending = prefs.getStringList(_pendingKey) ?? [];

    if (pending.isEmpty) {
      debugPrint('✅ [BackgroundGeneration] No pending generations to resume.');
      return;
    }

    debugPrint(
      '🔄 [BackgroundGeneration] Found ${pending.length} pending generation(s). Resuming...',
    );

    // Process each pending generation
    for (final item in List<String>.from(pending)) {
      try {
        final data = jsonDecode(item);
        final String pollUrl = data['pollUrl'];
        final String category = data['category'];
        final String prompt = data['prompt'];
        final int notificationId = data['notificationId'];
        final int timestamp = data['timestamp'];

        // Check if older than 10 minutes — likely expired
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (age > 10 * 60 * 1000) {
          debugPrint(
            '⏰ [BackgroundGeneration] Pending generation expired (${(age / 60000).toStringAsFixed(1)} min old): $pollUrl',
          );
          await _removePendingGeneration(pollUrl);
          await NotificationService().cancelNotification(notificationId);
          continue;
        }

        // Poll once to check current status
        await _checkAndResumePrediction(
          pollUrl: pollUrl,
          category: category,
          prompt: prompt,
          notificationId: notificationId,
        );
      } catch (e) {
        debugPrint(
          '❌ [BackgroundGeneration] Error resuming pending generation: $e',
        );
      }
    }
  }

  Future<void> _checkAndResumePrediction({
    required String pollUrl,
    required String category,
    required String prompt,
    required int notificationId,
  }) async {
    try {
      final replicateService = ReplicateService();
      await replicateService.initialize();

      // Single poll to check status
      final response = await http.get(
        Uri.parse(pollUrl),
        headers: {'Authorization': 'Bearer ${replicateService.authToken}'},
      );

      if (response.statusCode != 200) {
        debugPrint(
          '❌ [BackgroundGeneration] Resume poll failed: ${response.statusCode}',
        );
        await _removePendingGeneration(pollUrl);
        await NotificationService().cancelNotification(notificationId);
        return;
      }

      final data = jsonDecode(response.body);
      final status = data['status'];

      debugPrint('🔄 [BackgroundGeneration] Resume check — status: $status');

      if (status == 'succeeded') {
        final url = replicateService.extractOutput(data['output']);
        await _removePendingGeneration(pollUrl);
        await NotificationService().cancelNotification(notificationId);
        await saveAndNotifyAsset(url: url, category: category, prompt: prompt);
      } else if (status == 'failed' || status == 'canceled') {
        await _removePendingGeneration(pollUrl);
        await NotificationService().cancelNotification(notificationId);
        _failureController.add('Background $category generation failed.');
        NotificationService().showGenerationCompleteNotification(
          title: 'VidZeon',
          body: 'Background $category generation failed. Please try again.',
        );
      } else {
        // Still processing — resume polling in background
        debugPrint(
          '⏳ [BackgroundGeneration] Still processing, resuming poll...',
        );
        NotificationService().showProgressNotification(
          id: notificationId,
          title: 'VidZeon',
          body: 'Resuming $category generation...',
          progress: null,
          payload: 'OPEN_APP',
        );

        // Resume polling in the background (fire and forget)
        replicateService
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
              await saveAndNotifyAsset(
                url: url,
                category: category,
                prompt: prompt,
              );
            })
            .catchError((error) async {
              debugPrint(
                '❌ [BackgroundGeneration] Resumed poll failed: $error',
              );
              await _removePendingGeneration(pollUrl);
              await NotificationService().cancelNotification(notificationId);
              _failureController.add('Background $category generation failed.');
              NotificationService().showGenerationCompleteNotification(
                title: 'VidZeon',
                body:
                    'Background $category generation failed. Please try again.',
              );
            });
      }
    } catch (e) {
      debugPrint('❌ [BackgroundGeneration] Resume error: $e');
      await _removePendingGeneration(pollUrl);
      await NotificationService().cancelNotification(notificationId);
    }
  }

  /// Takes over an already running generation (e.g. user clicked "Generate in Background" mid-way).
  void takeOverGeneration({
    required String pollUrl,
    required String category,
    required String prompt,
  }) async {
    final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(
      100000,
    );

    // Save so it survives kills (cancelUrl not available here)
    await _savePendingGeneration(
      pollUrl: pollUrl,
      cancelUrl: '', // Not available when taking over
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

    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }
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
      title: 'VidZeon',
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
              title: 'VidZeon',
              body: 'Generating $category ($percent%)...',
              progress: percent,
              payload: 'OPEN_APP',
            );
          },
          onPredictionStarted: (String pollUrl, String cancelUrl) async {
            // Persist the poll URL and cancel URL so we can resume or cancel if app is killed
            await _savePendingGeneration(
              pollUrl: pollUrl,
              cancelUrl: cancelUrl,
              category: category,
              prompt: prompt,
              notificationId: notificationId,
            );

            // Start the foreground service to handle the polling
            final service = FlutterBackgroundService();
            if (!await service.isRunning()) {
              await service.startService();
            }
          },
        )
        .catchError((error) async {
          debugPrint('❌ [BackgroundGeneration] Generation failed: $error');

          // Cancel progress notification
          await NotificationService().cancelNotification(notificationId);

          if (error.toString().contains('Generation canceled')) {
            // Silently ignore explicit cancellations
            return '';
          }

          String errorMessage =
              'Failed to generate $category. Please try again.';
          if (error is NsfwContentException ||
              error.toString().contains('generated_content_restricted')) {
            errorMessage =
                'Your generated content was flagged as restricted and could not be saved.';
          }

          _failureController.add(errorMessage);
          NotificationService().showGenerationCompleteNotification(
            title: 'VidZeon',
            body: errorMessage,
          );
          return '';
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
      title: 'VidZeon',
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
          aspectRatio: imageModel.supportsAspectRatio ? aspectRatio : null,
        )
        .then((editedImageUrl) async {
          debugPrint(
            '✅ [BackgroundTwoStage] Stage 1 complete: $editedImageUrl',
          );

          NotificationService().showProgressNotification(
            id: notificationId,
            title: 'VidZeon',
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
            aspectRatio: videoModel.supportsAspectRatio ? aspectRatio : null,
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

          if (error.toString().contains('Generation canceled')) {
            // Silently ignore explicit cancellations
            return null;
          }

          String errorMessage =
              'Failed to generate video template. Please try again.';
          if (error is NsfwContentException ||
              error.toString().contains('generated_content_restricted')) {
            errorMessage =
                'Your generated content was flagged as restricted and could not be saved.';
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
