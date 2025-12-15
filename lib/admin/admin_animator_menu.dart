import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sundayschool_app/admin/admin_question_manager.dart';
import 'package:sundayschool_app/admin/admin_assignment_manager.dart';
import 'package:sundayschool_app/admin/admin_marks_viewer.dart';
import 'package:sundayschool_app/admin/admin_manage_animators.dart';
import 'package:sundayschool_app/admin/admin_create_animator.dart';

class AdminAnimatorMenu extends StatelessWidget {
  const AdminAnimatorMenu({super.key});

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
            'Questions',
            Icons.quiz_rounded,
            Colors.purple,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminQuestionManager(),
              ),
            ),
          ),
          _buildMenuCard(
            context,
            'Assignments',
            Icons.assignment_ind_rounded,
            Colors.orange,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminAssignmentManager(),
              ),
            ),
          ),
          _buildMenuCard(
            context,
            'View Marks',
            Icons.grade_rounded,
            Colors.teal,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AdminMarksViewer()),
            ),
          ),
          _buildMenuCard(
            context,
            'Manage Animators',
            Icons.manage_accounts_rounded,
            Colors.indigo,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminManageAnimators(),
              ),
            ),
          ),
          _buildMenuCard(
            context,
            'Create Animator',
            Icons.person_add_rounded,
            Colors.blue,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminCreateAnimator(),
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
