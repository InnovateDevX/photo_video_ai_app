import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:vidzeon/Helpers/error_dialog_helper.dart';
import 'package:vidzeon/Services/notification_service.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  bool _isDialogShowing = false;
  StreamSubscription? _subscription;
  
  void initialize() {
    _subscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _handleConnectivityChange(results);
    });
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    bool hasConnection = !results.contains(ConnectivityResult.none) && results.isNotEmpty;

    if (!hasConnection) {
      _showNoInternetDialog();
    } else {
      _dismissNoInternetDialog();
    }
  }

  void _showNoInternetDialog() {
    if (_isDialogShowing) return;
    
    final context = NotificationService().navigatorKey.currentContext;
    if (context == null) return; 

    _isDialogShowing = true;
    
    ErrorDialogHelper.showNoInternetRetryDialog(context, () async {
       // Manual retry action
       final results = await Connectivity().checkConnectivity();
       _handleConnectivityChange(results);
    });
  }

  void _dismissNoInternetDialog() {
    if (!_isDialogShowing) return;
    final context = NotificationService().navigatorKey.currentContext;
    if (context != null) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    _isDialogShowing = false;
  }
  
  void dispose() {
    _subscription?.cancel();
  }
}
