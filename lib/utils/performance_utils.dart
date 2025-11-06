import 'dart:async';
import 'package:flutter/foundation.dart';

/// Performance optimization utilities for the Sunday School app
class PerformanceUtils {
  /// Debug print that only works in debug mode
  static void debugPrint(String message) {
    if (kDebugMode) {
      print(message);
    }
  }

  /// Safe async operation with error handling
  static Future<T?> safeAsyncOperation<T>(
    Future<T> Function() operation, {
    String? errorMessage,
  }) async {
    try {
      return await operation();
    } catch (e) {
      debugPrint('Error in async operation: ${errorMessage ?? e.toString()}');
      return null;
    }
  }

  /// Debounce function to limit frequent calls
  static void debounce(String key, Duration delay, VoidCallback callback) {
    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(delay, callback);
  }

  static final Map<String, Timer> _debounceTimers = {};

  /// Clear all debounce timers
  static void clearDebounceTimers() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
  }
}
