import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sundayschool_app/firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminCreateAnimator extends StatefulWidget {
  const AdminCreateAnimator({super.key});

  @override
  State<AdminCreateAnimator> createState() => _AdminCreateAnimatorState();
}

class _AdminCreateAnimatorState extends State<AdminCreateAnimator> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController(); // Added phone controller
  final _addressController =
      TextEditingController(); // Added address controller
  bool _isLoading = false;
  bool _obscurePassword = true;

  String? _selectedParishId;
  String? _selectedParishName;

  Future<void> _createAnimator() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedParishId == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please select a parish')));
      }
      return;
    }

    setState(() => _isLoading = true);

    FirebaseApp? tempApp;
    try {
      tempApp = await Firebase.initializeApp(
        name: 'tempAnimatorCreationApp',
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);

      final userCredential = await tempAuth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = userCredential.user?.uid;

      if (uid != null) {
        final Map<String, dynamic> animatorData = {
          'email': _emailController.text.trim(),
          'name': _nameController.text.trim(),
          'phoneNumber': _phoneController.text.trim(), // Added phoneNumber
          'role': 'animator',
          'parishId': _selectedParishId,
          'parishName': _selectedParishName,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': FirebaseAuth.instance.currentUser?.uid,
        };

        if (_addressController.text.trim().isNotEmpty) {
          animatorData['address'] = _addressController.text.trim();
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(animatorData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Animator account created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      await tempApp?.delete();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.indigo.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          'Create Animator Account',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(color: Colors.grey.shade50),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Card(
              elevation: 8,
              shadowColor: Colors.indigo.withOpacity(0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 36.0,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_add_rounded,
                          size: 48,
                          color: Colors.indigo.shade900,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'New Animator Account',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Fill in the details below',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Name Field
                      TextFormField(
                        controller: _nameController,
                        style: GoogleFonts.inter(),
                        decoration: _buildInputDecoration(
                          'Animator Name',
                          Icons.person_outline_rounded,
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 20),

                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        style: GoogleFonts.inter(),
                        decoration: _buildInputDecoration(
                          'Email Address',
                          Icons.email_outlined,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v == null || !v.contains('@')
                            ? 'Invalid email address'
                            : null,
                      ),
                      const SizedBox(height: 20),

                      // Phone Number Field (Optional)
                      TextFormField(
                        controller: _phoneController,
                        style: GoogleFonts.inter(),
                        decoration: _buildInputDecoration(
                          'Phone Number (Optional)',
                          Icons.phone_outlined,
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 20),

                      // Parish Selection Dropdown
                      FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .where('role', isEqualTo: 'parish')
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (snapshot.hasError) {
                            return Text(
                              'Error loading parishes',
                              style: TextStyle(color: Colors.red.shade700),
                            );
                          }

                          final parishes = snapshot.data?.docs ?? [];

                          return DropdownButtonFormField<String>(
                            value: _selectedParishId,
                            decoration: _buildInputDecoration(
                              'Home Parish',
                              Icons.church_rounded,
                            ),
                            style: GoogleFonts.inter(
                              color: Colors.black87,
                              fontSize: 15,
                            ),
                            items: parishes.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final name =
                                  data['name'] ??
                                  data['parishName'] ??
                                  'Unnamed Parish';

                              return DropdownMenuItem(
                                value: doc.id,
                                child: Text(name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedParishId = value;
                                // Find the matching document to store the name
                                if (value != null) {
                                  final selectedDoc = parishes.firstWhere(
                                    (doc) => doc.id == value,
                                  );
                                  final data =
                                      selectedDoc.data()
                                          as Map<String, dynamic>;
                                  _selectedParishName =
                                      data['name'] ??
                                      data['parishName'] ??
                                      'Unnamed Parish';
                                }
                              });
                            },
                            validator: (v) =>
                                v == null ? 'Please select a parish' : null,
                            icon: Icon(
                              Icons.arrow_drop_down_circle_rounded,
                              color: Colors.blue.shade700,
                            ),
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Address Field (Optional)
                      TextFormField(
                        controller: _addressController,
                        style: GoogleFonts.inter(),
                        maxLines: 2,
                        decoration: _buildInputDecoration(
                          'Address (Optional)',
                          Icons.location_on_outlined,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        style: GoogleFonts.inter(),
                        decoration:
                            _buildInputDecoration(
                              'Password',
                              Icons.lock_outline_rounded,
                            ).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: Colors.blue.shade700,
                                ),
                                onPressed: () {
                                  setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  );
                                },
                              ),
                            ),
                        obscureText: _obscurePassword,
                        validator: (v) => v == null || v.length < 6
                            ? 'Minimum 6 characters required'
                            : null,
                      ),
                      const SizedBox(height: 32),

                      // Create Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade800,
                                Colors.blue.shade900,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.shade900.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _createAnimator,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 24,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'CREATE ACCOUNT',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(color: Colors.indigo.shade700),
      prefixIcon: Icon(icon, color: Colors.indigo.shade700),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.indigo.shade100),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.indigo.shade900, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
