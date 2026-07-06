import 'package:flutter/material.dart';
import '../Core/colors.dart';
import '../Core/gradient.dart';

class FeedbackHelper {
  static void showThumbsUpDialog(BuildContext context, {required bool isDark}) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.backgroundColor(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              MediaQuery.of(context).size.width * 0.06,
            ),
            side: BorderSide(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(sw * 0.06),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(sw * 0.04),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.thumb_up_alt_rounded,
                    color: Colors.green,
                    size: sw * 0.1,
                  ),
                ),
                SizedBox(height: sh * 0.02),
                Text(
                  'Glad you liked it!',
                  style: TextStyle(
                    fontSize: sw * 0.05,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor(isDark),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: sh * 0.015),
                Text(
                  'Your feedback helps us improve our generation models.',
                  style: TextStyle(
                    fontSize: sw * 0.038,
                    color: AppColors.secondaryTextColor(isDark),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: sh * 0.03),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    height: sh * 0.06,
                    decoration: ProGradientDecoration(
                      borderRadius: BorderRadius.circular(
                        MediaQuery.of(context).size.width * 0.07,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Close',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: sw * 0.04,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void showThumbsDownDialog(
    BuildContext context, {
    required bool isDark,
  }) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    String selectedReason = '';
    TextEditingController commentsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: AppColors.backgroundColor(isDark),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  MediaQuery.of(context).size.width * 0.06,
                ),
                side: BorderSide(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(sw * 0.05),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Improve Generation',
                            style: TextStyle(
                              fontSize: sw * 0.048,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor(isDark),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close,
                              color: AppColors.textColor(isDark),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      SizedBox(height: sh * 0.015),
                      Text(
                        'What went wrong with this generation?',
                        style: TextStyle(
                          fontSize: sw * 0.038,
                          color: AppColors.secondaryTextColor(isDark),
                        ),
                      ),
                      SizedBox(height: sh * 0.02),
                      _buildReasonChip(
                        'Blurry / Low Resolution',
                        selectedReason,
                        isDark,
                        sw,
                        (val) {
                          setState(() => selectedReason = val);
                        },
                      ),
                      SizedBox(height: sh * 0.01),
                      _buildReasonChip(
                        'Unnatural / Distorted details',
                        selectedReason,
                        isDark,
                        sw,
                        (val) {
                          setState(() => selectedReason = val);
                        },
                      ),
                      SizedBox(height: sh * 0.01),
                      _buildReasonChip(
                        'Did not match prompt',
                        selectedReason,
                        isDark,
                        sw,
                        (val) {
                          setState(() => selectedReason = val);
                        },
                      ),
                      SizedBox(height: sh * 0.01),
                      _buildReasonChip('Other', selectedReason, isDark, sw, (
                        val,
                      ) {
                        setState(() => selectedReason = val);
                      }),

                      SizedBox(height: sh * 0.02),
                      TextField(
                        controller: commentsController,
                        style: TextStyle(color: AppColors.textColor(isDark)),
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Additional details (optional)',
                          hintStyle: TextStyle(
                            color: AppColors.secondaryTextColor(isDark),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white12
                              : Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              MediaQuery.of(context).size.width * 0.03,
                            ),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.all(sw * 0.03),
                        ),
                      ),
                      SizedBox(height: sh * 0.025),
                      GestureDetector(
                        onTap: selectedReason.isEmpty
                            ? null
                            : () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                debugPrint(
                                  'Negative Feedback submitted: $selectedReason - ${commentsController.text}',
                                );
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Thank you for helping us improve!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                        child: Container(
                          width: double.infinity,
                          height: sh * 0.06,
                          decoration: selectedReason.isEmpty
                              ? BoxDecoration(
                                  color: Colors.grey,
                                  borderRadius: BorderRadius.circular(
                                    MediaQuery.of(context).size.width * 0.07,
                                  ),
                                )
                              : ProGradientDecoration(
                                  borderRadius: BorderRadius.circular(
                                    MediaQuery.of(context).size.width * 0.07,
                                  ),
                                ),
                          child: Center(
                            child: Text(
                              'Submit Feedback',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: sw * 0.04,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static void showFeedbackSheet(BuildContext context, {required bool isDark}) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    String selectedReason = '';
    TextEditingController commentsController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundColor(isDark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MediaQuery.of(context).size.width * 0.06),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: sw * 0.05,
                right: sw * 0.05,
                top: sh * 0.03,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Report Feedback',
                        style: TextStyle(
                          fontSize: sw * 0.05,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textColor(isDark),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close,
                          color: AppColors.textColor(isDark),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  SizedBox(height: sh * 0.02),
                  Text(
                    'What is the issue with this generation?',
                    style: TextStyle(
                      fontSize: sw * 0.04,
                      color: AppColors.secondaryTextColor(isDark),
                    ),
                  ),
                  SizedBox(height: sh * 0.02),
                  _buildReasonChip(
                    'Inappropriate Content',
                    selectedReason,
                    isDark,
                    sw,
                    (val) {
                      setState(() => selectedReason = val);
                    },
                  ),
                  SizedBox(height: sh * 0.01),
                  _buildReasonChip(
                    'Low Quality / Artifacts',
                    selectedReason,
                    isDark,
                    sw,
                    (val) {
                      setState(() => selectedReason = val);
                    },
                  ),
                  SizedBox(height: sh * 0.01),
                  _buildReasonChip(
                    'Did not follow instructions',
                    selectedReason,
                    isDark,
                    sw,
                    (val) {
                      setState(() => selectedReason = val);
                    },
                  ),
                  SizedBox(height: sh * 0.01),
                  _buildReasonChip('Other', selectedReason, isDark, sw, (val) {
                    setState(() => selectedReason = val);
                  }),

                  SizedBox(height: sh * 0.03),
                  TextField(
                    controller: commentsController,
                    style: TextStyle(color: AppColors.textColor(isDark)),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Additional details (optional)',
                      hintStyle: TextStyle(
                        color: AppColors.secondaryTextColor(isDark),
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.white12 : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          MediaQuery.of(context).size.width * 0.03,
                        ),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.all(sw * 0.04),
                    ),
                  ),
                  SizedBox(height: sh * 0.03),
                  GestureDetector(
                    onTap: selectedReason.isEmpty
                        ? null
                        : () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            // Here you would typically send the feedback to your backend
                            debugPrint(
                              'Feedback submitted: $selectedReason - ${commentsController.text}',
                            );
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Thank you for your feedback!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                    child: Container(
                      width: double.infinity,
                      height: sh * 0.065,
                      decoration: selectedReason.isEmpty
                          ? BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(
                                MediaQuery.of(context).size.width * 0.07,
                              ),
                            )
                          : ProGradientDecoration(
                              borderRadius: BorderRadius.circular(
                                MediaQuery.of(context).size.width * 0.07,
                              ),
                            ),
                      child: Center(
                        child: Text(
                          'Submit',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: sw * 0.045,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: sh * 0.04),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildReasonChip(
    String label,
    String selectedReason,
    bool isDark,
    double sw,
    Function(String) onSelect,
  ) {
    bool isSelected = selectedReason == label;
    return GestureDetector(
      onTap: () => onSelect(label),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: sw * 0.03,
          horizontal: sw * 0.04,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                    ? Colors.blue.withValues(alpha: 0.2)
                    : Colors.blue.shade50)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
          border: Border.all(
            color: isSelected
                ? Colors.blue
                : (isDark ? Colors.white24 : Colors.grey.shade300),
          ),
          borderRadius: BorderRadius.circular(sw * 0.03),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? Colors.blue : Colors.grey,
              size: sw * 0.05,
            ),
            SizedBox(width: sw * 0.03),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.textColor(isDark),
                  fontSize: sw * 0.038,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
