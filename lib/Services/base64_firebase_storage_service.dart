import 'package:firebase_storage/firebase_storage.dart';

/// Best-effort helper to upload base64 strings to Firebase Storage.
class Base64FirebaseStorageService {
  Base64FirebaseStorageService._();

  static final Base64FirebaseStorageService instance =
      Base64FirebaseStorageService._();

  Future<void> uploadRawBase64s({
    required String folderPath,
    required List<String> rawBase64s,
    required String filePrefix,
    String contentType = 'text/plain',
  }) async {
    if (rawBase64s.isEmpty) return;

    for (int i = 0; i < rawBase64s.length; i++) {
      final path = '$folderPath/${filePrefix}_$i.txt';
      final ref = FirebaseStorage.instance.ref(path);

      await ref.putString(
        rawBase64s[i],
        format: PutStringFormat.raw,
        metadata: SettableMetadata(contentType: contentType),
      );
    }
  }
}
