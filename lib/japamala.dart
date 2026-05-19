import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:flutter/services.dart';

class JapamalaScreen extends StatefulWidget {
  const JapamalaScreen({super.key});

  @override
  State<JapamalaScreen> createState() => _JapamalaScreenState();
}

class _JapamalaScreenState extends State<JapamalaScreen> {
  // 1. Create a WebViewController
  late final WebViewController _controller;
  bool _isLoading = true; // To show a loading indicator
  bool _isReady = false; // To delay rendering until animation settles

  // The URL for the Japamala page
  static const String webUrl =
      'https://parishudhajapamala.vercel.app/';

  @override
  void initState() {
    super.initState();

    // 2. Initialize the controller
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint('WebView is loading (progress: $progress%)');
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
            debugPrint('Page started loading: $url');
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            debugPrint('Page finished loading: $url');
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('''
            Page loading error:
              code: ${error.errorCode}
              description: ${error.description}
              errorType: ${error.errorType}
              isForMainFrame: ${error.isForMainFrame}
            ''');
          },
        ),
      );

    // Delay showing the WebView until the transition animation is complete
    // This prevents the ImageReader buffer overflow errors during scaling
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) {
        // --- ULTIMATE STABILITY: Delayed Load ---
        _controller.loadRequest(Uri.parse(webUrl));
        setState(() => _isReady = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
            ),
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: _buildPremiumAppBarButton(
            icon: Icons.arrow_back_ios_new_rounded,
            size: 18,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text(
          'Japamala',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        shape: const Border(
          bottom: BorderSide(
            color: Color(0xFFBC8A3A),
            width: 1.5,
          ),
        ),
        actions: [
          _buildPremiumAppBarButton(
            icon: Icons.refresh_rounded,
            size: 20,
            onTap: () => _controller.reload(),
            tooltip: 'Reload',
          ),
          const SizedBox(width: 8),
        ],
      ),
      // 4. Use the WebViewWidget with the initialized controller
      body: Stack(
        children: [
          if (_isReady)
            // Use a simpler approach: show WebView immediately when ready
            // The loading indicator will overlay it until the content is ready
            RepaintBoundary(
              child: WebViewWidget.fromPlatformCreationParams(
                params: AndroidWebViewWidgetCreationParams(
                  controller: _controller.platform,
                  displayWithHybridComposition: true,
                ),
              ),
            ),
          // Only show the overlay loader during the initial wait or if explicitly loading the main page
          if (!_isReady || (_isLoading && _isReady))
            Container(
              color: Colors.white,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFBC8A3A),
                  strokeWidth: 3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPremiumAppBarButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 20,
    String? tooltip,
  }) {
    return Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Tooltip(
            message: tooltip ?? '',
            child: Icon(
              icon,
              size: size,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
