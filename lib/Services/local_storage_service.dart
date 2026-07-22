import 'package:shared_preferences/shared_preferences.dart';
import '../Models/generated_asset.dart';

import 'package:flutter/foundation.dart';
import 'dart:io';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  static const String _assetsKey = 'generated_assets';

  // ValueNotifier to allow the UI to reactively update when a new asset is added
  final ValueNotifier<List<GeneratedAsset>> assetsNotifier = ValueNotifier([]);

  Future<void> initialize() async {
    await loadAssets();
  }

  Future<void> loadAssets() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? assetsJsonStrList = prefs.getStringList(_assetsKey);

    if (assetsJsonStrList != null) {
      assetsNotifier.value =
          assetsJsonStrList
              .map((item) => GeneratedAsset.fromJson(item))
              .toList()
            ..sort(
              (a, b) => b.createdAt.compareTo(a.createdAt),
            ); // Newest first
    }
  }

  Future<void> saveAsset(GeneratedAsset asset) async {
    final prefs = await SharedPreferences.getInstance();
    final updatedList = List<GeneratedAsset>.from(assetsNotifier.value)
      ..add(asset);
    updatedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final List<String> assetsJsonStrList = updatedList
        .map((e) => e.toJson())
        .toList();
    await prefs.setStringList(_assetsKey, assetsJsonStrList);

    assetsNotifier.value = updatedList;
    debugPrint(
      '✅ [LocalStorageService] Successfully saved asset metadata to local SharedPreferences.',
    );
  }

  Future<void> deleteAsset(String id) async {
    final prefs = await SharedPreferences.getInstance();

    // Find the asset to delete its physical file
    try {
      final asset = assetsNotifier.value.firstWhere((a) => a.id == id);
      final file = File(asset.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }

    // Remove from DB
    final updatedList = assetsNotifier.value.where((a) => a.id != id).toList();
    final List<String> assetsJsonStrList = updatedList
        .map((e) => e.toJson())
        .toList();
    await prefs.setStringList(_assetsKey, assetsJsonStrList);

    assetsNotifier.value = updatedList;
  }

  Future<void> updateAssetThumbnail(String id, String thumbPath) async {
    final prefs = await SharedPreferences.getInstance();
    final updatedList = assetsNotifier.value.map((a) {
      if (a.id == id) {
        return GeneratedAsset(
          id: a.id,
          filePath: a.filePath,
          category: a.category,
          prompt: a.prompt,
          createdAt: a.createdAt,
          thumbnailPath: thumbPath,
        );
      }
      return a;
    }).toList();

    final List<String> assetsJsonStrList = updatedList
        .map((e) => e.toJson())
        .toList();
    await prefs.setStringList(_assetsKey, assetsJsonStrList);

    assetsNotifier.value = updatedList;
  }

  /// Clears local generated assets and media files without touching credits or ledger data
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    for (final asset in assetsNotifier.value) {
      try {
        final file = File(asset.filePath);
        if (await file.exists()) {
          await file.delete();
        }
        if (asset.thumbnailPath != null) {
          final thumb = File(asset.thumbnailPath!);
          if (await thumb.exists()) {
            await thumb.delete();
          }
        }
      } catch (e) {
        debugPrint('Error deleting file on clearAllData: $e');
      }
    }
    await prefs.remove(_assetsKey);
    assetsNotifier.value = [];
  }
}
