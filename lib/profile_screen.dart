import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
// Import compression libraries
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _fullNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();

  String _schoolName = 'Loading...';
  String? _userDocId;
  String? _profileImageUrl;
  File? _newImageFile;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { _isLoading = false; });
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        _userDocId = userDoc.id;

        setState(() {
          _schoolName = data['schoolname'] ?? 'Not Set';
          _fullNameController.text = data['fullName'] ?? '';
          _phoneNumberController.text = data['phoneNumber'] ?? '';
          _profileImageUrl = data['profileImageUrl'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _schoolName = 'Profile Not Found';
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading profile: $e");
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _pickImage() async {
    final pickedImage = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        _newImageFile = File(pickedImage.path);
      });
    }
  }

  // CORE CHANGE 1: Function to compress the image file
  Future<File?> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    // Use the file path but ensure the extension is compatible (e.g., .jpg)
    final targetPath = p.join(tempDir.path, '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg');

    final compressedXFile = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 85, // Adjust quality for compression level (85 is good)
    );

    if (compressedXFile == null) {
      return null;
    }
    return File(compressedXFile.path);
  }

  Future<void> _updateProfile() async {
    if (_userDocId == null) return;

    setState(() { _isSaving = true; });

    try {
      String? updatedImageUrl = _profileImageUrl;

      // Variable to hold the file ready for upload
      File? uploadFile = _newImageFile;

      if (_newImageFile != null) {
        // CORE CHANGE 2: Compress the file before uploading
        final compressedFile = await _compressImage(_newImageFile!);

        if (compressedFile == null) {
          throw Exception("Failed to compress image.");
        }
        uploadFile = compressedFile;

        final storageRef = FirebaseStorage.instance.ref().child('profile_pictures/${_userDocId}');
        final uploadTask = await storageRef.putFile(uploadFile);
        updatedImageUrl = await uploadTask.ref.getDownloadURL();
      }

      // Basic validation for name and phone number
      if (_fullNameController.text.trim().isEmpty) {
        throw Exception("Full Name cannot be empty.");
      }


      await FirebaseFirestore.instance.collection('users').doc(_userDocId!).update({
        'fullName': _fullNameController.text.trim(),
        'phoneNumber': _phoneNumberController.text.trim(),
        'profileImageUrl': updatedImageUrl,
      });

      setState(() {
        _profileImageUrl = updatedImageUrl;
        _newImageFile = null;
      });

      if(mounted) {
        // CORE CHANGE 3: Use modern status dialog instead of Snackbar
        _showStatusDialog(
          context: context,
          isSuccess: true,
          title: "Success",
          message: "Your profile has been updated.",
        );
      }
    } catch (e) {
      if(mounted) {
        // CORE CHANGE 3: Use modern status dialog instead of Snackbar
        _showStatusDialog(
          context: context,
          isSuccess: false,
          title: "Error",
          message: "Update failed: ${e.toString().contains('Exception:') ? e.toString().split('Exception: ')[1] : 'Please check your inputs.'}",
        );
      }
    } finally {
      if(mounted) {
        setState(() { _isSaving = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor:Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1E40AF)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Profile',
          style: GoogleFonts.poppins(color: Colors.blue.shade900, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProfilePicture(),
            const SizedBox(height: 40),
            _buildTextField(label: 'Church Name', initialValue: _schoolName, readOnly: true),
            const SizedBox(height: 20),
            _buildTextField(label: 'Full Name', controller: _fullNameController),
            const SizedBox(height: 20),
            _buildTextField(label: 'Phone Number', controller: _phoneNumberController, keyboardType: TextInputType.phone),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isSaving ? null : _updateProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade900,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: _isSaving
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2,))
                  : Text('Update Profile', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // CORE CHANGE 4: Add the new Status Dialog widget
  Future<void> _showStatusDialog({
    required BuildContext context,
    required bool isSuccess,
    required String title,
    required String message,
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
    );
  }

  Widget _buildProfilePicture() {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Stack(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey.shade200,
              // CORE FIX: Set fallback to null when no URL is available.
              backgroundImage: _newImageFile != null
                  ? FileImage(_newImageFile!) as ImageProvider
                  : (_profileImageUrl != null
                  ? NetworkImage(_profileImageUrl!)
                  : null),
              // The child logic now correctly displays the Icon when backgroundImage is null.
              child: _profileImageUrl == null && _newImageFile == null
                  ? Icon(Icons.person, color: Colors.blue.shade900, size: 40)
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade900,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(6.0),
                  child: Icon(Icons.edit, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    TextEditingController? controller,
    String? initialValue,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.blue.shade900),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          readOnly: readOnly,
          keyboardType: keyboardType,
          style: GoogleFonts.poppins(color: readOnly ? Colors.blue[600] : Colors.blue[900]),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.blue.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}