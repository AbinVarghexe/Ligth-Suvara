import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WordOfLifeEntry {
  final String id;
  final String verse;
  final String? reference;
  final String? reflection;
  final String? author;
  final String? imageUrl; // ← was missing, now mapped from DB
  final String? videoUrl;
  final String? aspectRatio;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? createdAt;

  WordOfLifeEntry({
    required this.id,
    required this.verse,
    this.reference,
    this.reflection,
    this.author,
    this.imageUrl,
    this.videoUrl,
    this.aspectRatio,
    this.startDate,
    this.endDate,
    this.createdAt,
  });

  factory WordOfLifeEntry.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime? parseTs(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      return null;
    }

    return WordOfLifeEntry(
      id: doc.id,
      verse: data['verse']?.toString() ??
          data['text']?.toString() ??
          data['content']?.toString() ??
          data['title']?.toString() ??
          '',
      reference: data['reference']?.toString() ??
          data['verseRef']?.toString() ??
          data['ref']?.toString(),
      reflection: data['reflection']?.toString() ??
          data['note']?.toString() ??
          data['notes']?.toString() ??
          data['body']?.toString() ??
          data['description']?.toString(),
      author: data['author']?.toString(),
      // Map ALL common image field name variants from Firestore
      imageUrl: data['imageUrl']?.toString() ??
          data['image_url']?.toString() ??
          data['image']?.toString() ??
          data['mediaUrl']?.toString() ??
          data['media']?.toString() ??
          data['bgImage']?.toString() ??
          data['background']?.toString(),
      videoUrl: data['videoUrl']?.toString() ??
          data['video_url']?.toString() ??
          data['video']?.toString(),
      aspectRatio: data['aspectRatio']?.toString() ??
          data['aspect_ratio']?.toString(),
      startDate: parseTs(data['startDate'] ?? data['start_date'] ?? data['date']),
      endDate: parseTs(data['endDate'] ?? data['end_date']),
      createdAt: parseTs(data['createdAt']),
    );
  }

  bool get hasVideo {
    final url = resolvedVideoUrl;
    return url != null && url.isNotEmpty;
  }

  String? get resolvedVideoUrl {
    if (videoUrl != null && videoUrl!.trim().isNotEmpty) return videoUrl!.trim();
    if (imageUrl != null) {
      final url = imageUrl!.trim().toLowerCase();
      if (url.contains('.mp4') ||
          url.contains('.mov') ||
          url.contains('.m3u8') ||
          url.contains('youtube.com') ||
          url.contains('youtu.be') ||
          url.contains('vimeo.com')) {
        return imageUrl!.trim();
      }
    }
    return null;
  }

  double get resolvedAspectRatio {
    return (aspectRatio == '16:9') ? 16 / 9 : 9 / 16;
  }

  bool get isYoutubeVideo {
    final url = resolvedVideoUrl?.toLowerCase() ?? '';
    return url.contains('youtube.com') || url.contains('youtu.be');
  }

  String? get youtubeVideoId {
    final url = resolvedVideoUrl;
    if (url == null) return null;

    try {
      final uri = Uri.parse(url);
      
      // Handle youtu.be/abc
      if (uri.host.contains('youtu.be')) {
        if (uri.pathSegments.isNotEmpty) {
          return uri.pathSegments.first;
        }
      }
      
      // Handle youtube.com/shorts/abc or youtube.com/embed/abc or youtube.com/v/abc
      if (uri.host.contains('youtube.com')) {
        if (uri.pathSegments.contains('shorts') || 
            uri.pathSegments.contains('embed') || 
            uri.pathSegments.contains('v')) {
          final index = uri.pathSegments.indexWhere((seg) => seg == 'shorts' || seg == 'embed' || seg == 'v');
          if (index != -1 && index + 1 < uri.pathSegments.length) {
            return uri.pathSegments[index + 1];
          }
        }
        
        // Handle standard youtube.com/watch?v=abc
        if (uri.queryParameters.containsKey('v')) {
          return uri.queryParameters['v'];
        }
      }
    } catch (_) {}

    final regExp = RegExp(
      r'^.*(youtu.be\/|v\/|u\/\w\/|embed\/|shorts\/|watch\?v=|\&v=)([^#\&\?]*).*',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    if (match != null && match.group(2)!.length == 11) {
      return match.group(2);
    }
    return null;
  }

  /// Active when today is within [startDate, endDate].
  bool get isActive {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOk = startDate == null ||
        !DateTime(startDate!.year, startDate!.month, startDate!.day)
            .isAfter(today);
    final endOk = endDate == null ||
        !DateTime(endDate!.year, endDate!.month, endDate!.day).isBefore(today);
    return startOk && endOk;
  }

  bool get isExpired {
    if (endDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(endDate!.year, endDate!.month, endDate!.day).isBefore(today);
  }

  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;
}

class WordOfLifeProvider with ChangeNotifier {
  List<WordOfLifeEntry> _entries = [];
  List<WordOfLifeEntry> get entries => _entries;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  StreamSubscription<QuerySnapshot>? _subscription;

  WordOfLifeProvider() {
    _listen();
  }

  void _listen() {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _subscription = FirebaseFirestore.instance
        .collection('word_of_life')
        .orderBy('startDate', descending: false)
        .snapshots()
        .listen(
      (snapshot) {
        _entries = snapshot.docs.map((doc) => WordOfLifeEntry.fromDoc(doc)).toList();
        _sortEntries();
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _tryFallbackListen();
        debugPrint('WordOfLifeProvider error (retrying without orderBy): $e');
      },
    );
  }

  void _tryFallbackListen() {
    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('word_of_life')
        .snapshots()
        .listen(
      (snapshot) {
        _entries = snapshot.docs.map((doc) => WordOfLifeEntry.fromDoc(doc)).toList();
        _sortEntries();
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void _sortEntries() {
    _entries.sort((a, b) {
      final aActive = a.isActive && !a.isExpired;
      final bActive = b.isActive && !b.isExpired;
      if (aActive && !bActive) return -1;
      if (!aActive && bActive) return 1;
      if (a.endDate != null && b.endDate != null) return b.endDate!.compareTo(a.endDate!);
      if (a.startDate != null && b.startDate != null) return b.startDate!.compareTo(a.startDate!);
      return 0;
    });
  }

  Future<void> refresh() async {
    try {
      QuerySnapshot snapshot;
      try {
        snapshot = await FirebaseFirestore.instance
            .collection('word_of_life')
            .orderBy('startDate', descending: false)
            .get();
      } catch (_) {
        snapshot = await FirebaseFirestore.instance.collection('word_of_life').get();
      }
      _entries = snapshot.docs.map((doc) => WordOfLifeEntry.fromDoc(doc)).toList();
      _sortEntries();
      notifyListeners();
    } catch (e) {
      debugPrint('WordOfLifeProvider refresh error: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
