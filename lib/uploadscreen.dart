import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sundayschool_app/custom_app_bar.dart'; // ⭐️ 1. IMPORT THE CUSTOM APPBAR

class UploadScreen extends StatefulWidget {
  final String? eventId;

  const UploadScreen({super.key, this.eventId});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  // All state variables and logic methods remain exactly the same.
  // No changes needed here.
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _placeController = TextEditingController();
  final _descriptionController = TextEditingController();

  File? _imageFile;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _existingImageUrl;

  bool get _isEditing => widget.eventId != null;
  bool _isLoading = false;

  // CORE CHANGE 1: Add category state
  String? _selectedCategory;
  final List<String> _categories = ['CML', 'SUVARA'];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadEventData();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _placeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadEventData() async {
    setState(() { _isLoading = true; });
    try {
      final doc = await FirebaseFirestore.instance.collection('events').doc(widget.eventId!).get();
      if (doc.exists) {
        final data = doc.data()!;
        _titleController.text = data['title'] ?? '';
        _placeController.text = data['place'] ?? '';
        _descriptionController.text = data['description'] ?? '';

        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final loadedDateTime = timestamp.toDate();
          _selectedDate = loadedDateTime;
          _selectedTime = TimeOfDay.fromDateTime(loadedDateTime);
        }

        _existingImageUrl = data['imageUrl'];
        // Load existing category for editing
        if (data['category'] != null && _categories.contains(data['category'])) {
          _selectedCategory = data['category'];
        }

        setState(() {});
      }
    } catch (e) {
      _showStatusDialog(context: context, isSuccess: false, title: "Load Failed", message: "Failed to load event data: $e");
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
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
      _showStatusDialog(context: context, isSuccess: false, title: "Image Error", message: "Failed to process the selected image.");
      return;
    }

    final compressedFile = File(compressedXFile.path);

    // CORE CHANGE: Add file size check (400 KB limit)
    const sizeLimitKB = 400;
    final fileSizeInKB = await compressedFile.length() / 1024;

    if (fileSizeInKB > sizeLimitKB) {
      if (!mounted) return;
      _showStatusDialog(
        context: context,
        isSuccess: false,
        title: "Image Too Large",
        message: "File size (${fileSizeInKB.toStringAsFixed(2)} KB) exceeds the ${sizeLimitKB}KB limit. Please choose a smaller image.",
      );
      return;
    }

    setState(() {
      _imageFile = compressedFile;
    });
  }

  Future<void> _pickDateAndTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue[900]!,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

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

  Future<void> _saveEvent() async {
    // CORE FIX: Removed the mandatory image check: (_imageFile == null && !_isEditing)
    if (!_formKey.currentState!.validate() ||
        _selectedDate == null ||
        _selectedTime == null ||
        _selectedCategory == null) {

      // Updated message to reflect that the image is optional
      _showStatusDialog(context: context, isSuccess: false, title: "Incomplete Form", message: "Please fill all fields (Title, Place, Date, Time, Category).");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null && !_isEditing) {
      _showStatusDialog(context: context, isSuccess: false, title: "Not Logged In", message: "You must be logged in to create an event.");
      return;
    }

    setState(() { _isLoading = true; });

    try {
      String? imageUrl = _existingImageUrl;

      // This block only runs IF an image file exists (either newly picked or being re-uploaded/re-checked)
      if (_imageFile != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storageRef = FirebaseStorage.instance.ref().child('event_images/$fileName');
        imageUrl = await storageRef.putFile(_imageFile!).then((task) => task.ref.getDownloadURL());
      }
      // If _imageFile is null (no new image picked) and _isEditing is true,
      // _existingImageUrl will be used, making the image optional.

      final finalDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final eventData = {
        'title': _titleController.text.trim(),
        'place': _placeController.text.trim(),
        'description': _descriptionController.text.trim(),
        'timestamp': Timestamp.fromDate(finalDateTime),
        'imageUrl': imageUrl,
        'title_lowercase': _titleController.text.trim().toLowerCase(),
        // CORE CHANGE 3: Include the selected category
        'category': _selectedCategory,
        if (!_isEditing) 'creatorId': user!.uid,
        // CORE CHANGE: Set isPublic to false for all new events (draft mode)
        if (!_isEditing) 'isPublic': false,
      };

      if (_isEditing) {
        await FirebaseFirestore.instance.collection('events').doc(widget.eventId!).update(eventData);
      } else {
        await FirebaseFirestore.instance.collection('events').add(eventData);
      }

      if (mounted) {
        _showStatusDialog(
          context: context,
          isSuccess: true,
          title: "Success!",
          message: "Event has been ${_isEditing ? 'updated' : 'created'} successfully.",
          onDismiss: () => Navigator.of(context).pop(true),
        );
      }
    } catch (e) {
      _showStatusDialog(context: context, isSuccess: false, title: "Operation Failed", message: "An error occurred: $e");
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  // --- UI BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.blue[900]!;

    // ⭐️ 2. USE A STANDARD SCAFFOLD AND A COLUMN LAYOUT ⭐️
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(), // Use the shared AppBar
      body: _isLoading && _isEditing && _imageFile == null
          ? Center(child: CircularProgressIndicator(color: themeColor))
      // The body is a Column to hold the title and the scrollable form
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⭐️ 3. ADD THE SCREEN-SPECIFIC TITLE HERE ⭐️
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text(
              _isEditing ? 'Edit Event' : 'Create New Event',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: themeColor,
              ),
            ),
          ),
          // Use Expanded to make the form fill the remaining space and be scrollable
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
                    // CORE CHANGE 4: Insert the category dropdown
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

  // CORE CHANGE 5: New method to build the category dropdown
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

  // --- HELPER WIDGETS ---
  // (The rest of the helper widgets are kept below as they are in the original code.)

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

  Widget _buildImagePicker(Color themeColor) {
    bool hasImage = _imageFile != null || (_existingImageUrl != null && _existingImageUrl!.isNotEmpty);
    ImageProvider? imageProvider;
    if (_imageFile != null) {
      imageProvider = FileImage(_imageFile!);
    } else if (hasImage) {
      imageProvider = NetworkImage(_existingImageUrl!);
    }

    return GestureDetector(
      onTap: _isLoading ? null : _pickImage,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: themeColor, width: 1.5),
          image: hasImage ? DecorationImage(image: imageProvider!, fit: BoxFit.cover) : null,
        ),
        child: !hasImage
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined, size: 40, color: themeColor),
              const SizedBox(height: 8),
              Text('Tap to add event image', style: GoogleFonts.poppins(color: themeColor, fontWeight: FontWeight.w500)),
            ],
          ),
        )
            : Align(
          alignment: Alignment.bottomRight,
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
            child: const Icon(Icons.edit, color: Colors.white, size: 20),
          ),
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
      onPressed: _isLoading ? null : _saveEvent,
      icon: _isLoading ? Container() : Icon(_isEditing ? Icons.check_circle_outline : Icons.add_task_rounded),
      label: _isLoading
          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
          : Text(_isEditing ? 'Update Event' : 'Create Event', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
    );
  }

  Future<void> _showStatusDialog({
    required BuildContext context,
    required bool isSuccess,
    required String title,
    required String message,
    VoidCallback? onDismiss,
  }) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        final color = isSuccess ? const Color(0xFF22C55E) : Colors.red;
        final icon = isSuccess ? Icons.check_circle_rounded : Icons.error_rounded;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 20),
              Text(title, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 15, color: Colors.black.withOpacity(0.7))),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text("OK", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        );
      },
    ).then((_) => onDismiss?.call());
  }
}
