import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sundayschool_app/widgets/linkable_text.dart';

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
  
  late Animation<double> profileFade;
  late Animation<Offset> profileSlide;
  late Animation<double> messageFade;
  late Animation<Offset> messageSlide;
  late Animation<double> quoteScale;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    profileFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    profileSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    messageFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    messageSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    quoteScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.5, 0.9, curve: Curves.elasticOut),
      ),
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
                      alignment: Alignment.topCenter,
                      placeholder: (context, url) => Container(color: Colors.black),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade900,
                        child: const Icon(Icons.person, color: Colors.white24, size: 80),
                      ),
                    )
                  : Image.asset(
                      widget.imageUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
            ),
          ),

          /// 🔹 CINEMATIC GRADIENT SCENE
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.05),
                    Colors.white.withValues(alpha: 0.15),
                    const Color(0xFFFFFBEB).withValues(alpha: 0.85), // Sophisticated Cream
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.35, 1.0],
                ),
              ),
            ),
          ),

          /// 🔹 CONTENT (Scrollable overlay)
          Positioned.fill(
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
                child: Column(
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.42),
                    
                    /// 🧊 LEADER PROFILE CARD (Glassmorphic)
                    FadeTransition(
                      opacity: profileFade,
                      child: SlideTransition(
                        position: profileSlide,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.95),
                                    const Color(0xFFFFFDF9).withValues(alpha: 0.90),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFFBC8A3A).withValues(alpha: 0.25),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
                                    blurRadius: 25,
                                    offset: const Offset(0, 10),
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFFBC8A3A).withValues(alpha: 0.04),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    widget.name.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF1E3A8A), // Navy Blue
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  
                                  // Fading Gold horizontal separator
                                  Container(
                                    width: 100,
                                    height: 1.5,
                                    margin: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFFBC8A3A).withValues(alpha: 0.0),
                                          const Color(0xFFBC8A3A).withValues(alpha: 0.6),
                                          const Color(0xFFBC8A3A).withValues(alpha: 0.0),
                                        ],
                                      ),
                                    ),
                                  ),
                                  
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: widget.themeColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: widget.themeColor.withValues(alpha: 0.3),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Text(
                                      widget.role,
                                      style: GoogleFonts.outfit(
                                        color: widget.themeColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
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
                      const SizedBox(height: 24),
                      
                      /// 💬 MESSAGE CARD (Cinematic)
                      FadeTransition(
                        opacity: messageFade,
                        child: SlideTransition(
                          position: messageSlide,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.9),
                                      const Color(0xFFFFFBEB).withValues(alpha: 0.75),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: const Color(0xFFBC8A3A).withValues(alpha: 0.20),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Align(
                                      alignment: Alignment.topLeft,
                                      child: ScaleTransition(
                                        scale: quoteScale,
                                        child: Transform.rotate(
                                          angle: math.pi, // Rotated 180 degrees to look like opening quote
                                          child: const Icon(
                                            Icons.format_quote_rounded,
                                            color: Color(0xFFBC8A3A),
                                            size: 38,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: LinkableText(
                                        widget.message!,
                                        textAlign: TextAlign.center,
                                        linkColor: const Color(0xFFBC8A3A),
                                        style: GoogleFonts.libreBaskerville(
                                          color: const Color(0xFF334155), // Slate Gray for better reading
                                          fontSize: 16.5,
                                          height: 1.75,
                                          fontStyle: FontStyle.italic,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Align(
                                      alignment: Alignment.bottomRight,
                                      child: Icon(
                                        Icons.format_quote_rounded, // Default points right/down (closing quote)
                                        color: Color(0xFFBC8A3A),
                                        size: 30,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          /// ❌ MINIMAL CLOSE BUTTON
          Positioned(
            top: 50,
            right: 24,
            child: FadeTransition(
              opacity: profileFade,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8), // White background for button
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFBC8A3A).withValues(alpha: 0.2),
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
