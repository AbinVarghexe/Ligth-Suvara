import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class ContentProvider with ChangeNotifier {
  // Cache for Broadcasts (Latest Updates)
  List<QueryDocumentSnapshot> _broadcasts = [];
  List<QueryDocumentSnapshot> get broadcasts => _broadcasts;

  // Cache for Events (Recent Programs)
  List<QueryDocumentSnapshot> _events = [];
  List<QueryDocumentSnapshot> get events => _events;

  // Cache for Calendar Config
  Map<String, dynamic> _calendarConfig = {};
  Map<String, dynamic> get calendarConfig => _calendarConfig;

  // Cache for Login Screen Config
  Map<String, dynamic> _loginConfig = {};
  Map<String, dynamic> get loginConfig => _loginConfig;
  // Cache for Theme & Programs Config
  Map<String, dynamic> _themeProgramsConfig = {};
  Map<String, dynamic> get themeProgramsConfig => _themeProgramsConfig;

  bool _isLoadingBroadcasts = false;
  bool get isLoadingBroadcasts => _isLoadingBroadcasts;

  bool _isLoadingEvents = false;
  bool get isLoadingEvents => _isLoadingEvents;

  bool _isLoadingThemePrograms = false;
  bool get isLoadingThemePrograms => _isLoadingThemePrograms;

  // Stream Subscriptions
  StreamSubscription? _broadcastSubscription;
  StreamSubscription? _eventSubscription;
  StreamSubscription? _loginConfigSubscription;
  StreamSubscription? _themeProgramsSubscription;
  StreamSubscription? _calendarSubscription;

  // Define limits consistent with UI
  static const int _broadcastLimit = 4;
  static const int _eventLimit = 4;

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
      await _themeProgramsSubscription?.cancel();
      _themeProgramsSubscription = null;
      await _calendarSubscription?.cancel();
      _calendarSubscription = null;
    }
    fetchBroadcasts();
    fetchEvents();
    fetchLoginConfig();
    fetchThemeProgramsConfig();
    fetchCalendarConfig();
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
            _broadcasts = snapshot.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              return data?['notificationOnly'] != true;
            }).toList();
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
              return isPublic == true ||
                  creatorId == 'cwEVLXnIKvNkTOj2ld9WYTUXgFu2';
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

  void fetchThemeProgramsConfig() {
    if (_themeProgramsSubscription != null) return;

    if (_themeProgramsConfig.isEmpty) {
      _isLoadingThemePrograms = true;
      notifyListeners();
    }

    _themeProgramsSubscription = FirebaseFirestore.instance
        .collection('settings')
        .doc('theme_programs')
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists) {
              _themeProgramsConfig = snapshot.data() as Map<String, dynamic>;
              _isLoadingThemePrograms = false;
              notifyListeners();
            }
          },
          onError: (e) {
            debugPrint("Error fetching theme programs config: $e");
            _isLoadingThemePrograms = false;
            notifyListeners();
          },
        );
  }

  void fetchCalendarConfig() {
    if (_calendarSubscription != null) return;

    _calendarSubscription = FirebaseFirestore.instance
        .collection('settings')
        .doc('calendar')
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists) {
              _calendarConfig = snapshot.data() as Map<String, dynamic>;
              notifyListeners();
              _prefetchCalendarPdf();
            }
          },
          onError: (e) {
            debugPrint("Error fetching calendar config: $e");
          },
        );
  }

  void _prefetchCalendarPdf() async {
    final pdfUrl = _calendarConfig['pdfUrl'] ?? _calendarConfig['calendarUrl'] ?? _calendarConfig['url'] ?? '';
    if (pdfUrl.isEmpty) return;
    
    final lowerUrl = pdfUrl.toLowerCase();
    final isPdf = lowerUrl.contains('.pdf') || 
                 lowerUrl.contains('firebasestorage') ||
                 lowerUrl.contains('/o/');
    if (!isPdf) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final urlHash = pdfUrl.hashCode.toString();
      final localFile = File('${directory.path}/calendar_cache_$urlHash.pdf');

      if (await localFile.exists()) {
        debugPrint('Calendar PDF is already cached (prefetched).');
        return;
      }

      debugPrint('Pre-fetching calendar PDF in background: $pdfUrl');
      final response = await http.get(Uri.parse(pdfUrl));
      if (response.statusCode == 200) {
        await localFile.writeAsBytes(response.bodyBytes);
        debugPrint('Successfully pre-fetched and cached calendar PDF.');
      }
    } catch (e) {
      debugPrint('Error pre-fetching calendar PDF: $e');
    }
  }

  @override
  void dispose() {
    _broadcastSubscription?.cancel();
    _eventSubscription?.cancel();
    _loginConfigSubscription?.cancel();
    _themeProgramsSubscription?.cancel();
    _calendarSubscription?.cancel();
    super.dispose();
  }
}
