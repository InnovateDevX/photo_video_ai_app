import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
const String _pendingKey = 'background_pending_generations';
final Set<String> _activeDownloads = {};

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Initialize notifications for the isolate
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await _flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
  );

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Background polling loop
  Timer.periodic(const Duration(seconds: 3), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Ensure we get the latest data from the main isolate

    final List<String> pending = prefs.getStringList(_pendingKey) ?? [];
    final List<String> pendingDownloads =
        prefs.getStringList('background_pending_downloads') ?? [];

    if (pending.isEmpty &&
        pendingDownloads.isEmpty &&
        _activeDownloads.isEmpty) {
      // If nothing is pending, we can stop the service to save battery.
      debugPrint(
        '🛑 [ForegroundTask] No pending tasks or downloads. Stopping service.',
      );
      service.stopSelf();
      timer.cancel();
      return;
    }

    // Process background downloads
    for (int i = 0; i < pendingDownloads.length; i++) {
      try {
        final data = jsonDecode(pendingDownloads[i]);
        final String id = data['id'];

        if (!_activeDownloads.contains(id)) {
          _activeDownloads.add(id);
          _processDownload(data, prefs).catchError((e) {
            debugPrint('❌ [ForegroundTask] Download process error: $e');
            _activeDownloads.remove(id);
          });
        }
      } catch (e) {
        debugPrint('❌ [ForegroundTask] Error reading pending download: $e');
      }
    }

    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        String notificationBody = 'Processing...';
        if (pending.isNotEmpty) {
          notificationBody = 'Generating ${pending.length} item(s) in background...';
        } else if (pendingDownloads.isNotEmpty || _activeDownloads.isNotEmpty) {
          notificationBody = 'Saving media to gallery...';
        }

        // Keep the sticky notification updated with the number of pending tasks
        _flutterLocalNotificationsPlugin.show(
          id: 888, // Foreground service notification ID
          title: 'VidZeon',
          body: notificationBody,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'ai_generation_channel',
              'AI Generation',
              channelDescription: 'Ongoing generation progress',
              icon: '@mipmap/ic_launcher',
              ongoing: true,
              importance: Importance.low, // Low importance for sticky service
            ),
          ),
        );
      }
    }

    // Process each pending generation
    for (int i = 0; i < pending.length; i++) {
      try {
        final data = jsonDecode(pending[i]);
        final String pollUrl = data['pollUrl'];
        final String cancelUrl = data['cancelUrl'] ?? '';
        final String category = data['category'];
        final String prompt = data['prompt'];
        final int notificationId = data['notificationId'];
        final int timestamp = data['timestamp'];
        final String authToken =
            data['authToken'] ?? ''; // We must pass this from main isolate!

        if (authToken.isEmpty) continue;

        // Check for expiration (15 mins)
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (age > 15 * 60 * 1000) {
          // Cancel the prediction before removing
          if (cancelUrl.isNotEmpty) {
            await _cancelPrediction(cancelUrl, authToken);
          }
          await _removePendingGeneration(pollUrl, prefs);
          await _flutterLocalNotificationsPlugin.cancel(id: notificationId);
          continue;
        }

        // Poll Replicate API
        final response = await http.get(
          Uri.parse(pollUrl),
          headers: {'Authorization': 'Bearer $authToken'},
        );

        if (response.statusCode != 200) {
          continue; // Wait for next tick
        }

        final responseData = jsonDecode(response.body);
        final status = responseData['status'];

        if (status == 'starting' || status == 'processing') {
          // Update progress notification
          final logs = responseData['logs'] as String?;
          int percent = 0;
          if (logs != null && logs.isNotEmpty) {
            final lines = logs.split('\n');
            for (final line in lines.reversed) {
              if (line.contains('%|')) {
                final match = RegExp(r'(\d+)%\|').firstMatch(line);
                if (match != null) {
                  percent = int.tryParse(match.group(1) ?? '0') ?? 0;
                  break;
                }
              }
            }
          }

          _showProgressNotification(
            id: notificationId,
            title: 'VidZeon',
            body: 'Generating $category ($percent%)...',
            progress: percent,
          );
        } else if (status == 'succeeded') {
          // Finished!
          await _removePendingGeneration(pollUrl, prefs);
          await _flutterLocalNotificationsPlugin.cancel(id: notificationId);

          dynamic output = responseData['output'];
          String url = '';
          if (output is List && output.isNotEmpty) {
            url = output[0].toString();
          } else if (output is String) {
            url = output;
          }

          if (url.isNotEmpty) {
            await _downloadAndSaveAsset(
              url: url,
              category: category,
              prompt: prompt,
            );
          }
        } else if (status == 'failed' || status == 'canceled') {
          await _removePendingGeneration(pollUrl, prefs);
          await _flutterLocalNotificationsPlugin.cancel(id: notificationId);

          _showCompletionNotification(
            title: 'VidZeon',
            body: 'Background $category generation failed.',
          );
        }
      } catch (e) {
        debugPrint('❌ [ForegroundTask] Polling error: $e');
      }
    }
  });
}

Future<void> _removePendingGeneration(
  String pollUrl,
  SharedPreferences prefs,
) async {
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
}

/// Cancels a prediction by sending POST to its cancel URL.
/// Called from the background isolate when a prediction expires or is cancelled.
Future<void> _cancelPrediction(String cancelUrl, String authToken) async {
  try {
    debugPrint('🚫 [ForegroundTask] POST $cancelUrl (Canceling prediction)');
    final response = await http.post(
      Uri.parse(cancelUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      debugPrint(
        '⚠️ [ForegroundTask] Failed to cancel prediction: ${response.statusCode}',
      );
    } else {
      debugPrint('✅ [ForegroundTask] Prediction cancelled successfully.');
    }
  } catch (e) {
    debugPrint('❌ [ForegroundTask] Error cancelling prediction: $e');
  }
}

Future<void> _downloadAndSaveAsset({
  required String url,
  required String category,
  required String prompt,
}) async {
  try {
    final appDir = await getApplicationDocumentsDirectory();
    String ext = category == 'video' ? 'mp4' : 'png';
    final fileName = 'generation_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final file = File('${appDir.path}/$fileName');

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      await file.writeAsBytes(response.bodyBytes);

      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final List<String> completed =
          prefs.getStringList('background_completed_assets') ?? [];
      completed.add(
        jsonEncode({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'filePath': file.path,
          'category': category,
          'prompt': prompt,
          'createdAt': DateTime.now().toIso8601String(),
        }),
      );
      await prefs.setStringList('background_completed_assets', completed);

      _showCompletionNotification(
        title: 'VidZeon',
        body: 'Your $category generation is complete!',
      );
    }
  } catch (e) {
    debugPrint('❌ [ForegroundTask] Save error: $e');
  }
}

void _showProgressNotification({
  required int id,
  required String title,
  required String body,
  required int progress,
}) {
  _flutterLocalNotificationsPlugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'ai_generation_channel',
        'AI Generation',
        channelDescription: 'Ongoing generation progress',
        icon: '@mipmap/ic_launcher',
        showProgress: true,
        maxProgress: 100,
        progress: progress,
        indeterminate: progress == 0,
        ongoing: true,
        importance: Importance.defaultImportance,
      ),
    ),
  );
}

void _showCompletionNotification({
  required String title,
  required String body,
}) {
  final int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
  _flutterLocalNotificationsPlugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'ai_generation_channel',
        'AI Generation',
        channelDescription: 'Ongoing generation progress',
        icon: '@mipmap/ic_launcher',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}

Future<void> _processDownload(
  Map<String, dynamic> data,
  SharedPreferences prefs,
) async {
  final String id = data['id'];
  final String url = data['url'];
  final String category = data['category'];
  final String fileExtension = data['fileExtension'];
  final String prompt = data['prompt'];
  final int notificationId = data['notificationId'];

  try {
    _showProgressNotification(
      id: notificationId,
      title: 'VidZeon',
      body: 'Saving $category...',
      progress: 0,
    );

    final request = http.Request('GET', Uri.parse(url));
    final http.StreamedResponse response = await http.Client().send(request);

    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode}');
    }

    final int totalBytes = response.contentLength ?? -1;
    final List<int> bytes = [];
    int receivedBytes = 0;
    int lastPercent = 0;

    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
      receivedBytes += chunk.length;

      if (totalBytes > 0) {
        final int percent = ((receivedBytes / totalBytes) * 100).toInt();
        if (percent - lastPercent >= 5 || percent == 100) {
          lastPercent = percent;
          _showProgressNotification(
            id: notificationId,
            title: 'VidZeon',
            body: 'Saving $category ($percent%)...',
            progress: percent,
          );
        }
      }
    }

    final appDir = await getApplicationDocumentsDirectory();
    final fileName =
        '${category}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    final file = File('${appDir.path}/$fileName');
    await file.writeAsBytes(bytes);

    await _flutterLocalNotificationsPlugin.cancel(id: notificationId);

    // Save to completed assets
    await prefs.reload();
    final List<String> completed =
        prefs.getStringList('background_completed_assets') ?? [];
    completed.add(
      jsonEncode({
        'id': id,
        'filePath': file.path,
        'category': category,
        'prompt': prompt,
        'createdAt': DateTime.now().toIso8601String(),
      }),
    );
    await prefs.setStringList('background_completed_assets', completed);

    _showCompletionNotification(
      title: 'VidZeon',
      body: '✅ ${category == 'video' ? 'Video' : 'Image'} saved successfully!',
    );
  } catch (e) {
    debugPrint('❌ [ForegroundTask] Background download failed: $e');
    await _flutterLocalNotificationsPlugin.cancel(id: notificationId);
    _showCompletionNotification(
      title: 'VidZeon',
      body: 'Failed to save $category',
    );
  } finally {
    // Remove from pending list and active downloads
    await prefs.reload();
    final List<String> pending =
        prefs.getStringList('background_pending_downloads') ?? [];
    pending.removeWhere((item) {
      try {
        return jsonDecode(item)['id'] == id;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList('background_pending_downloads', pending);
    _activeDownloads.remove(id);
  }
}

Future<void> _handleCancelAllGenerations() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final List<String> pending = prefs.getStringList(_pendingKey) ?? [];

  if (pending.isEmpty) {
    debugPrint('🚫 [ForegroundTask] No pending predictions to cancel.');
    return;
  }

  debugPrint(
    '🚫 [ForegroundTask] Checking ${pending.length} prediction(s) to cancel...',
  );

  for (final item in List<String>.from(pending)) {
    try {
      final data = jsonDecode(item);
      final String pollUrl = data['pollUrl'];
      final String cancelUrl = data['cancelUrl'] ?? '';
      final int notificationId = data['notificationId'];
      final String authToken = data['authToken'] ?? '';

      if (pollUrl.isEmpty || authToken.isEmpty) {
        await _removePendingGeneration(pollUrl, prefs);
        continue;
      }

      final response = await http.get(
        Uri.parse(pollUrl),
        headers: {'Authorization': 'Bearer $authToken'},
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final String status = responseData['status'];

        if (status == 'succeeded') {
          debugPrint(
            '✅ [ForegroundTask] Prediction already succeeded - letting it download',
          );
          continue;
        } else if (status == 'failed' || status == 'canceled') {
          await _removePendingGeneration(pollUrl, prefs);
          await _flutterLocalNotificationsPlugin.cancel(id: notificationId);
          continue;
        }
      }

      // Cancel it
      if (cancelUrl.isNotEmpty) {
        await _cancelPrediction(cancelUrl, authToken);
      }

      await _flutterLocalNotificationsPlugin.cancel(id: notificationId);
      await _removePendingGeneration(pollUrl, prefs);
    } catch (e) {
      debugPrint('❌ [ForegroundTask] Error cancelling prediction: $e');
    }
  }

  debugPrint('✅ [ForegroundTask] Cancellation complete.');
}
