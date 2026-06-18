import 'dart:async';
import 'package:flutter/material.dart';
import 'package:trail_ai_app/Core/colors.dart';
import 'package:localization/localization.dart';
import 'package:trail_ai_app/Core/gradient.dart';
import 'package:trail_ai_app/Core/routes.dart';
import 'package:trail_ai_app/Services/credit_service.dart';

class TopBar extends StatefulWidget {
  const TopBar({super.key});

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late StreamSubscription<int> _deductionSubscription;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.15,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.15,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.bounceIn)),
        weight: 60,
      ),
    ]).animate(_controller);

    _deductionSubscription = CreditService().onCreditDeducted.listen((_) {
      if (mounted) {
        _controller.forward(from: 0.0);
      }
    });
  }

  @override
  void dispose() {
    _deductionSubscription.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<int>(
      stream: CreditService().creditStream,
      initialData: CreditService().credits,
      builder: (context, snapshot) {
        final credits = snapshot.data ?? 0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: width * 0.03),
            Flexible(
              child: Text(
                'ai_generate_title'.i18n(),
                style: TextStyle(
                  fontSize: width * 0.055,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor(isDark),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.paywall);
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
                              padding: EdgeInsets.symmetric(
                                horizontal: width * 0.03,
                                vertical: height * 0.006,
                              ),
                              decoration: ProGradientDecoration(
                                borderRadius: BorderRadius.circular(
                                  width * 0.05,
                                ),
                              ),
                              child: Text(
                                'pro'.i18n(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize:
                                      MediaQuery.of(context).size.width * 0.04,
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
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
