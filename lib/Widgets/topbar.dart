import 'package:flutter/material.dart';
import 'package:trail_ai_app/Core/colors.dart';
import 'package:localization/localization.dart';
import 'package:trail_ai_app/Core/gradient.dart';

Widget topBar(BuildContext context, {int credits = 0}) {
  double width = MediaQuery.of(context).size.width;
  double height = MediaQuery.of(context).size.height;
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      SizedBox(width: width * 0.03),
      Text(
        'ai_generate_title'.i18n(),
        style: TextStyle(
          fontSize: width * 0.06,
          fontWeight: FontWeight.bold,
          color: AppColors.textColor(isDark),
        ),
      ),
      const Spacer(),
      Container(
        alignment: Alignment.centerRight,
        margin: EdgeInsets.symmetric(horizontal: width * 0.01),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.card_giftcard,
              color: AppColors.iconColor(isDark),
              size: width * 0.06,
            ),
            SizedBox(width: width * 0.01),
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/paywall');
              },
              child: Container(
                height: height * 0.05,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(width * 0.05),
                  border: Border.all(
                    color: AppColors.creditsCardBorder(isDark),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      alignment: Alignment.center,
                      padding: EdgeInsets.fromLTRB(
                        width * 0.05,
                        height * 0.008,
                        width * 0.05,
                        height * 0.008,
                      ),
                      decoration: ProGradientDecoration(
                        borderRadius: BorderRadius.circular(width * 0.05),
                      ),
                      child: Text(
                        'pro'.i18n(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: MediaQuery.of(context).size.width * 0.04,
                        ),
                      ),
                    ),

                    SizedBox(width: width * 0.005),
                    Icon(
                      Icons.flash_on,
                      size: width * 0.04,
                      color: AppColors.textColor(isDark),
                    ),
                    Padding(
                      padding: EdgeInsets.only(right: width * 0.03),
                      child: Text(
                        '$credits',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textColor(isDark),
                          fontSize: width * 0.035,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
