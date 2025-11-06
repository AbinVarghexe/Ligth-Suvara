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
          backgroundColor: Colors.white,
          elevation: 0,
          leading: ModalRoute.of(context)?.canPop == true
              ? IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1E40AF), size: 20),
            onPressed: () => Navigator.of(context).pop(),
          )
              : GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()))
              // When returning from profile, tell the provider to re-fetch data
                  .then((_) => Provider.of<UserDataProvider>(context, listen: false).fetchUserData());
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
            style: GoogleFonts.poppins(color: const Color(0xFF1E40AF), fontWeight: FontWeight.bold, fontSize: 17),
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.announcement_outlined, color: Color(0xFF1E40AF)),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()));
              },
            ),
            // ⭐️ 5. Use the 'isAdmin' flag directly from the provider
            if (userData.isAdmin)
              IconButton(
                icon: const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF1E40AF)),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
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
