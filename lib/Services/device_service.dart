import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

/// Service responsible ONLY for retrieving the device identifier.
/// Architecture Decision: Encapsulate device info logic behind a single interface.
class DeviceService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Retrieves a stable device identifier.
  /// Includes fallback: If device ID cannot be retrieved, generates a new UUID.
  Future<String> getDeviceId() async {
    try {
      if (kIsWeb) {
        return const Uuid().v4();
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        // identifierForVendor can be null, fallback to UUID
        return iosInfo.identifierForVendor ?? const Uuid().v4();
      }
    } catch (e) {
      debugPrint('DeviceService Error: Failed to get device ID: $e');
    }
    // Fallback strategy: Return a newly generated UUID if exception is caught
    return const Uuid().v4();
  }
}
