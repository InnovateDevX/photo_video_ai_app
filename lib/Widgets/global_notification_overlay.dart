import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../Models/generated_asset.dart';
import '../Services/background_generation_service.dart';
import '../Core/colors.dart';
import '../Core/gradient.dart';
import '../pages/ai_result_screen.dart';
import '../Services/review_service.dart';

class GlobalNotificationOverlay extends StatefulWidget {
  final Widget child;

  const GlobalNotificationOverlay({super.key, required this.child});

  @override
  State<GlobalNotificationOverlay> createState() => _GlobalNotificationOverlayState();
}

class _GlobalNotificationOverlayState extends State<GlobalNotificationOverlay> with SingleTickerProviderStateMixin {
  late StreamSubscription<GeneratedAsset> _successSubscription;
  late StreamSubscription<String> _failureSubscription;
  
  GeneratedAsset? _currentAsset;
  String? _errorMessage;
  bool _isVisible = false;
  
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    // Listen for completion
    _successSubscription = BackgroundGenerationService().onGenerationComplete.listen((asset) {
      _showNotification(asset: asset);
    });

    // Listen for failure
    _failureSubscription = BackgroundGenerationService().onGenerationFailure.listen((msg) {
      _showNotification(error: msg);
    });
  }

  void _showNotification({GeneratedAsset? asset, String? error}) {
    if (!mounted) return;
    
    setState(() {
      _currentAsset = asset;
      _errorMessage = error;
      _isVisible = true;
    });
    
    _controller.forward();

    // Auto-hide after 6 seconds
    Timer(const Duration(seconds: 6), () {
      if (mounted && _isVisible) {
        _hideNotification();
      }
    });
  }

  void _hideNotification() {
    _controller.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isVisible = false;
          _currentAsset = null;
          _errorMessage = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _successSubscription.cancel();
    _failureSubscription.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    
    return Stack(
      children: [
        widget.child,
        if (_isVisible)
          Positioned(
            top: MediaQuery.of(context).padding.top + sh * 0.012,
            left: sw * 0.04,
            right: sw * 0.04,
            child: SlideTransition(
              position: _offsetAnimation,
              child: GestureDetector(
                onPanUpdate: (details) {
                  if (details.delta.dy < -5) {
                    _hideNotification();
                  }
                },
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: sw * 0.04, vertical: sh * 0.015),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? Colors.black.withOpacity(0.7) 
                              : Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                            width: 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Icon
                            Container(
                              padding: EdgeInsets.all(sw * 0.02),
                              decoration: BoxDecoration(
                                color: _errorMessage != null 
                                    ? Colors.red.withOpacity(0.1)
                                    : const Color(0xFFFF9800).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _errorMessage != null ? Icons.error_outline : Icons.auto_awesome,
                                color: _errorMessage != null ? Colors.red : const Color(0xFFFF9800),
                                size: sw * 0.05,
                              ),
                            ),
                            SizedBox(width: sw * 0.03),
                            
                            // Content
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _errorMessage != null ? 'Generation Failed' : 'Magic Ready! ✨',
                                    style: TextStyle(
                                      color: AppColors.textColor(isDark),
                                      fontWeight: FontWeight.bold,
                                      fontSize: sw * 0.038,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _errorMessage ?? (_currentAsset?.prompt ?? 'Your creation is ready to view'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.secondaryTextColor(isDark),
                                      fontSize: sw * 0.032,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Action
                            if (_errorMessage == null)
                              GestureDetector(
                                onTap: () {
                                  _hideNotification();
                                  if (_currentAsset != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AIResultScreen(
                                          resultImageUrl: _currentAsset!.filePath,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: sw * 0.035, vertical: sh * 0.01),
                                  decoration: ProGradientDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'View',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: sw * 0.034,
                                    ),
                                  ),
                                ),
                              ),
                            
                            if (_errorMessage != null)
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: _hideNotification,
                                color: AppColors.secondaryTextColor(isDark),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
