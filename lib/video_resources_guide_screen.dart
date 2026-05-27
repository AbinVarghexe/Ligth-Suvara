// lib/video_resources_guide_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class VideoResourcesGuideScreen extends StatefulWidget {
  const VideoResourcesGuideScreen({super.key});

  @override
  State<VideoResourcesGuideScreen> createState() => _VideoResourcesGuideScreenState();
}

class _VideoResourcesGuideScreenState extends State<VideoResourcesGuideScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _ytController = TextEditingController(
    text: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
  );
  String _extractedYtId = 'dQw4w9WgXcQ';
  String _thumbnailUrl = 'https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg';

  // State for helpful feedback
  int? _rating;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ytController.dispose();
    super.dispose();
  }

  void _parseYoutubeUrl(String url) {
    final regExp = RegExp(
      r'^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*',
    );
    final match = regExp.firstMatch(url);
    final id = (match != null && match.group(2)!.length == 11) ? match.group(2) : null;
    setState(() {
      if (id != null) {
        _extractedYtId = id;
        _thumbnailUrl = 'https://img.youtube.com/vi/$id/maxresdefault.jpg';
      } else {
        _extractedYtId = 'Invalid/Not Found';
        _thumbnailUrl = '';
      }
    });
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              message,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFBC8A3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const navyColor = Color(0xFF1E3A8A);
    const goldColor = Color(0xFFBC8A3A);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: navyColor, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
        title: Text(
          'Video & Reference Integration',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: navyColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Premium Tab bar container
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [navyColor, Color(0xFF3B82F6)],
                    ),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey.shade600,
                  labelStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(text: '1. Schema'),
                    Tab(text: '2. React (Web)'),
                    Tab(text: '3. Queries (SDKs)'),
                    Tab(text: '4. YouTube Helper'),
                    Tab(text: '5. Security Rules'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSchemaTab(navyColor, goldColor),
                  _buildReactTab(navyColor, goldColor),
                  _buildDirectQueriesTab(navyColor, goldColor),
                  _buildYoutubeHelperTab(navyColor, goldColor),
                  _buildSecurityRulesTab(navyColor, goldColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: DATA SCHEMA ---
  Widget _buildSchemaTab(Color navyColor, Color goldColor) {
    const jsonString = '''{
  "chapters": [
    {
      "id": "ch_1",
      "title": "Chapter 1: Creation of God",
      "resources": [
        {
          "id": "res_123",
          "title": "PPT Reference Slide",
          "url": "https://drive.google.com/file/d/...",
          "type": "drive" 
        },
        {
          "id": "res_456",
          "title": "Story Video",
          "url": "https://youtu.be/...",
          "type": "youtube"
        }
      ]
    }
  ]
}''';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      children: [
        _buildInfoCard(
          title: 'Firestore Database Structure',
          description: 'All reference resources are organized by class inside the video_resources collection.',
          icon: Icons.storage_rounded,
          color: Colors.blue.shade600,
        ),
        const SizedBox(height: 16),
        _buildSchemaVisualizer(navyColor, goldColor),
        const SizedBox(height: 20),
        _buildCodeBlockHeader(
          title: 'Document JSON Schema',
          onCopy: () => _copyToClipboard(jsonString, 'JSON Schema copied to clipboard'),
        ),
        _buildCodeBlock(jsonString, 'json'),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSchemaVisualizer(Color navyColor, Color goldColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Visual Firestore Hierarchy',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: navyColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildHierarchyNode(
            label: 'Collection: video_resources',
            icon: Icons.folder_open_rounded,
            color: const Color(0xFF6366F1),
          ),
          _buildHierarchyLine(),
          _buildHierarchyNode(
            label: 'Document: class_{classNum} (e.g. class_1, class_12)',
            icon: Icons.description_outlined,
            color: goldColor,
            isIndent: true,
          ),
          _buildHierarchyLine(isIndent: true),
          _buildHierarchyNode(
            label: 'Field: chapters (Array of Chapter Maps)',
            icon: Icons.list_alt_rounded,
            color: Colors.green,
            isIndent: true,
            doubleIndent: true,
          ),
        ],
      ),
    );
  }

  Widget _buildHierarchyNode({
    required String label,
    required IconData icon,
    required Color color,
    bool isIndent = false,
    bool doubleIndent = false,
  }) {
    double leftPadding = 0;
    if (doubleIndent) {
      leftPadding = 32;
    } else if (isIndent) {
      leftPadding = 16;
    }

    return Padding(
      padding: EdgeInsets.only(left: leftPadding),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHierarchyLine({bool isIndent = false}) {
    double leftPadding = isIndent ? 24 : 8;
    return Padding(
      padding: EdgeInsets.only(left: leftPadding, top: 4, bottom: 4),
      child: Container(
        width: 2,
        height: 16,
        color: Colors.grey.shade300,
      ),
    );
  }

  // --- TAB 2: REACT CONSUMPTION ---
  Widget _buildReactTab(Color navyColor, Color goldColor) {
    const codeString = '''import { useState, useEffect } from "react";
import { getClassResources, ClassResources } from "@/features/video-resources/services/videoResourceService";

export function StudentPortal({ classNum }: { classNum: number }) {
  const [data, setData] = useState<ClassResources | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadData() {
      try {
        const result = await getClassResources(classNum);
        setData(result);
      } catch (error) {
        console.error("Failed to load:", error);
      } finally {
        setLoading(false);
      }
    }
    loadData();
  }, [classNum]);

  if (loading) return <p>Loading resources...</p>;

  return (
    <div>
      {data?.chapters.map(chapter => (
        <div key={chapter.id}>
          <h3>{chapter.title}</h3>
          {/* Render resource list */}
        </div>
      ))}
    </div>
  );
}''';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      children: [
        _buildInfoCard(
          title: 'Fetching in React Dashboard',
          description: 'You can import and consume the service function getClassResources from any admin or student React dashboard component.',
          icon: Icons.code_rounded,
          color: Colors.cyan.shade600,
        ),
        const SizedBox(height: 16),
        _buildCodeBlockHeader(
          title: 'React Implementation Example',
          onCopy: () => _copyToClipboard(codeString, 'React code snippet copied to clipboard'),
        ),
        _buildCodeBlock(codeString, 'typescript'),
        const SizedBox(height: 40),
      ],
    );
  }

  // --- TAB 3: DIRECT QUERIES (SDKs) ---
  Widget _buildDirectQueriesTab(Color navyColor, Color goldColor) {
    const webSdkCode = '''import { doc, getDoc, getFirestore } from "firebase/firestore";

const db = getFirestore();

async function fetchClassResources(classNum: number) {
  const docRef = doc(db, "video_resources", `class_\${classNum}`);
  const docSnap = await getDoc(docRef);
  
  if (docSnap.exists()) {
    return docSnap.data().chapters || [];
  }
  return [];
}''';

    const flutterSdkCode = '''import 'package:cloud_firestore/cloud_firestore.dart';

Future<List<dynamic>> fetchClassResources(int classNum) async {
  var docSnapshot = await FirebaseFirestore.instance
      .collection('video_resources')
      .doc('class_\$classNum')
      .get();

  if (docSnapshot.exists) {
    return docSnapshot.data()?['chapters'] ?? [];
  }
  return [];
}''';

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                    ),
                  ],
                ),
                labelColor: navyColor,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: 'Web SDK (React)'),
                  Tab(text: 'Flutter / Dart SDK'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  children: [
                    _buildCodeBlockHeader(
                      title: 'Web SDK Modular v9+',
                      onCopy: () => _copyToClipboard(webSdkCode, 'Web SDK Code copied'),
                    ),
                    _buildCodeBlock(webSdkCode, 'typescript'),
                    const SizedBox(height: 40),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  children: [
                    _buildCodeBlockHeader(
                      title: 'Flutter Firebase SDK',
                      onCopy: () => _copyToClipboard(flutterSdkCode, 'Flutter SDK Code copied'),
                    ),
                    _buildCodeBlock(flutterSdkCode, 'dart'),
                    const SizedBox(height: 40),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 4: YOUTUBE UTILITY & PLAYGROUND ---
  Widget _buildYoutubeHelperTab(Color navyColor, Color goldColor) {
    const tsHelper = '''export function getYouTubeId(url: string): string | null {
  const regExp = /^.*(youtu.be\\/|v\\/|u\\/\\w\\/|embed\\/|watch\\?v=|\\&v=)([^#\\&\\?]*).*/;
  const match = url.match(regExp);
  return match && match[2].length === 11 ? match[2] : null;
}

// Generate thumbnail URL
const videoId = getYouTubeId(youtubeUrl);
const thumbnailUrl = `https://img.youtube.com/vi/\${videoId}/maxresdefault.jpg`;''';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      children: [
        _buildInfoCard(
          title: 'YouTube ID Extraction',
          description: 'Extract the unique 11-character video ID from YouTube links to display previews or load embedded players.',
          icon: FontAwesomeIcons.youtube,
          color: Colors.red,
        ),
        const SizedBox(height: 16),
        // Live Playground
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live Parse Playground',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: navyColor,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ytController,
                onChanged: _parseYoutubeUrl,
                decoration: InputDecoration(
                  labelText: 'YouTube URL',
                  labelStyle: GoogleFonts.outfit(color: Colors.grey.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: goldColor, width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _ytController.clear();
                      setState(() {
                        _extractedYtId = '';
                        _thumbnailUrl = '';
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Extracted ID',
                          style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        Text(
                          _extractedYtId,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: navyColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_thumbnailUrl.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Auto-Generated Preview',
                  style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      _thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
                        ),
                      ),
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildCodeBlockHeader(
          title: 'Parser Utility Function',
          onCopy: () => _copyToClipboard(tsHelper, 'TypeScript Helper copied'),
        ),
        _buildCodeBlock(tsHelper, 'typescript'),
        const SizedBox(height: 40),
      ],
    );
  }

  // --- TAB 5: SECURITY RULES ---
  Widget _buildSecurityRulesTab(Color navyColor, Color goldColor) {
    const rulesString = '''rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Video Resources collection rules
    match /video_resources/{classId} {
      // Anyone logged in can read
      allow read: if request.auth != null; 
      
      // Only authenticated users with admin status can write
      allow write: if request.auth != null && 
        get(/databases/\$(database)/documents/users/\$(request.auth.uid)).data.role == 'admin';
    }
  }
}''';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      children: [
        _buildInfoCard(
          title: 'Firestore Security Configuration',
          description: 'Deploy these rules in firestore.rules to ensure student accessibility while restricting creation/modification to verified admins.',
          icon: Icons.security_rounded,
          color: Colors.deepOrange.shade600,
        ),
        const SizedBox(height: 16),
        _buildCodeBlockHeader(
          title: 'Firestore Rules Script',
          onCopy: () => _copyToClipboard(rulesString, 'Firestore rules copied to clipboard'),
        ),
        _buildCodeBlock(rulesString, 'javascript'),
        const SizedBox(height: 20),
        _buildFeedbackWidget(navyColor, goldColor),
        const SizedBox(height: 40),
      ],
    );
  }

  // --- SHARED SUB-WIDGETS ---

  Widget _buildInfoCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color.darken(),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBlockHeader({required String title, required VoidCallback onCopy}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onCopy,
          icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFFBC8A3A)),
          label: Text(
            'Copy',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFBC8A3A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeBlock(String code, String language) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Slate 900
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Text(
          code,
          style: GoogleFonts.firaCode(
            color: const Color(0xFFE2E8F0),
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackWidget(Color navyColor, Color goldColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Was this integration guide helpful?',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: navyColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < (_rating ?? 0) ? Icons.star_rounded : Icons.star_border_rounded,
                  color: Colors.amber,
                  size: 28,
                ),
                onPressed: () {
                  setState(() {
                    _rating = index + 1;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Thank you for your feedback!',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: navyColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
              );
            }),
          )
        ],
      ),
    );
  }
}

// Extension to darken colors
extension ColorDarken on Color {
  Color darken([double amount = .2]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
