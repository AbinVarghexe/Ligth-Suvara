import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// A simple model to hold our user's data
class UserData {
  final String schoolDisplayName;
  final String? profileImageUrl;
  final bool isAdmin;
  final bool isAnimator;
  final bool isSchool;
  final bool isParish;
  final bool isObserver;
  final bool isTeacher;
  final String? parishId;
  final String? schoolId;
  final String? schoolName;

  UserData({
    this.schoolDisplayName = 'Guest',
    this.profileImageUrl,
    this.isAdmin = false,
    this.isAnimator = false,
    this.isSchool = false,
    this.isParish = false,
    this.isObserver = false,
    this.isTeacher = false,
    this.parishId,
    this.schoolId,
    this.schoolName,
  });
}

// The Provider class that will manage the state
class UserDataProvider with ChangeNotifier {
  UserData _userData = UserData(); // Internal private state
  UserData get userData => _userData; // Public getter for the data

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  UserDataProvider() {
    // Listen to auth state changes to automatically fetch or clear data
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        fetchUserData(user);
      } else {
        // If user logs out, clear the data
        _userData = UserData();
        _isLoading = false; // Not loading anymore
        notifyListeners();
      }
    });
  }

  Future<void> fetchUserData([User? user]) async {
    final currentUser = user ?? FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      String finalDisplayName = currentUser.email?.split('@').first ?? 'User';
      String? imageUrl;
      bool isAdmin = false;
      bool isAnimator = false;
      bool isSchool = false;
      bool isParish = false;
      bool isObserver = false;
      bool isTeacher = false;
      String? parishId;
      String? schoolId;
      String? schoolNameStr;

      if (userDoc.exists) {
        final data = userDoc.data();
        final name =
            data?['schoolName'] ?? data?['schoolname'] ?? data?['name'];

        if (name != null && name.toString().isNotEmpty) {
          finalDisplayName = name.toString();
          schoolNameStr = name.toString();
        }
        imageUrl = data?['profileImageUrl']?.toString();
        final role = data?['role'];
        isAdmin = role == 'admin';
        isAnimator = role == 'animator';
        isSchool = role == 'school';
        isParish = role == 'parish';
        isObserver = role == 'observer';
        isTeacher = role == 'teacher';
        // Improved parishId fetching: check both 'parishId' and 'parish' fields
        parishId = data?['parishId'] ?? data?['parish'];
        schoolId = data?['schoolId'];
      }

      // Update the internal state
      _userData = UserData(
        schoolDisplayName: finalDisplayName,
        profileImageUrl: imageUrl,
        isAdmin: isAdmin,
        isAnimator: isAnimator,
        isSchool: isSchool,
        isParish: isParish,
        isObserver: isObserver,
        isTeacher: isTeacher,
        parishId: parishId,
        schoolId: schoolId,
        schoolName: schoolNameStr,
      );
    } catch (e) {
      debugPrint("Error fetching user data for provider: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
