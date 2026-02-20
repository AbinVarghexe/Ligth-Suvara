// lib/custom_app_bar.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart'; // ⭐️ 1. Import Provider
import 'package:sundayschool_app/admin_dashboard_screen.dart';
import 'package:sundayschool_app/notification_screen.dart';
import 'package:sundayschool_app/profile_screen.dart';
import 'package:sundayschool_app/providers/user_data_provider.dart'; // ⭐️ 2. Import your UserDataProvider

// ⭐️ 3. Convert to a much simpler StatelessWidget
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    // ⭐️ 4. Use a "Consumer" to get data from the provider
    // This widget will automatically rebuild only when the user data changes.
    return Consumer<UserDataProvider>(
      builder: (context, userDataProvider, child) {
        // Get the centrally-managed user data
        final userData = userDataProvider.userData;

        // The rest of your AppBar UI remains IDENTICAL, but uses the provider's data
        return AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade900, Colors.blue.shade700],
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          /* shape: Border( // Removed border as it might clash with gradient
            bottom: BorderSide(
              color: const Color(0xFFFFE4B5).withOpacity(0.5),
              width: 1,
            ),
          ), */
          leading: ModalRoute.of(context)?.canPop == true
              ? IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, // Changed to white
                  ),
                  onPressed: () => Navigator.pop(context),
                )
              : GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    )
                    // When returning from profile, tell the provider to re-fetch data
                    .then(
                      (_) => Provider.of<UserDataProvider>(
                        context,
                        listen: false,
                      ).fetchUserData(),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      backgroundImage: userData.profileImageUrl != null
                          ? NetworkImage(userData.profileImageUrl!)
                          : null,
                      child: userData.profileImageUrl == null
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
          title: Text(
            userData.schoolDisplayName, // Use data from provider
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                );
              },
            ),
            // ⭐️ 5. Use the 'isAdmin' flag directly from the provider
            if (userData.isAdmin)
              IconButton(
                icon: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: Color(0xFF1E40AF),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminDashboardScreen(),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
