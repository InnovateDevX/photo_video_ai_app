import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  /// Uploads a file to Firebase Storage and returns the public download URL.
  Future<String> uploadFile(File file, {String folder = 'ai_inputs'}) async {
    final String fileName = '${const Uuid().v4()}${path.extension(file.path)}';
    final String filePath = '$folder/$fileName';
    final Reference ref = FirebaseStorage.instance.ref().child(filePath);

    // Upload file
    await ref.putFile(file);

    // Get download URL
    return await ref.getDownloadURL();
  }

  /// Uploads multiple files and returns a list of download URLs.
  Future<List<String>> uploadFiles(List<File> files, {String folder = 'ai_inputs'}) async {
    return await Future.wait(files.map((f) => uploadFile(f, folder: folder)));
  }
}
