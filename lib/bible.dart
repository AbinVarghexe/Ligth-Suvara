import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

// Import necessary platform-specific settings for Android
import 'package:webview_flutter_android/webview_flutter_android.dart';

class PocBibleScreen extends StatefulWidget {
  const PocBibleScreen({super.key});

  @override
  State<PocBibleScreen> createState() => _PocBibleScreenState();
}

class _PocBibleScreenState extends State<PocBibleScreen> {
  late final WebViewController _controller;

  static const String webUrl =
      'https://www.wordproject.org/bibles/ml/';
  bool _isLoading = true;
  bool _isReady = false; // Flag to delay rendering until transition finishes

  @override
  void initState() {
    super.initState();

    final WebViewController controller = WebViewController();

    // Access platform methods directly, only call those supported by your plugin version
    if (controller.platform is AndroidWebViewController) {
      (controller.platform as AndroidWebViewController)
        ..setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      // Configure navigation and error handling
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('Page started loading: $url');
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) async {
            debugPrint('Page finished loading: $url');
            setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Error loading page: ${error.description}');
            setState(() => _isLoading = false);
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
    // Use WillPopScope to handle the system back button on Android
    return WillPopScope(
      onWillPop: () async {
        if (await _controller.canGoBack()) {
          await _controller.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
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
            'Bible',
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
            FutureBuilder<bool>(
              future: _controller.canGoBack(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!) {
                  return _buildPremiumAppBarButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    onTap: () => _controller.goBack(),
                    tooltip: 'Back',
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            _buildPremiumAppBarButton(
              icon: Icons.refresh_rounded,
              size: 20,
              onTap: () => _controller.reload(),
              tooltip: 'Reload',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            if (_isReady)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: _isLoading ? 0.0 : 1.0, // Fade in once loaded
                child: RepaintBoundary(
                  child: WebViewWidget.fromPlatformCreationParams(
                    params: AndroidWebViewWidgetCreationParams(
                      controller: _controller.platform,
                      displayWithHybridComposition: true,
                    ),
                  ),
                ),
              ),
            if (!_isReady || _isLoading)
              Container(
                color: Colors.white,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFBC8A3A),
                  ),
                ),
              ),
          ],
        ),
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
