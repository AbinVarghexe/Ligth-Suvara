// lib/homescreen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for HapticFeedback
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sundayschool_app/auth_screen.dart';
import 'package:sundayschool_app/uploadscreen.dart';
import 'package:sundayschool_app/notification_screen.dart';
import 'package:sundayschool_app/admin_dashboard_screen.dart';
import 'package:sundayschool_app/event_detail_screen.dart';
import 'package:sundayschool_app/profile_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';

// The two ways we can sort
enum SortOption { newestFirst, alphabetical }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- STATE VARIABLES ---
  SortOption _currentSortOption = SortOption.newestFirst;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // State for the modern category filter
  int _selectedCategoryIndex = 0; // 0: ALL, 1: CML, 2: SUVARA
  final List<String> _categories = ['ALL', 'CML', 'SUVARA'];

  String _schoolDisplayName = 'Loading...';
  String? _profileImageUrl;

  // 1. ADD new state variable for admin status
  bool _isAdmin = false;
  // 2. REMOVE: late Future<bool> _isAdminFuture;

  @override
  void initState() {
    super.initState();
    // 3. REMOVE: _isAdminFuture = _checkIfAdmin();
    _loadUserData(); // Updated to handle admin check now
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  // 4. UPDATE _loadUserData to include admin check and setState
  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _schoolDisplayName = 'Guest User';
          _profileImageUrl = null;
          _isAdmin = false; // Ensure it's false for guest
        });
      }
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      String finalDisplayName = user.email?.split('@').first ?? 'User';
      String? imageUrl;
      bool localIsAdmin = false; // Variable to hold fetched admin status

      if (userDoc.exists) {
        final data = userDoc.data();
        final schoolName = data?['schoolName'] ?? data?['schoolname'];
        if (schoolName != null && schoolName.toString().isNotEmpty) {
          finalDisplayName = schoolName.toString();
        }
        imageUrl = data?['profileImageUrl']?.toString();
        // Check for admin role
        localIsAdmin = data?['role'] == 'admin';
      }
      if (mounted) {
        setState(() {
          _schoolDisplayName = finalDisplayName;
          _profileImageUrl = imageUrl;
          _isAdmin = localIsAdmin; // Update the state variable
        });
      }
    } catch (e) {
      debugPrint("Error loading user data: $e");
      if (mounted) {
        setState(() => _schoolDisplayName = 'Error');
      }
    }
  }

  // 5. REMOVE: Future<bool> _checkIfAdmin() async { ... }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sort Events By'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<SortOption>(
                title: const Text('Newest First'),
                value: SortOption.newestFirst,
                groupValue: _currentSortOption,
                onChanged: (value) {
                  if (value != null) {
                    setState(() { _currentSortOption = value; });
                    Navigator.of(context).pop();
                  }
                },
              ),
              RadioListTile<SortOption>(
                title: const Text('Alphabetical (A-Z)'),
                value: SortOption.alphabetical,
                groupValue: _currentSortOption,
                onChanged: (value) {
                  if (value != null) {
                    setState(() { _currentSortOption = value; });
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Logout', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to log out?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
              (Route<dynamic> route) => false,
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // The main scaffold structure remains the same
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            ).then((_) {
              _loadUserData();
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              backgroundImage: _profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null,
              child: _profileImageUrl == null ? Icon(Icons.person, color: Colors.blue.shade900) : null,
            ),
          ),
        ),
        title: Text(
          _schoolDisplayName,
          style: GoogleFonts.poppins(color: Colors.blue.shade900, fontWeight: FontWeight.bold, fontSize: 17),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseAuth.instance.currentUser != null ? FirebaseFirestore.instance
                .collection('notifications')
                .where('recipientId', whereIn: [FirebaseAuth.instance.currentUser!.uid, 'all'])
                .snapshots() : null,
            builder: (context, snapshot) {
              int unreadCount = 0;
              if (snapshot.hasData && snapshot.data != null) {
                unreadCount = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>?;
                  return data != null && data['isRead'] == false;
                }).length;
              }

              return IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.announcement_outlined, color: Color(0xFF1E40AF)),
                    if (unreadCount > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                  );
                },
              );
            },
          ),
          // 6. Use the _isAdmin state variable directly
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF1E40AF)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
                );
              },
            ),
          // 7. REMOVE FutureBuilder block
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF1E40AF)),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Highlight Events', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                const SizedBox(height: 16),
                const HighlightEventCard(),
                const SizedBox(height: 24),
                _buildRecentEventsHeader(),
                const SizedBox(height: 16),
                // --- ✨ CALLING THE NEW MODERN FILTER ✨ ---
                _buildModernCategoryFilter(),
                const SizedBox(height: 16),
                _buildSearchBox(),
                const SizedBox(height: 16),
                _buildRecentEventsList(),
                const SizedBox(height: 40), // Padding for watermark
              ],
            ),
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Text(
              '© ${DateTime.now().year} AJCE. All Rights Reserved.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.blue.shade900.withAlpha(128),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UploadScreen()),
          );
        },
        backgroundColor: Colors.blue.shade900,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // --- Helper widgets ---
  Widget _buildRecentEventsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Recent Events', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1E40AF))),
        IconButton(
          icon: const Icon(Icons.filter_list, color: Color(0xFF1E40AF)),
          onPressed: _showSortDialog,
        ),
      ],
    );
  }

  // --- ✨ NEW, MODERN, ANIMATED CATEGORY FILTER ✨ ---
  Widget _buildModernCategoryFilter() {
    final Color themeColor = Colors.blue.shade900;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: Alignment(
                _selectedCategoryIndex == 0 ? -1.0 : (_selectedCategoryIndex == 1 ? 0.0 : 1.0),
                0),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeIn,
            child: Container(
              width: (MediaQuery.of(context).size.width - 32) / 3, // Subtract padding
              height: 40,
              decoration: BoxDecoration(
                color: themeColor,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Row(
            children: List.generate(_categories.length, (index) {
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact(); // Add a nice tactile feel
                    setState(() {
                      _selectedCategoryIndex = index;
                    });
                  },
                  child: Center(
                    child: Text(
                      _categories[index],
                      style: GoogleFonts.poppins(
                        color: _selectedCategoryIndex == index
                            ? Colors.white
                            : themeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search by event title...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.blue.shade50,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
      ),
    );
  }

  // --- 8. LOGIC UPDATED TO FILTER BY CREATOR ID IF NOT ADMIN ---
  Widget _buildRecentEventsList() {
    final selectedCategory = _categories[_selectedCategoryIndex];
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    Query baseQuery = FirebaseFirestore.instance.collection('events')
        .orderBy('timestamp', descending: true);

    // CORE CHANGE: Filter by creatorId if user is not an admin
    if (!_isAdmin && currentUserUid != null) {
      baseQuery = baseQuery.where('creatorId', isEqualTo: currentUserUid);
    }
    // End CORE CHANGE

    if (selectedCategory != 'ALL') {
      baseQuery = baseQuery.where('category', isEqualTo: selectedCategory.toLowerCase());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: baseQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Check for index error specifically
          if (snapshot.error.toString().contains('requires an index')) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 50),
                    SizedBox(height: 10),
                    Text(
                      "Database Index Required",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "The query for filtering events by creator and category requires a composite index in Firestore. Please create it in the Firebase console.",
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const EventListSkeleton();
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // Provide appropriate message if no events are found.
          String message = "No events found.";
          if (selectedCategory != 'ALL') {
            message = "No events found for $selectedCategory.";
          } else if (currentUserUid != null && !_isAdmin) {
            message = "No events created by you found.";
          }
          return Center(
              child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                      message,
                      style: GoogleFonts.poppins(color: Colors.grey.shade600)
                  )
              )
          );
        }

        // --- Client-side filtering for SEARCH on top of the category query results ---
        final eventDocs = snapshot.data!.docs;
        List<DocumentSnapshot> filteredDocs = eventDocs;

        if (_searchQuery.isNotEmpty) {
          filteredDocs = eventDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title']?.toString().toLowerCase() ?? '';
            return title.contains(_searchQuery);
          }).toList();
        }

        // --- Client-side SORTING ---
        if (_currentSortOption == SortOption.alphabetical) {
          filteredDocs.sort((a, b) {
            String aTitle = (a.data() as Map<String, dynamic>)['title']?.toString().toLowerCase() ?? '';
            String bTitle = (b.data() as Map<String, dynamic>)['title']?.toString().toLowerCase() ?? '';
            return aTitle.compareTo(bTitle);
          });
        }

        if (filteredDocs.isEmpty) {
          return Center(
              child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                      'No events matching "$_searchQuery".',
                      style: GoogleFonts.poppins(color: Colors.grey.shade600)
                  )
              )
          );
        }

        // Build the list from the final filtered and sorted documents
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            var eventDoc = filteredDocs[index];
            var data = eventDoc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 12.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 2,
              color: Colors.blue.shade50,
              child: ListTile(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => EventDetailScreen(eventId: eventDoc.id),
                    ),
                  );
                },
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10.0),
                  child: Container(
                    width: 60,
                    height: 60,
                    color: Colors.blue.shade100,
                    child: data['imageUrl'] != null
                        ? Image.network(
                      data['imageUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, st) =>
                      const Icon(Icons.broken_image, color: Colors.white),
                    )
                        : const Icon(Icons.image, color: Colors.white),
                  ),
                ),
                title: Text(
                  data['title'] ?? 'No Title',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                subtitle: Text(
                  data['description'] ?? 'No Description',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.blue[700],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// HighlightEventCard unchanged
class HighlightEventCard extends StatefulWidget {
  const HighlightEventCard({super.key});
  @override
  State<HighlightEventCard> createState() => _HighlightEventCardState();
}

class _HighlightEventCardState extends State<HighlightEventCard> {
  late final Stream<QuerySnapshot> _highlightStream;

  @override
  void initState() {
    super.initState();
    _highlightStream = _createHighlightStream();
  }

  // CORE FIX: Custom method to build the filtered stream for the highlight card
  Stream<QuerySnapshot> _createHighlightStream() {
    final user = FirebaseAuth.instance.currentUser;
    Query baseQuery = FirebaseFirestore.instance.collection('events');

    // If a user is logged in, restrict the highlighted event to those they created.
    if (user != null) {
      // This enforces the privacy constraint for non-admin users.
      baseQuery = baseQuery.where('creatorId', isEqualTo: user.uid);
    }

    // Always order by timestamp to get the newest, and limit to 1.
    return baseQuery
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots();
  }
  // END CORE FIX

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _highlightStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.grey.shade300,
            ),
            child: const Center(child: Text("No highlight event available.")),
          );
        }
        var eventDoc = snapshot.data!.docs.first;
        var data = eventDoc.data() as Map<String, dynamic>;
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EventDetailScreen(eventId: eventDoc.id),
              ),
            );
          },
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              image: DecorationImage(
                image: NetworkImage(
                  data['imageUrl'] ?? 'https://via.placeholder.com/400x200?text=No+Image',
                ),
                fit: BoxFit.cover,
                onError: (exception, stackTrace) {
                  debugPrint('Error loading image: $exception');
                },
              ),
            ),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withAlpha(153), // 60% opacity
                        Colors.transparent
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.center,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Text(
                    data['title'] ?? 'No Title',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 10.0,
                          color: Colors.black54,
                          offset: Offset(2.0, 2.0),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// EventListSkeleton unchanged
class EventListSkeleton extends StatelessWidget {
  const EventListSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    Widget buildShimmerBlock(
        {required double height,
          double width = double.infinity,
          double radius = 15.0}) {
      return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                buildShimmerBlock(height: 60, width: 60, radius: 10),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildShimmerBlock(height: 16, width: 200),
                      const SizedBox(height: 8),
                      buildShimmerBlock(height: 14, width: 150),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}