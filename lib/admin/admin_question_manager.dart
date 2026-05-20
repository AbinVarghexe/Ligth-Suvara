import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminQuestionManager extends StatefulWidget {
  const AdminQuestionManager({super.key});

  @override
  State<AdminQuestionManager> createState() => _AdminQuestionManagerState();
}

class _AdminQuestionManagerState extends State<AdminQuestionManager> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _intToRoman(int number) {
    if (number <= 0) return number.toString();
    final Map<int, String> romanMap = {
      1000: 'M',
      900: 'CM',
      500: 'D',
      400: 'CD',
      100: 'C',
      90: 'XC',
      50: 'L',
      40: 'XL',
      10: 'X',
      9: 'IX',
      5: 'V',
      4: 'IV',
      1: 'I',
    };
    String result = '';
    romanMap.forEach((key, value) {
      while (number >= key) {
        result += value;
        number -= key;
      }
    });
    return result;
  }

  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _maxMarkController = TextEditingController();
  final TextEditingController _partTitleController =
      TextEditingController(); // New
  final List<Map<String, dynamic>> _subFields = [];
  bool _isReadOnly = false;

  bool _isLoading = false;
  bool _isMandatory = true;
  String _selectedPart = 'I'; // New
  final List<String> _parts = ['I', 'II', 'III', 'IV', 'V'];
  final Map<String, TextEditingController> _partTitleControllers = {};
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _availableDocIds.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.addAll(_availableDocIds);
        _isSelectionMode = true;
      }
    });
  }

  final List<String> _availableDocIds = [];

  Future<void> _bulkDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Bulk Delete'),
        content: Text(
          'Are you sure you want to delete ${_selectedIds.length} questions?',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final batch = _firestore.batch();
        for (var id in _selectedIds) {
          batch.delete(_firestore.collection('questions').doc(id));
        }
        await batch.commit();
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Questions deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _bulkToggleMandatory(bool mandatory) async {
    setState(() => _isLoading = true);
    try {
      final batch = _firestore.batch();
      for (var id in _selectedIds) {
        batch.update(_firestore.collection('questions').doc(id), {
          'isMandatory': mandatory,
        });
      }
      await batch.commit();
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated ${_selectedIds.length} questions')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _initializePartControllers() {
    for (var part in _parts) {
      if (!_partTitleControllers.containsKey(part)) {
        _partTitleControllers[part] = TextEditingController();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initializePartControllers();
    _fetchExistingPartTitles();
  }

  void _addPart() {
    setState(() {
      String nextPart = _intToRoman(_parts.length + 1);
      if (!_parts.contains(nextPart)) {
        _parts.add(nextPart);
        _partTitleControllers[nextPart] = TextEditingController();
      }
    });
  }

  Future<void> _fetchExistingPartTitles() async {
    try {
      final snapshot = await _firestore.collection('questions').get();
      bool changed = false;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final part = data['part']?.toString();
        final title = data['partTitle']?.toString();

        if (part != null) {
          if (!_parts.contains(part)) {
            _parts.add(part);
            _partTitleControllers[part] = TextEditingController();
            changed = true;
          }
          if (title != null && _partTitleControllers[part]!.text.isEmpty) {
            _partTitleControllers[part]!.text = title;
            if (part == _selectedPart) {
              _partTitleController.text = title;
            }
            changed = true;
          }
        }
      }
      if (changed) setState(() {});
    } catch (e) {
      debugPrint("Error fetching existing part titles: $e");
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _maxMarkController.dispose();
    _partTitleController.dispose();
    _partTitleControllers.forEach((_, controller) => controller.dispose());
    for (var field in _subFields) {
      field['text']?.dispose();
      field['maxMark']?.dispose();
    }
    super.dispose();
  }

  void _addSubField() {
    setState(() {
      _subFields.add({
        'text': TextEditingController(),
        'maxMark': TextEditingController(),
        'isReadOnly': false,
        'adminText': TextEditingController(),
      });
    });
  }

  void _removeSubField(int index) {
    setState(() {
      _subFields[index]['text']?.dispose();
      _subFields[index]['maxMark']?.dispose();
      _subFields.removeAt(index);
    });
  }

  Future<void> _addQuestion() async {
    if (_questionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter question text')),
      );
      return;
    }

    setState(() => _isLoading = true);
    setState(() => _isLoading = true);
    try {
      final int? maxMark = int.tryParse(_maxMarkController.text);

      final List<Map<String, dynamic>> subFieldsData = _subFields.map((field) {
        return {
          'text': (field['text'] as TextEditingController).text,
          'maxMark': int.tryParse(
            (field['maxMark'] as TextEditingController).text,
          ),
          'isReadOnly': field['isReadOnly'] as bool? ?? false,
          'adminText': (field['adminText'] as TextEditingController).text
              .trim(),
        };
      }).toList();

      final int count =
          (await _firestore.collection('questions').count().get()).count ?? 0;

      await _firestore.collection('questions').add({
        'text': _questionController.text,
        'maxMark': maxMark,
        'isMandatory': _isMandatory,
        'isReadOnly': _isReadOnly,
        'part': _selectedPart, // New
        'partTitle': _partTitleController.text, // New
        'order': count + 1,
        'subFields': subFieldsData,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _questionController.clear();
      _maxMarkController.clear();
      for (var field in _subFields) {
        field['text']?.dispose();
        field['maxMark']?.dispose();
      }
      _subFields.clear();
      setState(() {
        _isMandatory = true;
        _isReadOnly = false;
      });
      if (mounted) {
        await _showSuccessDialog('Question added successfully');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding question: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteQuestion(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this question?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        await _firestore.collection('questions').doc(id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Question deleted successfully'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting question: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isSelectionMode
                  ? [Colors.blue.shade800, Colors.blue.shade600]
                  : [Colors.blue.shade900, Colors.blue.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          _isSelectionMode
              ? '${_selectedIds.length} Selected'
              : 'Manage Questions',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            _isSelectionMode ? Icons.close : Icons.arrow_back_ios_new,
            color: Colors.white,
          ),
          onPressed: () {
            if (_isSelectionMode) {
              setState(() {
                _selectedIds.clear();
                _isSelectionMode = false;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  onPressed: () => _toggleSelectAll(),
                  tooltip: 'Select All',
                ),
                IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: () => _bulkToggleMandatory(true),
                  tooltip: 'Make Mandatory',
                ),
                IconButton(
                  icon: const Icon(Icons.radio_button_unchecked),
                  onPressed: () => _bulkToggleMandatory(false),
                  tooltip: 'Make Optional',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _bulkDelete,
                  tooltip: 'Delete Selected',
                ),
              ]
            : <Widget>[],
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(color: Colors.grey.shade50),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Part Configuration Card
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ExpansionTile(
                    title: Text(
                      'Configure Part Titles',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    leading: Icon(
                      Icons.settings_suggest_rounded,
                      color: Colors.blue.shade900,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            ..._parts.map((part) {
                              final controller = _partTitleControllers[part]!;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: TextField(
                                  controller: controller,
                                  decoration: _buildInputDecoration(
                                    'Title for Part $part',
                                    Icons.title_rounded,
                                  ),
                                  onChanged: (val) {
                                    if (_selectedPart == part) {
                                      _partTitleController.text = val;
                                    }
                                  },
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _addPart,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Add More Parts'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blue.shade900,
                                  side: BorderSide(color: Colors.blue.shade900),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Add Question Card
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Card(
                  elevation: 4,
                  shadowColor: Colors.blue.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white,
                      border: Border.all(color: Colors.blue.shade50, width: 1),
                    ),
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.add_circle_outline_rounded,
                                color: Colors.blue.shade900,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Add New Question',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _questionController,
                          maxLines: 3,
                          style: GoogleFonts.inter(),
                          decoration: _buildInputDecoration(
                            'Question Text',
                            Icons.help_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _maxMarkController,
                          style: GoogleFonts.inter(),
                          decoration: _buildInputDecoration(
                            'Max Marks',
                            Icons.grade_outlined,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: DropdownButtonFormField<String>(
                                value: _selectedPart,
                                isExpanded: true,
                                decoration: _buildInputDecoration(
                                  'Part',
                                ).copyWith(isDense: true),
                                style: GoogleFonts.inter(color: Colors.black),
                                items: _parts.map((part) {
                                  return DropdownMenuItem(
                                    value: part,
                                    child: Text('Part $part'),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedPart = value;
                                      _partTitleController.text =
                                          _partTitleControllers[value]?.text ??
                                          '';
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 6,
                              child: TextField(
                                controller: _partTitleController,
                                style: GoogleFonts.inter(),
                                decoration: _buildInputDecoration(
                                  'Part Title',
                                  Icons.title_rounded,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Mandatory',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Switch(
                                  value: _isMandatory,
                                  onChanged: (val) =>
                                      setState(() => _isMandatory = val),
                                  activeColor: Colors.blue.shade900,
                                ),
                              ],
                            ),
                            if (_subFields.isNotEmpty) ...[
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Filled By',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _buildSelectionButton(
                                          'Animator',
                                          !_isReadOnly,
                                          () => setState(
                                            () => _isReadOnly = false,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildSelectionButton(
                                          'Admin',
                                          _isReadOnly,
                                          () => setState(
                                            () => _isReadOnly = true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ] else
                              const Spacer(flex: 2),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Sub-fields section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Sub-fields (Optional)',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _addSubField,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Sub-field'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.blue.shade700,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_subFields.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _subFields.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: TextField(
                                            controller:
                                                _subFields[index]['text'],
                                            decoration:
                                                _buildInputDecoration(
                                                  'Sub-field Title',
                                                  Icons.label_outline,
                                                ).copyWith(
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 2,
                                          child: TextField(
                                            controller:
                                                _subFields[index]['maxMark'],
                                            keyboardType: TextInputType.number,
                                            decoration:
                                                _buildInputDecoration(
                                                  'Mark',
                                                  Icons.grade_outlined,
                                                ).copyWith(
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              _removeSubField(index),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _addQuestion,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade900,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                              shadowColor: Colors.blue.shade200,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.save_rounded,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Add Question',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Questions List Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      'All Questions',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Questions List
              StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('questions')
                    .orderBy('order')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: Colors.blue.shade900,
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;
                  _availableDocIds.clear();
                  _availableDocIds.addAll(docs.map((d) => d.id));

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 60,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No questions added yet',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final docId = docs[index].id;
                      final isSelected = _selectedIds.contains(docId);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: _isSelectionMode
                              ? () => _toggleSelection(docId)
                              : null,
                          onLongPress: () => _toggleSelection(docId),
                          child: Card(
                            elevation: isSelected ? 4 : 0,
                            color: isSelected
                                ? Colors.blue.shade50
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.blue.shade400
                                    : Colors.blue.shade50,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Stack(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.blue.shade900
                                          : Colors.blue.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 20,
                                            )
                                          : Text(
                                              '${index + 1}',
                                              style: GoogleFonts.poppins(
                                                color: Colors.blue.shade900,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                              title: Text(
                                data['text'] ?? '',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        if (data['maxMark'] != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Max Marks: ${data['maxMark']}',
                                              style: GoogleFonts.inter(
                                                color: Colors.grey.shade700,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: data['isMandatory'] == false
                                                ? Colors.orange.shade50
                                                : Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            data['isMandatory'] == false
                                                ? 'Optional'
                                                : 'Mandatory',
                                            style: GoogleFonts.inter(
                                              color:
                                                  data['isMandatory'] == false
                                                  ? Colors.orange.shade800
                                                  : Colors.blue.shade800,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        if (data['isReadOnly'] == true)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Admin Set: ${data['adminMark']}',
                                              style: GoogleFonts.inter(
                                                color: Colors.green.shade800,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (data['subFields'] != null &&
                                        (data['subFields'] as List)
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        'Sub-fields:',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      ...(data['subFields'] as List).map((sf) {
                                        final subField =
                                            sf as Map<String, dynamic>;
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            left: 8,
                                            bottom: 2,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.subdirectory_arrow_right,
                                                size: 14,
                                                color: Colors.grey.shade400,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  '${subField['text']} (${subField['maxMark']} marks)${subField['isReadOnly'] == true ? ' - Admin Set: ${subField['adminMark']}' : ''}',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color:
                                                        subField['isReadOnly'] ==
                                                            true
                                                        ? Colors.green.shade700
                                                        : Colors.grey.shade600,
                                                    fontWeight:
                                                        subField['isReadOnly'] ==
                                                            true
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                    const SizedBox(height: 8),
                                    if (data['part'] != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.indigo.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'Part ${data['part']}${data['partTitle'] != null && data['partTitle'].toString().isNotEmpty ? ': ${data['partTitle']}' : ''}',
                                          style: GoogleFonts.inter(
                                            color: Colors.indigo.shade800,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      color: Colors.blue.shade400,
                                      size: 20,
                                    ),
                                    tooltip: 'Edit',
                                    onPressed: () => _editQuestion(
                                      docs[index].id,
                                      data['text'] ?? '',
                                      data['maxMark']?.toString() ?? '',
                                      data['isMandatory'] ?? true,
                                      data['isReadOnly'] ?? false,
                                      data['adminMark']?.toString() ?? '0',
                                      data['part']?.toString() ?? 'I',
                                      data['partTitle']?.toString() ?? '',
                                      data['subFields'] != null
                                          ? List<Map<String, dynamic>>.from(
                                              data['subFields'],
                                            )
                                          : null,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red.shade300,
                                      size: 20,
                                    ),
                                    tooltip: 'Delete',
                                    onPressed: () =>
                                        _deleteQuestion(docs[index].id),
                                  ),
                                ],
                              ), // Row
                            ), // ListTile
                          ), // Card
                        ), // InkWell
                      ); // Padding
                    }, // itemBuilder
                  ); // ListView.builder
                }, // builder
              ), // StreamBuilder
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, [IconData? icon]) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.blue.shade700),
      prefixIcon: icon != null ? Icon(icon, color: Colors.blue.shade700) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade100),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade900, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  Future<void> _editQuestion(
    String docId,
    String currentText,
    String currentMaxMark,
    bool currentMandatory,
    bool currentReadOnly,
    String currentAdminText,
    String currentPart,
    String currentPartTitle,
    List<Map<String, dynamic>>? currentSubFields,
  ) async {
    final textController = TextEditingController(text: currentText);
    final maxMarkController = TextEditingController(text: currentMaxMark);
    final partTitleController = TextEditingController(text: currentPartTitle);
    String selectedPart = currentPart;
    final adminTextController = TextEditingController(text: currentAdminText);
    final List<Map<String, dynamic>> subFields = (currentSubFields ?? []).map((
      sf,
    ) {
      return {
        'text': TextEditingController(text: sf['text']?.toString() ?? ''),
        'maxMark': TextEditingController(text: sf['maxMark']?.toString() ?? ''),
        'adminText': TextEditingController(
          text: sf['adminText']?.toString() ?? '',
        ),
      };
    }).toList();
    bool isMandatory = currentMandatory;
    bool isReadOnly = currentReadOnly;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit_rounded, color: Colors.blue.shade900),
              const SizedBox(width: 8),
              Text(
                'Edit Question',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textController,
                  decoration: _buildInputDecoration(
                    'Question Text',
                    Icons.edit,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: maxMarkController,
                  decoration: _buildInputDecoration('Max Marks', Icons.grade),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: DropdownButtonFormField<String>(
                        value: selectedPart,
                        isExpanded: true,
                        decoration: _buildInputDecoration(
                          'Part',
                        ).copyWith(isDense: true),
                        style: GoogleFonts.inter(color: Colors.black),
                        items: _parts.map((part) {
                          return DropdownMenuItem(
                            value: part,
                            child: Text('Part $part'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => selectedPart = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: partTitleController,
                        style: GoogleFonts.inter(),
                        decoration: _buildInputDecoration(
                          'Part Title',
                          Icons.title_rounded,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Mandatory',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Switch(
                          value: isMandatory,
                          onChanged: (val) => setState(() => isMandatory = val),
                          activeColor: Colors.blue.shade900,
                        ),
                      ],
                    ),
                    if (subFields.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filled By',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildSelectionButton(
                                  'Animator',
                                  !isReadOnly,
                                  () => setState(() => isReadOnly = false),
                                ),
                                const SizedBox(width: 8),
                                _buildSelectionButton(
                                  'Admin',
                                  isReadOnly,
                                  () => setState(() => isReadOnly = true),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else
                      const Spacer(flex: 2),
                  ],
                ),

                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sub-fields',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        setState(() {
                          subFields.add({
                            'text': TextEditingController(),
                            'maxMark': TextEditingController(),
                          });
                        });
                      },
                      color: Colors.blue.shade700,
                    ),
                  ],
                ),
                ...subFields.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final sf = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: sf['text'],
                                decoration:
                                    _buildInputDecoration(
                                      'Title',
                                      Icons.label_outline,
                                    ).copyWith(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: sf['maxMark'],
                                keyboardType: TextInputType.number,
                                decoration:
                                    _buildInputDecoration(
                                      'Mark',
                                      Icons.grade_outlined,
                                    ).copyWith(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                    ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                setState(() {
                                  subFields[idx]['text']?.dispose();
                                  subFields[idx]['maxMark']?.dispose();
                                  subFields[idx]['adminText']?.dispose();
                                  subFields.removeAt(idx);
                                });
                              },
                            ),
                          ],
                        ),
                        if (isReadOnly) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: sf['adminText'],
                            decoration:
                                _buildInputDecoration(
                                  'Prefilled Text (Admin Set)',
                                  Icons.lock_outline,
                                ).copyWith(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                for (var sf in subFields) {
                  sf['text']?.dispose();
                  sf['maxMark']?.dispose();
                  sf['adminText']?.dispose();
                }
                adminTextController.dispose();
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (textController.text.isNotEmpty) {
                  try {
                    final List<Map<String, dynamic>> subFieldsDatas = subFields
                        .map((sf) {
                          return {
                            'text': (sf['text'] as TextEditingController).text,
                            'maxMark': int.tryParse(
                              (sf['maxMark'] as TextEditingController).text,
                            ),
                            'adminText':
                                (sf['adminText'] as TextEditingController).text
                                    .trim(),
                          };
                        })
                        .toList();

                    final int? parsedMark = int.tryParse(
                      maxMarkController.text,
                    );

                    await _firestore.collection('questions').doc(docId).update({
                      'text': textController.text,
                      'maxMark': parsedMark,
                      'isMandatory': isMandatory,
                      'isReadOnly': isReadOnly,
                      'adminText': adminTextController.text.trim(),
                      'part': selectedPart,
                      'partTitle': partTitleController.text,
                      'subFields': subFieldsDatas,
                    });

                    if (mounted) {
                      Navigator.pop(context);
                      await _showSuccessDialog('Question updated successfully');
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error updating question: $e')),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade900,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Update', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionButton(
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade900 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.blue.shade900 : Colors.grey.shade300,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSuccessDialog(String message) async {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
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
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 48,
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Success!',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Continue',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
