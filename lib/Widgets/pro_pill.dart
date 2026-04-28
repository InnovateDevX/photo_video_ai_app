import 'package:flutter/material.dart';
import 'package:trail_ai_app/Core/colors.dart';
import 'package:trail_ai_app/Core/gradient.dart';
import 'package:localization/localization.dart';
import 'package:trail_ai_app/Core/routes.dart';
import 'package:trail_ai_app/Services/credit_service.dart';

class ProPill extends StatelessWidget {
  final double w;
  final double h;
  final bool isDark;

  const ProPill({
    super.key,
    required this.w,
    required this.h,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: CreditService().creditStream,
      initialData: CreditService().credits,
      builder: (context, snapshot) {
        final credits = snapshot.data ?? 0;
        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.paywall),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.tileBackgroundColor(isDark),
              borderRadius: BorderRadius.circular(w * 0.1),
              border: Border.all(color: AppColors.creditsCardBorder(isDark)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: w * 0.03,
                    vertical: h * 0.005,
                  ),
                  decoration: ProGradientDecoration(
                    borderRadius: BorderRadius.circular(w * 0.1),
                  ),
                  child: Text(
                    'pro'.i18n(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: w * 0.035,
                      color: Colors.white,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    left: w * 0.015,
                    right: w * 0.03,
                    top: h * 0.005,
                    bottom: h * 0.005,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bolt, color: Colors.white, size: w * 0.045),
                      SizedBox(width: w * 0.005),
                      Text(
                        '$credits',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: w * 0.035,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
