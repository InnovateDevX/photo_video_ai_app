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
  Stream<GeneratedAsset> get onGenerationComplete => _completionController.stream;

  // Stream to notify about failures
  final StreamController<String> _failureController =
      StreamController<String>.broadcast();
  Stream<String> get onGenerationFailure => _failureController.stream;

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
    final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    
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

          // Save it to Local App Storage instead of Gallery
          try {
            final appDir = await getApplicationDocumentsDirectory();
            
            // Determine extension
            String ext = category == 'video' ? 'mp4' : 'png';
            if (url.toLowerCase().endsWith('.jpg') || url.toLowerCase().endsWith('.jpeg')) ext = 'jpg';
            if (url.toLowerCase().endsWith('.webp')) ext = 'webp';
            if (url.toLowerCase().endsWith('.gif')) ext = 'gif';

            final fileName = 'generation_${DateTime.now().millisecondsSinceEpoch}.$ext';
            final file = File('${appDir.path}/$fileName');

            // Download file
            final response = await http.get(Uri.parse(url));
            if (response.statusCode == 200) {
              await file.writeAsBytes(response.bodyBytes);
              debugPrint('💾 [BackgroundGeneration] Downloaded locally to: ${file.path}');
              
              // Save to Local DB
              final asset = GeneratedAsset(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                filePath: file.path,
                category: category,
                prompt: prompt,
                createdAt: DateTime.now(),
              );
              await LocalStorageService().saveAsset(asset);
              
              debugPrint('💾 [BackgroundGeneration] Successfully saved to Local DB.');
              debugPrint('📍 [BackgroundGeneration] Local Path: ${file.path}');

              // Notify listeners (UI)
              _completionController.add(asset);

              // Send local notification
              NotificationService().showGenerationCompleteNotification(
                title: 'Trail AI Studio',
                body: 'Your $category generation is complete! Tap to view.',
                payload: asset.id, // Passing the local asset ID
              );
            } else {
              debugPrint('❌ [BackgroundGeneration] Failed to download to local storage. Status: ${response.statusCode}');
            }
          } catch (e) {
            debugPrint(
              '❌ [BackgroundGeneration] Exception saving to local storage: $e',
            );
          }
        })
        .catchError((error) async {
          debugPrint('❌ [BackgroundGeneration] Generation failed: $error');
          
          // Cancel progress notification
          await NotificationService().cancelNotification(notificationId);
          
          _failureController.add('Failed to generate $category. Please try again.');
          NotificationService().showGenerationCompleteNotification(
            title: 'Trail AI Studio',
            body: 'Failed to generate $category. Please try again.',
          );
        });
  }
}
