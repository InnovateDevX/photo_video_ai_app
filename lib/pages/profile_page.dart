import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:vidzeon/Core/colors.dart';
import 'package:vidzeon/Core/routes.dart';
import 'package:vidzeon/Services/reel_service.dart';
import 'package:vidzeon/Services/local_storage_service.dart';
import 'package:vidzeon/Models/generated_asset.dart';
import 'package:vidzeon/pages/ai_result_screen.dart';
import 'package:vidzeon/pages/settings_page.dart';
import 'package:vidzeon/Services/thumbnail_service.dart';
import 'package:vidzeon/Core/gradient.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ReelService _reelService = ReelService();
  static final _processingIds = <String>{};

  String? _lastUid;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _lastUid = FirebaseAuth.instance.currentUser?.uid;

    // Listen for auth changes (Login/Logout)
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted && _lastUid != user?.uid) {
        setState(() {
          _lastUid = user?.uid;
        });
      }
    });

    // Pre-fetch reels on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reelService.fetchSavedReelsOnce();
      _reelService.fetchLikedReelsOnce();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(isDark),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Custom App Bar
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: w * 0.05,
                  vertical: h * 0.02,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    GestureDetector(
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
                      child: Container(
                        padding: EdgeInsets.all(w * 0.025),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E1E)
                              : Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: AppColors.textColor(isDark),
                          size: w * 0.05,
                        ),
                      ),
                    ),
                    // Title
                    Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: w * 0.045,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textColor(isDark),
                      ),
                    ),
                    // Settings Button
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsPage(),
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.all(w * 0.025),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E1E)
                              : Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.settings_outlined,
                          color: AppColors.textColor(isDark),
                          size: w * 0.05,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: h * 0.02),

            // Grid Content
            Padding(
              padding: EdgeInsets.symmetric(horizontal: w * 0.05),
              child: _buildPersistentAssetsGrid(w, h, isDark),
            ),

            SizedBox(height: h * 0.15),
          ],
        ),
      ),
    );
  }

  Widget _buildPersistentAssetsGrid(double w, double h, bool isDark) {
    return ValueListenableBuilder<List<GeneratedAsset>>(
      valueListenable: LocalStorageService().assetsNotifier,
      builder: (context, assets, child) {
        if (assets.isEmpty) {
          return SizedBox(
            height: h * 0.6, // Centers the content vertically in the available viewport
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No Video Yet',
                    style: TextStyle(
                      color: AppColors.textColor(isDark),
                      fontSize: w * 0.05,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: h * 0.015),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: w * 0.1),
                    child: Text(
                      "Discover AI's innovative, first-time art creation!",
                      style: TextStyle(
                        color: AppColors.textColor(isDark).withValues(alpha: 0.6),
                        fontSize: w * 0.038,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: h * 0.04),
                  GestureDetector(
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
                    child: Container(
                      width: w * 0.55,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppGradients.proGradient,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: AppGradients.proGradient.colors.first
                                .withValues(alpha: 0.3),
                            blurRadius: w * 0.04,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Discover',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: w * 0.042,
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
        }

        return GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: w * 0.03,
            mainAxisSpacing: w * 0.03,
            childAspectRatio: 0.9,
          ),
          itemCount: assets.length,
          itemBuilder: (context, index) {
            final asset = assets[index];
            final file = File(asset.filePath);

            if (asset.category == 'video' &&
                asset.thumbnailPath == null &&
                !_processingIds.contains(asset.id)) {
              _processingIds.add(asset.id);
              ThumbnailService().processGeneratedAsset(asset);
            }

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (innerContext) => Scaffold(
                      backgroundColor: AppColors.backgroundColor(isDark),
                      appBar: AppBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        leading: IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_new,
                            color: AppColors.textColor(isDark),
                          ),
                          onPressed: () => Navigator.pop(innerContext),
                        ),
                        title: Text(
                          'Result',
                          style: TextStyle(color: AppColors.textColor(isDark)),
                        ),
                      ),
                      body: SafeArea(
                        child: AIResultScreen(
                          resultImageUrl: asset.filePath,
                          onDelete: () async {
                            final confirm = await showDialog<bool>(
                              context: innerContext,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Media'),
                                content: const Text('Are you sure you want to delete this? It cannot be recovered.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await LocalStorageService().deleteAsset(asset.id);
                              if (innerContext.mounted) {
                                Navigator.pop(innerContext); // Close result screen
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Removed successfully')),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.profileGridItemBackground(isDark),
                  borderRadius: BorderRadius.circular(w * 0.03),
                  border: Border.all(
                    color: AppColors.profileGridItemBorder(isDark),
                    width: w * 0.003,
                  ),
                ),
                clipBehavior: Clip.hardEdge,
                child: !file.existsSync()
                    ? Icon(
                        Icons.broken_image,
                        color: AppColors.textColor(
                          isDark,
                        ).withValues(alpha: 0.5),
                      )
                    : asset.category == 'image'
                    ? Image.file(file, fit: BoxFit.cover)
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          if (asset.thumbnailPath != null &&
                              File(asset.thumbnailPath!).existsSync())
                            Image.file(
                              File(asset.thumbnailPath!),
                              fit: BoxFit.cover,
                            )
                          else
                            Container(color: Colors.black),
                          Center(
                            child: Icon(
                              Icons.play_circle_fill,
                              color: Colors.white,
                              size: w * 0.08,
                            ),
                          ),
                        ],
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
