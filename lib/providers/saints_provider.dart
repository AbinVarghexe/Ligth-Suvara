import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SaintResourceItem {
  final String id;
  final String title;
  final String type; // 'youtube', 'pdf', 'drive', 'web', 'doc', 'text' etc.
  final String url;
  final String? content;
  final String? mediaUrl;

  SaintResourceItem({
    required this.id,
    required this.title,
    required this.type,
    required this.url,
    this.content,
    this.mediaUrl,
  });

  factory SaintResourceItem.fromMap(Map<String, dynamic> map, [String? defaultId]) {
    return SaintResourceItem(
      id: map['id']?.toString() ?? defaultId ?? '',
      title: map['title']?.toString() ?? map['name']?.toString() ?? '',
      type: map['type']?.toString() ?? 'web',
      url: map['url']?.toString() ?? '',
      content: map['content']?.toString() ?? map['description']?.toString() ?? map['body']?.toString(),
      mediaUrl: map['mediaUrl']?.toString() ?? map['media_url']?.toString() ?? map['media']?.toString() ?? map['imageUrl']?.toString() ?? map['image_url']?.toString() ?? map['image']?.toString(),
    );
  }
}

class SaintCategory {
  final String id;
  final String name;
  final String? description;
  final String? content;
  final String? mediaUrl;
  final List<SaintResourceItem> items;

  SaintCategory({
    required this.id,
    required this.name,
    this.description,
    this.content,
    this.mediaUrl,
    required this.items,
  });

  factory SaintCategory.fromMap(Map<String, dynamic> map, [String? defaultId]) {
    final rawItems = map['resources'] ?? map['items'];
    List<SaintResourceItem> parsedItems = [];
    if (rawItems is List) {
      parsedItems = rawItems
          .map((item) => SaintResourceItem.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } else if (rawItems is Map) {
      rawItems.forEach((key, value) {
        if (value is Map) {
          parsedItems.add(SaintResourceItem.fromMap(Map<String, dynamic>.from(value), key));
        }
      });
    }

    return SaintCategory(
      id: map['id']?.toString() ?? defaultId ?? '',
      name: map['name']?.toString() ?? map['title']?.toString() ?? '',
      description: map['description']?.toString(),
      content: map['content']?.toString() ?? map['body']?.toString(),
      mediaUrl: map['mediaUrl']?.toString() ?? map['media_url']?.toString() ?? map['media']?.toString() ?? map['imageUrl']?.toString() ?? map['image_url']?.toString() ?? map['image']?.toString(),
      items: parsedItems,
    );
  }
}

class SaintsData {
  final List<SaintCategory> categories;

  SaintsData({required this.categories});

  factory SaintsData.fromMap(Map<String, dynamic> map) {
    final rawCategories = map['categories'];
    List<SaintCategory> parsedCategories = [];
    if (rawCategories is List) {
      parsedCategories = rawCategories
          .map((cat) => SaintCategory.fromMap(Map<String, dynamic>.from(cat)))
          .toList();
    } else if (rawCategories is Map) {
      rawCategories.forEach((key, value) {
        if (value is Map) {
          parsedCategories.add(SaintCategory.fromMap(Map<String, dynamic>.from(value), key));
        }
      });
    }
    return SaintsData(categories: parsedCategories);
  }
}

class SaintsProvider with ChangeNotifier {
  SaintsData? _saintsData;
  SaintsData? get saintsData => _saintsData;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  SaintsProvider() {
    fetchSaintsData();
  }

  Future<void> fetchSaintsData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('saints_resources')
          .doc('all')
          .get();

      if (doc.exists && doc.data() != null) {
        // Print the keys and structure to the debug console to assist with diagnosis
        debugPrint("SAINTS FIREBASE DATA: ${doc.data()}");
        _saintsData = SaintsData.fromMap(doc.data()!);
      } else {
        _saintsData = SaintsData(categories: []);
      }
    } catch (e) {
      _error = e.toString();
      debugPrint("Error fetching saints data: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
