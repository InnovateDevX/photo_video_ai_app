import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class ReviewService {
  static final ReviewService _instance = ReviewService._internal();
  factory ReviewService() => _instance;
  ReviewService._internal();

  final InAppReview _inAppReview = InAppReview.instance;

  static const String _reviewCounterKey = 'generation_review_counter';
  static const int _threshold = 1; // Trigger after every 3 "wins"

  /// Requests a review immediately when called.
  Future<void> requestReviewIfAppropriate(BuildContext? context) async {
    try {
      debugPrint('⭐️ [ReviewService] Requesting store review...');
      final isAvailable = await _inAppReview.isAvailable();

      if (isAvailable) {
        await _inAppReview.requestReview();
      } else {
        debugPrint('⭐️ [ReviewService] Review not available at this time.');
      }
    } catch (e) {
      debugPrint('❌ [ReviewService] Error: $e');
    }
  }

  /// Forces a review request (e.g., from settings)
  Future<void> forceReview() async {
    if (await _inAppReview.isAvailable()) {
      await _inAppReview.requestReview();
    }
  }

  /// Opens the store page for this app
  Future<void> openStoreListing() async {
    await _inAppReview.openStoreListing();
  }
}
