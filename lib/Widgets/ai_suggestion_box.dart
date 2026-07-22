import 'package:flutter/material.dart';
import '../Core/colors.dart';

class AiSuggestionBox extends StatelessWidget {
  final String text;
  final bool isDark;

  const AiSuggestionBox({
    super.key,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return Container(
      padding: EdgeInsets.all(w * 0.04),
      decoration: BoxDecoration(
        color: AppColors.tileBackgroundColor(isDark),
        borderRadius: BorderRadius.circular(w * 0.05),
        border: Border.all(
          color: AppColors.creditsCardBorder(isDark),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb,
                color: Colors.orange,
                size: w * 0.05,
              ),
              SizedBox(width: w * 0.02),
              Text(
                'AI Suggestion:',
                style: TextStyle(
                  fontSize: w * 0.04,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor(isDark),
                ),
              ),
            ],
          ),
          SizedBox(height: h * 0.015),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: w * 0.02, vertical: h * 0.005),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(
                    fontSize: w * 0.035,
                    color: AppColors.secondaryTextColor(isDark),
                  ),
                ),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: w * 0.035,
                      color: AppColors.secondaryTextColor(isDark),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
