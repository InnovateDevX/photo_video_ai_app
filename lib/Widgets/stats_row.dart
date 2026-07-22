import 'package:flutter/material.dart';
import 'package:vidzeon/Core/colors.dart';

import 'package:vidzeon/Services/reel_service.dart';

class StatsRow extends StatelessWidget {
  final double w;
  final double h;
  final bool isDark;

  // Kept for API compatibility but no longer used — counts come from ReelService directly
  final Stream<dynamic> savedReelsStream;
  final Stream<dynamic> likedReelsStream;

  const StatsRow({
    super.key,
    required this.w,
    required this.h,
    required this.isDark,
    required this.savedReelsStream,
    required this.likedReelsStream,
  });

  @override
  Widget build(BuildContext context) {
    final reelService = ReelService();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: w * 0.12),
      child: Row(
        children: [
          // Downloads / Saved
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: reelService.savedReelsNotifier,
              builder: (context, saved, _) {
                return _buildStatCard(
                  w,
                  h,
                  isDark,
                  Icons.download_outlined,
                  '${saved.length} Downloads',
                );
              },
            ),
          ),
          SizedBox(width: w * 0.03),
          // Liked
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: reelService.likedReelsNotifier,
              builder: (context, liked, _) {
                return _buildStatCard(
                  w,
                  h,
                  isDark,
                  Icons.star_border,
                  '${liked.length} Liked',
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    double w,
    double h,
    bool isDark,
    IconData icon,
    String label,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: h * 0.015),
      decoration: BoxDecoration(
        color: AppColors.tileBackgroundColor(isDark),
        borderRadius: BorderRadius.circular(w * 0.04),
        border: Border.all(color: AppColors.creditsCardBorder(isDark)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textColor(isDark), size: w * 0.05),
          SizedBox(height: h * 0.005),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textColor(isDark),
              fontSize: w * 0.03,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
