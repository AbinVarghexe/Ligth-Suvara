import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CatechismHourEntry {
  final String id;
  final String title;
  final String? imageUrl;
  final String? notes;
  final DateTime? date;       // The scheduled session date
  final DateTime? createdAt;
  final bool isLast;

  CatechismHourEntry({
    required this.id,
    required this.title,
    this.imageUrl,
    this.notes,
    this.date,
    this.createdAt,
    this.isLast = false,
  });

  factory CatechismHourEntry.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime? parseTs(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      return null;
    }

    return CatechismHourEntry(
      id: doc.id,
      title: data['title']?.toString() ?? data['name']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ??
          data['image_url']?.toString() ??
          data['image']?.toString() ??
          data['mediaUrl']?.toString(),
      notes: data['notes']?.toString() ??
          data['note']?.toString() ??
          data['description']?.toString() ??
          data['content']?.toString(),
      date: parseTs(data['date'] ?? data['activeDate']),
      createdAt: parseTs(data['createdAt']),
    );
  }

  CatechismHourEntry copyWith({
    String? id,
    String? title,
    String? imageUrl,
    String? notes,
    DateTime? date,
    DateTime? createdAt,
    bool? isLast,
  }) {
    return CatechismHourEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      isLast: isLast ?? this.isLast,
    );
  }

  /// Entry is ACTIVE from its session date until end of (sessionDate + 6 days).
  /// e.g. a June 20 entry stays active through June 26 at 11:59:59 PM.
  /// If it is the latest/last entry, it remains active indefinitely if no newer entry is added.
  bool get isActive {
    if (isLast) return true;
    if (date == null) return true; // no date = always active
    final now = DateTime.now();
    final sessionDay = DateTime(date!.year, date!.month, date!.day);
    // Active window ends at 23:59:59 on sessionDay + 6
    final activeUntil = sessionDay
        .add(const Duration(days: 6))
        .copyWith(hour: 23, minute: 59, second: 59);
    return now.isBefore(activeUntil) || now.isAtSameMomentAs(activeUntil);
  }

  bool get isPast {
    if (isLast) return false;
    if (date == null) return false;
    final now = DateTime.now();
    final sessionDay = DateTime(date!.year, date!.month, date!.day);
    final activeUntil = sessionDay
        .add(const Duration(days: 6))
        .copyWith(hour: 23, minute: 59, second: 59);
    return now.isAfter(activeUntil);
  }
}

class CatechismHourProvider with ChangeNotifier {
  List<CatechismHourEntry> _entries = [];
  List<CatechismHourEntry> get entries => _entries;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  StreamSubscription<QuerySnapshot>? _subscription;

  CatechismHourProvider() {
    _listen();
  }

  List<CatechismHourEntry> _markLatestEntry(List<CatechismHourEntry> rawEntries) {
    if (rawEntries.isEmpty) return rawEntries;
    DateTime? latestDate;
    for (final entry in rawEntries) {
      if (entry.date != null) {
        if (latestDate == null || entry.date!.isAfter(latestDate)) {
          latestDate = entry.date;
        }
      }
    }
    if (latestDate == null) return rawEntries;
    return rawEntries.map((entry) {
      final isLast = entry.date != null && entry.date!.isAtSameMomentAs(latestDate!);
      return entry.copyWith(isLast: isLast);
    }).toList();
  }

  void _listen() {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _subscription = FirebaseFirestore.instance
        .collection('catechism_hours') // ← correct plural collection name
        .orderBy('date', descending: false)
        .snapshots()
        .listen(
      (snapshot) {
        final parsed = snapshot.docs
            .map((doc) => CatechismHourEntry.fromDoc(doc))
            .toList();
        _entries = _markLatestEntry(parsed);
        // Active (upcoming / today) first sorted by soonest date, then past (most recent first)
        _entries.sort((a, b) {
          final aActive = a.isActive;
          final bActive = b.isActive;
          if (aActive && !bActive) return -1;
          if (!aActive && bActive) return 1;
          if (a.date != null && b.date != null) {
            return aActive
                ? a.date!.compareTo(b.date!) // upcoming: soonest first
                : b.date!.compareTo(a.date!); // past: most recent first
          }
          return 0;
        });
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        debugPrint('CatechismHourProvider error: $e');
        notifyListeners();
      },
    );
  }

  Future<void> refresh() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('catechism_hours')
          .orderBy('date', descending: false)
          .get();
      final parsed = snapshot.docs
          .map((doc) => CatechismHourEntry.fromDoc(doc))
          .toList();
      _entries = _markLatestEntry(parsed);
      _entries.sort((a, b) {
        final aActive = a.isActive;
        final bActive = b.isActive;
        if (aActive && !bActive) return -1;
        if (!aActive && bActive) return 1;
        if (a.date != null && b.date != null) {
          return aActive
              ? a.date!.compareTo(b.date!)
              : b.date!.compareTo(a.date!);
        }
        return 0;
      });
      notifyListeners();
    } catch (e) {
      debugPrint('CatechismHourProvider refresh error: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
