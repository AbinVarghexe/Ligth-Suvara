import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

class JapamalaScreen extends StatefulWidget {
  const JapamalaScreen({super.key});

  @override
  State<JapamalaScreen> createState() => _JapamalaScreenState();
}

class _JapamalaScreenState extends State<JapamalaScreen> {
  // 1. Create a WebViewController
  late final WebViewController _controller;
  bool _isLoading = true; // To show a loading indicator

  // The URL for the Japamala page
  static const String webUrl =
      'https://nelsonmcbs.com/2019/10/22/holy-rosary-malayalam-japamala-kontha/';

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
      )
    // 3. Load the specific URL
      ..loadRequest(Uri.parse(webUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // --- FIX: ADDED A BACK BUTTON ---
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Japamala',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600, // w600 is a good modern choice
            color: Colors.blue.shade900,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue.shade900,
        elevation: 1,
        // Optional: Add a button to reload the page
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      // 4. Use the WebViewWidget with the initialized controller
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
