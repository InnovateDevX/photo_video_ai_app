import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';

/// Provider responsible for managing user state after initialization.
class UserProvider extends ChangeNotifier {
  final UserRepository _userRepository;

  UserModel? _currentUserData;
  bool _isLoading = false;
  String? _error;

  UserProvider({UserRepository? userRepository})
    : _userRepository = userRepository ?? UserRepository();

  UserModel? get currentUserData => _currentUserData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Loads the user data. Typically called right after AppInitializer resolves the mapped UID.
  Future<void> loadUser(String uid) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUserData = await _userRepository.getUser(uid);
      if (_currentUserData == null) {
        _error = 'User data not found';
      }
    } catch (e) {
      _error = 'Error loading user data: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
