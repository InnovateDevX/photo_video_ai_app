import 'dart:convert';
import 'dart:io';

class Base64ImageEncoder {
  const Base64ImageEncoder._();

  static Future<String> encodeFile(File file, {String? mimeType}) async {
    final bytes = await file.readAsBytes();
    final inferredMimeType = mimeType ?? _inferMimeType(file.path);
    final raw = base64Encode(bytes);
    return 'data:$inferredMimeType;base64,$raw';
  }

  static String _inferMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
