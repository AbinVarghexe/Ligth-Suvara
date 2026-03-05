import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:sundayschool_app/school_selection_screen.dart';

class AdminTeacherManagementScreen extends StatefulWidget {
  const AdminTeacherManagementScreen({super.key});

  @override
  State<AdminTeacherManagementScreen> createState() =>
      _AdminTeacherManagementScreenState();
}

class _AdminTeacherManagementScreenState
    extends State<AdminTeacherManagementScreen> {
  String? _selectedSchoolId;
  String? _selectedSchoolName;

  Future<void> _selectSchool() async {
    final selectedSchool = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SchoolSelectionScreen(
          enableBroadcast: false,
          excludeAssignedSchools: false,
        ),
      ),
    );

    if (selectedSchool != null) {
      setState(() {
        _selectedSchoolId = selectedSchool['id'];
        _selectedSchoolName = selectedSchool['name'];
      });
    }
  }

  Future<void> _showAddTeacherDialog() async {
    if (_selectedSchoolId == null) return;

    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final qualificationController = TextEditingController();
    final classesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String selectedAcademicYear = '2024-25';
    DateTime? selectedDob;
    File? pickedImage;
    bool isSubmitting = false;

    final List<String> academicYears = [
      '2023-24',
      '2024-25',
      '2025-26',
      '2026-27',
    ];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Add Teacher',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final image = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 70,
                          );
                          if (image != null) {
                            setState(() => pickedImage = File(image.path));
                          }
                        },
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.blue.shade50,
                          backgroundImage: pickedImage != null
                              ? FileImage(pickedImage!)
                              : null,
                          child: pickedImage == null
                              ? Icon(
                                  Icons.add_a_photo,
                                  color: Colors.blue.shade700,
                                  size: 30,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Teacher Name',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: phoneController,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: const Icon(Icons.phone),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (!RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          ).hasMatch(value)) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Date of Birth',
                          prefixIcon: const Icon(Icons.cake),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        controller: TextEditingController(
                          text: selectedDob == null
                              ? ''
                              : DateFormat('dd/MM/yyyy').format(selectedDob!),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime(1990),
                            firstDate: DateTime(1950),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => selectedDob = picked);
                          }
                        },
                        validator: (value) =>
                            selectedDob == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedAcademicYear,
                        decoration: InputDecoration(
                          labelText: 'Academic Year',
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: academicYears.map((year) {
                          return DropdownMenuItem(
                            value: year,
                            child: Text(year),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => selectedAcademicYear = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: classesController,
                        decoration: InputDecoration(
                          labelText: 'Assigned Classes',
                          prefixIcon: const Icon(Icons.class_),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: qualificationController,
                        decoration: InputDecoration(
                          labelText: 'Qualification',
                          prefixIcon: const Icon(Icons.school),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setState(() => isSubmitting = true);
                            try {
                              String? profileImageUrl;
                              if (pickedImage != null) {
                                final ref = FirebaseStorage.instance
                                    .ref()
                                    .child('teacher_profiles')
                                    .child(
                                      '${DateTime.now().millisecondsSinceEpoch}.jpg',
                                    );
                                await ref.putFile(pickedImage!);
                                profileImageUrl = await ref.getDownloadURL();
                              }

                              await FirebaseFirestore.instance
                                  .collection('teachers')
                                  .add({
                                    'name': nameController.text.trim(),
                                    'phone': phoneController.text.trim(),
                                    'email': emailController.text.trim(),
                                    'dob': selectedDob != null
                                        ? Timestamp.fromDate(selectedDob!)
                                        : null,
                                    'academicYear': selectedAcademicYear,
                                    'classes': classesController.text.trim(),
                                    'qualification': qualificationController
                                        .text
                                        .trim(),
                                    'profilePicture': profileImageUrl,
                                    'schoolId': _selectedSchoolId,
                                    'schoolName': _selectedSchoolName,
                                    'createdAt': FieldValue.serverTimestamp(),
                                  });
                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              setState(() => isSubmitting = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Add Teacher'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditTeacherDialog(
    String teacherId,
    Map<String, dynamic> data,
  ) async {
    final nameController = TextEditingController(text: data['name']);
    final phoneController = TextEditingController(text: data['phone']);
    final emailController = TextEditingController(text: data['email']);
    final qualificationController = TextEditingController(
      text: data['qualification'],
    );
    final classesController = TextEditingController(text: data['classes']);
    final formKey = GlobalKey<FormState>();

    String selectedAcademicYear = data['academicYear'] ?? '2024-25';
    DateTime? selectedDob = (data['dob'] as Timestamp?)?.toDate();
    File? pickedImage;
    bool isSubmitting = false;

    final List<String> academicYears = [
      '2023-24',
      '2024-25',
      '2025-26',
      '2026-27',
    ];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Edit Teacher',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final image = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 70,
                          );
                          if (image != null) {
                            setState(() => pickedImage = File(image.path));
                          }
                        },
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.blue.shade50,
                          backgroundImage: pickedImage != null
                              ? FileImage(pickedImage!)
                              : (data['profilePicture'] != null
                                        ? NetworkImage(data['profilePicture'])
                                        : null)
                                    as ImageProvider?,
                          child:
                              pickedImage == null &&
                                  data['profilePicture'] == null
                              ? Icon(
                                  Icons.add_a_photo,
                                  color: Colors.blue.shade700,
                                  size: 30,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Teacher Name',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: phoneController,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: const Icon(Icons.phone),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (!RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          ).hasMatch(value)) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Date of Birth',
                          prefixIcon: const Icon(Icons.cake),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        controller: TextEditingController(
                          text: selectedDob == null
                              ? ''
                              : DateFormat('dd/MM/yyyy').format(selectedDob!),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDob ?? DateTime(1990),
                            firstDate: DateTime(1950),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => selectedDob = picked);
                          }
                        },
                        validator: (value) =>
                            selectedDob == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedAcademicYear,
                        decoration: InputDecoration(
                          labelText: 'Academic Year',
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: academicYears.map((year) {
                          return DropdownMenuItem(
                            value: year,
                            child: Text(year),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => selectedAcademicYear = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: classesController,
                        decoration: InputDecoration(
                          labelText: 'Assigned Classes',
                          prefixIcon: const Icon(Icons.class_),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: qualificationController,
                        decoration: InputDecoration(
                          labelText: 'Qualification',
                          prefixIcon: const Icon(Icons.school),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setState(() => isSubmitting = true);
                            try {
                              String? profileImageUrl = data['profilePicture'];
                              if (pickedImage != null) {
                                final ref = FirebaseStorage.instance
                                    .ref()
                                    .child('teacher_profiles')
                                    .child(
                                      '${DateTime.now().millisecondsSinceEpoch}.jpg',
                                    );
                                await ref.putFile(pickedImage!);
                                profileImageUrl = await ref.getDownloadURL();
                              }

                              await FirebaseFirestore.instance
                                  .collection('teachers')
                                  .doc(teacherId)
                                  .update({
                                    'name': nameController.text.trim(),
                                    'phone': phoneController.text.trim(),
                                    'email': emailController.text.trim(),
                                    'dob': selectedDob != null
                                        ? Timestamp.fromDate(selectedDob!)
                                        : null,
                                    'academicYear': selectedAcademicYear,
                                    'classes': classesController.text.trim(),
                                    'qualification': qualificationController
                                        .text
                                        .trim(),
                                    'profilePicture': profileImageUrl,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });
                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              setState(() => isSubmitting = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteTeacher(String teacherId, String teacherName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Teacher',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text('Are you sure you want to delete $teacherName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('teachers')
            .doc(teacherId)
            .delete();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Teacher Management',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade600],
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      floatingActionButton: _selectedSchoolId != null
          ? FloatingActionButton.extended(
              onPressed: _showAddTeacherDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Teacher'),
              backgroundColor: Colors.blue.shade900,
              foregroundColor: Colors.white,
            )
          : null,
      body: Column(
        children: [
          // Glassmorphic Header for School Selection
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade900.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.school_rounded,
                        color: Colors.blue.shade700,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected School',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          Text(
                            _selectedSchoolName ?? 'None selected',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _selectSchool,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade900,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _selectedSchoolId == null ? 'Select' : 'Change',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: _selectedSchoolId == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.group_add_rounded,
                            size: 80,
                            color: Colors.blue.shade200,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Select a school to manage teachers',
                          style: GoogleFonts.poppins(
                            color: Colors.blue.shade900.withOpacity(0.5),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('teachers')
                        .where('schoolId', isEqualTo: _selectedSchoolId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      final docs = snapshot.data?.docs ?? [];

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_off_rounded,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No teachers found for this school.',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () =>
                                      _showEditTeacherDialog(doc.id, data),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Hero(
                                          tag: 'teacher-${doc.id}',
                                          child: Container(
                                            width: 60,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              color: Colors.blue.shade50,
                                              image:
                                                  data['profilePicture'] != null
                                                  ? DecorationImage(
                                                      image: NetworkImage(
                                                        data['profilePicture'],
                                                      ),
                                                      fit: BoxFit.cover,
                                                    )
                                                  : null,
                                            ),
                                            child:
                                                data['profilePicture'] == null
                                                ? Icon(
                                                    Icons.person,
                                                    color: Colors.blue.shade700,
                                                    size: 30,
                                                  )
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                data['name'] ?? 'Unknown',
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Colors.blue.shade900,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.phone_rounded,
                                                    size: 14,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    data['phone'] ?? 'No phone',
                                                    style: GoogleFonts.poppins(
                                                      color:
                                                          Colors.grey.shade600,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Wrap(
                                                spacing: 8,
                                                children: [
                                                  _buildInfoBadge(
                                                    'Classes: ${data['classes'] ?? 'N/A'}',
                                                    Colors.blue,
                                                  ),
                                                  _buildInfoBadge(
                                                    'Year: ${data['academicYear'] ?? 'N/A'}',
                                                    Colors.indigo,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                Icons.edit_rounded,
                                                color: Colors.blue.shade700,
                                                size: 20,
                                              ),
                                              onPressed: () =>
                                                  _showEditTeacherDialog(
                                                    doc.id,
                                                    data,
                                                  ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                color: Colors.redAccent,
                                                size: 20,
                                              ),
                                              onPressed: () => _deleteTeacher(
                                                doc.id,
                                                data['name'] ?? 'Teacher',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
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
      ),
    );
  }

  Widget _buildInfoBadge(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: color.shade700,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
