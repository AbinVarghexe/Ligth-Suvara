import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ContentProvider with ChangeNotifier {
  // Cache for Broadcasts (Latest Updates)
  List<QueryDocumentSnapshot> _broadcasts = [];
  List<QueryDocumentSnapshot> get broadcasts => _broadcasts;

  // Cache for Events (Recent Programs)
  List<QueryDocumentSnapshot> _events = [];
  List<QueryDocumentSnapshot> get events => _events;

  // Cache for Login Screen Config
  Map<String, dynamic> _loginConfig = {};
  Map<String, dynamic> get loginConfig => _loginConfig;

  bool _isLoadingBroadcasts = false;
  bool get isLoadingBroadcasts => _isLoadingBroadcasts;

  bool _isLoadingEvents = false;
  bool get isLoadingEvents => _isLoadingEvents;

  // Stream Subscriptions
  StreamSubscription? _broadcastSubscription;
  StreamSubscription? _eventSubscription;
  StreamSubscription? _loginConfigSubscription;

  // Define limits consistent with UI
  static const int _broadcastLimit = 10;
  static const int _eventLimit = 5;

  ContentProvider() {
    // Start listening on initialization
    refreshContent();
  }

  /// Initiates stream listeners for both broadcasts and events
  Future<void> refreshContent({bool forceRefresh = false}) async {
    if (forceRefresh) {
      await _eventSubscription?.cancel();
      _eventSubscription = null;
      await _broadcastSubscription?.cancel();
      _broadcastSubscription = null;
    }
    fetchBroadcasts();
    fetchEvents();
    fetchLoginConfig();
  }

  void fetchBroadcasts() {
    // If we're already listening, we don't need to start another listener
    if (_broadcastSubscription != null) return;

    if (_broadcasts.isEmpty) {
      _isLoadingBroadcasts = true;
      notifyListeners();
    }

    _broadcastSubscription = FirebaseFirestore.instance
        .collection('broadcasts')
        .orderBy('timestamp', descending: true)
        .limit(_broadcastLimit)
        .snapshots()
        .listen(
          (snapshot) {
            _broadcasts = snapshot.docs;
            _isLoadingBroadcasts = false;
            notifyListeners();
          },
          onError: (e) {
            debugPrint("Error fetching broadcasts: $e");
            _isLoadingBroadcasts = false;
            notifyListeners();
          },
        );
  }

  void fetchEvents() {
    if (_eventSubscription != null) return;

    if (_events.isEmpty) {
      _isLoadingEvents = true;
      notifyListeners();
    }

    _eventSubscription = FirebaseFirestore.instance
        .collection('events')
        .orderBy('timestamp', descending: true)
        .limit(_eventLimit)
        .snapshots()
        .listen(
          (snapshot) {
            _events = snapshot.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              if (data == null) return false;
              final isPublic = data['isPublic'] ?? false;
              final creatorId = data['creatorId'] as String?;
              return isPublic == true || creatorId == 'cwEVLXnIKvNkTOj2ld9WYTUXgFu2';
            }).toList();
            _isLoadingEvents = false;
            notifyListeners();
          },
          onError: (e) {
            debugPrint("Error fetching events: $e");
            _isLoadingEvents = false;
            notifyListeners();
          },
        );
  }

  void fetchLoginConfig() {
    if (_loginConfigSubscription != null) return;

    _loginConfigSubscription = FirebaseFirestore.instance
        .collection('settings')
        .doc('login_screen_config')
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists) {
              _loginConfig = snapshot.data() as Map<String, dynamic>;
              notifyListeners();
            }
          },
          onError: (e) {
            debugPrint("Error fetching login config: $e");
          },
        );
  }

  @override
  void dispose() {
    _broadcastSubscription?.cancel();
    _eventSubscription?.cancel();
    _loginConfigSubscription?.cancel();
    super.dispose();
  }
}
