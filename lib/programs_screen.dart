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
              final List<dynamic> rawList =
                  data['programs'] ?? _getDefaultPrograms();
              final List<Map<String, dynamic>> programsList =
                  rawList.map((item) => Map<String, dynamic>.from(item as Map)).toList();

              final List<Map<String, dynamic>> firstFive =
                  programsList.take(5).toList();
              final List<Map<String, dynamic>> remaining =
                  programsList.skip(5).toList();

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
                    _buildProgramList(firstFive),
                    if (remaining.isNotEmpty)
                      _buildMoreButton(context, remaining),
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

        return ProgramCard(
          program: programs[index],
          animation: CurvedAnimation(
            parent: _controller,
            curve: Interval(begin, end, curve: Curves.easeOutCubic),
          ),
        );
      },
    );
  }

  Widget _buildMoreButton(
    BuildContext context,
    List<Map<String, dynamic>> remainingPrograms,
  ) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: _controller,
              curve: const Interval(0.7, 1.0, curve: Curves.easeOutCubic),
            ),
          ),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
        ),
        child: Container(
          margin: const EdgeInsets.only(top: 8, bottom: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                _primaryBlue,
                _primaryBlue.withOpacity(0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _primaryBlue.withOpacity(0.25),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MoreProgramsScreen(
                      programs: remainingPrograms,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'More Programs',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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

class ProgramCard extends StatefulWidget {
  final Map<String, dynamic> program;
  final Animation<double> animation;

  const ProgramCard({
    super.key,
    required this.program,
    required this.animation,
  });

  @override
  State<ProgramCard> createState() => _ProgramCardState();
}

class _ProgramCardState extends State<ProgramCard> {
  bool _isExpanded = false;

  final Color _primaryBlue = const Color(0xFF1E3A8A);
  final Color _goldAccent = const Color(0xFFBC8A3A);

  @override
  Widget build(BuildContext context) {
    final String title = widget.program['title']?.toString() ?? '';
    final String desc = widget.program['desc']?.toString() ?? '';
    final String iconName = widget.program['iconName']?.toString() ?? 'star';
    final bool isLongDescription = desc.length > 60;

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero)
          .animate(widget.animation),
      child: FadeTransition(
        opacity: widget.animation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB).withOpacity(0.4), // Warm glass tint
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
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: isLongDescription
                  ? () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _primaryBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _primaryBlue.withOpacity(0.1)),
                      ),
                      child: Icon(
                        _getIconFromName(iconName),
                        color: _primaryBlue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: _primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            alignment: Alignment.topLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  desc,
                                  maxLines: _isExpanded ? null : 2,
                                  overflow: _isExpanded
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF64748B),
                                    height: 1.4,
                                  ),
                                ),
                                if (isLongDescription) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    _isExpanded ? 'Show less' : 'Read more',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _goldAccent,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
}

class MoreProgramsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> programs;

  const MoreProgramsScreen({
    super.key,
    required this.programs,
  });

  @override
  State<MoreProgramsScreen> createState() => _MoreProgramsScreenState();
}

class _MoreProgramsScreenState extends State<MoreProgramsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Color _primaryBlue = const Color(0xFF1E3A8A);
  final Color _goldAccent = const Color(0xFFBC8A3A);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
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
          'More Programs',
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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                        'ADDITIONAL PROGRAMS',
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
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: widget.programs.length,
                  itemBuilder: (context, index) {
                    double begin = 0.1 + (index * 0.1);
                    begin = begin.clamp(0.0, 0.8);
                    double end = (begin + 0.4).clamp(0.0, 1.0);

                    return ProgramCard(
                      program: widget.programs[index],
                      animation: CurvedAnimation(
                        parent: _controller,
                        curve: Interval(begin, end, curve: Curves.easeOutCubic),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
