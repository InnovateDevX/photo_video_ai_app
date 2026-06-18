import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Models/reel.dart';
import 'remote_config_service.dart';

class ReelService {
  static final ReelService _instance = ReelService._internal();
  factory ReelService({RemoteConfigService? remoteConfig}) => _instance;
  ReelService._internal();

  final RemoteConfigService _remoteConfig = RemoteConfigService();

  // ── Persisted liked/saved reel IDs ───────────────────────────────────────
  static const _likedKey = 'local_liked_reel_ids';
  static const _savedKey = 'local_saved_reel_ids';
  static const _likedReelsKey = 'local_liked_reels_data';
  static const _savedReelsKey = 'local_saved_reels_data';

  // In-memory state
  final Set<String> _likedReels = {};
  final Set<String> _savedReels = {};
  final Map<String, Reel> _likedReelData = {};
  final Map<String, Reel> _savedReelData = {};

  // Track temporary increments (for display)
  final Map<String, int> _likeIncrements = {};
  final Map<String, int> _saveIncrements = {};

  // Notifiers for reactive UI (replaces Firestore streams)
  final ValueNotifier<List<Reel>> likedReelsNotifier = ValueNotifier([]);
  final ValueNotifier<List<Reel>> savedReelsNotifier = ValueNotifier([]);

  bool _initialized = false;

  /// Call this once at app start. Loads persisted liked/saved data from disk.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();

    // Load liked IDs
    final likedIds = prefs.getStringList(_likedKey) ?? [];
    _likedReels.addAll(likedIds);

    // Load liked reel data
    final likedData = prefs.getStringList(_likedReelsKey) ?? [];
    for (final jsonStr in likedData) {
      try {
        final reel = Reel.fromJson(jsonDecode(jsonStr));
        _likedReelData[reel.id] = reel;
      } catch (_) {}
    }

    // Load saved IDs
    final savedIds = prefs.getStringList(_savedKey) ?? [];
    _savedReels.addAll(savedIds);

    // Load saved reel data
    final savedData = prefs.getStringList(_savedReelsKey) ?? [];
    for (final jsonStr in savedData) {
      try {
        final reel = Reel.fromJson(jsonDecode(jsonStr));
        _savedReelData[reel.id] = reel;
      } catch (_) {}
    }

    _refreshNotifiers();
    debugPrint('✅ [ReelService] Loaded ${_likedReels.length} liked, ${_savedReels.length} saved reels from local storage.');
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  Future<void> _persistLiked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_likedKey, _likedReels.toList());
    await prefs.setStringList(
      _likedReelsKey,
      _likedReelData.values.map((r) => jsonEncode(r.toJson())).toList(),
    );
    _refreshNotifiers();
  }

  Future<void> _persistSaved() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_savedKey, _savedReels.toList());
    await prefs.setStringList(
      _savedReelsKey,
      _savedReelData.values.map((r) => jsonEncode(r.toJson())).toList(),
    );
    _refreshNotifiers();
  }

  void _refreshNotifiers() {
    likedReelsNotifier.value = _likedReels
        .map((id) => _likedReelData[id])
        .whereType<Reel>()
        .toList();
    savedReelsNotifier.value = _savedReels
        .map((id) => _savedReelData[id])
        .whereType<Reel>()
        .toList();
  }

  // ── Reels from Remote Config ──────────────────────────────────────────────

  List<Reel> _getReelsFromConfig() {
    try {
      final jsonStr = _remoteConfig.reelsJson;
      if (jsonStr.isEmpty) return [];

      final List<dynamic> jsonList = json.decode(jsonStr);

      return jsonList.asMap().entries.map((entry) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(entry.value);
        final String id = data['id'] ?? 'reel_${entry.key}';

        final likeIncrement = _likeIncrements[id] ?? 0;
        final saveIncrement = _saveIncrements[id] ?? 0;
        data['likesCount'] = (data['likesCount'] ?? 0) + likeIncrement;
        data['savedCount'] = (data['savedCount'] ?? 0) + saveIncrement;

        return Reel.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('❌ [ReelService] Error parsing reels from remote config: $e');
      return [];
    }
  }

  Stream<List<Reel>> getReelsStream() => Stream.value(_getReelsFromConfig());
  Future<List<Reel>> getReels() async => _getReelsFromConfig();

  // ── LIKES ─────────────────────────────────────────────────────────────────

  Future<void> likeReel(String reelId, Reel reel) async {
    if (!_likedReels.contains(reelId)) {
      _likedReels.add(reelId);
      _likedReelData[reelId] = reel;
      _likeIncrements[reelId] = (_likeIncrements[reelId] ?? 0) + 1;
      await _persistLiked();
      debugPrint('✅ [ReelService] likeReel: Liked $reelId (persisted)');
    }
  }

  Future<void> unlikeReel(String reelId) async {
    if (_likedReels.contains(reelId)) {
      _likedReels.remove(reelId);
      _likedReelData.remove(reelId);
      final current = _likeIncrements[reelId] ?? 0;
      if (current > 0) _likeIncrements[reelId] = current - 1;
      await _persistLiked();
      debugPrint('✅ [ReelService] unlikeReel: Unliked $reelId (persisted)');
    }
  }

  bool isReelLikedSync(String reelId) => _likedReels.contains(reelId);
  Stream<bool> isReelLiked(String reelId) => Stream.value(isReelLikedSync(reelId));

  Stream<List<Reel>> getLikedReelsStream() => Stream.value(likedReelsNotifier.value);
  Future<List<Reel>> fetchLikedReelsOnce() async => likedReelsNotifier.value;

  // ── SAVES ─────────────────────────────────────────────────────────────────

  Future<void> saveReel(String reelId, Reel reel) async {
    if (!_savedReels.contains(reelId)) {
      _savedReels.add(reelId);
      _savedReelData[reelId] = reel;
      _saveIncrements[reelId] = (_saveIncrements[reelId] ?? 0) + 1;
      await _persistSaved();
      debugPrint('✅ [ReelService] saveReel: Saved $reelId (persisted)');
    }
  }

  Future<void> unsaveReel(String reelId) async {
    if (_savedReels.contains(reelId)) {
      _savedReels.remove(reelId);
      _savedReelData.remove(reelId);
      final current = _saveIncrements[reelId] ?? 0;
      if (current > 0) _saveIncrements[reelId] = current - 1;
      await _persistSaved();
      debugPrint('✅ [ReelService] unsaveReel: Unsaved $reelId (persisted)');
    }
  }

  bool isReelSavedSync(String reelId) => _savedReels.contains(reelId);
  Stream<bool> isReelSaved(String reelId) => Stream.value(isReelSavedSync(reelId));

  Stream<List<Reel>> getSavedReelsStream() => Stream.value(savedReelsNotifier.value);
  Future<List<Reel>> fetchSavedReelsOnce() async => savedReelsNotifier.value;

  // ── Utility ───────────────────────────────────────────────────────────────

  Future<void> addReel({
    required String videoUrl,
    required String videoPrompt,
    String imagePrompt = '',
    bool imageEdit = false,
    String type = 'video',
    bool isEditable = false,
  }) async {
    debugPrint('⚠️ [ReelService] addReel is not supported with Remote Config');
  }
}
