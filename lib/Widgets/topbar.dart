import 'package:flutter/material.dart';

import 'package:vidzeon/Core/colors.dart';
import 'package:vidzeon/Core/gradient.dart';
import 'package:vidzeon/pages/profile_page.dart';
import 'package:vidzeon/Widgets/pro_pill.dart';

/// The home top bar.
///
/// Shows the VidZeon title, a Pro pill that opens the paywall when the user
/// isn't subscribed (or a static "PRO" badge when they are), and the profile
/// avatar.
class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: width * 0.03),
        Flexible(
          child: Text(
            'VidZeon',
            style: TextStyle(
              fontSize: width * 0.055,
              fontWeight: FontWeight.w900,
              height: 1.1,
              color: AppColors.textColor(isDark),
            ),
            maxLines: 2,
          ),
        ),
        const Spacer(),
        // Pro pill — opens paywall if not subscribed.
        ProPill(w: width, h: height, isDark: isDark),
        SizedBox(width: width * 0.015),
        Container(
          alignment: Alignment.centerRight,
          margin: EdgeInsets.only(right: width * 0.03),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Profile Photo
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(2), // Gradient outline width
                  decoration: const ProGradientDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: width * 0.045,
                    backgroundColor: isDark
                        ? const Color(0xFF1E1E1E)
                        : Colors.grey.shade300,
                    child: Icon(
                      Icons.person,
                      color: isDark ? Colors.white70 : Colors.black54,
                      size: width * 0.055,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
