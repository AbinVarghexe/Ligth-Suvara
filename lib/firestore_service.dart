// lib/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Function to check if the currently logged-in user is an admin
Future<bool> isAdmin() async {
  // Get the current user from Firebase Auth
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    // If no user is logged in, they are not an admin
    return false;
  }

  try {
    // Get the user's document from the 'users' collection using their UID
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    // Check if the document exists and if the 'role' field is 'admin'
    if (userDoc.exists && userDoc.data()?['role'] == 'admin') {
      return true;
    } else {
      return false;
    }
  } catch (e) {
    // If there's an error (e.g., network issue), assume they are not an admin
    print("Error checking admin status: $e");
    return false;
  }
}


// ⬇️ --- ADD THIS NEW FUNCTION --- ⬇️

// --- Function to send a notification ---
Future<void> sendNotification({
  required String title,
  required String body,
  required String recipientId, // This can be 'all' or a specific user's email
}) async {
  try {
    // Add a new document to the 'notifications' collection
    await FirebaseFirestore.instance.collection('notifications').add({
      'title': title,
      'body': body,
      'recipientId': recipientId,
      'isRead': false, // Always set to false initially
      'timestamp': FieldValue.serverTimestamp(), // Use the server's time for consistency
    });
  } catch (e) {
    print("Error sending notification: $e");
    // Re-throw the error so the UI can catch it and show a failure message
    throw Exception('Could not send notification.');
  }
}

// --- NEW (Optional but Recommended): Function to mark notifications as read ---
Future<void> markNotificationAsRead(String notificationId) async {
  try {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  } catch (e) {
    print("Error marking notification as read: $e");
  }
}
