import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class Base64ImageEncoder {
  const Base64ImageEncoder._();

  static Future<String> encodeFile(File file, {String? mimeType}) async {
    final bytes = await file.readAsBytes();
    final inferredMimeType = mimeType ?? _inferMimeType(bytes, file.path);
    final raw = base64Encode(bytes);
    final result = 'data:$inferredMimeType;base64,$raw';
    debugPrint(
      '🖼 [Base64ImageEncoder] File: ${file.path}, '
      'Inferred MIME: $inferredMimeType',
    );
    return result;
  }

  /// Extracts the raw base64 string (without data:...;base64, prefix).
  static String extractRawBase64(String encoded) {
    if (encoded.contains(',')) {
      return encoded.split(',').last;
    }
    return encoded;
  }

  static String _inferMimeType(List<int> bytes, String path) {
    if (bytes.length >= 4) {
      // Check PNG: 89 50 4E 47
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        debugPrint('🔍 [Base64ImageEncoder] Detected PNG by magic bytes');
        return 'image/png';
      }
      // Check JPEG: FF D8 FF
      if (bytes.length >= 3 &&
          bytes[0] == 0xFF &&
          bytes[1] == 0xD8 &&
          bytes[2] == 0xFF) {
        debugPrint('🔍 [Base64ImageEncoder] Detected JPEG by magic bytes');
        return 'image/jpeg';
      }
      // Check WebP: RIFF
      if (bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46) {
        if (bytes.length >= 12 &&
            bytes[8] == 0x57 &&
            bytes[9] == 0x45 &&
            bytes[10] == 0x42 &&
            bytes[11] == 0x50) {
          debugPrint('🔍 [Base64ImageEncoder] Detected WebP by magic bytes');
          return 'image/webp';
        }
      }
      // Check GIF: GIF8
      if (bytes[0] == 0x47 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x38) {
        debugPrint('🔍 [Base64ImageEncoder] Detected GIF by magic bytes');
        return 'image/gif';
      }
    }

    // Fallback to extension-based detection
    final lower = path.toLowerCase();
    if (lower.contains('.png')) {
      debugPrint('🔍 [Base64ImageEncoder] Fallback: PNG by extension');
      return 'image/png';
    }
    if (lower.contains('.webp')) {
      debugPrint('🔍 [Base64ImageEncoder] Fallback: WebP by extension');
      return 'image/webp';
    }
    if (lower.contains('.gif')) {
      debugPrint('🔍 [Base64ImageEncoder] Fallback: GIF by extension');
      return 'image/gif';
    }
    if (lower.contains('.jpg') || lower.contains('.jpeg')) {
      debugPrint('🔍 [Base64ImageEncoder] Fallback: JPEG by extension');
      return 'image/jpeg';
    }
    debugPrint(
      '🔍 [Base64ImageEncoder] No magic bytes/extension match — defaulting to image/png',
    );
    return 'image/png'; // Default to PNG (lossless) instead of JPEG
  }
}
