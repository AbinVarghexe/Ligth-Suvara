// lib/catechism_screen.dart

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:http/http.dart' as http; // Needed for downloading files
import 'dart:io'; // Needed for File and Platform checks
import 'package:path_provider/path_provider.dart'; // For app's private directory
import 'package:open_filex/open_filex.dart'; // Needed to open the downloaded file
import 'package:flutter/services.dart';

class CatechismScreen extends StatefulWidget {
  const CatechismScreen({super.key});

  @override
  State<CatechismScreen> createState() => _CatechismScreenState();
}

class _CatechismScreenState extends State<CatechismScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isDownloading = false;
  bool _isReady = false; // Flag to delay rendering until transition finishes

  // --- State for the custom download notification ---
  bool _showDownloadComplete = false;
  String _downloadedFileName = '';
  String _downloadedFilePath = '';

  static const String webUrl = 'https://www.syromalabarcatechesis.com/presentation';

  // --- Helper method to show the modern download complete popup ---
  void _showDownloadNotification(String fileName, String filePath) {
    setState(() {
      _downloadedFileName = fileName;
      _downloadedFilePath = filePath;
      _showDownloadComplete = true;
    });

    // Automatically hide the notification after a few seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showDownloadComplete = false;
        });
      }
    });
  }

  // --- File Download Utility Functions ---

  bool _isDownloadUrl(String url) {
    final downloadExtensions = [
      '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.zip', '.rar',
      '.mp3', '.mp4', '.jpg', '.jpeg', '.png',
    ];
    final lowerUrl = url.toLowerCase();
    // Checks if URL contains a known download extension or 'download' keyword
    return downloadExtensions.any((ext) => lowerUrl.contains(ext)) ||
        lowerUrl.contains('download') ||
        lowerUrl.contains('attachment');
  }

  String _getFileName(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final fileName = pathSegments.last;
        if (fileName.isNotEmpty) {
          return fileName.split('?').first;
        }
      }
      return 'download_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      return 'download_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> _downloadFile(String url) async {
    if (_isDownloading) return;

    setState(() { _isDownloading = true; });

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Starting download...', style: GoogleFonts.poppins()),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        String fileName = _getFileName(url);

        // Extract filename from content-disposition header if available
        final contentDisposition = response.headers['content-disposition'];
        if (contentDisposition != null) {
          final fileNameRegex = RegExp(r"filename[^;=\n]*=((['\u0022]|[^;\n]*))");
          final match = fileNameRegex.firstMatch(contentDisposition);
          if (match != null) {
            String extractedName = match.group(1) ?? fileName;
            // Clean up the filename
            extractedName = extractedName.replaceAll(RegExp(r"['\u0022]"), '');
            if(extractedName.isNotEmpty) {
              fileName = extractedName;
            }
          }
        }
        
        // --- SAVE TO APP'S PRIVATE DIRECTORY ---
        Directory? directory;
        if (Platform.isAndroid) {
          // Use the app's exclusive external storage directory.
          // This is the recommended approach that doesn't require special permissions.
          directory = await getExternalStorageDirectory();
        } else {
          // For iOS and other platforms
          directory = await getApplicationDocumentsDirectory();
        }

        if (directory == null) {
          throw Exception('Could not access storage directory.');
        }

        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        if (await file.exists()) {
          _showDownloadNotification(fileName, filePath);
        } else {
          throw Exception('File was not saved successfully.');
        }

      } else {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download error: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isDownloading = false; });
      }
    }
  }


  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {},
          onPageStarted: (String url) => setState(() { _isLoading = true; }),
          onPageFinished: (String url) => setState(() { _isLoading = false; }),
          onWebResourceError: (WebResourceError error) {
            debugPrint('Page loading error: code: ${error.errorCode}, description: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            if (_isDownloadUrl(request.url)) {
              _downloadFile(request.url);
              return NavigationDecision.prevent; // Prevent the WebView from navigating away
            }
            return NavigationDecision.navigate;
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
          'Catechism',
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
          if (_isDownloading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
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

          // --- MODERN DOWNLOAD COMPLETE POPUP ---
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            bottom: _showDownloadComplete ? 20.0 : -150.0, // Animate in/out
            left: 20.0,
            right: 20.0,
            child: Material(
              elevation: 6.0,
              borderRadius: BorderRadius.circular(12.0),
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade600, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Download Complete',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _downloadedFileName,
                            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        try {
                          await OpenFilex.open(_downloadedFilePath);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Could not open file: $e'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        }
                      },
                      child: Text(
                        'Open',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
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
