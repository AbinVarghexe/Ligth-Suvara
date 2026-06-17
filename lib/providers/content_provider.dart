import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class LiveVideoConfig {
  final bool isLive;
  final String title;
  final String url;
  final String startDate;
  final String startTime;
  final String endDate;
  final String endTime;

  LiveVideoConfig({
    required this.isLive,
    required this.title,
    required this.url,
    required this.startDate,
    required this.startTime,
    required this.endDate,
    required this.endTime,
  });

  factory LiveVideoConfig.fromMap(Map<String, dynamic> map) {
    return LiveVideoConfig(
      isLive: map['isLive'] ?? false,
      title: map['title'] ?? 'Live Stream',
      url: map['url'] ?? '',
      startDate: map['startDate'] ?? '',
      startTime: map['startTime'] ?? '',
      endDate: map['endDate'] ?? '',
      endTime: map['endTime'] ?? '',
    );
  }

  /// Evaluates whether the stream is active based on local time and scheduled slots.
  bool get isActive {
    if (!isLive || url.isEmpty) return false;
    
    // If scheduling parameters are blank, default to simple toggle status
    if (startDate.isEmpty || startTime.isEmpty || endDate.isEmpty || endTime.isEmpty) {
      return true;
    }

    try {
      final now = DateTime.now();
      
      // Parse ISO Date strings
      final start = DateTime.parse('${startDate}T$startTime:00');
      final end = DateTime.parse('${endDate}T$endTime:00');
      
      return now.isAfter(start) && now.isBefore(end);
    } catch (e) {
      // Fallback to simple isLive toggle if dates fail to parse
      return isLive;
    }
  }
}

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

  // Cache for Dynamic Resource Sections
  List<Map<String, dynamic>> _resourceSections = [];
  List<Map<String, dynamic>> get resourceSections => _resourceSections;

  // Cache for Live Video Config
  LiveVideoConfig _liveVideoConfig = LiveVideoConfig(
    isLive: false,
    title: 'Live Stream',
    url: '',
    startDate: '',
    startTime: '',
    endDate: '',
    endTime: '',
  );
  LiveVideoConfig get liveVideoConfig => _liveVideoConfig;

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
  StreamSubscription? _resourceSectionsSubscription;
  StreamSubscription? _liveVideoConfigSubscription;

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
      await _resourceSectionsSubscription?.cancel();
      _resourceSectionsSubscription = null;
      await _liveVideoConfigSubscription?.cancel();
      _liveVideoConfigSubscription = null;
    }
    fetchBroadcasts();
    fetchEvents();
    fetchLoginConfig();
    fetchThemeProgramsConfig();
    fetchCalendarConfig();
    fetchResourceSections();
    fetchLiveVideoConfig();
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

  void fetchResourceSections() {
    if (_resourceSectionsSubscription != null) return;

    _resourceSectionsSubscription = FirebaseFirestore.instance
        .collection('video_resources')
        .doc('sections_config')
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists) {
              final data = snapshot.data();
              final sectionsRaw = data?['sections'] as List<dynamic>? ?? [];
              final List<Map<String, dynamic>> parsed = sectionsRaw
                  .map((s) => Map<String, dynamic>.from(s))
                  .toList();
              // Sort sections by their 'order' field
              parsed.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
              
              _resourceSections = parsed;
              notifyListeners();
            }
          },
          onError: (e) {
            debugPrint("Error fetching resource sections config: $e");
          },
        );
  }

  void fetchLiveVideoConfig() {
    if (_liveVideoConfigSubscription != null) return;

    _liveVideoConfigSubscription = FirebaseFirestore.instance
        .collection('settings')
        .doc('live_video_config')
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists && snapshot.data() != null) {
              _liveVideoConfig = LiveVideoConfig.fromMap(snapshot.data()!);
              notifyListeners();
            } else {
              _liveVideoConfig = LiveVideoConfig(
                isLive: false,
                title: 'Live Stream',
                url: '',
                startDate: '',
                startTime: '',
                endDate: '',
                endTime: '',
              );
              notifyListeners();
            }
          },
          onError: (e) {
            debugPrint("Error fetching live video config: $e");
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
    _resourceSectionsSubscription?.cancel();
    _liveVideoConfigSubscription?.cancel();
    super.dispose();
  }
}
