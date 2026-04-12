/// Connectivity service — monitors internet availability.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  /// Check initial connectivity and start monitoring.
  Future<void> init() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = _hasInternet(results);
    notifyListeners();
    startMonitoring();
  }

  /// Listen for connectivity changes.
  void startMonitoring() {
    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = _hasInternet(results);
      if (wasOnline != _isOnline) {
        notifyListeners();
      }
    });
  }

  bool _hasInternet(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
