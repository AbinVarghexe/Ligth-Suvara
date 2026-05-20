import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CinematicMessageView extends StatefulWidget {
  final String name;
  final String role;
  final String? message;
  final String imageUrl;
  final Color themeColor;

  const CinematicMessageView({
    super.key,
    required this.name,
    required this.role,
    this.message,
    required this.imageUrl,
    this.themeColor = const Color(0xFFD4AF37),
  });

  @override
  _CinematicMessageViewState createState() => _CinematicMessageViewState();
}

class _CinematicMessageViewState extends State<CinematicMessageView>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> fadeAnim;
  late Animation<Offset> slideAnim;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    fadeAnim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOut),
    );

    slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOut),
    );

    controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasMessage = widget.message != null && widget.message!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          /// 🔹 IMAGE BACKGROUND (Full Screen)
          Positioned.fill(
            child: TweenAnimationBuilder(
              duration: const Duration(milliseconds: 1200),
              tween: Tween(begin: 1.15, end: 1.0),
              builder: (_, double scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: widget.imageUrl.startsWith('http')
                  ? CachedNetworkImage(
                      imageUrl: widget.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.black),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade900,
                        child: const Icon(Icons.person, color: Colors.white24, size: 80),
                      ),
                    )
                  : Image.asset(
                      widget.imageUrl,
                      fit: BoxFit.cover,
                    ),
            ),
          ),

          /// 🔹 CINEMATIC GRADIENT SCENE
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.05),
                    Colors.white.withOpacity(0.2),
                    const Color(0xFFFFFBEB).withOpacity(0.9), // Sophisticated Cream
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          /// 🔹 CONTENT (Bottom Aligned)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// 🧊 LEADER PROFILE CARD (Glassmorphic)
                  FadeTransition(
                    opacity: fadeAnim,
                    child: SlideTransition(
                      position: slideAnim,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9), // 🔹 High-opacity light glass
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFFBC8A3A).withOpacity(0.2), // 🔹 Subtle Gold border
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  widget.name.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF1E3A8A), // 🔹 Change to Navy Blue
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: widget.themeColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    widget.role,
                                    style: GoogleFonts.outfit(
                                      color: widget.themeColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (hasMessage) ...[
                    const SizedBox(height: 20),
                    /// 💬 MESSAGE CARD (Cinematic)
                    FadeTransition(
                      opacity: fadeAnim,
                      child: SlideTransition(
                        position: slideAnim,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85), // 🔹 High-opacity light glass
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFFBC8A3A).withOpacity(0.15), // 🔹 Subtle Gold border
                              width: 1.0,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.format_quote_rounded,
                                  color: const Color(0xFFBC8A3A), size: 32), // 🔹 Keep Gold for icons
                              const SizedBox(height: 16),
                              Text(
                                widget.message!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.libreBaskerville(
                                  color: const Color(0xFF334155), // 🔹 Slate Gray for better reading
                                  fontSize: 17,
                                  height: 1.6,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          /// ❌ MINIMAL CLOSE BUTTON
          Positioned(
            top: 50,
            right: 24,
            child: FadeTransition(
              opacity: fadeAnim,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8), // 🔹 White background for button
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFBC8A3A).withOpacity(0.2),
                        ),
                      ),
                      child: const Icon(Icons.close_rounded, color: Color(0xFF1E3A8A), size: 24),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
