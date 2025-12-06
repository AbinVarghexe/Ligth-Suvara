// lib/catechism_screen.dart

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http; // Needed for downloading files
import 'dart:io'; // Needed for File and Platform checks
import 'package:path_provider/path_provider.dart'; // For app's private directory
import 'package:open_file/open_file.dart'; // Needed to open the downloaded file

class CatechismScreen extends StatefulWidget {
  const CatechismScreen({super.key});

  @override
  State<CatechismScreen> createState() => _CatechismScreenState();
}

class _CatechismScreenState extends State<CatechismScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isDownloading = false;

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
      )
      ..loadRequest(Uri.parse(webUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Study Materials',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.blue.shade900,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue.shade900,
        elevation: 1,
        actions: [
          if (_isDownloading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),

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
                          await OpenFile.open(_downloadedFilePath);
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
}
