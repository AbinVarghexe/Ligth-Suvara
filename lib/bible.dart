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

  static const String webUrl = 'https://www.pocbible.com/m/';
  bool _isLoading = true;

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
          onPageFinished: (String url) {
            debugPrint('Page finished loading: $url');
            setState(() => _isLoading = false);

            // Inject JavaScript to force viewport meta tag for proper scaling.
            _controller.runJavaScript("""
              var viewport = document.querySelector("meta[name=viewport]");
              if (!viewport) {
                viewport = document.createElement('meta');
                viewport.name = 'viewport';
                document.getElementsByTagName('head')[0].appendChild(viewport);
              }
              viewport.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
            """);
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
