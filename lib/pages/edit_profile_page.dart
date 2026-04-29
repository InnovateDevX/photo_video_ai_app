import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trail_ai_app/Core/colors.dart';
import 'package:trail_ai_app/Core/gradient.dart';
import 'package:trail_ai_app/Services/profile_service.dart';
import 'package:trail_ai_app/Services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trail_ai_app/Services/content_safety_service.dart';
import 'package:trail_ai_app/Helpers/nsfw_dialog_helper.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic>? initialProfile;

  const EditProfilePage({super.key, this.initialProfile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();
  
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;

  File? _imageFile;
  bool _isLoading = false;
  bool _isCheckingUsername = false;
  bool _isUsernameAvailable = true;
  String _currentUsername = "";

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    final user = FirebaseAuth.instance.currentUser;

    _currentUsername = profile?['username'] ?? '';
    _nameController = TextEditingController(text: profile?['displayName'] ?? user?.displayName ?? '');
    _usernameController = TextEditingController(text: _currentUsername);
    _bioController = TextEditingController(text: profile?['bio'] ?? '');

    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _usernameController.removeListener(_onUsernameChanged);
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() async {
    final newUsername = _usernameController.text.trim().toLowerCase();
    
    // Replace slashes handling
    if (_usernameController.text.contains('/')) {
      _usernameController.text = _usernameController.text.replaceAll('/', '');
      _usernameController.selection = TextSelection.fromPosition(TextPosition(offset: _usernameController.text.length));
    }

    if (newUsername == _currentUsername.toLowerCase()) {
      setState(() {
        _isUsernameAvailable = true;
        _isCheckingUsername = false;
      });
      return;
    }

    if (newUsername.isEmpty) {
      setState(() {
        _isUsernameAvailable = false;
        _isCheckingUsername = false;
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
    });

    final isAvailable = await _profileService.isUsernameAvailable(newUsername);
    
    if (mounted) {
      setState(() {
        _isUsernameAvailable = isAvailable;
        _isCheckingUsername = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (image == null) return;

    final file = File(image.path);

    try {
      // Show checking overlay
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(
            child: CircularProgressIndicator(color: Color(0xFFD66031)),
          ),
        );
      }

      await ContentSafetyService().checkImageFileSafe(file);

      if (mounted) Navigator.pop(context); // Remove loading

      setState(() {
        _imageFile = file;
      });
    } catch (e) {
      if (mounted) Navigator.pop(context); // Remove loading

      if (e is NsfwContentException) {
        if (mounted) {
          NsfwDialogHelper.showRestrictedContentDialog(context);
        }
      } else {
        debugPrint('⚠️ [EditProfilePage] Safety check error: $e');
        // Still set the image if it's not a safety violation but some other error
        setState(() {
          _imageFile = file;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final bio = _bioController.text.trim();

    if (name.isEmpty || username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display Name and Username are required.')),
      );
      return;
    }

    if (!_isUsernameAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose an available username.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception("Not logged in");

      String? photoUrl;
      if (_imageFile != null) {
        photoUrl = await _profileService.uploadProfilePicture(user.uid, _imageFile!);
      } else {
        photoUrl = widget.initialProfile?['photoUrl'];
      }

      await _profileService.saveProfile(
        uid: user.uid,
        currentUsername: _currentUsername,
        newUsername: username,
        displayName: name,
        bio: bio,
        photoUrl: photoUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final existingPhotoUrl = widget.initialProfile?['photoUrl'] ?? FirebaseAuth.instance.currentUser?.photoURL;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(isDark),
      appBar: AppBar(
        title: Text('Edit Profile', style: TextStyle(color: AppColors.textColor(isDark))),
        backgroundColor: AppColors.backgroundColor(isDark),
        iconTheme: IconThemeData(color: AppColors.textColor(isDark)),
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: w * 0.05, vertical: h * 0.02),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profile Image
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            Container(
                              padding: EdgeInsets.all(w * 0.01),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.tileBackgroundColor(isDark),
                              ),
                              child: CircleAvatar(
                                radius: w * 0.15,
                                backgroundColor: AppColors.profileAvatarBackground(isDark),
                                backgroundImage: _imageFile != null
                                    ? FileImage(_imageFile!) as ImageProvider
                                    : (existingPhotoUrl != null 
                                            ? NetworkImage(existingPhotoUrl) 
                                            : const AssetImage('assets/iconamoon_profile-light.png')) as ImageProvider,
                                child: (_imageFile == null && existingPhotoUrl == null)
                                    ? Icon(Icons.person, size: w * 0.15, color: Colors.white)
                                    : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: EdgeInsets.all(w * 0.02),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD66031),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.camera_alt, color: Colors.white, size: w * 0.04),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: h * 0.04),

                    // Display Name
                    _buildTextField(
                      label: "Display Name",
                      hint: "e.g., Trail Boss",
                      controller: _nameController,
                      isDark: isDark,
                      w: w,
                      h: h,
                    ),
                    SizedBox(height: h * 0.02),

                    // Username
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Username",
                          style: TextStyle(color: AppColors.secondaryTextColor(isDark), fontSize: w * 0.03),
                        ),
                        SizedBox(height: h * 0.005),
                        TextField(
                          controller: _usernameController,
                          style: TextStyle(color: AppColors.textColor(isDark)),
                          decoration: InputDecoration(
                            hintText: "unique_handle",
                            prefixText: "@",
                            hintStyle: TextStyle(color: AppColors.secondaryTextColor(isDark).withOpacity(0.5)),
                            filled: true,
                            fillColor: AppColors.tileBackgroundColor(isDark),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(w * 0.03),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: _isCheckingUsername
                                ? Padding(
                                    padding: EdgeInsets.all(w * 0.03),
                                    child: SizedBox(
                                      width: w * 0.05, height: w * 0.05,
                                      child: CircularProgressIndicator(strokeWidth: w * 0.005),
                                    ),
                                  )
                                : (_usernameController.text.isNotEmpty && _usernameController.text.trim().toLowerCase() != _currentUsername.toLowerCase())
                                    ? Icon(
                                        _isUsernameAvailable ? Icons.check_circle : Icons.cancel,
                                        color: _isUsernameAvailable ? Colors.green : Colors.red,
                                      )
                                    : null,
                          ),
                        ),
                        if (!_isUsernameAvailable && _usernameController.text.isNotEmpty && _usernameController.text.trim().toLowerCase() != _currentUsername.toLowerCase() && !_isCheckingUsername)
                          Padding(
                            padding: EdgeInsets.only(top: h * 0.005, left: w * 0.01),
                            child: Text(
                              "Username is already taken.",
                              style: TextStyle(color: Colors.red, fontSize: w * 0.03),
                            ),
                          )
                      ],
                    ),
                    SizedBox(height: h * 0.02),

                    // Bio
                    _buildTextField(
                      label: "Bio",
                      hint: "Tell us about yourself...",
                      controller: _bioController,
                      isDark: isDark,
                      w: w,
                      h: h,
                      maxLines: 4,
                    ),
                    SizedBox(height: h * 0.05),

                    // Save Button
                    GestureDetector(
                      onTap: _saveProfile,
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: h * 0.02),
                        decoration: ProGradientDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(w * 0.08)),
                        ),
                        child: Center(
                          child: Text(
                            'Save Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: w * 0.045,
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
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool isDark,
    required double w,
    required double h,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.secondaryTextColor(isDark), fontSize: w * 0.03),
        ),
        SizedBox(height: h * 0.005),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: AppColors.textColor(isDark)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.secondaryTextColor(isDark).withOpacity(0.5)),
            filled: true,
            fillColor: AppColors.tileBackgroundColor(isDark),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(w * 0.03),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
