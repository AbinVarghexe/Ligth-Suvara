import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class AdminThemeProgramsManager extends StatefulWidget {
  const AdminThemeProgramsManager({super.key});

  @override
  State<AdminThemeProgramsManager> createState() =>
      _AdminThemeProgramsManagerState();
}

class _AdminThemeProgramsManagerState extends State<AdminThemeProgramsManager>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // App Theme Controllers
  final _yearController = TextEditingController();
  final _malayalamController = TextEditingController();
  final _englishController = TextEditingController();
  List<Map<String, dynamic>> _programs = [];

  // Login Screen Controllers
  final _verseTitleController = TextEditingController();
  final _verseTextController = TextEditingController();
  final _verseRefController = TextEditingController();
  final _verseBgController = TextEditingController();
  String _verseTextColor = 'white';
  String _verseTitleBgColor = 'transparent';
  bool _hideVerseText = false;
  List<Map<String, dynamic>> _carouselItems = [];

  bool _isLoading = true;
  bool _isSaving = false;

  final Map<String, IconData> _availableIcons = {
    'fire': FontAwesomeIcons.fire,
    'bookOpenReader': FontAwesomeIcons.bookOpenReader,
    'graduationCap': FontAwesomeIcons.graduationCap,
    'users': FontAwesomeIcons.users,
    'circleQuestion': FontAwesomeIcons.circleQuestion,
    'handsHoldingChild': FontAwesomeIcons.handsHoldingChild,
    'masksTheater': FontAwesomeIcons.masksTheater,
    'star': FontAwesomeIcons.star,
    'church': FontAwesomeIcons.church,
    'cross': FontAwesomeIcons.cross,
    'dove': FontAwesomeIcons.dove,
    'heart': FontAwesomeIcons.heart,
    'lightbulb': FontAwesomeIcons.lightbulb,
    'music': FontAwesomeIcons.music,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _yearController.dispose();
    _malayalamController.dispose();
    _englishController.dispose();
    _verseTitleController.dispose();
    _verseTextController.dispose();
    _verseRefController.dispose();
    _verseBgController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Load Theme & Programs
      final themeDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('theme_programs')
          .get();

      if (themeDoc.exists) {
        final data = themeDoc.data()!;
        _yearController.text = data['themeYear'] ?? '2025-2026';
        _malayalamController.text = data['themeMalayalam'] ?? '';
        _englishController.text = data['themeEnglish'] ?? '';
        if (data['programs'] != null) {
          _programs = List<Map<String, dynamic>>.from(data['programs']);
        }
      }

      // 2. Load Login Screen Config
      final loginDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('login_screen_config')
          .get();

      if (loginDoc.exists) {
        final data = loginDoc.data()!;
        _verseTitleController.text = data['verseTitle'] ?? 'DAILY VERSE';
        _verseTextController.text = data['verseText'] ?? '';
        _verseRefController.text = data['verseRef'] ?? '';
        _verseBgController.text = data['verseBgImage'] ?? '';
        _verseTextColor = data['verseTextColor'] ?? 'white';
        _verseTitleBgColor = data['verseTitleBgColor'] ?? 'transparent';
        _hideVerseText = data['hideVerseText'] ?? false;
        _carouselItems = data['carousel'] != null
            ? List<Map<String, dynamic>>.from(data['carousel'])
            : [];
      } else {
        // DEFINE DEFAULTS IF DOC MISSING (Visibility Fix)
        _verseTitleController.text = 'DAILY VERSE';
        _verseTextController.text = 'Thy word is a lamp unto my feet, and a light unto my path.';
        _verseRefController.text = 'Psalm 119:105';
        _verseBgController.text = '';
        _carouselItems = [
          {
            'name': 'BISHOP',
            'role': 'Diocese of Suvara',
            'label': 'MESSAGE',
            'image': 'https://firebasestorage.googleapis.com/v0/b/sundayschool-app.appspot.com/o/placeholder%2Fbishop.png?alt=media',
            'message': 'Welcome to our Sunday School portal.'
          },
          {
            'name': 'DIRECTOR',
            'role': 'Catechetical Centre',
            'label': 'INVITATION',
            'image': 'https://firebasestorage.googleapis.com/v0/b/sundayschool-app.appspot.com/o/placeholder%2Fdirector.png?alt=media',
            'message': 'Explore our programs and register today.'
          }
        ];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveData() async {
    setState(() => _isSaving = true);
    try {
      // Save Theme & Programs
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('theme_programs')
          .set({
        'themeYear': _yearController.text.trim(),
        'themeMalayalam': _malayalamController.text.trim(),
        'themeEnglish': _englishController.text.trim(),
        'programs': _programs,
      }, SetOptions(merge: true));

      // Save Login Screen Config
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('login_screen_config')
          .set({
        'verseTitle': _verseTitleController.text.trim(),
        'verseText': _verseTextController.text.trim(),
        'verseRef': _verseRefController.text.trim(),
        'verseBgImage': _verseBgController.text.trim(),
        'verseTextColor': _verseTextColor,
        'verseTitleBgColor': _verseTitleBgColor,
        'hideVerseText': _hideVerseText,
        'carousel': _carouselItems,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All changes saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickAndUploadImage(Function(String) onUpload) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() => _isSaving = true);
    try {
      final fileName = 'login_assets/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(fileName);
      await storageRef.putFile(File(image.path));
      final downloadUrl = await storageRef.getDownloadURL();
      onUpload(downloadUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showProgramDialog({int? index}) {
    final titleController = TextEditingController(
      text: index != null ? _programs[index]['title'] : '',
    );
    final descController = TextEditingController(
      text: index != null ? _programs[index]['desc'] : '',
    );
    String selectedIcon =
        index != null ? (_programs[index]['iconName'] ?? 'star') : 'star';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                index == null ? 'Add Program' : 'Edit Program',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      children: _availableIcons.keys.map((k) {
                        return IconButton(
                          icon: Icon(_availableIcons[k]),
                          color: selectedIcon == k ? Colors.blue : Colors.grey,
                          onPressed: () => setDialogState(() => selectedIcon = k),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final data = {
                      'title': titleController.text,
                      'desc': descController.text,
                      'iconName': selectedIcon,
                    };
                    setState(() {
                      if (index == null) {
                        _programs.add(data);
                      } else {
                        _programs[index] = data;
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCarouselDialog({int? index}) {
    final nameController = TextEditingController(
      text: index != null ? _carouselItems[index]['name'] : '',
    );
    final roleController = TextEditingController(
      text: index != null ? _carouselItems[index]['role'] : '',
    );
    final labelController = TextEditingController(
      text: index != null ? _carouselItems[index]['label'] : '',
    );
    final msgController = TextEditingController(
      text: index != null ? _carouselItems[index]['message'] : '',
    );
    String currentImageUrl = index != null ? _carouselItems[index]['image'] : '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(index == null ? 'Add Carousel Slide' : 'Edit Slide'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (currentImageUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(currentImageUrl, height: 100, fit: BoxFit.cover),
                      ),
                    ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Change Photo'),
                    onPressed: () => _pickAndUploadImage((url) {
                      setDialogState(() => currentImageUrl = url);
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name (e.g. Bishop)'),
                  ),
                  TextField(
                    controller: roleController,
                    decoration: const InputDecoration(labelText: 'Role/Title'),
                  ),
                  TextField(
                    controller: labelController,
                    decoration: const InputDecoration(labelText: 'Small Label'),
                  ),
                  TextField(
                    controller: msgController,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Message Content'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final data = {
                    'name': nameController.text,
                    'role': roleController.text,
                    'label': labelController.text,
                    'image': currentImageUrl,
                    'message': msgController.text,
                  };
                  setState(() {
                    if (index == null) {
                      _carouselItems.add(data);
                    } else {
                      _carouselItems[index] = data;
                    }
                  });
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Theme & Info',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.blue.shade900),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue.shade900,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue.shade900,
          tabs: const [
            Tab(text: 'App Theme'),
            Tab(text: 'Login Screen'),
          ],
        ),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              onPressed: _saveData,
              tooltip: 'Save All',
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAppThemeTab(),
          _buildLoginScreenTab(),
        ],
      ),
    );
  }

  Widget _buildAppThemeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Theme of the Year'),
          TextField(controller: _yearController, decoration: const InputDecoration(labelText: 'Year')),
          TextField(controller: _malayalamController, decoration: const InputDecoration(labelText: 'Malayalam Theme')),
          TextField(controller: _englishController, decoration: const InputDecoration(labelText: 'English Theme')),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('Our Programs'),
              IconButton(icon: const Icon(Icons.add_circle, color: Colors.blue), onPressed: () => _showProgramDialog()),
            ],
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _programs.length,
            itemBuilder: (context, i) => ListTile(
              title: Text(_programs[i]['title']),
              subtitle: Text(_programs[i]['desc'], maxLines: 1),
              trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _programs.removeAt(i))),
              onTap: () => _showProgramDialog(index: i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginScreenTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Verse Section'),
          TextField(
            controller: _verseTitleController,
            decoration: InputDecoration(
              labelText: 'Section Title (e.g. Daily Verse)',
              labelStyle: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _getVerseTextColor(_verseTextColor), // Assuming _getVerseTextColor takes the color string
                letterSpacing: 2.0,
                shadows: [
                  if (_verseBgController.text.isNotEmpty)
                    Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4),
                ],
              ),
            ),
          ),
          TextField(controller: _verseTextController, maxLines: 2, decoration: const InputDecoration(labelText: 'Verse Text')),
          TextField(controller: _verseRefController, decoration: const InputDecoration(labelText: 'Verse Reference')),
          const SizedBox(height: 12),
          Text('Title Background:', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildColorOption('transparent', Colors.transparent, 'None', isTitleBg: true),
              const SizedBox(width: 12),
              _buildColorOption('white', Colors.white, 'White', isTitleBg: true),
              const SizedBox(width: 12),
              _buildColorOption('black', Colors.black, 'Black', isTitleBg: true),
              const SizedBox(width: 12),
              _buildColorOption('gold', const Color(0xFFBC8A3A), 'Gold', isTitleBg: true),
              const SizedBox(width: 12),
              _buildColorOption('blue', const Color(0xFF1E3A8A), 'Blue', isTitleBg: true),
            ],
          ),
          const SizedBox(height: 16),
          Text('Text Color:', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildColorOption('white', Colors.white, 'White'),
              const SizedBox(width: 12),
              _buildColorOption('black', Colors.black, 'Black'),
              const SizedBox(width: 12),
              _buildColorOption('gold', const Color(0xFFBC8A3A), 'Gold'),
              const SizedBox(width: 12),
              _buildColorOption('blue', const Color(0xFF1E3A8A), 'Blue'),
            ],
          ),
          const SizedBox(height: 16),
          if (_verseBgController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(_verseBgController.text, height: 100, width: double.infinity, fit: BoxFit.cover),
              ),
            ),
          Text('Background Photo:', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.photo_camera),
                label: const Text('Change'),
                onPressed: () => _pickAndUploadImage((url) {
                  setState(() => _verseBgController.text = url);
                }),
              ),
              if (_verseBgController.text.isNotEmpty) ...[
                const SizedBox(width: 12),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('Remove', style: TextStyle(color: Colors.red)),
                  onPressed: () => setState(() => _verseBgController.text = ''),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // 🔹 VISIBILITY FOCUS CONTROLS
          Text('Visibility Focus:', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text('Hide Verse Text', style: GoogleFonts.outfit(fontSize: 14)),
            subtitle: Text('Show background image with 100% clarity', style: GoogleFonts.outfit(fontSize: 12)),
            value: _hideVerseText,
            onChanged: (v) => setState(() => _hideVerseText = v),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('Carousel Slides'),
              IconButton(icon: const Icon(Icons.add_circle, color: Colors.blue), onPressed: () => _showCarouselDialog()),
            ],
          ),
          const SizedBox(height: 8),
          _buildLeaderMessageCard('Bishop\'s Message', 'Bishop'),
          const SizedBox(height: 8),
          _buildLeaderMessageCard('Director\'s Message', 'Director'),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _carouselItems.length,
            itemBuilder: (context, i) {
              final item = _carouselItems[i];
              final role = (item['role'] ?? '').toString().toLowerCase();
              if (role.contains('bishop') || role.contains('director')) {
                return const SizedBox.shrink();
              }
              return ListTile(
                leading: item['image'].toString().startsWith('http') 
                  ? CircleAvatar(backgroundImage: NetworkImage(item['image']))
                  : const CircleAvatar(child: Icon(Icons.person)),
                title: Text(item['name'] ?? 'Untitled'),
                subtitle: Text(item['role'] ?? '', maxLines: 1),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red), 
                  onPressed: () => setState(() => _carouselItems.removeAt(i))
                ),
                onTap: () => _showCarouselDialog(index: i),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
      ),
    );
  }

  Widget _buildLeaderMessageCard(String title, String roleKeyword) {
    int index = _carouselItems.indexWhere((item) => (item['role'] ?? '').toString().toLowerCase().contains(roleKeyword.toLowerCase()));
    
    if (index == -1) return const SizedBox.shrink();

    final item = _carouselItems[index];

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade100,
          backgroundImage: (item['image'] ?? '').toString().startsWith('http')
              ? NetworkImage(item['image'])
              : const AssetImage('assets/images/leader_placeholder.png') as ImageProvider,
        ),
        title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        subtitle: Text('Edit ${item['role']}\'s message', style: GoogleFonts.outfit(fontSize: 12)),
        trailing: TextButton(
          onPressed: () => _showCarouselDialog(index: index),
          child: const Text('Edit'),
        ),
      ),
    );
  }

  Widget _buildColorOption(String value, Color color, String label, {bool isTitleBg = false}) {
    bool isSelected = isTitleBg ? (_verseTitleBgColor == value) : (_verseTextColor == value);
    return InkWell(
      onTap: () => setState(() {
        if (isTitleBg) {
          _verseTitleBgColor = value;
        } else {
          _verseTextColor = value;
        }
      }),
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color == Colors.transparent ? Colors.grey.withOpacity(0.1) : color,
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? Colors.blue : Colors.grey.shade400, width: isSelected ? 3 : 1),
            ),
            child: color == Colors.transparent ? const Icon(Icons.block, size: 16, color: Colors.grey) : null,
          ),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Color _getVerseTextColor(String colorStr) {
    switch (colorStr) {
      case 'black': return Colors.black;
      case 'gold': return const Color(0xFFBC8A3A);
      case 'blue': return const Color(0xFF1E3A8A);
      case 'white': default: return Colors.white;
    }
  }
}
