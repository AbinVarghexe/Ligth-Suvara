// lib/edit_event_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:sundayschool_app/custom_app_bar.dart';
import 'package:flutter/cupertino.dart'; // Core: for modern picker
import 'package:sundayschool_app/utils/image_optimizer.dart';

class EditEventScreen extends StatefulWidget {
  final DocumentSnapshot eventDoc;

  const EditEventScreen({super.key, required this.eventDoc});

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _placeController;
  late TextEditingController _descriptionController;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  File? _newImageFile;
  String? _currentImageUrl;
  bool _isLoading = false;

  String? _selectedCategory;
  final List<String> _categories = ['cml', 'suvara'];

  // CORE CHANGE: Field to hold existing isPublic status
  bool _currentIsPublic = false;

  @override
  void initState() {
    super.initState();
    final data = widget.eventDoc.data() as Map<String, dynamic>? ?? {};

    _titleController = TextEditingController(text: data['title'] ?? '');
    _placeController = TextEditingController(text: data['place'] ?? '');
    _descriptionController = TextEditingController(
      text: data['description'] ?? '',
    );
    _currentImageUrl = data['imageUrl'];

    // CORE CHANGE: Load existing 'isPublic' status (defaults to false)
    _currentIsPublic = data['isPublic'] ?? false;

    if (data['timestamp'] is Timestamp) {
      final loadedDateTime = (data['timestamp'] as Timestamp).toDate();
      _selectedDate = loadedDateTime;
      _selectedTime = TimeOfDay.fromDateTime(loadedDateTime);
    }

    if (data['category'] != null && _categories.contains(data['category'])) {
      _selectedCategory = data['category'];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _placeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedImage = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedImage == null) return;

    setState(() => _isLoading = true);
    final compressedFile = await ImageOptimizer.compressBelowLimit(
      File(pickedImage.path),
      targetSizeKB: 400,
    );
    setState(() => _isLoading = false);

    if (compressedFile == null) {
      if (!mounted) return;
      _showStatusDialog(
        context: context,
        isSuccess: false,
        title: "Image Error",
        message: "Failed to process the selected image.",
      );
      return;
    }

    // 3. SET STATE WITH VALID COMPRESSED FILE
    setState(() {
      _newImageFile = compressedFile;
    });
  }

  Future<void> _pickDate() async {
    DateTime tempDate = _selectedDate ?? DateTime.now();
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          height: 350,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Select Date',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: tempDate,
                  minimumDate: DateTime(2020),
                  maximumDate: DateTime(2100),
                  onDateTimeChanged: (val) => tempDate = val,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _selectedDate = tempDate);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade900,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    'Confirm Date',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    DateTime tempTime = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime?.hour ?? now.hour,
      _selectedTime?.minute ?? now.minute,
    );

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          height: 350,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Select Time',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: tempTime,
                  use24hFormat: false,
                  onDateTimeChanged: (val) => tempTime = val,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedTime = TimeOfDay.fromDateTime(tempTime);
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade900,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    'Confirm Time',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateEvent() async {
    if (!_formKey.currentState!.validate() ||
        _selectedDate == null ||
        _selectedTime == null ||
        _selectedCategory == null) {
      _showStatusDialog(
        context: context,
        isSuccess: false,
        title: "Incomplete Form",
        message:
            "Please fill all fields, select a category, and choose a date and time.",
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? imageUrl = _currentImageUrl;

      if (_newImageFile != null) {
        // Since _newImageFile is already compressed and size-checked in _pickImage(), we upload it directly.
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storageRef = FirebaseStorage.instance.ref().child(
          'event_images/$fileName',
        );
        imageUrl = await storageRef
            .putFile(_newImageFile!)
            .then((task) => task.ref.getDownloadURL());
      }

      final finalDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final updatedData = {
        'title': _titleController.text.trim(),
        'place': _placeController.text.trim(),
        'description': _descriptionController.text.trim(),
        'timestamp': Timestamp.fromDate(finalDateTime),
        'imageUrl': imageUrl,
        'category': _selectedCategory,
        'title_lowercase': _titleController.text.trim().toLowerCase(),
        // CORE CHANGE: Preserve the original isPublic status
        'isPublic': _currentIsPublic,
      };

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventDoc.id)
          .update(updatedData);

      if (mounted) {
        _showStatusDialog(
          context: context,
          isSuccess: true,
          title: "Update Successful!",
          message: "The event has been updated successfully.",
          onDismiss: () => Navigator.of(context).pop(true),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showStatusDialog(
        context: context,
        isSuccess: false,
        title: "Update Failed",
        message: "An error occurred: $e",
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.blue[900]!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(), // Use the shared AppBar
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: themeColor))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Text(
                    'Edit Event',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildImagePicker(themeColor),
                          const SizedBox(height: 24),
                          _buildTextFormField(
                            controller: _titleController,
                            label: 'Event Title',
                            icon: Icons.title_rounded,
                            themeColor: themeColor,
                            validator: (v) =>
                                v!.isEmpty ? 'Title is required' : null,
                          ),
                          const SizedBox(height: 20),
                          _buildCategoryDropdown(themeColor),
                          const SizedBox(height: 20),
                          _buildTextFormField(
                            controller: _placeController,
                            label: 'Place / Venue',
                            icon: Icons.location_on_outlined,
                            themeColor: themeColor,
                            validator: (v) =>
                                v!.isEmpty ? 'Place is required' : null,
                          ),
                          const SizedBox(height: 20),
                          // CORE CHANGE 6: Modern Date/Time Picker
                          _buildModernDateTimePicker(themeColor),
                          const SizedBox(height: 20),
                          _buildTextFormField(
                            controller: _descriptionController,
                            label: 'Description',
                            icon: Icons.notes_rounded,
                            themeColor: themeColor,
                            maxLines: 5,
                            validator: (v) =>
                                v!.isEmpty ? 'Description is required' : null,
                          ),
                          const SizedBox(height: 40),
                          _buildSaveButton(themeColor),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildImagePicker(Color themeColor) {
    ImageProvider? newImageProvider = _newImageFile != null
        ? FileImage(_newImageFile!)
        : null;
    ImageProvider? currentImageProvider =
        _currentImageUrl != null && _currentImageUrl!.isNotEmpty
        ? NetworkImage(_currentImageUrl!)
        : null;
    ImageProvider? displayImage = newImageProvider ?? currentImageProvider;

    return GestureDetector(
      onTap: _isLoading ? null : _pickImage,
      child: Container(
        height: 180,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: themeColor, width: 1.5),
          image: displayImage != null
              ? DecorationImage(image: displayImage, fit: BoxFit.cover)
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (displayImage != null)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                ),
              ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  displayImage != null
                      ? Icons.edit
                      : Icons.add_a_photo_outlined,
                  color: displayImage != null ? Colors.white : themeColor,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  displayImage != null
                      ? 'Tap to Change Image'
                      : 'Tap to Select Image',
                  style: GoogleFonts.poppins(
                    color: displayImage != null ? Colors.white : themeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown(Color themeColor) {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      isExpanded: true,
      icon: Icon(Icons.expand_more_rounded, color: themeColor, size: 28),
      decoration: InputDecoration(
        labelText: 'Category',
        labelStyle: GoogleFonts.poppins(color: themeColor),
        prefixIcon: Icon(Icons.category_outlined, color: themeColor),
        filled: true,
        fillColor: Colors.blue.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: themeColor, width: 2),
        ),
      ),
      hint: Text('Select a category', style: GoogleFonts.poppins()),
      onChanged: _isLoading
          ? null
          : (String? newValue) {
              setState(() {
                _selectedCategory = newValue;
              });
            },
      validator: (value) => value == null ? 'Category is required' : null,
      items: _categories.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(
            value.toUpperCase(),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: themeColor,
            ),
          ),
        );
      }).toList(),
      dropdownColor: Colors.white,
    );
  }

  // CORE CHANGE 7: Modern Date/Time Picker Widgets
  Widget _buildModernDateTimePicker(Color themeColor) {
    return Row(
      children: [
        Expanded(
          child: _buildTimePickCard(
            label: 'Date',
            value: _selectedDate != null
                ? DateFormat('MMM dd, yyyy').format(_selectedDate!)
                : 'Select Date',
            icon: Icons.calendar_today_rounded,
            themeColor: themeColor,
            onTap: _pickDate,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTimePickCard(
            label: 'Time',
            value: _selectedTime?.format(context) ?? 'Select Time',
            icon: Icons.access_time_rounded,
            themeColor: themeColor,
            onTap: _pickTime,
          ),
        ),
      ],
    );
  }

  Widget _buildTimePickCard({
    required String label,
    required String value,
    required IconData icon,
    required Color themeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: themeColor.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: themeColor),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color themeColor,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.poppins(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: themeColor),
        prefixIcon: Icon(icon, color: themeColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: themeColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: themeColor, width: 2),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildSaveButton(Color themeColor) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _updateEvent,
      icon: _isLoading
          ? Container(
              width: 24,
              height: 24,
              padding: const EdgeInsets.all(2.0),
              child: const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            )
          : const Icon(Icons.check_circle_outline, color: Colors.white),
      label: Text(
        _isLoading ? 'Saving...' : 'Update Event',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: themeColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 5,
      ),
    );
  }

  void _showStatusDialog({
    required BuildContext context,
    required bool isSuccess,
    required String title,
    required String message,
    VoidCallback? onDismiss,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
              color: isSuccess ? Colors.green : Colors.red,
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
        content: Text(message, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onDismiss?.call();
            },
            child: Text(
              'OK',
              style: GoogleFonts.poppins(color: Colors.blue[900]),
            ),
          ),
        ],
      ),
    );
  }
}
