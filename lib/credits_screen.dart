import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.08, end: 0.28).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Show a beautiful glassmorphism popup modal with full photo, name, and role
  void _showImagePreviewDialog({
    required BuildContext context,
    required String name,
    required String role,
    required String? imageAsset,
    Alignment alignment = Alignment.center,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Member Preview',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.86,
              constraints: const BoxConstraints(maxWidth: 380),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: const Color(0xFFD4AF37),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                    blurRadius: 32,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Header bar with close button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                color: Color(0xFFD4AF37),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Team Member',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Full image container
                    Container(
                      width: double.infinity,
                      height: 320,
                      color: const Color(0xFF0F172A),
                      child: imageAsset != null
                          ? Image.asset(
                              imageAsset,
                              fit: BoxFit.cover,
                              alignment: alignment,
                              errorBuilder: (_, __, ___) => _buildSilhouettePlaceholder(140),
                            )
                          : _buildSilhouettePlaceholder(140),
                    ),

                    // Bottom info section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      child: Column(
                        children: [
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E3A8A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 2.5,
                            width: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFC5A869),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            role,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
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
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Center(
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF8D6E3F),
                      size: 18,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),
        ),
        centerTitle: true,
        title: Image.asset(
          'assets/images/new_logo_light.png',
          height: 52,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.light_mode_rounded,
            color: Color(0xFFD4AF37),
            size: 44,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/images/sky_clouds.png"),
                  fit: BoxFit.cover,
                  opacity: 0.25,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF3F7FC),
                    Color(0xFFFAF7F0),
                    Color(0xFFF8F5EC),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Behind',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E3A8A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Image.asset(
                        'assets/images/new_logo_light.png',
                        height: 38,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.light_mode_rounded,
                          color: Color(0xFFD4AF37),
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- TEAM MEMBERS CARD (Animated Glow Container) ---
                  _buildTeamCard(),

                  const SizedBox(height: 24),

                  // Logos Card: Amal Jyothi College of Engineering & CSE Department
                  _buildLogosCard(),

                  const SizedBox(height: 24),

                  // Dedication Text (Moved below Department & College Logos)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0),
                    child: Text(
                      'Light is the result of faith, innovation and teamwork.\nProudly developed by the Department of Computer Science & Engineering, Amal Jyothi College of Engineering.\nWe are grateful to everyone who supported and inspired us.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF475569),
                        height: 1.55,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard() {
    final List<Map<String, dynamic>> studentDevelopers = [
      {
        'name': 'Abin Varghese',
        'role': 'Team Member',
        'imageAsset': 'assets/images/abin.png',
        'alignment': Alignment.topCenter,
      },
      {
        'name': 'Akhil Babu',
        'role': 'Team Member',
        'imageAsset': 'assets/images/akhil.png',
        'alignment': Alignment.topCenter,
      },
      {
        'name': 'Alins Binu',
        'role': 'Team Member',
        'imageAsset': 'assets/images/alins.png',
        'alignment': Alignment.topCenter,
      },
    ];

    return GlowingRunningBorder(
      borderRadius: 28,
      thickness: 2.2,
      duration: const Duration(seconds: 4),
      gradientColors: const [
        Color(0xFFBC8A3A), // Gold
        Color(0xFFFFD700), // Bright Gold
        Color(0xFFFF8C00), // Warm Amber
        Color(0xFFBC8A3A),
      ],
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          children: [
            Column(
              children: [
                _buildMemberAvatar(
                  imageAsset: 'assets/images/drjubymathew.jpeg',
                  size: 96,
                  alignment: Alignment.center,
                  onTap: () => _showImagePreviewDialog(
                    context: context,
                    name: 'Dr. Juby Mathew',
                    role: 'Head of the Department & Guide',
                    imageAsset: 'assets/images/drjubymathew.jpeg',
                    alignment: Alignment.center,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Dr. Juby Mathew',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 2.5,
                  width: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC5A869),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Head of the Department',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Container(height: 1, color: const Color(0xFFE2D6B5)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFC5A869),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'DEVELOPERS',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFC5A869),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(height: 1, color: const Color(0xFFE2D6B5)),
                ),
              ],
            ),

            const SizedBox(height: 20),

            LayoutBuilder(
              builder: (context, constraints) {
                final double totalWidth = constraints.maxWidth;
                final double itemWidth = (totalWidth - 32) / 3;
                final double avatarSize = (itemWidth * 0.82).clamp(70.0, 88.0);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(studentDevelopers.length * 2 - 1, (index) {
                    if (index.isOdd) {
                      return Container(
                        width: 16,
                        alignment: Alignment.center,
                        padding: EdgeInsets.only(top: avatarSize * 0.42),
                        child: Column(
                          children: [
                            Container(
                              height: 24,
                              width: 1.2,
                              color: const Color(0xFFE2D6B5),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '+',
                              style: TextStyle(
                                color: Color(0xFFC5A869),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 24,
                              width: 1.2,
                              color: const Color(0xFFE2D6B5),
                            ),
                          ],
                        ),
                      );
                    }

                    final devIndex = index ~/ 2;
                    final dev = studentDevelopers[devIndex];
                    final Alignment alignment = dev['alignment'] as Alignment;

                    return SizedBox(
                      width: itemWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMemberAvatar(
                            imageAsset: dev['imageAsset'],
                            size: avatarSize,
                            alignment: alignment,
                            onTap: () => _showImagePreviewDialog(
                              context: context,
                              name: dev['name'],
                              role: dev['role'],
                              imageAsset: dev['imageAsset'],
                              alignment: alignment,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            dev['name'],
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E3A8A),
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Container(
                            height: 2,
                            width: 24,
                            decoration: BoxDecoration(
                              color: const Color(0xFFC5A869),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            dev['role'],
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Member avatar circle with golden outer ring, pulse glow, and tap handler
  Widget _buildMemberAvatar({
    required String? imageAsset,
    required double size,
    Alignment alignment = Alignment.center,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFC5A869),
                width: 2.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: _glowAnimation.value + 0.05),
                  blurRadius: 14,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: imageAsset != null
                  ? Image.asset(
                      imageAsset,
                      fit: BoxFit.cover,
                      alignment: alignment,
                      errorBuilder: (_, __, ___) => _buildSilhouettePlaceholder(size),
                    )
                  : _buildSilhouettePlaceholder(size),
            ),
          );
        },
      ),
    );
  }

  /// Clean soft blue silhouette placeholder sized proportionally to avatar
  Widget _buildSilhouettePlaceholder(double size) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE2E8F0),
            Color(0xFFCBD5E1),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: size * 0.65,
        color: const Color(0xFF94A3B8),
      ),
    );
  }



  /// Logos Card: Department Logo on Top & College Logo Below
  Widget _buildLogosCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFF1E5C8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          // 1. DEPARTMENT OF COMPUTER SCIENCE & ENGINEERING (ON TOP)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/LS20260816131016.png',
                height: 52,
                width: 52,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/images/cse_logo.png',
                  height: 52,
                  width: 52,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.computer_rounded,
                    color: Color(0xFF1E3A8A),
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DEPARTMENT OF',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFBC8A3A),
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      'COMPUTER SCIENCE &\nENGINEERING',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E3A8A),
                        height: 1.2,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Horizontal Divider
          Container(
            height: 1,
            width: double.infinity,
            color: const Color(0xFFE2D6B5),
          ),

          const SizedBox(height: 14),

          // 2. AMAL JYOTHI COLLEGE OF ENGINEERING (BELOW)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Image.asset(
              'assets/images/ajcelogo.png',
              height: 48,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Image.asset(
                'assets/images/ajce_logo.png',
                height: 48,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Column(
                  children: [
                    Text(
                      'AMAL JYOTHI',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: const Color(0xFF1E3A8A),
                      ),
                    ),
                    Text(
                      'COLLEGE OF ENGINEERING (AUTONOMOUS)',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dynamic Running Gradient Glow Border Widget
class GlowingRunningBorder extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final List<Color> gradientColors;
  final double thickness;
  final Duration duration;

  const GlowingRunningBorder({
    super.key,
    required this.child,
    this.borderRadius = 28.0,
    this.thickness = 2.5,
    this.duration = const Duration(seconds: 4),
    this.gradientColors = const [
      Color(0xFFBC8A3A),
      Color(0xFFFFD700),
      Color(0xFFFF8C00),
      Color(0xFFBC8A3A),
    ],
  });

  @override
  State<GlowingRunningBorder> createState() => _GlowingRunningBorderState();
}

class _GlowingRunningBorderState extends State<GlowingRunningBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _GlowBorderPainter(
            animationValue: _controller.value,
            borderRadius: widget.borderRadius,
            gradientColors: widget.gradientColors,
            thickness: widget.thickness,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _GlowBorderPainter extends CustomPainter {
  final double animationValue;
  final double borderRadius;
  final List<Color> gradientColors;
  final double thickness;

  _GlowBorderPainter({
    required this.animationValue,
    required this.borderRadius,
    required this.gradientColors,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rRect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final Color glowColor = _getGlowColor(animationValue);

    // 1. Soft Halo glow
    final haloPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness * 3.5
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, thickness * 2.0);
    canvas.drawRRect(rRect, haloPaint);

    final staticGlowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness * 1.5
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, thickness * 1.0);
    canvas.drawRRect(rRect, staticGlowPaint);

    // 2. Shimmer wave sweep gradient running animation
    final List<Color> shimmerColors = [
      Colors.transparent,
      gradientColors.first.withValues(alpha: 0.3),
      gradientColors.length > 1 ? gradientColors[1] : gradientColors.first,
      Colors.white,
      gradientColors.length > 1 ? gradientColors[1] : gradientColors.first,
      Colors.transparent,
      (gradientColors.length > 1 ? gradientColors[1] : gradientColors.first)
          .withValues(alpha: 0.5),
      Colors.white.withValues(alpha: 0.8),
      (gradientColors.length > 1 ? gradientColors[1] : gradientColors.first)
          .withValues(alpha: 0.5),
      Colors.transparent,
    ];

    const List<double> shimmerStops = [
      0.0,
      0.4,
      0.45,
      0.5,
      0.55,
      0.6,
      0.75,
      0.8,
      0.85,
      1.0,
    ];

    final waveValue = math.sin(animationValue * 2 * math.pi);
    final shimmerPaint = Paint()
      ..shader = SweepGradient(
        colors: shimmerColors,
        stops: shimmerStops,
        transform: GradientRotation(
          animationValue * 2 * math.pi + waveValue * 0.2,
        ),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(rRect, shimmerPaint);
  }

  Color _getGlowColor(double t) {
    if (t < 0.33) {
      return Color.lerp(
        const Color(0xFFBC8A3A),
        const Color(0xFFFF8C00),
        t / 0.33,
      )!;
    } else if (t < 0.66) {
      return Color.lerp(
        const Color(0xFFFF8C00),
        Colors.white,
        (t - 0.33) / 0.33,
      )!;
    } else {
      return Color.lerp(
        Colors.white,
        const Color(0xFFBC8A3A),
        (t - 0.66) / 0.34,
      )!;
    }
  }

  @override
  bool shouldRepaint(covariant _GlowBorderPainter oldDelegate) => true;
}


