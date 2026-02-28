import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AdminThemeProgramsManager extends StatefulWidget {
  const AdminThemeProgramsManager({super.key});

  @override
  State<AdminThemeProgramsManager> createState() =>
      _AdminThemeProgramsManagerState();
}

class _AdminThemeProgramsManagerState extends State<AdminThemeProgramsManager> {
  final _yearController = TextEditingController();
  final _malayalamController = TextEditingController();
  final _englishController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _programs = [];

  // Available icons for programs
  final Map<String, IconData> _availableIcons = {
    'fire': FontAwesomeIcons.fire,
    'bookOpenReader': FontAwesomeIcons.bookOpenReader,
    'graduationCap': FontAwesomeIcons.graduationCap,
    'users': FontAwesomeIcons.users,
    'circleQuestion': FontAwesomeIcons.circleQuestion,
    'handsHoldingChild': FontAwesomeIcons.handsHoldingChild,
    'masksTheater': FontAwesomeIcons.masksTheater,
    'star': FontAwesomeIcons.star,
    'church': FontAwesomeIcons.church,
    'cross': FontAwesomeIcons.cross,
    'dove': FontAwesomeIcons.dove,
    'heart': FontAwesomeIcons.heart,
    'lightbulb': FontAwesomeIcons.lightbulb,
    'music': FontAwesomeIcons.music,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('theme_programs')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _yearController.text = data['themeYear'] ?? '2025-26';
        _malayalamController.text =
            data['themeMalayalam'] ?? '“നിത്യജീവനിലുള്ള പ്രത്യാശ”';
        _englishController.text =
            data['themeEnglish'] ?? 'Hope in Eternal Life';

        if (data['programs'] != null) {
          _programs = List<Map<String, dynamic>>.from(data['programs']);
        }
      } else {
        // Default values if no document exists
        _yearController.text = '2025-26';
        _malayalamController.text = '“നിത്യജീവനിലുള്ള പ്രത്യാശ”';
        _englishController.text = 'Hope in Eternal Life';
        _programs = [
          {
            'title': 'Uthanothsavam',
            'desc':
                'An integral and intensive 5-day formation for catechetical students.',
            'iconName': 'fire',
          },
          {
            'title': 'BTC & CTC Course',
            'desc': 'Catechists’ Training Course designed to equip teachers.',
            'iconName': 'bookOpenReader',
          },
        ];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveData() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('theme_programs')
          .set({
            'themeYear': _yearController.text.trim(),
            'themeMalayalam': _malayalamController.text.trim(),
            'themeEnglish': _englishController.text.trim(),
            'programs': _programs,
          }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving data: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showProgramDialog({int? index}) {
    final titleController = TextEditingController(
      text: index != null ? _programs[index]['title'] : '',
    );
    final descController = TextEditingController(
      text: index != null ? _programs[index]['desc'] : '',
    );
    String selectedIcon = index != null
        ? (_programs[index]['iconName'] ?? 'star')
        : 'star';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                index == null ? 'Add Program' : 'Edit Program',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Program Title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select Icon',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableIcons.keys.map((iconKey) {
                        final isSelected = selectedIcon == iconKey;
                        return InkWell(
                          onTap: () =>
                              setDialogState(() => selectedIcon = iconKey),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.blue.shade100
                                  : Colors.grey.shade100,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.blue.shade700
                                    : Colors.transparent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _availableIcons[iconKey],
                              color: isSelected
                                  ? Colors.blue.shade800
                                  : Colors.grey.shade600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade900,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    final newProgram = {
                      'title': titleController.text.trim(),
                      'desc': descController.text.trim(),
                      'iconName': selectedIcon,
                    };

                    setState(() {
                      if (index == null) {
                        _programs.add(newProgram);
                      } else {
                        _programs[index] = newProgram;
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Theme & Programs',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_rounded),
              onPressed: _saveData,
              tooltip: 'Save All Changes',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Theme of the Year',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _yearController,
              decoration: InputDecoration(
                labelText: 'Year (e.g., 2025-26)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _malayalamController,
              decoration: InputDecoration(
                labelText: 'Malayalam Theme',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _englishController,
              decoration: InputDecoration(
                labelText: 'English Theme',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 40),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Our Programs List',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle,
                    color: Colors.blue,
                    size: 30,
                  ),
                  onPressed: () => _showProgramDialog(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_programs.isEmpty)
              const Text('No programs added yet.')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _programs.length,
                itemBuilder: (context, index) {
                  final prog = _programs[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade50,
                        child: Icon(
                          _availableIcons[prog['iconName']] ??
                              FontAwesomeIcons.star,
                          color: Colors.blue.shade900,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        prog['title'] ?? '',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        prog['desc'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showProgramDialog(index: index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _programs.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
