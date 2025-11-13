// lib/homescreen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:async/async.dart';
import 'dart:math' as math;

enum SortOption { newestFirst, alphabetical }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  SortOption _currentSortOption = SortOption.newestFirst;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  int _selectedCategoryIndex = 0;
  final List<String> _categories = ['ALL', 'CML', 'SUVARA'];

  String _schoolDisplayName = 'Loading...';
  String? _profileImageUrl;
  bool _isAdmin = false;

  late AnimationController _headerAnimationController;
  late AnimationController _fabAnimationController;
  late Animation<double> _headerAnimation;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _searchController.addListener(_onSearchChanged);

    _headerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOutCubic,
    );
    _headerAnimationController.forward();

    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.elasticOut,
    );
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _fabAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _headerAnimationController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _schoolDisplayName = 'Guest User';
          _profileImageUrl = null;
          _isAdmin = false;
        });
      }
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      String finalDisplayName = user.email?.split('@').first ?? 'User';
      String? imageUrl;
      bool localIsAdmin = false;

      if (userDoc.exists) {
        final data = userDoc.data();
        final schoolName = data?['schoolName'] ?? data?['schoolname'];
        if (schoolName != null && schoolName.toString().isNotEmpty) {
          finalDisplayName = schoolName.toString();
        }
        imageUrl = data?['profileImageUrl']?.toString();
        localIsAdmin = data?['role'] == 'admin';
      }
      if (mounted) {
        setState(() {
          _schoolDisplayName = finalDisplayName;
          _profileImageUrl = imageUrl;
          _isAdmin = localIsAdmin;
        });
      }
    } catch (e) {
      debugPrint("Error loading user data: $e");
      if (mounted) {
        setState(() => _schoolDisplayName = 'Error');
      }
    }
  }

  void _showSortDialog() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Sort Events By',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSortOption(
              'Newest First',
              Icons.schedule_rounded,
              SortOption.newestFirst,
            ),
            _buildSortOption(
              'Alphabetical (A-Z)',
              Icons.sort_by_alpha_rounded,
              SortOption.alphabetical,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String title, IconData icon, SortOption option) {
    final isSelected = _currentSortOption == option;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentSortOption = option);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        color: isSelected ? Colors.blue.shade50 : Colors.transparent,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.shade900
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.blue.shade900 : Colors.grey.shade700,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Colors.blue.shade900, size: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.logout_rounded, color: Colors.red.shade600),
            ),
            const SizedBox(width: 12),
            Text(
              'Confirm Logout',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text('Logout', style: GoogleFonts.poppins()),
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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        slivers: [
          _buildModernAppBar(),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _headerAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildHighlightSection(),
                  const SizedBox(height: 32),
                  _buildRecentEventsSection(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade700,
                Colors.blue.shade900,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade900.withAlpha(102),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UploadScreen()),
              );
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: Text(
              'New Event',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 80,
      floating: false,
      pinned: true,
      backgroundColor: Colors.blue.shade900,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade900,
                Colors.blue.shade700,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfileScreen(),
                            ),
                          ).then((_) => _loadUserData());
                        },
                        child: Hero(
                          tag: 'profile_avatar',
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white,
                                  Colors.blue.shade100,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(51),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.blue.shade100,
                              backgroundImage: _profileImageUrl != null
                                  ? NetworkImage(_profileImageUrl!)
                                  : null,
                              child: _profileImageUrl == null
                                  ? Icon(Icons.person,
                                  color: Colors.blue.shade900, size: 28)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _schoolDisplayName,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      _buildHeaderIconButton(
                        StreamBuilder<List<QuerySnapshot>>(
                          stream: StreamZip([
                            FirebaseFirestore.instance
                                .collection('notifications')
                                .where('recipientId', whereIn: [
                              FirebaseAuth.instance.currentUser?.uid ??
                                  'INVALID_USER',
                              'all'
                            ]).snapshots(),
                            FirebaseFirestore.instance
                                .collection('broadcasts')
                                .snapshots(),
                          ]),
                          builder: (context, snapshot) {
                            int unreadCount = 0;
                            if (snapshot.hasData && snapshot.data != null) {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                final allDocs = [
                                  ...snapshot.data![0].docs,
                                  ...snapshot.data![1].docs
                                ];
                                unreadCount = allDocs.where((doc) {
                                  final data =
                                  doc.data() as Map<String, dynamic>?;
                                  final readBy =
                                      data?['readBy'] as List<dynamic>? ?? [];
                                  return !readBy.contains(user.uid);
                                }).length;
                              }
                            }
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(Icons.notifications_rounded,
                                    color: Colors.white, size: 24),
                                if (unreadCount > 0)
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 18,
                                        minHeight: 18,
                                      ),
                                      child: Text(
                                        unreadCount > 9 ? '9+' : '$unreadCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                            () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationsScreen(),
                            ),
                          ).then((_) => setState(() {}));
                        },
                      ),
                      if (_isAdmin) const SizedBox(width: 8),
                      if (_isAdmin)
                        _buildHeaderIconButton(
                          const Icon(Icons.admin_panel_settings_rounded,
                              color: Colors.white, size: 24),
                              () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                const AdminDashboardScreen(),
                              ),
                            );
                          },
                        ),
                      const SizedBox(width: 8),
                      _buildHeaderIconButton(
                        const Icon(Icons.logout_rounded,
                            color: Colors.white, size: 24),
                        _logout,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton(Widget icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(51),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(77), width: 1),
        ),
        child: icon,
      ),
    );
  }

  Widget _buildHighlightSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade400, Colors.orange.shade600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.shade400.withAlpha(77),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.star_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Highlight Event',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const HighlightEventCard(),
        ],
      ),
    );
  }

  Widget _buildRecentEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade700,
                          Colors.blue.shade900,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade900.withAlpha(77),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.event_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Recent Events',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _showSortDialog,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.blue.shade900.withAlpha(51), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(13),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.tune_rounded,
                      color: Colors.blue.shade900, size: 20),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildModernCategoryFilter(),
        const SizedBox(height: 16),
        _buildSearchBox(),
        const SizedBox(height: 16),
        _buildRecentEventsList(),
        const SizedBox(height: 16),
        Center(
          child: Text(
            '© ${DateTime.now().year} AJCE. All Rights Reserved.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildModernCategoryFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: Colors.blue.shade900.withAlpha(26), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              alignment: Alignment(
                _selectedCategoryIndex == 0
                    ? -1.0
                    : (_selectedCategoryIndex == 1 ? 0.0 : 1.0),
                0,
              ),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              child: Container(
                width: (MediaQuery.of(context).size.width - 40) / 3,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade900],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade900.withAlpha(77),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: List.generate(_categories.length, (index) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedCategoryIndex = index);
                    },
                    child: Container(
                      color: Colors.transparent,
                      child: Center(
                        child: Text(
                          _categories[index],
                          style: GoogleFonts.poppins(
                            color: _selectedCategoryIndex == index
                                ? Colors.white
                                : Colors.blue.shade900,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Colors.blue.shade900.withAlpha(26), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: GoogleFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search events...',
            hintStyle: GoogleFonts.poppins(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
            prefixIcon: Icon(Icons.search_rounded,
                color: Colors.blue.shade900, size: 22),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.clear_rounded,
                  color: Colors.grey.shade400, size: 20),
              onPressed: () {
                HapticFeedback.lightImpact();
                _searchController.clear();
              },
            )
                : null,
            border: InputBorder.none,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentEventsList() {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    Query baseQuery = FirebaseFirestore.instance
        .collection('events')
        .orderBy('timestamp', descending: true);

    if (!_isAdmin && currentUserUid != null) {
      baseQuery = baseQuery.where('creatorId', isEqualTo: currentUserUid);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: baseQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(Icons.error_outline,
                      size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: EventListSkeleton(),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final allDocs = snapshot.data!.docs;
        final selectedCategory = _categories[_selectedCategoryIndex];
        List<DocumentSnapshot> filteredDocs = allDocs;

        if (selectedCategory != 'ALL') {
          filteredDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data['category']?.toString().toUpperCase() ?? '') ==
                selectedCategory;
          }).toList();
        }

        if (_searchQuery.isNotEmpty) {
          filteredDocs = filteredDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title']?.toString().toLowerCase() ?? '';
            return title.contains(_searchQuery);
          }).toList();
        }

        if (_currentSortOption == SortOption.alphabetical) {
          filteredDocs.sort((a, b) {
            String aTitle = (a.data() as Map<String, dynamic>)['title']
                ?.toString()
                .toLowerCase() ??
                '';
            String bTitle = (b.data() as Map<String, dynamic>)['title']
                ?.toString()
                .toLowerCase() ??
                '';
            return aTitle.compareTo(bTitle);
          });
        }

        if (filteredDocs.isEmpty) {
          return _buildEmptyState();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: filteredDocs.asMap().entries.map((entry) {
              int index = entry.key;
              var eventDoc = entry.value;
              return _buildEventCard(eventDoc, index);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildEventCard(DocumentSnapshot eventDoc, int index) {
    var data = eventDoc.data() as Map<String, dynamic>;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: Colors.blue.shade900.withAlpha(26), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EventDetailScreen(eventId: eventDoc.id),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Hero(
                    tag: 'event_${eventDoc.id}',
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.blue.shade100,
                            Colors.blue.shade200,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade900.withAlpha(51),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: data['imageUrl'] != null
                            ? Image.network(
                          data['imageUrl'],
                          fit: BoxFit.cover,
                          cacheWidth: 160,
                          cacheHeight: 160,
                          errorBuilder: (ctx, err, st) => Icon(
                            Icons.image_rounded,
                            color: Colors.blue.shade900,
                            size: 32,
                          ),
                        )
                            : Icon(
                          Icons.image_rounded,
                          color: Colors.blue.shade900,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                data['title'] ?? 'No Title',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.blue.shade900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (data['category'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: data['category']
                                      ?.toString()
                                      .toUpperCase() ==
                                      'CML'
                                      ? Colors.purple.shade50
                                      : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: data['category']
                                        ?.toString()
                                        .toUpperCase() ==
                                        'CML'
                                        ? Colors.purple.shade200
                                        : Colors.orange.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  data['category']?.toString().toUpperCase() ??
                                      '',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: data['category']
                                        ?.toString()
                                        .toUpperCase() ==
                                        'CML'
                                        ? Colors.purple.shade700
                                        : Colors.orange.shade700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          data['description'] ?? 'No Description',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatEventTime(data['timestamp'] as Timestamp?),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.blue.shade900.withAlpha(128),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(48.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _searchQuery.isNotEmpty
                    ? Icons.search_off_rounded
                    : Icons.event_busy_rounded,
                size: 64,
                color: Colors.blue.shade900,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No matching events'
                  : 'No events found',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try adjusting your search or filters'
                  : 'Create your first event to get started',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatEventTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown date';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// HighlightEventCard with modern design
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

  Stream<QuerySnapshot> _createHighlightStream() {
    final user = FirebaseAuth.instance.currentUser;
    Query baseQuery = FirebaseFirestore.instance.collection('events');

    if (user != null) {
      baseQuery = baseQuery.where('creatorId', isEqualTo: user.uid);
    }

    return baseQuery.orderBy('timestamp', descending: true).limit(1).snapshots();
  }

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
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Colors.white,
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade100,
                  Colors.blue.shade200,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade900.withAlpha(51),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_note_rounded,
                      size: 48, color: Colors.blue.shade900),
                  const SizedBox(height: 12),
                  Text(
                    "No highlight event",
                    style: GoogleFonts.poppins(
                      color: Colors.blue.shade900,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        var eventDoc = snapshot.data!.docs.first;
        var data = eventDoc.data() as Map<String, dynamic>;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EventDetailScreen(eventId: eventDoc.id),
              ),
            );
          },
          child: Hero(
            tag: 'highlight_${eventDoc.id}',
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade900.withAlpha(77),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      data['imageUrl'] ??
                          'https://via.placeholder.com/400x220?text=No+Image',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.blue.shade300,
                                Colors.blue.shade500,
                              ],
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.image_rounded,
                                size: 64, color: Colors.white),
                          ),
                        );
                      },
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withAlpha(204),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (data['category'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(51),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.white.withAlpha(77), width: 1),
                              ),
                              child: Text(
                                data['category']?.toString().toUpperCase() ?? '',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            data['title'] ?? 'No Title',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                              shadows: [
                                Shadow(
                                  blurRadius: 12.0,
                                  color: Colors.black.withAlpha(128),
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Modern EventListSkeleton
class EventListSkeleton extends StatelessWidget {
  const EventListSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    Widget buildShimmerBlock({
      required double height,
      double width = double.infinity,
      double radius = 16.0,
    }) {
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
      child: Column(
        children: List.generate(5, (index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                buildShimmerBlock(height: 80, width: 80, radius: 16),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildShimmerBlock(height: 18, width: double.infinity),
                      const SizedBox(height: 8),
                      buildShimmerBlock(height: 14, width: 200),
                      const SizedBox(height: 8),
                      buildShimmerBlock(height: 12, width: 120),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
