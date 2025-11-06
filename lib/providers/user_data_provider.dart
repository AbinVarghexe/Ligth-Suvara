import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// A simple model to hold our user's data
class UserData {
  final String schoolDisplayName;
  final String? profileImageUrl;
  final bool isAdmin;

  UserData({
    this.schoolDisplayName = 'Guest',
    this.profileImageUrl,
    this.isAdmin = false,
  });
}

// The Provider class that will manage the state
class UserDataProvider with ChangeNotifier {
  UserData _userData = UserData(); // Internal private state
  UserData get userData => _userData; // Public getter for the data

  UserDataProvider() {
    // Listen to auth state changes to automatically fetch or clear data
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        fetchUserData(user);
      } else {
        // If user logs out, clear the data
        _userData = UserData();
        notifyListeners();
      }
    });
  }

  Future<void> fetchUserData([User? user]) async {
    final currentUser = user ?? FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();

      String finalDisplayName = currentUser.email?.split('@').first ?? 'User';
      String? imageUrl;
      bool isAdmin = false;

      if (userDoc.exists) {
        final data = userDoc.data();
        final schoolName = data?['schoolName'] ?? data?['schoolname'];

        if (schoolName != null && schoolName.toString().isNotEmpty) {
          finalDisplayName = schoolName.toString();
        }
        imageUrl = data?['profileImageUrl']?.toString();
        isAdmin = data?['role'] == 'admin';
      }

      // Update the internal state
      _userData = UserData(
        schoolDisplayName: finalDisplayName,
        profileImageUrl: imageUrl,
        isAdmin: isAdmin,
      );

      // Notify all listening widgets that the data has changed
      notifyListeners();
    } catch (e) {
      print("Error fetching user data for provider: $e");
    }
  }
}
