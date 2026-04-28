import 'package:flutter/material.dart';
import 'package:trail_ai_app/Core/colors.dart';
import 'package:localization/localization.dart';
import 'package:trail_ai_app/Models/reel.dart';

class StatsRow extends StatelessWidget {
  final double w;
  final double h;
  final bool isDark;
  final Stream<List<Reel>> savedReelsStream;
  final Stream<List<Reel>> likedReelsStream;

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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: w * 0.05),
      child: Row(
        children: [
          _buildStatCard(
            w,
            h,
            isDark,
            Icons.remove_red_eye_outlined,
            '0 ${'views_stat_label'.i18n()}',
          ),
          SizedBox(width: w * 0.03),
          StreamBuilder<List<Reel>>(
            stream: savedReelsStream,
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;
              return _buildStatCard(
                w,
                h,
                isDark,
                Icons.download_outlined,
                '$count ${'downloads_stat_label'.i18n()}',
              );
            },
          ),
          SizedBox(width: w * 0.03),
          StreamBuilder<List<Reel>>(
            stream: likedReelsStream,
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;
              return _buildStatCard(
                w,
                h,
                isDark,
                Icons.star_border,
                '$count ${'liked_stat_label'.i18n()}',
              );
            },
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
    return Expanded(
      child: Container(
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
      ),
    );
  }
}
