// lib/edit_event_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
// Assuming you have this custom app bar
import 'package:sundayschool_app/custom_app_bar.dart';

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
    _descriptionController = TextEditingController(text: data['description'] ?? '');
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
    final pickedImage = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedImage == null) return;

    final tempDir = await getTemporaryDirectory();
    final targetPath = p.join(tempDir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');

    // 1. COMPRESS IMAGE
    final compressedXFile = await FlutterImageCompress.compressAndGetFile(
      pickedImage.path,
      targetPath,
      quality: 85,
    );

    if (compressedXFile == null) {
      if (!mounted) return;
      _showStatusDialog(context: context, isSuccess: false, title: "Image Error", message: "Failed to process the selected image.");
      return;
    }

    final compressedFile = File(compressedXFile.path);

    // 2. CHECK SIZE RESTRICTION (400 KB)
    const sizeLimitKB = 400;
    final fileSizeInKB = await compressedFile.length() / 1024;

    if (fileSizeInKB > sizeLimitKB) {
      if (!mounted) return;
      _showStatusDialog(
        context: context,
        isSuccess: false,
        title: "Image Too Large",
        message: "File size exceeds the ${sizeLimitKB}KB limit (Current: ${fileSizeInKB.toStringAsFixed(2)}KB). Please choose a smaller image.",
      );
      // Stop execution if file is too large
      return;
    }

    // 3. SET STATE WITH VALID COMPRESSED FILE
    setState(() {
      _newImageFile = compressedFile;
    });
  }

  Future<void> _pickDateAndTime() async {
    final themeColor = Colors.blue[900]!;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: themeColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (pickedTime == null) return;

    setState(() {
      _selectedDate = pickedDate;
      _selectedTime = pickedTime;
    });
  }

  Future<void> _updateEvent() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null || _selectedTime == null || _selectedCategory == null) {
      _showStatusDialog(
          context: context,
          isSuccess: false,
          title: "Incomplete Form",
          message: "Please fill all fields, select a category, and choose a date and time.");
      return;
    }

    setState(() { _isLoading = true; });

    try {
      String? imageUrl = _currentImageUrl;

      if (_newImageFile != null) {
        // Since _newImageFile is already compressed and size-checked in _pickImage(), we upload it directly.
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storageRef = FirebaseStorage.instance.ref().child('event_images/$fileName');
        imageUrl = await storageRef.putFile(_newImageFile!).then((task) => task.ref.getDownloadURL());
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

      await FirebaseFirestore.instance.collection('events').doc(widget.eventDoc.id).update(updatedData);

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
      _showStatusDialog(context: context, isSuccess: false, title: "Update Failed", message: "An error occurred: $e");
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.blue[900]!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(),
      body: Column(
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
                      validator: (v) => v!.isEmpty ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 20),
                    _buildCategoryDropdown(themeColor),
                    const SizedBox(height: 20),
                    _buildTextFormField(
                      controller: _placeController,
                      label: 'Place / Venue',
                      icon: Icons.location_on_outlined,
                      themeColor: themeColor,
                      validator: (v) => v!.isEmpty ? 'Place is required' : null,
                    ),
                    const SizedBox(height: 20),
                    _buildDateTimePickerTile(themeColor),
                    const SizedBox(height: 20),
                    _buildTextFormField(
                      controller: _descriptionController,
                      label: 'Description',
                      icon: Icons.notes_rounded,
                      themeColor: themeColor,
                      maxLines: 5,
                      validator: (v) => v!.isEmpty ? 'Description is required' : null,
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
    ImageProvider? newImageProvider = _newImageFile != null ? FileImage(_newImageFile!) : null;
    ImageProvider? currentImageProvider = _currentImageUrl != null && _currentImageUrl!.isNotEmpty ? NetworkImage(_currentImageUrl!) : null;
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
          image: displayImage != null ? DecorationImage(image: displayImage, fit: BoxFit.cover) : null,
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
                  displayImage != null ? Icons.edit : Icons.add_a_photo_outlined,
                  color: displayImage != null ? Colors.white : themeColor,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  displayImage != null ? 'Tap to Change Image' : 'Tap to Select Image',
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
      onChanged: _isLoading ? null : (String? newValue) {
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

  Widget _buildDateTimePickerTile(Color themeColor) {
    String displayText;
    if (_selectedDate == null) {
      displayText = 'Select Event Date & Time';
    } else {
      final formattedDate = DateFormat('MMM dd, yyyy').format(_selectedDate!);
      final formattedTime = _selectedTime?.format(context) ?? 'Time not set';
      displayText = '$formattedDate  •  $formattedTime';
    }

    return InkWell(
      onTap: _isLoading ? null : _pickDateAndTime,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: themeColor)),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined, color: themeColor),
            const SizedBox(width: 12),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  displayText,
                  style: GoogleFonts.poppins(fontSize: 16, color: _selectedDate == null ? themeColor.withOpacity(0.8) : Colors.black),
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: themeColor),
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
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: themeColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: themeColor, width: 2)),
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
        child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
      )
          : const Icon(Icons.check_circle_outline, color: Colors.white),
      label: Text(
        _isLoading ? 'Saving...' : 'Update Event',
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
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
              child: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
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
            child: Text('OK', style: GoogleFonts.poppins(color: Colors.blue[900])),
          ),
        ],
      ),
    );
  }
}
