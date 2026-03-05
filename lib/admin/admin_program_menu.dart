import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sundayschool_app/admin/admin_program_manager.dart';
import 'package:sundayschool_app/admin/admin_school_registrations.dart';
import 'package:sundayschool_app/admin/admin_program_analytics.dart';
import 'package:sundayschool_app/admin/admin_theme_programs_manager.dart';

class AdminProgramMenu extends StatelessWidget {
  const AdminProgramMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100),
      color: Colors.grey.shade50,
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
        children: [
          _buildMenuCard(
            context,
            'Analytics',
            Icons.bar_chart_rounded,
            Colors.green,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminProgramAnalytics(),
              ),
            ),
          ),
          _buildMenuCard(
            context,
            'Manage Programs',
            Icons.event_available_rounded,
            Colors.purpleAccent,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminProgramManager(),
              ),
            ),
          ),
          _buildMenuCard(
            context,
            'See Registrations',
            Icons.school_rounded,
            Colors.indigo,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminSchoolRegistrations(),
              ),
            ),
          ),
          _buildMenuCard(
            context,
            'Theme & Info',
            Icons.edit_note_rounded,
            Colors.orange,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminThemeProgramsManager(),
              ),
            ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
