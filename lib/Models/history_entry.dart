import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Represents a single entry in the image editing history stack.
///
/// MEMORY-SAFE: Stores image state as a temporary file on disk instead of
/// keeping the full [Uint8List] in RAM. A 12-megapixel JPEG can produce a
/// 40–80 MB RGBA buffer; keeping 20 of these in memory guarantees OOM on
/// mid/low-tier devices.
///
/// Call [loadBytes] to retrieve bytes when needed (e.g. on undo/redo).
/// Call [deleteFile] when the entry is evicted from the stack so the temp
/// file is cleaned up immediately.
class HistoryEntry {
  /// Absolute path to the temporary PNG file that holds the image state.
  final String filePath;
  final String label;
  final DateTime timestamp;

  const HistoryEntry({
    required this.filePath,
    required this.label,
    required this.timestamp,
  });

  /// Writes [bytes] to a new temporary file and returns a [HistoryEntry]
  /// that points at it.  The caller must ensure [deleteFile] is called when
  /// the entry is no longer needed to avoid storage leaks.
  static Future<HistoryEntry> fromBytes({
    required Uint8List bytes,
    required String label,
  }) async {
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now();
    // Prefix makes it easy to bulk-delete editor temp files on startup.
    final file = File(
      '${dir.path}/history_${label}_${ts.millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    return HistoryEntry(filePath: file.path, label: label, timestamp: ts);
  }

  /// Loads and returns the image bytes from disk.
  /// Returns null and logs a warning if the file has been deleted.
  Future<Uint8List?> loadBytes() async {
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('⚠️ [HistoryEntry] Temp file missing for "$label": $filePath');
      return null;
    }
    return file.readAsBytes();
  }

  /// Deletes the backing temp file.  Safe to call multiple times.
  Future<void> deleteFile() async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️  [HistoryEntry] Deleted temp file: $filePath');
      }
    } catch (e) {
      debugPrint('⚠️ [HistoryEntry] Could not delete temp file: $e');
    }
  }
}
