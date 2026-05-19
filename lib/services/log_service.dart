import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class LogService {
  // Singleton pattern
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Track the presence connection stream
  bool _isPresenceInitialized = false;

  /// Logs a system action to the Firestore `logs` collection
  Future<void> logAction(
    String action,
    String details, {
    String type = 'system',
  }) async {
    try {
      final user = _auth.currentUser;
      final email = user?.email ?? 'Unknown User';
      final uid = user?.uid ?? 'unknown_uid';

      await _firestore.collection('logs').add({
        'action': action,
        'details': details,
        'type': type,
        'user': email,
        'uid': uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error writing to Firestore logs: $e');
    }
  }

  /// Initializes pseudopresence monitoring for the current user
  Future<void> initPresence(String uid, String email, String role) async {
    if (_isPresenceInitialized) return;
    _isPresenceInitialized = true;

    try {
      await _firestore.collection('users').doc(uid).set({
        'status': 'online',
        'last_seen': FieldValue.serverTimestamp(),
        'email': email,
        'role': role,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error writing to Firestore presence: $e');
    }
  }

  /// Explicitly marks the user as offline (e.g., during manual logout)
  Future<void> setOffline(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'status': 'offline',
        'last_seen': FieldValue.serverTimestamp(),
      });
      _isPresenceInitialized = false;
    } catch (e) {
      debugPrint('Error setting offline status: $e');
    }
  }

  /// Get a stream of recent logs
  Stream<QuerySnapshot> getLogsStream({int limit = 100}) {
    return _firestore
        .collection('logs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Get a stream of online users
  Stream<QuerySnapshot> getPresenceStream() {
    return _firestore
        .collection('users')
        .where('status', isEqualTo: 'online')
        .snapshots();
  }
}
