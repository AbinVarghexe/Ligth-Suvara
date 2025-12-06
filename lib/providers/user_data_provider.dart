import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// A simple model to hold our user's data
class UserData {
  final String schoolDisplayName;
  final String? profileImageUrl;
  final bool isAdmin;
  final bool isAnimator; // New field

  UserData({
    this.schoolDisplayName = 'Guest',
    this.profileImageUrl,
    this.isAdmin = false,
    this.isAnimator = false, // Default to false
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
    
    // Set loading to true only if we don't have data yet to avoid flickering if called multiple times
    // or you can force it if you want to show loading on every fetch
    // _isLoading = true; 
    // notifyListeners();

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();

      String finalDisplayName = currentUser.email?.split('@').first ?? 'User';
      String? imageUrl;
      bool isAdmin = false;
      bool isAnimator = false;

      if (userDoc.exists) {
        final data = userDoc.data();
        final schoolName = data?['schoolName'] ?? data?['schoolname'] ?? data?['name']; // Added 'name' check

        if (schoolName != null && schoolName.toString().isNotEmpty) {
          finalDisplayName = schoolName.toString();
        }
        imageUrl = data?['profileImageUrl']?.toString();
        final role = data?['role'];
        isAdmin = role == 'admin';
        isAnimator = role == 'animator';
      }

      // Update the internal state
      _userData = UserData(
        schoolDisplayName: finalDisplayName,
        profileImageUrl: imageUrl,
        isAdmin: isAdmin,
        isAnimator: isAnimator,
      );
      
    } catch (e) {
      print("Error fetching user data for provider: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
