import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
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
  List<String> _selectedSchoolIds = []; // Holds multiple IDs if type is 'specific'
  String _displaySelectionText = 'Public'; // Text shown on the 'Specific Parish' card

  bool _isSending = false;

  void _showFeedbackDialog(String title, String content, bool isError) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        title: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 10),
            Text(title,
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(content, style: GoogleFonts.poppins()),
        actions: <Widget>[
          TextButton(
            child: Text('Okay',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            onPressed: () => Navigator.of(ctx).pop(),
          )
        ],
      ),
    );
  }

  // --- 3. SEND LOGIC UPDATED FOR MULTIPLE RECIPIENTS ---
  Future<void> _sendNotification() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_audienceType == 'specific' && _selectedSchoolIds.isEmpty) {
       _showFeedbackDialog('Error', 'Please select at least one specific school.', true);
       return;
    }

    setState(() { _isSending = true; });

    try {
      final title = _titleController.text.trim();
      final body = _messageController.text.trim();
      final timestamp = FieldValue.serverTimestamp();

      WriteBatch batch = FirebaseFirestore.instance.batch();

      if (_audienceType == 'public') {
        // Send to broadcasts collection
        final broadcastRef = FirebaseFirestore.instance.collection('broadcasts').doc();
        batch.set(broadcastRef, {
          'title': title,
          'body': body,
          'timestamp': timestamp,
        });
      } else if (_audienceType == 'all') {
         // Send one notification marked for 'all'
        final notificationRef = FirebaseFirestore.instance.collection('notifications').doc();
         batch.set(notificationRef, {
          'title': title,
          'body': body,
          'timestamp': timestamp,
          'isBroadcast': true, // Use isBroadcast flag
          'recipientId': 'all',
          'isRead': false,
        });
      } else { // 'specific'
        // Send a separate notification for each selected school ID
        for (String schoolId in _selectedSchoolIds) {
          final notificationRef = FirebaseFirestore.instance.collection('notifications').doc();
          batch.set(notificationRef, {
            'title': title,
            'body': body,
            'timestamp': timestamp,
            'isBroadcast': false, // Private message
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
          successMessage = 'Notification sent to ${_selectedSchoolIds.length} school(s).';
        } else {
           successMessage = 'Notification sent to $_displaySelectionText.';
        }
        _showFeedbackDialog('Success!', successMessage, false);
        _formKey.currentState?.reset();
        _titleController.clear();
        _messageController.clear();
        setState(() {
          _audienceType = 'public';
          _selectedSchoolIds = [];
          _displaySelectionText = 'Public';
        });
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackDialog('Error',
            'Failed to send notification. Please try again. Error: $e', true);
      }
    } finally {
      if (mounted) {
        setState(() { _isSending = false; });
      }
    }
  }

  // --- 4. NAVIGATION TO MULTI-SELECTION SCREEN ---
  void _selectSpecificSchools() async {
    final List<String>? selectedIds = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (context) => const MultiSchoolSelectionScreen(),
      ),
    );

    if (selectedIds != null && mounted) {
      setState(() {
        _audienceType = 'specific';
        _selectedSchoolIds = selectedIds;
        // Update display text based on selection count
        if (selectedIds.isEmpty) {
          _displaySelectionText = 'Specific Parish'; // Revert label if none selected
        } else if (selectedIds.length == 1) {
          _displaySelectionText = '1 Parish Selected';
        } else {
          _displaySelectionText = '${selectedIds.length} Schools Selected';
        }
      });
    } else {
      // If user cancels and no schools were previously selected for 'specific'
       if (_audienceType == 'specific' && _selectedSchoolIds.isEmpty) {
         setState(() {
            _audienceType = 'public'; // Revert to default if nothing selected/confirmed
            _displaySelectionText = 'Public';
         });
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text('New Message',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: const Color(0xFF1E3A8A))),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E3A8A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
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

              // --- Audience Selection Cards ---
              Column(
                children: [
                  _buildRecipientCard(
                    icon: Icons.campaign_rounded,
                    label: 'Public',
                    isSelected: _audienceType == 'public',
                    onTap: () {
                      setState(() {
                        _audienceType = 'public';
                        _selectedSchoolIds = [];
                        _displaySelectionText = 'Public';
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  IntrinsicHeight( // Ensure cards in the row have same height
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch, // Make children fill height
                      children: [
                        Expanded(
                          child: _buildRecipientCard(
                            icon: Icons.public_rounded,
                            label: 'All Parishes',
                            isSelected: _audienceType == 'all',
                            onTap: () {
                              setState(() {
                                _audienceType = 'all';
                                _selectedSchoolIds = [];
                                _displaySelectionText = 'All Parishes';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildRecipientCard(
                            icon: Icons.location_city_rounded,
                            // --- 5. DYNAMIC LABEL ---
                            // Use _displaySelectionText for the label when 'specific' is active
                            label: _audienceType == 'specific'
                                   ? _displaySelectionText
                                   : 'Specific Parish',
                            isSelected: _audienceType == 'specific',
                            onTap: _selectSpecificSchools, // Navigate to multi-select
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
                decoration: _buildInputDecoration(label: 'Notification Title (Max 50 Chars)'),
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
              const SizedBox(height: 40),

              ElevatedButton.icon(
                onPressed: _isSending ? null : _sendNotification,
                icon: _isSending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Icon(Icons.send_rounded, size: 20),
                label: Text(
                  _isSending ? 'Sending...' : 'Publish Update',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
              color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
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
            Icon(icon,
                color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF4B5563),
                size: 28),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF1F2937),
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
      labelStyle: GoogleFonts.poppins(color: const Color(0xFF6B7280), fontWeight: FontWeight.w500),
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

