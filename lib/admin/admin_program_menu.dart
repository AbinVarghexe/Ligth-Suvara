import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sundayschool_app/admin/admin_program_manager.dart';
import 'package:sundayschool_app/admin/admin_school_registrations.dart';
import 'package:sundayschool_app/admin/admin_program_analytics.dart';
import 'package:sundayschool_app/admin/admin_theme_programs_manager.dart';
import 'package:sundayschool_app/admin/admin_public_registrations_viewer.dart';
import 'package:sundayschool_app/admin/admin_public_registration_analytics.dart';
import 'package:sundayschool_app/admin/admin_public_programs_manager.dart';

class AdminProgramMenu extends StatelessWidget {
  const AdminProgramMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 40, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFD4AF37), Color(0xFFF9D423), Color(0xFFD4AF37)],
              stops: [0.0, 0.5, 1.0],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ).createShader(bounds),
            child: Text(
              "Program Management",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
                shadows: [
                  Shadow(color: Colors.black.withOpacity(0.35), offset: const Offset(1, 2), blurRadius: 6),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Analytics, registrations, and program settings",
            style: GoogleFonts.outfit(
              color: const Color(0xFF1E293B).withOpacity(0.8), 
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 32),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.0,
            children: [
              _buildMenuCard(
                context,
                'Analytics',
                Icons.bar_chart_rounded,
                Colors.greenAccent,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminProgramAnalytics()),
                ),
              ),
              _buildMenuCard(
                context,
                'Manage Programs',
                Icons.event_available_rounded,
                Colors.purpleAccent,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminProgramManager()),
                ),
              ),
              _buildMenuCard(
                context,
                'See Registrations',
                Icons.school_rounded,
                Colors.indigoAccent,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminSchoolRegistrations()),
                ),
              ),
              _buildMenuCard(
                context,
                'Theme & Info',
                Icons.edit_note_rounded,
                Colors.orangeAccent,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminThemeProgramsManager()),
                ),
              ),
              _buildMenuCard(
                context,
                'Public Programs',
                Icons.campaign_rounded,
                Colors.tealAccent,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminPublicProgramsManager()),
                ),
              ),
              _buildMenuCard(
                context,
                'Public Registrations',
                Icons.people_alt_rounded,
                Colors.pinkAccent,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminPublicRegistrationsViewer()),
                ),
              ),
              _buildMenuCard(
                context,
                'Public Analytics',
                Icons.insights_rounded,
                Colors.amberAccent,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminPublicRegistrationAnalytics()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.45), // Milky Luminous Base
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withOpacity(0.3), width: 1.5),
                    ),
                    child: Icon(icon, color: color.darken(0.1), size: 38), // Use slightly darker version of theme color
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: const Color(0xFF1E293B), // High-visibility Midnight Blue
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension ColorExtension on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsv = HSVColor.fromColor(this);
    final newValue = (hsv.value - amount).clamp(0.0, 1.0);
    return hsv.withValue(newValue).toColor();
  }
}
