import 'package:flutter/material.dart';
import 'package:trail_ai_app/Core/colors.dart';
import 'package:trail_ai_app/Core/routes.dart';

class ProfileHeader extends StatelessWidget {
  final double w;
  final double h;
  final bool isDark;
  final String displayName;
  final String handle;
  final String bio;
  final String? photoUrl;
  final bool isGuest;
  final Widget proPill;

  const ProfileHeader({
    super.key,
    required this.w,
    required this.h,
    required this.isDark,
    required this.displayName,
    required this.handle,
    required this.bio,
    this.photoUrl,
    required this.isGuest,
    required this.proPill,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: h * 0.35,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: h * 0.25,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF8A6445),
                        Color(0xFFD6BBA0),
                        Color(0xFF8A6445),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: w * 0.04,
                    vertical: h * 0.01,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Material(
                        color: Colors.white.withOpacity(0.2),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.hardEdge,
                        child: InkWell(
                          onTap: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              Navigator.pushReplacementNamed(
                                context,
                                AppRoutes.home,
                              );
                            }
                          },
                          child: Padding(
                            padding: EdgeInsets.all(w * 0.025),
                            child: Icon(
                              Icons.arrow_back_ios_new,
                              size: w * 0.045,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      proPill,
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.all(w * 0.01),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.backgroundColor(isDark),
                    ),
                    child: CircleAvatar(
                      radius: w * 0.16,
                      backgroundColor: AppColors.profileAvatarBackground(
                        isDark,
                      ),
                      backgroundImage: (photoUrl != null)
                          ? NetworkImage(photoUrl!)
                          : const AssetImage(
                                  'assets/iconamoon_profile-light.png',
                                )
                                as ImageProvider,
                      child: (photoUrl == null)
                          ? Icon(
                              Icons.person,
                              size: w * 0.15,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: h * 0.015),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              displayName,
              style: TextStyle(
                fontSize: w * 0.06,
                fontWeight: FontWeight.w900,
                color: AppColors.textColor(isDark),
              ),
            ),
            SizedBox(width: w * 0.02),
            Container(
              padding: EdgeInsets.all(w * 0.01),
              decoration: BoxDecoration(
                color: const Color(0xFFE46633),
                borderRadius: BorderRadius.circular(w * 0.015),
              ),
              child: Icon(Icons.link, size: w * 0.035, color: Colors.white),
            ),
          ],
        ),
        SizedBox(height: h * 0.005),
        Text(
          handle,
          style: TextStyle(
            fontSize: w * 0.035,
            color: AppColors.profileHandle(isDark),
          ),
        ),
        SizedBox(height: h * 0.01),
        Text(
          bio,
          style: TextStyle(
            fontSize: w * 0.035,
            fontWeight: FontWeight.w500,
            color: AppColors.textColor(isDark),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
