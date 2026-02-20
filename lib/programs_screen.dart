import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Our Programs',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: _primaryBlue,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: _primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        iconTheme: IconThemeData(color: _primaryBlue),
      ),
      body: Stack(
        children: [
          // Gradient Background Layer
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 1.0],
                colors: [
                  Color(0xFFFFFAF0), // Very Soft Cream (Floral White)
                  Color(0xFFFFF8E1), // Ultra Light Gold
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildThemeCard(),
                        const SizedBox(height: 25),
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Text(
                            'FORMATION & TRAINING',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        _buildProgramList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard() {
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
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [_primaryBlue, Colors.blue.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _primaryBlue.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Text(
                  'THEME OF THE YEAR',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '2025-26',
                style: GoogleFonts.outfit(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                '“നിത്യജീവനിലുള്ള പ്രത്യാശ”',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansMalayalam(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hope in Eternal Life',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue.shade100,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgramList() {
    final List<Map<String, dynamic>> programs = [
      {
        'title': 'Uthanothsavam',
        'desc':
            'An integral and intensive 5-day formation for catechetical students.',
        'icon': FontAwesomeIcons.fire,
      },
      {
        'title': 'BTC & CTC Course',
        'desc': 'Catechists’ Training Course designed to equip teachers.',
        'icon': FontAwesomeIcons.bookOpenReader,
      },
      {
        'title': 'HDC',
        'desc':
            'Teachers’ Diploma Course for advanced theological understanding.',
        'icon': FontAwesomeIcons.graduationCap,
      },
      {
        'title': 'Teachers’ Seminar',
        'desc':
            'A one-day seminar based on the year’s theme to refresh and inspire.',
        'icon': FontAwesomeIcons.users,
      },
      {
        'title': 'Teachers’ Quiz',
        'desc': 'Interactive quiz sessions based on specific spiritual topics.',
        'icon': FontAwesomeIcons.circleQuestion,
      },
      {
        'title': 'Lifeline',
        'desc':
            'A two-day orientation programme tailored for Std VIII children.',
        'icon': FontAwesomeIcons.handsHoldingChild,
      },
      {
        'title': 'Bible Kalolsavam',
        'desc':
            'A spiritual and cultural arts festival organized to promote Biblical literacy and Christian values through creative expression.',
        'icon': FontAwesomeIcons.masksTheater,
      },
    ];

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: programs.length,
      itemBuilder: (context, index) {
        // Staggered animation for list items
        final double begin = 0.4 + (index * 0.1);
        final double end = (begin + 0.4 > 1.0) ? 1.0 : begin + 0.4;

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
                color: Colors.white.withOpacity(0.8), // Cream background
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(
                    0xFFFFE4B5,
                  ).withOpacity(0.4), // Soft gold border
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.08), // Warm shadow
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    programs[index]['icon'] as IconData,
                    color: _primaryBlue,
                    size: 22,
                  ),
                ),
                title: Text(
                  programs[index]['title'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _primaryBlue,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    programs[index]['desc'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade600,
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
}
