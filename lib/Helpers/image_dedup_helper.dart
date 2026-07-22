import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

/// Combined fingerprint of an image used for duplicate detection.
///
/// - [sha256] catches **exact** duplicates (same file bytes).
/// - [dHash] catches **visually** identical images that have been re-encoded,
///   resized, or screenshotted (perceptual hash).
class ImageFingerprint {
  /// SHA-256 of the raw file bytes (hex string, 64 chars).
  final String sha256;

  /// 64-bit perceptual hash, encoded as 16-char hex.
  /// Empty string if the file couldn't be decoded as an image.
  final String dHash;

  const ImageFingerprint({required this.sha256, required this.dHash});
}

/// Helper that detects duplicate image uploads using two strategies:
///
/// 1. **SHA-256 file hash** — exact match (same file picked twice).
/// 2. **dHash perceptual hash** — visually similar match (re-encoded
///    screenshots, resized re-saves, etc.). Uses Hamming distance with a
///    small threshold (default 5) to tolerate minor pixel differences.
class ImageDedupHelper {
  /// Hamming distance threshold (out of 64 bits) below which two dHashes are
  /// considered visually identical. ≤5 is a typical default for dHash.
  static const int dHashThreshold = 5;

  // ── Single-strategy hash helpers ──────────────────────────────────────────

  /// SHA-256 of the raw file bytes. Catches identical files.
  static Future<String> computeFileSha256(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  /// Perceptual dHash of an image file. Resizes to 9×8, then compares each
  /// pair of horizontally-adjacent pixels per row to produce a 64-bit hash.
  static Future<String> computeDHash(File file) async {
    final raw = await file.readAsBytes();
    return _computeDHashFromBytes(raw);
  }

  /// Perceptual dHash from in-memory bytes. Useful if you've already read the
  /// file once for [computeFileSha256].
  static Future<String> computeDHashFromBytes(Uint8List raw) =>
      Future.value(_computeDHashFromBytes(raw));

  // ── Combined fingerprint ──────────────────────────────────────────────────

  /// Builds a full [ImageFingerprint] for the file.
  ///
  /// Reads the file once, then computes both hashes from the same in-memory
  /// bytes (avoids hitting disk twice).
  static Future<ImageFingerprint> fingerprint(File file) async {
    final bytes = await file.readAsBytes();
    final sha = sha256.convert(bytes).toString();
    final d = _computeDHashFromBytes(bytes);
    return ImageFingerprint(sha256: sha, dHash: d);
  }

  // ── Duplicate detection ──────────────────────────────────────────────────

  /// Result of a duplicate check.
  static Future<({bool isDuplicate, String reason})> isDuplicate({
    required ImageFingerprint candidate,
    required List<ImageFingerprint> existing,
  }) async {
    if (existing.isEmpty) {
      return (isDuplicate: false, reason: '');
    }

    // 1. Exact match via SHA-256 — fastest, catches same-file duplicates.
    for (final fp in existing) {
      if (fp.sha256 == candidate.sha256) {
        return (isDuplicate: true, reason: 'exact');
      }
    }

    // 2. Perceptual match via dHash (skip if candidate couldn't be decoded).
    if (candidate.dHash.isNotEmpty) {
      for (final fp in existing) {
        if (fp.dHash.isEmpty) continue;
        final dist = _hammingDistanceHex(candidate.dHash, fp.dHash);
        if (dist <= dHashThreshold) {
          return (isDuplicate: true, reason: 'similar');
        }
      }
    }

    return (isDuplicate: false, reason: '');
  }

  // ── Internals ────────────────────────────────────────────────────────────

  static String _computeDHashFromBytes(Uint8List raw) {
    final decoded = img.decodeImage(raw);
    if (decoded == null) return '';

    // 9 wide × 8 tall gives us 8 rows × 8 horizontal comparisons = 64 bits.
    final resized = img.copyResize(decoded, width: 9, height: 8);
    final gray = img.grayscale(resized);

    int hash = 0;
    int bit = 0;
    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        final leftLum = gray.getPixel(x, y).luminance;
        final rightLum = gray.getPixel(x + 1, y).luminance;
        if (leftLum < rightLum) {
          hash |= (1 << bit);
        }
        bit++;
      }
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  /// Hamming distance between two equal-length hex-encoded 64-bit integers.
  /// Returns 64 if the strings have different lengths.
  static int _hammingDistanceHex(String hex1, String hex2) {
    if (hex1.length != hex2.length) return 64;
    final a = int.parse(hex1, radix: 16);
    final b = int.parse(hex2, radix: 16);
    int xor = a ^ b;
    int count = 0;
    while (xor != 0) {
      count += xor & 1;
      xor >>= 1;
    }
    return count;
  }
}
