import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

// Import necessary platform-specific settings for Android
import 'package:webview_flutter_android/webview_flutter_android.dart';

class PocBibleScreen extends StatefulWidget {
  const PocBibleScreen({super.key});

  @override
  State<PocBibleScreen> createState() => _PocBibleScreenState();
}

class _PocBibleScreenState extends State<PocBibleScreen> {
  late final WebViewController _controller;

  static const String webUrl = 'https://thiruvachanam.in/';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    final WebViewController controller = WebViewController();

    // Access platform methods directly, only call those supported by your plugin version
    if (controller.platform is AndroidWebViewController) {
      (controller.platform as AndroidWebViewController)
        ..setMediaPlaybackRequiresUserGesture(false)
        ..setUseWideViewPort(
          true,
        ); // Force wide viewport for desktop-like rendering
    }

    _controller = controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      ) // Spoof Desktop UA
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

            // Inject viewport meta tag to force desktop width (zoomed out view)
            // This prevents the page from loading in "enlarged form" on mobile
            await _controller.runJavaScript('''
              var meta = document.createElement('meta');
              meta.name = "viewport";
              meta.content = "width=1024, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes";
              var head = document.getElementsByTagName('head')[0];
              // Remove existing viewport tag if any
              var existing = head.querySelector('meta[name="viewport"]');
              if (existing) { existing.remove(); }
              head.appendChild(meta);
            ''');
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Error loading page: ${error.description}');
            setState(() => _isLoading = false);
          },
        ),
      )
      // Load the URL
      ..loadRequest(Uri.parse(webUrl));
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
          // ⭐️ ADD THE LEADING BACK BUTTON HERE ⭐️
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'POC Bible',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.blue.shade900,
          elevation: 1,
          actions: [
            // Add Back navigation controls
            FutureBuilder<bool>(
              future: _controller.canGoBack(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!) {
                  return IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new),
                    onPressed: () => _controller.goBack(),
                    tooltip: 'Back',
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            FutureBuilder<bool>(
              future: _controller.canGoForward(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!) {
                  return IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    onPressed: () => _controller.goForward(),
                    tooltip: 'Forward',
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _controller.reload(),
              tooltip: 'Reload',
            ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              Container(
                color: Colors.white,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
