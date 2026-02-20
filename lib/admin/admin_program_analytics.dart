import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminProgramAnalytics extends StatefulWidget {
  const AdminProgramAnalytics({super.key});

  @override
  State<AdminProgramAnalytics> createState() => _AdminProgramAnalyticsState();
}

class _AdminProgramAnalyticsState extends State<AdminProgramAnalytics> {
  bool _isLoading = true;

  // Raw Data
  final List<Map<String, dynamic>> _allRegistrations = [];
  final Map<String, String> _programNames = {}; // ID -> Name

  // Filter State
  String _selectedProgramFilter = 'All'; // 'All' or specific Program Name

  // Computed Stats
  int _totalRegistrations = 0;
  Map<String, int> _programCounts = {}; // For performance list
  List<Map<String, dynamic>> _topSchools = [];

  @override
  void initState() {
    super.initState();
    _fetchAnalyticsData();
  }

  Future<void> _fetchAnalyticsData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch raw data (program_registrations)
      final registrationsSnapshot = await FirebaseFirestore.instance
          .collection('program_registrations')
          .get();

      final List<Map<String, dynamic>> rawData = [];
      for (var doc in registrationsSnapshot.docs) {
        final data = doc.data();
        final status = data['status']?.toString();
        // Filter valid statuses matches AdminSchoolRegistrations
        if (status != 'approved_parish' && status != 'locked') continue;
        rawData.add(data);
      }

      // 2. Extract unique program names for the filter
      final pNames = <String>{};
      for (var data in rawData) {
        final name = data['programName']?.toString();
        if (name != null && name.isNotEmpty) {
          pNames.add(name);
        }
      }

      if (mounted) {
        setState(() {
          _allRegistrations.clear();
          _allRegistrations.addAll(rawData);
          _programNames.clear();
          for (var name in pNames) {
            _programNames[name] = name;
          }

          _isLoading = false;
          _recalculateStats();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading analytics: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _recalculateStats() {
    int total = 0;
    final pCounts = <String, int>{};
    final sCounts = <String, int>{};
    final sNames = <String, String>{};

    for (var data in _allRegistrations) {
      final pName = data['programName']?.toString() ?? 'Unknown Program';

      // Apply Filter
      if (_selectedProgramFilter != 'All' && pName != _selectedProgramFilter) {
        continue;
      }

      final schoolId = data['schoolUserId']?.toString();
      final schoolName = data['schoolName']?.toString() ?? 'Unknown School';

      // Calculate how much this registration adds
      final isCountOnly = data['isCountOnly'] == true;
      final int countToAdd = isCountOnly
          ? (data['studentCount'] as int? ?? 1)
          : 1;

      // Count Program (if 'All', counts per program. If specific, only that program increments)
      pCounts[pName] = (pCounts[pName] ?? 0) + countToAdd;
      total += countToAdd;

      // Count School
      if (schoolId != null) {
        sCounts[schoolId] = (sCounts[schoolId] ?? 0) + countToAdd;
        if (schoolName != 'Unknown School') {
          sNames[schoolId] = schoolName;
        }
      }
    }

    // Process Top Schools
    final schoolList = sCounts.entries.map((e) {
      return {
        'id': e.key,
        'name': sNames[e.key] ?? 'Unknown School',
        'count': e.value,
      };
    }).toList();

    schoolList.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    setState(() {
      _totalRegistrations = total;
      _programCounts = pCounts;
      _topSchools = schoolList;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          'Program Analytics',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModernFilterDropdown(),
                  const SizedBox(height: 24),
                  _buildOverviewCard(),
                  const SizedBox(height: 24),
                  // Only show program performance if 'All' is selected, otherwise it's redundant (just one bar)
                  if (_selectedProgramFilter == 'All') ...[
                    _buildSectionTitle('Program Statistics'),
                    const SizedBox(height: 16),
                    _buildProgramPerformanceList(),
                    const SizedBox(height: 24),
                  ],
                  _buildSectionTitle('Top Registered Schools'),
                  const SizedBox(height: 16),
                  _buildLeaderboard(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildModernFilterDropdown() {
    final List<String> options = [
      'All',
      ..._programNames.keys.toList()..sort(),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedProgramFilter,
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.blue.shade700,
              size: 20,
            ),
          ),
          isExpanded: true,
          style: GoogleFonts.poppins(
            color: Colors.blue.shade900,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          borderRadius: BorderRadius.circular(16),
          dropdownColor: Colors.white,
          items: options.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Row(
                children: [
                  Icon(
                    value == 'All'
                        ? Icons.dashboard_rounded
                        : Icons.event_note_rounded,
                    size: 18,
                    color: value == _selectedProgramFilter
                        ? Colors.blue.shade700
                        : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 12),
                  Text(value),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedProgramFilter = newValue;
              });
              _recalculateStats();
            }
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade800,
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade800, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade300.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedProgramFilter == 'All'
                ? 'Total Registrations'
                : 'Registrations for $_selectedProgramFilter',
            style: GoogleFonts.poppins(
              color: Colors.blue.shade100,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _totalRegistrations.toString(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _selectedProgramFilter == 'All'
                  ? 'Across ${_programCounts.length} Programs'
                  : 'Selected Program',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramPerformanceList() {
    final sortedEntries = _programCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedEntries.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
      );
    }

    final maxCount = sortedEntries.isNotEmpty ? sortedEntries.first.value : 1;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedEntries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = sortedEntries[index];
        final name = entry.key; // Key is Name now
        final count = entry.value;
        final percentage = maxCount > 0 ? count / maxCount : 0.0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade100,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$count',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Stack(
                children: [
                  Container(
                    height: 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: percentage,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade400, Colors.blue.shade600],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeaderboard() {
    if (_topSchools.isEmpty) {
      return Center(
        child: Text(
          'No registrations found for this selection.',
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _topSchools.take(5).length, // Show top 5
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final school = _topSchools[index];
        final rank = index + 1;

        } else if (rank == 2) {
          badgeColor = const Color(0xFFC0C0C0);
        } else if (rank == 3) {
          badgeColor = const Color(0xFFCD7F32);
        } else {
          badgeColor = Colors.blue.shade100;
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: rank <= 3
                ? Border.all(color: badgeColor.withOpacity(0.5), width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: GoogleFonts.poppins(
                      color: rank <= 3 ? Colors.black87 : Colors.blue.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  school['name'],
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${school['count']} Reg',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
