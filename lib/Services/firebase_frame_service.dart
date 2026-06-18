import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FirebaseFrameService {
  static final FirebaseFrameService _instance =
      FirebaseFrameService._internal();
  factory FirebaseFrameService() => _instance;
  FirebaseFrameService._internal();

  // Cached urls per aspect ratio folder
  final Map<String, List<String>> _cachedFrames = {};
  final Set<String> _loadingRatios = {};
  final Set<String> _fetchedRatios = {};

  List<String> urlsForRatio(String ratio) => _cachedFrames[ratio] ?? [];
  bool hasFetched(String ratio) => _fetchedRatios.contains(ratio);
  bool isLoading(String ratio) => _loadingRatios.contains(ratio);

  /// Helper to determine the closest aspect ratio folder name based on a double ratio (width/height).
  String getClosestRatioFolder(double aspectRatio) {
    if (aspectRatio <= 0) return '1x1';

    // Ratios:
    // 9:16 = 0.5625
    // 4:5  = 0.8
    // 1:1  = 1.0
    // 16:9 = 1.777

    final Map<String, double> targetRatios = {
      '9x16': 9 / 16,
      '4x5': 4 / 5,
      '1x1': 1.0,
      '16x9': 16 / 9,
    };

    String closest = '1x1';
    double minDiff = double.infinity;

    for (var entry in targetRatios.entries) {
      final diff = (aspectRatio - entry.value).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = entry.key;
      }
    }
    return closest;
  }

  /// Fetch frames for a specific aspect ratio folder.
  Future<List<String>> fetchFrames(
    String ratioFolder, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _fetchedRatios.contains(ratioFolder)) {
      return _cachedFrames[ratioFolder] ?? [];
    }
    if (_loadingRatios.contains(ratioFolder)) {
      while (_loadingRatios.contains(ratioFolder)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _cachedFrames[ratioFolder] ?? [];
    }

    _loadingRatios.add(ratioFolder);
    try {
      debugPrint(
        '[FirebaseFrameService] Fetching frames for "$ratioFolder"...',
      );
      final result = await FirebaseStorage.instance
          .ref('frames/$ratioFolder')
          .listAll()
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw TimeoutException('list() timed out for $ratioFolder'),
          );
      final refs = result.items;
      final urls = await Future.wait(refs.map((r) => r.getDownloadURL()));
      _cachedFrames[ratioFolder] = urls;
      _fetchedRatios.add(ratioFolder);
      debugPrint(
        '[FirebaseFrameService] Fetched ${urls.length} frames for "$ratioFolder".',
      );
    } catch (e) {
      debugPrint(
        '[FirebaseFrameService] Error fetching frames for "$ratioFolder": $e',
      );
      _cachedFrames.putIfAbsent(ratioFolder, () => []);
      _fetchedRatios.add(ratioFolder);
    } finally {
      _loadingRatios.remove(ratioFolder);
    }
    return _cachedFrames[ratioFolder]!;
  }
}
