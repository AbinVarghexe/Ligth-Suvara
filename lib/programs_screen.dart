import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sundayschool_app/widgets/heavenly_background.dart';
import 'package:shimmer/shimmer.dart';

class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Defines the primary brand color
  final Color _primaryBlue = const Color(0xFF1E3A8A); // Deep Royal Blue
  final Color _goldAccent = const Color(0xFFBC8A3A); // Gold Accent

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Our Programs',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            color: _primaryBlue,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: _primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: HeavenlyBackground(
        showImage: true,
        child: SafeArea(
          child: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('settings')
                .doc('theme_programs')
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildShimmerLoading();
              }

              Map<String, dynamic> data = {};
              if (snapshot.hasData && snapshot.data!.exists) {
                data = snapshot.data!.data() as Map<String, dynamic>;
              }

              final themeYear = data['themeYear'] ?? '2025-2026';
              final themeMal =
                  data['themeMalayalam'] ?? '“നിത്യജീവനിലുള്ള പ്രത്യാശ”';
              final themeEng = data['themeEnglish'] ?? 'Hope in Eternal Life';
              final List<dynamic> programsList =
                  data['programs'] ?? _getDefaultPrograms();

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildThemeCard(themeYear, themeMal, themeEng),
                    const SizedBox(height: 35),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _goldAccent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'FORMATION & TRAINING',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _primaryBlue.withOpacity(0.8),
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildProgramList(
                      programsList.cast<Map<String, dynamic>>(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildThemeCard(
    String year,
    String malayalamTheme,
    String englishTheme,
  ) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: _controller,
              curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
            ),
          ),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
        ),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              colors: [_primaryBlue, const Color(0xFF1E40AF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _primaryBlue.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: -10,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Text(
                  'THEME OF THE YEAR',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                year,
                style: GoogleFonts.outfit(
                  fontSize: 54,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                malayalamTheme,
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansMalayalam(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                englishTheme,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue.shade100.withOpacity(0.9),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getDefaultPrograms() {
    return [
      {
        'title': 'Uthanothsavam',
        'desc':
            'An integral and intensive 5-day formation for catechetical students.',
        'iconName': 'fire',
      },
      {
        'title': 'BTC & CTC Course',
        'desc': 'Catechists’ Training Course designed to equip teachers.',
        'iconName': 'bookOpenReader',
      },
      {
        'title': 'HDC',
        'desc':
            'Teachers’ Diploma Course for advanced theological understanding.',
        'iconName': 'graduationCap',
      },
      {
        'title': 'Teachers’ Seminar',
        'desc':
            'A one-day seminar based on the year’s theme to refresh and inspire.',
        'iconName': 'users',
      },
      {
        'title': 'Teachers’ Quiz',
        'desc': 'Interactive quiz sessions based on specific spiritual topics.',
        'iconName': 'circleQuestion',
      },
      {
        'title': 'Lifeline',
        'desc':
            'A two-day orientation programme tailored for Std VIII children.',
        'iconName': 'handsHoldingChild',
      },
      {
        'title': 'Bible Kalolsavam',
        'desc':
            'A spiritual and cultural arts festival organized to promote Biblical literacy and Christian values through creative expression.',
        'iconName': 'masksTheater',
      },
    ];
  }

  IconData _getIconFromName(String iconName) {
    switch (iconName) {
      case 'fire':
        return FontAwesomeIcons.fire;
      case 'bookOpenReader':
        return FontAwesomeIcons.bookOpenReader;
      case 'graduationCap':
        return FontAwesomeIcons.graduationCap;
      case 'users':
        return FontAwesomeIcons.users;
      case 'circleQuestion':
        return FontAwesomeIcons.circleQuestion;
      case 'handsHoldingChild':
        return FontAwesomeIcons.handsHoldingChild;
      case 'masksTheater':
        return FontAwesomeIcons.masksTheater;
      case 'star':
        return FontAwesomeIcons.star;
      case 'church':
        return FontAwesomeIcons.church;
      case 'cross':
        return FontAwesomeIcons.cross;
      case 'dove':
        return FontAwesomeIcons.dove;
      case 'heart':
        return FontAwesomeIcons.heart;
      case 'lightbulb':
        return FontAwesomeIcons.lightbulb;
      case 'music':
        return FontAwesomeIcons.music;
      default:
        return FontAwesomeIcons.star;
    }
  }

  Widget _buildProgramList(List<Map<String, dynamic>> programs) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: programs.length,
      itemBuilder: (context, index) {
        // Staggered animation for list items safely clamped
        double begin = 0.4 + (index * 0.1);
        begin = begin.clamp(0.0, 0.8);
        double end = (begin + 0.4).clamp(0.0, 1.0);

        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(
                  parent: _controller,
                  curve: Interval(begin, end, curve: Curves.easeOutCubic),
                ),
              ),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: _controller,
              curve: Interval(begin, end, curve: Curves.easeOut),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(
                  0xFFFFFBEB,
                ).withOpacity(0.4), // Warm glass tint
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _goldAccent.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _goldAccent.withOpacity(0.08),
                    spreadRadius: 1,
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),

              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                leading: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _primaryBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _primaryBlue.withOpacity(0.1)),
                  ),
                  child: Icon(
                    _getIconFromName(
                      programs[index]['iconName']?.toString() ?? 'star',
                    ),
                    color: _primaryBlue,
                    size: 24,
                  ),
                ),
                title: Text(
                  programs[index]['title'] as String,
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _primaryBlue,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    programs[index]['desc'] as String,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.white.withOpacity(0.5),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Theme Card Shimmer
            Container(
              height: 280,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
              ),
            ),
            const SizedBox(height: 35),
            // Header Shimmer
            Row(
              children: [
                Container(width: 4, height: 24, color: Colors.white),
                const SizedBox(width: 12),
                Container(width: 180, height: 14, color: Colors.white),
              ],
            ),
            const SizedBox(height: 16),
            // List Item Shimmers
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              itemBuilder: (_, __) => Container(
                height: 100,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
