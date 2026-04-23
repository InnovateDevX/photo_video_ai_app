import 'package:flutter/material.dart';
import 'package:trail_ai_app/Core/colors.dart';
import 'package:trail_ai_app/Core/strings.dart'; // AppStrings.selectionCategories
import 'package:localization/localization.dart';
import 'package:trail_ai_app/Widgets/topbar.dart';

import 'package:trail_ai_app/Core/gradient.dart';
import 'package:trail_ai_app/pages/generation_page.dart';
import '../Services/credit_service.dart';

class Selection extends StatefulWidget {
  const Selection({super.key});

  @override
  State<Selection> createState() => _SelectionState();
}

class _SelectionState extends State<Selection> {
  int _selectedCategoryIndex = 0;
  final List<String> categories = AppStrings.selectionCategories;

  @override
  void initState() {
    super.initState();
    CreditService().initialize();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: AppColors.backgroundColor(isDark),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: h * 0.05),
          StreamBuilder<int>(
            stream: CreditService().creditStream,
            initialData: CreditService().credits,
            builder: (context, snapshot) {
              return topBar(context, credits: snapshot.data ?? 0);
            },
          ),
          SizedBox(height: h * 0.02),

          // Categories segmented control
          Container(
            height: h * 0.055,
            width: double.infinity,
            margin: EdgeInsets.symmetric(
              horizontal: w * 0.05,
            ),

            decoration: BoxDecoration(
              color: AppColors.tileBackgroundColor(isDark),
              borderRadius: BorderRadius.circular(w * 0.08),
            ),
            child: Row(
              children: List.generate(categories.length, (index) {
                return Expanded(
                  child: videoGenSel(
                    label: categories[index],
                    isSelected: _selectedCategoryIndex == index,
                    onTap: () {
                      setState(() {
                        _selectedCategoryIndex = index;
                      });
                      debugPrint("Category clicked: ${categories[index]}");
                    },
                  ),
                );
              }),
            ),
          ),

          // Empty State Card
          Expanded(
            child: Center(
              child: Container(
                margin: EdgeInsets.fromLTRB(
                  MediaQuery.of(context).size.width * 0.1,
                  MediaQuery.of(context).size.height * 0.07,
                  MediaQuery.of(context).size.width * 0.1,
                  MediaQuery.of(context).size.height * 0.2,
                ),
                decoration: ProGradientDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(w * 0.08)),
                ),
                padding: EdgeInsets.all(w * 0.004), // Gradient border width
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.creditsCardBackground(isDark),
                    borderRadius: BorderRadius.circular(w * 0.075),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.card_giftcard,
                        size: w * 0.2,
                        color: AppColors.iconColor(isDark),
                      ),
                      SizedBox(height: h * 0.02),
                      Text(
                        'selection_title'.i18n(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: w * 0.055,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textColor(isDark),
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: h * 0.012),
                      Text(
                        'selection_subtitle'.i18n(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.secondaryTextColor(isDark),
                          fontSize: w * 0.04,
                        ),
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.03,
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GenerationPage(),
                            ),
                          );
                          debugPrint("Start Creating tapped");
                        },
                        child: Container(
                          decoration: ProGradientDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(w * 0.08)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: w * 0.08,
                              vertical: h * 0.015,
                            ),
                            child: Text(
                              'start_create'.i18n(),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize:
                                    MediaQuery.of(context).size.width * 0.035,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget videoGenSel({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final w = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: Alignment.center,
        margin: EdgeInsets.symmetric(horizontal: w * 0.005),
        decoration: isSelected
            ? ProGradientDecoration(
                borderRadius: BorderRadius.all(Radius.circular(w * 0.06)),
              )
            : null,
        child: isSelected
            ? Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(w * 0.06),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.tileBackgroundColor(isDark),
                    borderRadius: BorderRadius.circular(w * 0.06),
                    boxShadow: [
                      if (!isDark) ...[
                        const BoxShadow(
                          color: Color(0x44000000),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: Offset(3, 3),
                        ),
                        const BoxShadow(
                          color: Color(0xCCFFFFFF),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: Offset(-3, -3),
                        ),
                      ],
                    ],
                  ),
                  child: Text(
                    label.i18n(),
                    style: TextStyle(
                      color: AppColors.secondaryTextColor(isDark),
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
