import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:flutter/services.dart';

class CalendarWebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const CalendarWebViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<CalendarWebViewScreen> createState() => _CalendarWebViewScreenState();
}

class _CalendarWebViewScreenState extends State<CalendarWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();

    // If it's a PDF, wrap it in Google Docs Viewer for native WebView rendering on Android
    String finalUrl = widget.url;
    if (widget.url.toLowerCase().contains('.pdf') || 
        widget.url.contains('firebasestorage') ||
        widget.url.contains('/o/')) {
      finalUrl = 'https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(widget.url)}';
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint('Calendar WebView progress: $progress%');
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Calendar WebView error: ${error.description}');
          },
        ),
      );

    // Transition delay for stability
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _controller.loadRequest(Uri.parse(finalUrl));
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
          child: _buildAppBarButton(
            icon: Icons.arrow_back_ios_new_rounded,
            size: 18,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
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
          _buildAppBarButton(
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
            RepaintBoundary(
              child: WebViewWidget.fromPlatformCreationParams(
                params: AndroidWebViewWidgetCreationParams(
                  controller: _controller.platform,
                  displayWithHybridComposition: true,
                ),
              ),
            ),
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

  Widget _buildAppBarButton({
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
