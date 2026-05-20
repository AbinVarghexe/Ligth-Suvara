import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart'; // Added for HapticFeedback
import 'package:sundayschool_app/multi_school_selection.dart';

// --- 1. IMPORT THE NEW MULTI-SELECTION SCREEN ---

class AdminNotificationScreen extends StatefulWidget {
  const AdminNotificationScreen({super.key});

  @override
  State<AdminNotificationScreen> createState() =>
      _AdminNotificationScreenState();
}

class _AdminNotificationScreenState extends State<AdminNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  // --- 2. STATE VARIABLES UPDATED ---
  String _audienceType = 'public'; // 'public', 'all', 'specific'
  List<String> _selectedSchoolIds = [];
  String _displaySelectionText = 'Public Broadcast';

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  bool _isSending = false;

  void _showFeedbackDialog(String title, String content, bool isError) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(content, style: GoogleFonts.poppins()),
        actions: <Widget>[
          TextButton(
            child: Text(
              'Okay',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  // --- NEW: PICK IMAGE WITH PERMISSION CHECK ---
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Compress slightly
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackDialog('Error', 'Failed to pick image: $e', true);
      }
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  // --- 3. SEND LOGIC UPDATED FOR MULTIPLE RECIPIENTS ---
  Future<void> _sendNotification() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_audienceType == 'specific' && _selectedSchoolIds.isEmpty) {
      _showFeedbackDialog(
        'Error',
        'Please select at least one specific school.',
        true,
      );
      return;
    }

    // Direct send without confirmation dialog
    setState(() {
      _isSending = true;
    });

    try {
      final title = _titleController.text.trim();
      final body = _messageController.text.trim();
      final timestamp = FieldValue.serverTimestamp();

      String? imageUrl;

      // --- UPLOAD IMAGE IF SELECTED ---
      if (_selectedImage != null) {
        try {
          final String fileName =
              '${DateTime.now().millisecondsSinceEpoch}.jpg';
          final Reference storageRef = FirebaseStorage.instance
              .ref()
              .child('broadcast_images')
              .child(fileName);

          final UploadTask uploadTask = storageRef.putFile(_selectedImage!);
          final TaskSnapshot taskSnapshot = await uploadTask;
          imageUrl = await taskSnapshot.ref.getDownloadURL();
        } catch (e) {
          if (mounted) {
            setState(() {
              _isSending = false;
            });
            _showFeedbackDialog(
              'Upload Error',
              'Failed to upload image: $e',
              true,
            );
            return;
          }
        }
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();

      if (_audienceType == 'public') {
        // Send to broadcasts collection
        final broadcastRef = FirebaseFirestore.instance
            .collection('broadcasts')
            .doc();
        batch.set(broadcastRef, {
          'title': title,
          'body': body,
          'timestamp': timestamp,
          if (imageUrl != null) 'imageUrl': imageUrl,
        });
      } else if (_audienceType == 'all') {
        // Send to 'role_school' (All Sunday Schools)
        final notificationRef = FirebaseFirestore.instance
            .collection('notifications')
            .doc();
        batch.set(notificationRef, {
          'title': title,
          'body': body,
          'timestamp': timestamp,
          if (imageUrl != null) 'imageUrl': imageUrl,
          'isBroadcast': true,
          'recipientId': 'role_school', // Changed from 'all' to 'role_school'
          'isRead': false,
        });
      } else {
        // 'specific'
        for (String schoolId in _selectedSchoolIds) {
          final notificationRef = FirebaseFirestore.instance
              .collection('notifications')
              .doc();
          batch.set(notificationRef, {
            'title': title,
            'body': body,
            'timestamp': timestamp,
            if (imageUrl != null) 'imageUrl': imageUrl,
            'isBroadcast': false,
            'recipientId': schoolId, // Specific user ID
            'isRead': false,
          });
        }
      }

      // Commit all writes at once
      await batch.commit();

      if (mounted) {
        String successMessage;
        if (_audienceType == 'specific') {
          successMessage =
              'Notification sent to ${_selectedSchoolIds.length} school(s).';
        } else {
          successMessage = 'Notification posted successfully.';
        }
        _showFeedbackDialog('Success!', successMessage, false);
        _formKey.currentState?.reset();
        _titleController.clear();
        _messageController.clear();
        setState(() {
          _audienceType = 'public';
          _selectedSchoolIds = [];
          _displaySelectionText = 'Public Broadcast';
          _selectedImage = null; // Clear image
        });
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackDialog(
          'Error',
          'Failed to send notification. Error: $e',
          true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // --- 4. NAVIGATION TO MULTI-SELECTION SCREEN ---
  void _selectSpecificSchools() async {
    final List<String>? selectedIds = await Navigator.of(context)
        .push<List<String>>(
          MaterialPageRoute(
            builder: (context) => const MultiSchoolSelectionScreen(),
          ),
        );

    if (selectedIds != null && mounted) {
      setState(() {
        _audienceType = 'specific';
        _selectedSchoolIds = selectedIds;
        if (selectedIds.isEmpty) {
          _displaySelectionText = 'No Parish Selected';
        } else if (selectedIds.length == 1) {
          _displaySelectionText = '1 Parish Selected';
        } else {
          _displaySelectionText = '${selectedIds.length} Parishes Selected';
        }
      });
    }
  }

  void _showViewersList(List<dynamic> userIds) {
    if (userIds.isEmpty) return;
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      'Viewed By',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${userIds.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where(FieldPath.documentId, whereIn: userIds)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final users = snapshot.data?.docs ?? [];
                    if (users.isEmpty) {
                      return Center(
                        child: Text(
                          'No user details found',
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final userData =
                            users[index].data() as Map<String, dynamic>?;
                        final role = userData?['role'] ?? '';
                        String name =
                            userData?['schoolname'] ??
                            userData?['name'] ??
                            'Unknown User';
                        if (role == 'parish') {
                          name = '$name (Parish)';
                        }
                        final location =
                            userData?['location'] ??
                            userData?['parishName'] ??
                            '';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade50,
                            child: Icon(
                              Icons.person_outline_rounded,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          title: Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: location.isNotEmpty
                              ? Text(
                                  location,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                )
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: AppBar(
          title: Text(
            'Notification Manager',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E3A8A),
            ),
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1E3A8A),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          bottom: TabBar(
            labelColor: const Color(0xFF1E3A8A),
            unselectedLabelColor: Colors.grey,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            indicatorColor: const Color(0xFF1E3A8A),
            tabs: const [
              Tab(text: 'Compose'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(children: [_buildComposeTab(), _buildHistoryTab()]),
      ),
    );
  }

  Widget _buildComposeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audience',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                _buildRecipientCard(
                  icon: Icons.campaign_rounded,
                  label: 'Public Broadcast (Everyone)',
                  isSelected: _audienceType == 'public',
                  onTap: () {
                    setState(() {
                      _audienceType = 'public';
                      _selectedSchoolIds = [];
                      _displaySelectionText = 'Public Broadcast';
                    });
                  },
                ),
                const SizedBox(height: 16),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildRecipientCard(
                          icon: Icons.public_rounded,
                          label: 'All Sunday Schools',
                          isSelected: _audienceType == 'all',
                          onTap: () {
                            setState(() {
                              _audienceType = 'all';
                              _selectedSchoolIds = [];
                              _displaySelectionText = 'All Sunday Schools';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildRecipientCard(
                          icon: Icons.location_city_rounded,
                          label: _audienceType == 'specific'
                              ? _displaySelectionText
                              : 'Specific Parish',
                          isSelected: _audienceType == 'specific',
                          onTap: _selectSpecificSchools,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _titleController,
              style: GoogleFonts.poppins(fontSize: 16),
              decoration: _buildInputDecoration(
                label: 'Notification Title (Max 50 Chars)',
              ),
              maxLength: 50,
              validator: (value) =>
                  value!.trim().isEmpty ? 'Please enter a title' : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _messageController,
              style: GoogleFonts.poppins(fontSize: 16),
              decoration: _buildInputDecoration(label: 'Detailed Message'),
              maxLines: 8,
              validator: (value) =>
                  value!.trim().isEmpty ? 'Please enter a message' : null,
            ),
            const SizedBox(height: 20),
            if (_selectedImage != null)
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: FileImage(_selectedImage!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: _removeImage,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(
                  Icons.add_photo_alternate_rounded,
                  color: Color(0xFF1E3A8A),
                ),
                label: Text(
                  'Add Image',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF1E3A8A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _isSending ? null : _sendNotification,
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
              label: Text(
                _isSending ? 'Sending...' : 'Publish Update',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // State for History Tab
  String _historyFilter = 'broadcasts'; // 'broadcasts' or 'notifications'
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  // Cache for school names to prevent slow loading
  final Map<String, String> _schoolNameCache = {};

  Future<String?> _getSchoolName(String userId) async {
    if (userId == 'all') return 'All Parishes';

    // Return cached name if available
    if (_schoolNameCache.containsKey(userId)) {
      return _schoolNameCache[userId];
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        final data = doc.data();
        // Try common name fields
        final name = data?['schoolname'] ?? 'Unknown Parish';
        _schoolNameCache[userId] = name; // Cache the result
        return name;
      }
    } catch (e) {
      debugPrint('Error fetching school name: $e');
    }
    return null;
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Widget _buildHistoryTab() {
    return Column(
      children: [
        // --- Filter Toggle ---
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          color: const Color(0xFFF0F4F8),
          child: Row(
            children: [
              Expanded(
                child: _buildFilterButton(
                  'Public Broadcasts',
                  'broadcasts',
                  Icons.campaign_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterButton(
                  'Private Messages',
                  'notifications',
                  Icons.lock_rounded,
                ),
              ),
            ],
          ),
        ),

        // --- Selection Toolbar (Visible when selecting) ---
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isSelectionMode ? 60 : 0,
          color: const Color(0xFFDBEAFE),
          child: _isSelectionMode
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF1E3A8A)),
                        onPressed: () => setState(() {
                          _isSelectionMode = false;
                          _selectedIds.clear();
                        }),
                      ),
                      Text(
                        '${_selectedIds.length} Selected',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E3A8A),
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Delete Selected',
                        icon: const Icon(
                          Icons.delete_rounded,
                          color: Colors.red,
                        ),
                        onPressed: _selectedIds.isNotEmpty
                            ? () => _confirmDelete(
                                _selectedIds.toList(),
                                _historyFilter,
                              )
                            : null,
                      ),
                    ],
                  ),
                )
              : const SizedBox(),
        ),

        const SizedBox(height: 8),

        // --- List Content ---
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(_historyFilter)
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _historyFilter == 'broadcasts'
                            ? Icons.campaign_outlined
                            : Icons.lock_outline_rounded,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _historyFilter == 'broadcasts'
                            ? 'No public broadcasts found'
                            : 'No private messages found',
                        style: GoogleFonts.poppins(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final id = docs[index].id;
                  final title = data['title'] ?? 'No Title';
                  final body = data['body'] ?? 'No Content';
                  final timestamp = data['timestamp'] as Timestamp?;
                  final dateStr = timestamp != null
                      ? DateTime.fromMillisecondsSinceEpoch(
                          timestamp.millisecondsSinceEpoch,
                        ).toString().split('.')[0]
                      : 'Unknown Date';

                  final isSelected = _selectedIds.contains(id);

                  return GestureDetector(
                    onLongPress: () {
                      setState(() {
                        _isSelectionMode = true;
                        _toggleSelection(id);
                      });
                    },
                    onTap: () {
                      if (_isSelectionMode) {
                        _toggleSelection(id);
                      }
                    },
                    child: Card(
                      elevation: isSelected ? 4 : 2,
                      color: isSelected
                          ? const Color(0xFFEFF6FF)
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isSelected
                            ? const BorderSide(
                                color: Color(0xFF3B82F6),
                                width: 2,
                              )
                            : BorderSide.none,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            if (_isSelectionMode)
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Icon(
                                  isSelected
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: isSelected
                                      ? const Color(0xFF3B82F6)
                                      : Colors.grey.shade400,
                                ),
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // --- Recipient Info (Async Name Fetching) ---
                                  if (_historyFilter == 'notifications')
                                    FutureBuilder<String?>(
                                      future: _getSchoolName(
                                        data['recipientId'] ?? '',
                                      ),
                                      builder: (context, nameSnapshot) {
                                        final displayName =
                                            nameSnapshot.data ??
                                            data['recipientId'] ??
                                            'Unknown';
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 6.0,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.school_rounded,
                                                  size: 14,
                                                  color: Colors.blue.shade700,
                                                ),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    displayName,
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.blue.shade800,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                  Text(
                                    title,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        dateStr,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      if (_historyFilter ==
                                          'notifications') ...[
                                        Builder(
                                          builder: (context) {
                                            final readBy =
                                                data['readBy']
                                                    as List<dynamic>? ??
                                                [];
                                            final readCount = readBy.length;
                                            return InkWell(
                                              onTap: () =>
                                                  _showViewersList(readBy),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.visibility_rounded,
                                                      size: 14,
                                                      color:
                                                          Colors.blue.shade700,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '$readCount',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors
                                                                .blue
                                                                .shade800,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (!_isSelectionMode)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    _confirmDelete([id], _historyFilter),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButton(String label, String value, IconData icon) {
    final isSelected = _historyFilter == value;
    return InkWell(
      onTap: () {
        setState(() {
          _historyFilter = value;
          // Exit selection mode when switching filters to avoid confusion
          _isSelectionMode = false;
          _selectedIds.clear();
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A8A) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(List<String> docIds, String collection) async {
    final count = docIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  size: 32,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Delete ${count > 1 ? "$count Messages" : "Message"}?',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to delete ${count > 1 ? "these items" : "this item"}? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        "Cancel",
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        "Delete",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        for (final id in docIds) {
          final docRef = FirebaseFirestore.instance
              .collection(collection)
              .doc(id);
          batch.delete(docRef);
        }
        await batch.commit();

        if (mounted) {
          setState(() {
            // Exit selection mode after successful delete
            _isSelectionMode = false;
            _selectedIds.clear();
          });

          // Success Dialog
          showDialog(
            context: context,
            barrierDismissible: false, // Prevent dismissing by tapping outside
            builder: (ctx) => Dialog(
              /* Similar beautiful styling for success, auto-dismiss possibly or just OK button */
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Deleted!',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$count messages removed.',
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );

          // Auto close success dialog after 1.5s
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted && Navigator.canPop(context)) {
              Navigator.of(
                context,
              ).pop(); // Close success dialog only (removed rootNavigator)
            }
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Widget _buildRecipientCard({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDBEAFE) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? Colors.blue.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFF4B5563),
              size: 28,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isSelected
                      ? const Color(0xFF3B82F6)
                      : const Color(0xFF1F2937),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2, // Allow text to wrap slightly if needed
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String label}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(
        color: const Color(0xFF6B7280),
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }
}
