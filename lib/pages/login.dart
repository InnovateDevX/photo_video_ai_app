import 'package:flutter/material.dart';
import 'package:trail_ai_app/Core/colors.dart';
import 'package:trail_ai_app/Core/gradient.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trail_ai_app/Services/auth_service.dart';
import 'dart:async';
import 'package:trail_ai_app/Core/user_session.dart';
import 'package:trail_ai_app/Services/subscription_service.dart';
import 'package:trail_ai_app/Services/notification_service.dart';
import 'package:trail_ai_app/pages/edit_profile_page.dart';
import 'package:trail_ai_app/pages/signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handlePostLogin() async {
    final user = _authService.currentUser;
    if (user != null && mounted) {
      // ✅ Update Global Session
      UserSession.instance.uid = user.uid;

      // ✅ Sync services with the new identity
      unawaited(SubscriptionService().logIn(user.uid));
      unawaited(NotificationService().syncTokenNow());

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      if (!doc.exists || doc.data()?['profile']?['username'] == null) {
        // Needs profile setup
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const EditProfilePage()),
        );
      } else {
        Navigator.pop(context); // Go back to where they were
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final credential = await _authService.signInWithGoogle();
      if (credential != null) {
        await _handlePostLogin();
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showError("Please enter email and password");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.signInWithEmail(email, password);
      await _handlePostLogin();
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textColor(isDark)),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: w * 0.06,
                  vertical: h * 0.02,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Welcome Back",
                      style: TextStyle(
                        fontSize: w * 0.08,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textColor(isDark),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: h * 0.01),
                    Text(
                      "Log in to sync your credits and saved reels",
                      style: TextStyle(
                        fontSize: w * 0.04,
                        color: AppColors.secondaryTextColor(isDark),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: h * 0.06),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: "Email",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(w * 0.03),
                        ),
                        filled: true,
                        fillColor: AppColors.tileBackgroundColor(isDark),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: h * 0.02),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: "Password",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(w * 0.03),
                        ),
                        filled: true,
                        fillColor: AppColors.tileBackgroundColor(isDark),
                      ),
                      obscureText: true,
                    ),
                    SizedBox(height: h * 0.03),

                    // Log In Button
                    GestureDetector(
                      onTap: _handleEmailSignIn,
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: h * 0.02),
                        decoration: ProGradientDecoration(
                          borderRadius: BorderRadius.circular(w * 0.03),
                        ),
                        child: Center(
                          child: Text(
                            "Log In",
                            style: TextStyle(
                              fontSize: w * 0.04,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: h * 0.015),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignupPage(),
                          ),
                        );
                      },
                      child: Text(
                        "Don't have an account? Sign Up",
                        style: TextStyle(
                          color: AppColors.textColor(isDark),
                          fontSize: w * 0.035,
                        ),
                      ),
                    ),
                    SizedBox(height: h * 0.03),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: AppColors.secondaryTextColor(isDark),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: w * 0.04),
                          child: Text(
                            "OR",
                            style: TextStyle(
                              color: AppColors.secondaryTextColor(isDark),
                              fontSize: w * 0.03,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: AppColors.secondaryTextColor(isDark),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: h * 0.03),

                    // Google Sign In
                    GestureDetector(
                      onTap: _handleGoogleSignIn,
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: h * 0.02),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(w * 0.03),
                          border: Border.all(
                            color: AppColors.secondaryTextColor(
                              isDark,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.g_mobiledata,
                              size: w * 0.08,
                              color: Colors.blue,
                            ),
                            SizedBox(width: w * 0.02),
                            Text(
                              "Continue with Google",
                              style: TextStyle(
                                fontSize: w * 0.04,
                                color: AppColors.textColor(isDark),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
