import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // Added for HapticFeedback
import 'package:sundayschool_app/custom_app_bar.dart';
import 'package:flutter/cupertino.dart'; // Core: for modern picker
import 'package:sundayschool_app/utils/image_optimizer.dart';
import 'package:sundayschool_app/homescreen.dart';

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
    setState(() {
      _isLoading = true;
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId!)
          .get();
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

        // Load existing category — case-insensitive match so stored values
        // like 'cml' or 'CML' both map correctly to the dropdown entries.
        final storedCategory = data['category'] as String?;
        if (storedCategory != null) {
          final match = _categories.firstWhere(
            (c) => c.toLowerCase() == storedCategory.toLowerCase(),
            orElse: () => '',
          );
          if (match.isNotEmpty) _selectedCategory = match;
        }
      }
    } catch (e) {
      if (mounted) {
        _showStatusDialog(
          context: context,
          isSuccess: false,
          title: "Load Failed",
          message: "Failed to load event data: $e",
        );
      }
    } finally {
      // Single setState in finally ensures the form always renders with
      // all pre-filled values (including category) once loading is done.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

    setState(() {
      _imageFile = compressedFile;
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

  Future<void> _saveEvent() async {
    // CORE FIX: Removed the mandatory image check: (_imageFile == null && !_isEditing)
    if (!_formKey.currentState!.validate() ||
        _selectedDate == null ||
        _selectedTime == null ||
        _selectedCategory == null) {
      // Updated message to reflect that the image is optional
      _showStatusDialog(
        context: context,
        isSuccess: false,
        title: "Incomplete Form",
        message: "Please fill all fields (Title, Place, Date, Time, Category).",
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null && !_isEditing) {
      _showStatusDialog(
        context: context,
        isSuccess: false,
        title: "Not Logged In",
        message: "You must be logged in to create an event.",
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? imageUrl = _existingImageUrl;

      // This block only runs IF an image file exists (either newly picked or being re-uploaded/re-checked)
      if (_imageFile != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storageRef = FirebaseStorage.instance.ref().child(
          'event_images/$fileName',
        );
        imageUrl = await storageRef
            .putFile(_imageFile!)
            .then((task) => task.ref.getDownloadURL());
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

      // Fetch user profile to get 'forane'
      String? userForane;
      if (user != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          if (userDoc.exists) {
            userForane = userDoc.data()?['forane'];
          }
        } catch (e) {
          debugPrint('Error fetching user forane: $e');
        }
      }

      final Map<String, dynamic> eventData = {
        'title': _titleController.text.trim(),
        'place': _placeController.text.trim(),
        'description': _descriptionController.text.trim(),
        'timestamp': Timestamp.fromDate(finalDateTime),
        'imageUrl': imageUrl,
        'title_lowercase': _titleController.text.trim().toLowerCase(),
        'category': _selectedCategory,
        'forane': userForane,
        if (!_isEditing) 'creatorId': user!.uid,
        if (!_isEditing) 'isPublic': false,
        // createdAt is only written once at creation time
        if (!_isEditing) 'createdAt': FieldValue.serverTimestamp(),
        // updatedAt is refreshed on both create AND every subsequent edit
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId!)
            .update(eventData);
      } else {
        await FirebaseFirestore.instance.collection('events').add(eventData);
      }

      if (mounted) {
        _showStatusDialog(
          context: context,
          isSuccess: true,
          title: "Success!",
          message:
              "Event has been ${_isEditing ? 'updated' : 'created'} successfully.",
          onDismiss: () => Navigator.of(context).pop(true),
        );
      }
    } catch (e) {
      _showStatusDialog(
        context: context,
        isSuccess: false,
        title: "Operation Failed",
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
                            validator: (v) =>
                                v!.isEmpty ? 'Title is required' : null,
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

  // --- HELPER WIDGETS ---
  // (The rest of the helper widgets are kept below as they are in the original code.)

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

  Widget _buildImagePicker(Color themeColor) {
    bool hasImage =
        _imageFile != null ||
        (_existingImageUrl != null && _existingImageUrl!.isNotEmpty);
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
          gradient: !hasImage
              ? HomeScreen.getEventPlaceholderData(
                      _selectedCategory ?? '',
                    )['gradient']
                    as LinearGradient?
              : null,
          image: hasImage
              ? DecorationImage(image: imageProvider!, fit: BoxFit.cover)
              : null,
        ),
        child: !hasImage
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _selectedCategory != null
                          ? HomeScreen.getEventPlaceholderData(
                              _selectedCategory!,
                            )['icon']
                          : Icons.add_a_photo_outlined,
                      size: 40,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to add event image',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          const Shadow(
                            blurRadius: 4,
                            color: Colors.black26,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
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
      onPressed: _isLoading ? null : _saveEvent,
      icon: _isLoading
          ? Container()
          : Icon(
              _isEditing ? Icons.check_circle_outline : Icons.add_task_rounded,
            ),
      label: _isLoading
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              _isEditing ? 'Update Event' : 'Create Event',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
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
        final icon = isSuccess
            ? Icons.check_circle_rounded
            : Icons.error_rounded;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.black.withOpacity(0.7),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  "OK",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        );
      },
    ).then((_) => onDismiss?.call());
  }
}
