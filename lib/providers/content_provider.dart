import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ContentProvider with ChangeNotifier {
  // Cache for Broadcasts (Latest Updates)
  List<QueryDocumentSnapshot> _broadcasts = [];
  List<QueryDocumentSnapshot> get broadcasts => _broadcasts;

  // Cache for Events (Recent Programs)
  List<QueryDocumentSnapshot> _events = [];
  List<QueryDocumentSnapshot> get events => _events;

  bool _isLoadingBroadcasts = false;
  bool get isLoadingBroadcasts => _isLoadingBroadcasts;

  bool _isLoadingEvents = false;
  bool get isLoadingEvents => _isLoadingEvents;

  // Define limits consistent with UI
  static const int _broadcastLimit = 10;
  static const int _eventLimit = 5;

  ContentProvider() {
    // Optionally fetch on initialization
    refreshContent();
  }

  /// Fetches both broadcasts and events
  Future<void> refreshContent() async {
    await Future.wait([fetchBroadcasts(), fetchEvents()]);
  }

  Future<void> fetchBroadcasts() async {
    // If we already have data, we can optionally skip or just refresh silently
    // For now, we'll set loading to true only if we have NO data to avoid UI flicker
    if (_broadcasts.isEmpty) {
      _isLoadingBroadcasts = true;
      notifyListeners();
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('broadcasts')
          .orderBy('timestamp', descending: true)
          .limit(_broadcastLimit)
          .get();

      _broadcasts = snapshot.docs;
    } catch (e) {
      debugPrint("Error fetching broadcasts: $e");
    } finally {
      _isLoadingBroadcasts = false;
      notifyListeners();
    }
  }

  Future<void> fetchEvents() async {
    if (_events.isEmpty) {
      _isLoadingEvents = true;
      notifyListeners();
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('events')
          .orderBy('timestamp', descending: true)
          .limit(_eventLimit)
          .get();

      _events = snapshot.docs;
    } catch (e) {
      debugPrint("Error fetching events: $e");
    } finally {
      _isLoadingEvents = false;
      notifyListeners();
    }
  }
}
