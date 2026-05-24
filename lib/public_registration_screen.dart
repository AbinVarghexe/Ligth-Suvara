import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class PublicRegistrationScreen extends StatefulWidget {
  final String eventId;
  final String eventTitle;
  final String? regInfo;

  const PublicRegistrationScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    this.regInfo,
  });

  @override
  State<PublicRegistrationScreen> createState() =>
      _PublicRegistrationScreenState();
}

class _PublicRegistrationScreenState extends State<PublicRegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingProgram = true;
  List<CustomField> _fields = [];

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _boolValues = {};
  final Map<String, String> _selectValues = {};

  String _selectedCountryCode = '+91';
  final List<String> _countryCodes = [
    '+91', // India
    '+1', // USA/Canada
    '+44', // UK
    '+971', // UAE
    '+966', // Saudi Arabia
    '+965', // Kuwait
    '+968', // Oman
    '+974', // Qatar
    '+61', // Australia
    '+49', // Germany
    '+33', // France
    '+39', // Italy
    '+31', // Netherlands
    '+65', // Singapore
    '+60', // Malaysia
  ];

  AnimationController? _bgAnimationController;

  @override
  void initState() {
    super.initState();
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat(reverse: true);
    _fetchProgramFields();
  }

  @override
  void dispose() {
    _bgAnimationController?.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchProgramFields() async {
    setState(() => _isLoadingProgram = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('public_registration_programs')
          .doc(widget.eventId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['customFields'] != null) {
          final List<dynamic> fieldsData = data['customFields'];
          setState(() {
            _fields = fieldsData
                .map((f) => CustomField.fromMap(Map<String, dynamic>.from(f)))
                .where((f) => f.id != 'academicBackground')
                .toList();
          });
        }
      }

      if (_fields.isEmpty) {
        _fields = _getDefaultFields();
      }

      for (var field in _fields) {
        if (field.type == 'boolean') {
          _boolValues[field.id] = false;
        } else if (field.type == 'select') {
          if (field.options.isNotEmpty) {
            _selectValues[field.id] = field.options.first;
          } else {
            _selectValues[field.id] = '';
          }
        } else {
          _controllers[field.id] = TextEditingController();
        }
      }
    } catch (e) {
      debugPrint('Error fetching program fields: $e');
      setState(() {
        _fields = _getDefaultFields();
      });
      for (var field in _fields) {
        _controllers[field.id] = TextEditingController();
      }
    } finally {
      setState(() => _isLoadingProgram = false);
    }
  }

  List<CustomField> _getDefaultFields() {
    return [
      CustomField(id: "name", name: "Full Name", type: "text", isMandatory: true, options: []),
      CustomField(id: "phone", name: "Phone Number", type: "text", isMandatory: true, options: []),
      CustomField(id: "email", name: "Email Address", type: "text", isMandatory: false, options: []),
      CustomField(id: "qualification", name: "Educational Qualification", type: "text", isMandatory: false, options: []),
      CustomField(id: "currentStatus", name: "Current Status (Student / Working / Etc.)", type: "text", isMandatory: false, options: []),
      CustomField(id: "address", name: "Residential Address", type: "text", isMandatory: false, options: []),
    ];
  }

  Widget _buildAnimatedOrb({
    required Color color,
    required double size,
    required double left,
    required double top,
    required double dx,
    required double dy,
  }) {
    if (_bgAnimationController == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _bgAnimationController!,
      builder: (context, child) {
        return Positioned(
          left: left + (dx * _bgAnimationController!.value),
          top: top + (dy * _bgAnimationController!.value),
          child: Opacity(
            opacity: 0.12 + (0.04 * _bgAnimationController!.value),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [color, color.withOpacity(0.0)],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedBackground() {
    return Stack(
      children: [
        Container(color: const Color(0xFFFFFAF0)),
        _buildAnimatedOrb(
          color: const Color(0xFFFFDAB9),
          size: 400,
          left: -100,
          top: -100,
          dx: 40,
          dy: 30,
        ),
        _buildAnimatedOrb(
          color: const Color(0xFFB0E0E6),
          size: 500,
          left: 200,
          top: 400,
          dx: -50,
          dy: -40,
        ),
        _buildAnimatedOrb(
          color: const Color(0xFFFFF8DC),
          size: 300,
          left: -50,
          top: 600,
          dx: 30,
          dy: -20,
        ),
        Positioned.fill(child: Container(color: Colors.white.withOpacity(0.1))),
      ],
    );
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> regData = {
        'programId': widget.eventId,
        'programTitle': widget.eventTitle,
        'timestamp': FieldValue.serverTimestamp(),
      };

      final Map<String, dynamic> customFieldValues = {};

      for (var field in _fields) {
        dynamic value;
        if (field.type == 'boolean') {
          value = _boolValues[field.id] ?? false;
        } else if (field.type == 'select') {
          value = _selectValues[field.id] ?? '';
        } else {
          final textVal = _controllers[field.id]?.text.trim() ?? '';
          if (field.type == 'number') {
            value = num.tryParse(textVal) ?? textVal;
          } else {
            value = textVal;
          }
        }

        const predefinedKeys = {
          'name',
          'phone',
          'email',
          'qualification',
          'currentStatus',
          'academicBackground',
          'address'
        };

        if (predefinedKeys.contains(field.id)) {
          if (field.id == 'phone') {
            regData[field.id] = '$_selectedCountryCode$value';
          } else {
            regData[field.id] = value;
          }
        } else {
          customFieldValues[field.id] = value;
        }
      }

      if (customFieldValues.isNotEmpty) {
        regData['customFieldValues'] = customFieldValues;
      }

      await FirebaseFirestore.instance.collection('public_registrations').add(regData);
      if (mounted) _showSuccessDialog();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        backgroundColor: Colors.white.withOpacity(0.98),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 72,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Registration Successful!',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You have successfully registered for ${widget.eventTitle}. We will contact you soon.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 8,
                  shadowColor: const Color(0xFF1E3A8A).withOpacity(0.3),
                ),
                child: Text(
                  'Great!',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF0),
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 800),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutQuart,
                    builder: (context, value, child) => Transform.translate(
                      offset: Offset(0, 30 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Registration Form',
                                  style: GoogleFonts.outfit(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFBC8A3A),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        widget.eventTitle,
                                        style: GoogleFonts.outfit(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF1E3A8A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (widget.regInfo != null &&
                                    widget.regInfo!.isNotEmpty) ...[
                                  const SizedBox(height: 28),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.85),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: const Color(
                                            0xFFBC8A3A,
                                          ).withOpacity(0.3),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.05,
                                            ),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFBC8A3A,
                                                  ).withOpacity(0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.info_outline_rounded,
                                                  color: Color(0xFFBC8A3A),
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Program Information',
                                                style: GoogleFonts.outfit(
                                                  fontWeight: FontWeight.w800,
                                                  color: const Color(
                                                    0xFF0F172A,
                                                  ),
                                                  fontSize: 15,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFFBC8A3A,
                                              ).withOpacity(0.05),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: const Border(
                                                left: BorderSide(
                                                  color: Color(0xFFBC8A3A),
                                                  width: 4,
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              widget.regInfo!,
                                              style: GoogleFonts.outfit(
                                                fontSize: 14,
                                                color: const Color(0xFF334155),
                                                height: 1.6,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 36),
                                if (_isLoadingProgram)
                                  const Center(
                                    child: Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 40.0),
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF1E3A8A),
                                      ),
                                    ),
                                  )
                                else ...[
                                  ..._fields.map(
                                      (field) => _buildDynamicField(field)),
                                  const SizedBox(height: 12),
                                  _buildSubmitButton(),
                                ],
                                const SizedBox(height: 60),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.6),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF0F172A),
                size: 18,
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/suvara logo wbg6.png',
              height: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicField(CustomField field) {
    if (field.id == 'phone') {
      return _buildPhoneField(field);
    } else if (field.type == 'boolean') {
      return _buildBooleanToggleField(field);
    } else if (field.type == 'select') {
      return _buildDropdownField(field);
    } else {
      return _buildDynamicTextField(field);
    }
  }

  Widget _buildDynamicTextField(CustomField field) {
    final controller = _controllers[field.id] ?? TextEditingController();
    final isNumber = field.type == 'number';
    final isAddress = field.id == 'address';

    IconData icon = Icons.edit_note_rounded;
    if (field.id == 'name') {
      icon = Icons.person_outline_rounded;
    } else if (field.id == 'email') {
      icon = Icons.email_outlined;
    } else if (field.id == 'address') {
      icon = Icons.home_outlined;
    } else if (field.id == 'qualification' || field.id == 'academicBackground') {
      icon = Icons.school_outlined;
    } else if (field.id == 'currentStatus') {
      icon = Icons.work_outline_rounded;
    } else if (isNumber) {
      icon = Icons.numbers_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Text(
                  field.name,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
                if (field.isMandatory)
                  const Text(
                    ' *',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: TextFormField(
              controller: controller,
              maxLines: isAddress ? 3 : 1,
              keyboardType: isNumber
                  ? TextInputType.number
                  : (field.id == 'email' ? TextInputType.emailAddress : TextInputType.text),
              inputFormatters: isNumber
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w500,
                color: const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  icon,
                  color: const Color(0xFF1E3A8A),
                  size: 20,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: Color(0xFF1E3A8A),
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Colors.red, width: 1),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                hintText: 'Enter your ${field.name}',
                hintStyle: GoogleFonts.outfit(
                  fontSize: 14,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w400,
                ),
              ),
              validator: (v) {
                if (field.isMandatory && (v == null || v.trim().isEmpty)) {
                  return '${field.name} is required';
                }
                if (field.id == 'email' && v != null && v.trim().isNotEmpty && !v.contains('@')) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneField(CustomField field) {
    final controller = _controllers[field.id] ?? TextEditingController();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Text(
                  field.name,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
                if (field.isMandatory)
                  const Text(
                    ' *',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: _selectedCountryCode == '+91'
                  ? 10
                  : 15,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w500,
                color: const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                counterText: '',
                prefixIcon: Container(
                  width: 95,
                  margin: const EdgeInsets.only(right: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.phone_android_rounded,
                        color: Color(0xFF1E3A8A),
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCountryCode,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E3A8A),
                            ),
                            items: _countryCodes.map((code) {
                              return DropdownMenuItem(
                                value: code,
                                child: Text(code),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _selectedCountryCode = v);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: Color(0xFF1E3A8A),
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Colors.red, width: 1),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                hintText: 'Enter your phone number',
                hintStyle: GoogleFonts.outfit(
                  fontSize: 14,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w400,
                ),
              ),
              validator: (v) {
                if (field.isMandatory && (v == null || v.trim().isEmpty)) {
                  return 'Phone number is required';
                }
                if (v != null && v.trim().isNotEmpty) {
                  if (_selectedCountryCode == '+91') {
                    if (v.length != 10) {
                      return 'Indian phone numbers must be 10 digits';
                    }
                  } else {
                    if (v.length < 7) return 'Enter a valid phone number';
                  }
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBooleanToggleField(CustomField field) {
    bool currentValue = _boolValues[field.id] ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Text(
                  field.name,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
                if (field.isMandatory)
                  const Text(
                    ' *',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  value: currentValue,
                  activeColor: const Color(0xFF1E3A8A),
                  activeTrackColor: const Color(0xFF1E3A8A).withOpacity(0.2),
                  inactiveThumbColor: Colors.grey.shade400,
                  inactiveTrackColor: Colors.grey.shade200,
                  title: Text(
                    currentValue ? 'Yes' : 'No',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: currentValue ? const Color(0xFF1E3A8A) : const Color(0xFF64748B),
                      fontSize: 15,
                    ),
                  ),
                  secondary: const Icon(
                    Icons.rule_rounded,
                    color: Color(0xFF1E3A8A),
                    size: 20,
                  ),
                  onChanged: (bool value) {
                    setState(() {
                      _boolValues[field.id] = value;
                    });
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(CustomField field) {
    String currentValue = _selectValues[field.id] ?? '';
    List<String> options = field.options;

    if (options.isNotEmpty && !options.contains(currentValue)) {
      currentValue = options.first;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Text(
                  field.name,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
                if (field.isMandatory)
                  const Text(
                    ' *',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: DropdownButtonFormField<String>(
              value: currentValue.isEmpty && options.isNotEmpty ? options.first : currentValue,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(20),
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w500,
                color: const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.list_rounded,
                  color: Color(0xFF1E3A8A),
                  size: 20,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: Color(0xFF1E3A8A),
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Colors.red, width: 1),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
              ),
              items: options.map((option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _selectValues[field.id] = v;
                  });
                }
              },
              validator: (v) {
                if (field.isMandatory && (v == null || v.isEmpty)) {
                  return 'Please select ${field.name}';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitRegistration,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Complete Registration',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class CustomField {
  final String id;
  final String name;
  final String type;
  final bool isMandatory;
  final List<String> options;

  CustomField({
    required this.id,
    required this.name,
    required this.type,
    required this.isMandatory,
    required this.options,
  });

  factory CustomField.fromMap(Map<String, dynamic> map) {
    return CustomField(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      type: map['type']?.toString() ?? 'text',
      isMandatory: map['isMandatory'] == true,
      options: List<String>.from(map['options'] ?? []),
    );
  }
}
