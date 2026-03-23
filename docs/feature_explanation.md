# Feature Explanation: Animators, Marks & Login Screen

This document explains the code and logic behind four core features of the Light Suvara Sunday School Management System:

1. [How Animators Are Created](#1-how-animators-are-created)
2. [How Animators Are Managed](#2-how-animators-are-managed)
3. [How Animators Are Assigned to Schools](#3-how-animators-are-assigned-to-schools)
4. [How Marks Are Viewed](#4-how-marks-are-viewed)
5. [How Events and Updates Are Shown on the Login Screen](#5-how-events-and-updates-are-shown-on-the-login-screen)

---

## 1. How Animators Are Created

**File:** `lib/admin/admin_create_animator.dart`

**Who can do this:** Only the Admin role.

### Overview

An Animator is a special user account with the `role: 'animator'` field in Firestore. The Admin creates animator accounts through a dedicated form screen. The key challenge is that creating a Firebase Auth user normally signs the creator out. To avoid this, the app uses a **temporary secondary Firebase app instance** to create the new user without affecting the currently-logged-in admin session.

### Step-by-Step Code Flow

#### Step 1 — Form Input

The form collects:

| Field | Controller | Required? |
|---|---|---|
| Animator Name | `_nameController` | Yes |
| Email Address | `_emailController` | Yes |
| Phone Number | `_phoneController` | Optional |
| Home Parish | Dropdown (`_selectedParishId`) | Yes |
| Address | `_addressController` | Optional |
| Password | `_passwordController` | Yes (min 6 chars) |

The parish dropdown is populated by a `FutureBuilder` that queries Firestore for all users with `role == 'parish'`:

```dart
// In admin_create_animator.dart — parish dropdown data source
FutureBuilder<QuerySnapshot>(
  future: FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'parish')
      .get(),
  builder: (context, snapshot) {
    final parishes = snapshot.data?.docs ?? [];
    return DropdownButtonFormField<String>(
      items: parishes.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return DropdownMenuItem(
          value: doc.id,
          child: Text(data['name'] ?? data['parishName'] ?? 'Unnamed Parish'),
        );
      }).toList(),
      onChanged: (value) {
        _selectedParishId = value;
        // also capture the parish name for display
      },
    );
  },
)
```

#### Step 2 — Temporary Firebase App for Safe User Creation

When the admin taps **CREATE ACCOUNT**, `_createAnimator()` runs:

```dart
// In admin_create_animator.dart — _createAnimator()
Future<void> _createAnimator() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  FirebaseApp? tempApp;
  try {
    // 1. Create an isolated secondary Firebase app instance.
    //    This means the new user account is created WITHOUT
    //    signing out the currently logged-in Admin.
    tempApp = await Firebase.initializeApp(
      name: 'tempAnimatorCreationApp',
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final tempAuth = FirebaseAuth.instanceFor(app: tempApp);

    // 2. Create the Firebase Auth account using the temporary instance
    final userCredential = await tempAuth.createUserWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    final uid = userCredential.user?.uid;

    if (uid != null) {
      // 3. Write the animator's profile document to Firestore
      //    using the NEW user's UID as the document ID.
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': _emailController.text.trim(),
        'name': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'role': 'animator',       // <-- This field controls the dashboard shown after login
        'parishId': _selectedParishId,
        'parishName': _selectedParishName,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser?.uid, // Admin's UID for audit
        // 'address' is added only if it was provided
      });
    }
  } on FirebaseAuthException catch (e) {
    // Show error (e.g., email already in use)
  } finally {
    // 4. ALWAYS delete the temporary app to release resources
    await tempApp?.delete();
    setState(() => _isLoading = false);
  }
}
```

#### Step 3 — Result in Firestore

After creation, the `users` collection contains a new document:

```
users/{newAnimatorUID}
  ├── email:       "animator@example.com"
  ├── name:        "John Animator"
  ├── phoneNumber: "9876543210"
  ├── role:        "animator"         ← drives login routing
  ├── parishId:    "parishDocId123"
  ├── parishName:  "Holy Trinity"
  ├── address:     "123 Church Road"
  ├── createdAt:   <serverTimestamp>
  └── createdBy:   "adminUID456"
```

When this animator logs in, `AuthWrapper` reads the `role` field and routes them to `AnimatorDashboardScreen`.

---

## 2. How Animators Are Managed

**File:** `lib/admin/admin_manage_animators.dart`

**Who can do this:** Only the Admin role.

### Overview

The Admin can view, search, edit, and delete animator accounts. All animators are listed from the `users` collection where `role == 'animator'`. Changes are written directly to Firestore.

### Real-Time List with Search

The animator list is rendered using a `StreamBuilder` that listens to the `users` collection filtered by role:

```dart
// In admin_manage_animators.dart — build()
StreamBuilder<QuerySnapshot>(
  stream: _firestore
      .collection('users')
      .where('role', isEqualTo: 'animator')
      .snapshots(), // Real-time updates
  builder: (context, snapshot) {
    final docs = snapshot.data?.docs ?? [];

    // Filter by search query
    final filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || email.contains(_searchQuery);
    }).toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final data = filtered[index].data() as Map<String, dynamic>;
        return _buildAnimatorCard(filtered[index].id, data);
      },
    );
  },
)
```

A `TextField` updates `_searchQuery` as the admin types, rebuilding the filter on each keystroke.

### Editing an Animator

Tapping the edit icon on an animator card opens an `AlertDialog` with pre-filled fields. The dialog allows updating:

- **Name** — `TextEditingController` pre-filled with `currentData['name']`
- **Phone Number** — pre-filled with `currentData['phoneNumber']`
- **Home Parish** — a Dropdown re-fetched from `users` where `role == 'parish'`
- **Address** — pre-filled with `currentData['address']`

```dart
// In admin_manage_animators.dart — _editAnimator()
Future<void> _editAnimator(String animatorId, Map<String, dynamic> currentData) async {
  // ... show dialog, collect updates ...
  final result = await showDialog<Map<String, dynamic>>(...);

  if (result != null) {
    // Write only the changed fields back to Firestore
    await _firestore.collection('users').doc(animatorId).update({
      'name': result['name'],
      'phoneNumber': result['phoneNumber'],
      'parishId': result['parishId'],
      'parishName': result['parishName'],
      'address': result['address'],
    });
  }
}
```

### Deleting an Animator

A confirmation dialog is shown before deletion. The document is removed from `users` using `.delete()`:

```dart
// In admin_manage_animators.dart — _deleteAnimator()
Future<void> _deleteAnimator(String animatorId) async {
  final confirmed = await showDialog<bool>(...); // Confirmation dialog
  if (confirmed == true) {
    await _firestore.collection('users').doc(animatorId).delete();
  }
}
```

> **Note:** This removes the Firestore profile document. The Firebase Auth account is **not** deleted automatically from the client side, as that requires the Admin SDK or re-authentication.

---

## 3. How Animators Are Assigned to Schools

**File:** `lib/admin/admin_assignment_manager.dart`

**Who can do this:** Only the Admin role.

### Overview

Assignments are stored in the `animator_assignments` Firestore collection. Each document's ID is the **Animator's UID**, and it contains an `assignments` array. Each element in the array represents one school assignment with a unique `unitId` for identification.

### Data Structure

```
animator_assignments/{animatorUID}
  └── assignments: [
        {
          unitId:       "a1b2c3d4",   // 8-char UUID (unique identifier for this link)
          schoolUserId: "schoolUID",   // UID of the school user
          schoolName:   "St. Paul's Sunday School",
          parish:       "Holy Trinity Parish",
          forane:       "North Forane",
          year:         "2026"
        },
        { ... second school ... }
      ]
```

### Initial Data Loading

On screen initialization, two calls are made:

```dart
// In admin_assignment_manager.dart — initState()
void initState() {
  super.initState();
  _fetchSchools();      // One-time load of all schools
  _listenToAssignments(); // Real-time listener to track which schools are already assigned
}
```

`_fetchSchools()` loads all users with `role == 'school'` (ordered alphabetically) to populate the school dropdown.

`_listenToAssignments()` builds a live map that tracks which schools are already assigned to which year, used for duplicate-assignment prevention:

```dart
// In admin_assignment_manager.dart — _listenToAssignments()
void _listenToAssignments() {
  _firestore.collection('animator_assignments').snapshots().listen((snapshot) {
    final assignedMap = <String, Set<String>>{}; // schoolId -> {years}

    for (var doc in snapshot.docs) {
      final list = (doc.data()['assignments'] as List<dynamic>?) ?? [];
      for (var item in list) {
        final schoolId = item['schoolUserId'] as String;
        final year = item['year'] as String;
        assignedMap.putIfAbsent(schoolId, () => {}).add(year);
      }
    }

    setState(() => _assignedSchoolsByYear = assignedMap);
  });
}
```

### Making an Assignment

The admin selects an Animator, a School, and a Year from three dropdowns, then taps **Assign**. The `_assignButton()` function validates and writes the assignment:

```dart
// In admin_assignment_manager.dart — _assignButton()
Future<void> _assignButton() async {
  // 1. Validate selections
  if (_selectedAnimatorId == null || _selectedSchoolId == null) { /* show error */ return; }

  // 2. Prevent duplicate: check if school is already assigned for this year
  final assignedYears = _assignedSchoolsByYear[_selectedSchoolId];
  if (assignedYears != null && assignedYears.contains(_selectedYear)) {
    // Show snackbar: "School already assigned for this year"
    return;
  }

  // 3. Build the new assignment object
  final schoolData = (_allSchools.firstWhere((d) => d.id == _selectedSchoolId))
      .data() as Map<String, dynamic>;

  final newAssignment = {
    'unitId':       const Uuid().v4().substring(0, 8), // Short unique ID
    'schoolUserId': _selectedSchoolId,
    'schoolName':   schoolData['schoolname'] ?? 'Unknown School',
    'parish':       schoolData['parish'] ?? 'Unknown Parish',
    'forane':       schoolData['forane'] ?? 'Unknown Forane',
    'year':         _selectedYear,
  };

  // 4. Use a Firestore transaction for atomic read-modify-write
  final docRef = _firestore.collection('animator_assignments').doc(_selectedAnimatorId);

  await _firestore.runTransaction((transaction) async {
    final snapshot = await transaction.get(docRef);
    List<dynamic> assignments = snapshot.exists
        ? (snapshot.data()?['assignments'] ?? [])
        : [];

    // 5. Enforce max 7 schools per animator
    if (assignments.length >= 7) {
      throw Exception('Animator already has 7 schools assigned.');
    }

    assignments.add(newAssignment);

    // 6. Write back — merge: true preserves any other fields on the document
    transaction.set(docRef, {'assignments': assignments}, SetOptions(merge: true));
  });
}
```

**Why a Firestore Transaction?** Transactions perform an atomic read-then-write. If another admin assigns a school at the same time, the transaction retries automatically, preventing race conditions.

### Removing an Assignment

```dart
// In admin_assignment_manager.dart — _removeAssignment()
Future<void> _removeAssignment(String animatorId, Map<String, dynamic> assignment) async {
  final docRef = _firestore.collection('animator_assignments').doc(animatorId);

  await _firestore.runTransaction((transaction) async {
    final snapshot = await transaction.get(docRef);
    List<dynamic> assignments = snapshot.data()?['assignments'] ?? [];

    // Remove by matching the unique unitId
    assignments.removeWhere((a) => a['unitId'] == assignment['unitId']);

    transaction.update(docRef, {'assignments': assignments});
  });
}
```

### Editing an Assignment (Changing the School)

```dart
// In admin_assignment_manager.dart — _replaceAssignment()
Future<void> _replaceAssignment(
    String animatorId, Map<String, dynamic> oldAssignment, String newSchoolId) async {
  final docRef = _firestore.collection('animator_assignments').doc(animatorId);

  await _firestore.runTransaction((transaction) async {
    final snapshot = await transaction.get(docRef);
    List<dynamic> assignments = snapshot.data()?['assignments'] ?? [];

    // Remove the old entry by its unique unitId
    assignments.removeWhere((a) => a['unitId'] == oldAssignment['unitId']);

    // Add updated entry — generates a NEW unitId for the changed link
    final schoolData = (_allSchools.firstWhere((d) => d.id == newSchoolId))
        .data() as Map<String, dynamic>;

    assignments.add({
      'unitId':       const Uuid().v4().substring(0, 8),
      'schoolUserId': newSchoolId,
      'schoolName':   schoolData['schoolname'] ?? 'Unknown School',
      'parish':       schoolData['parish'] ?? 'Unknown Parish',
      'forane':       schoolData['forane'] ?? 'Unknown Forane',
      'year':         oldAssignment['year'], // Keep the original year
    });

    transaction.update(docRef, {'assignments': assignments});
  });
}
```

### How the Animator Sees Their Assignments

In `lib/animator/animator_dashboard_screen.dart`, the animator's dashboard uses a `StreamBuilder` that listens to their own document in `animator_assignments`:

```dart
// In animator_dashboard_screen.dart
StreamBuilder<DocumentSnapshot>(
  stream: FirebaseFirestore.instance
      .collection('animator_assignments')
      .doc(user.uid)           // Listen to this specific animator's document
      .snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const CircularProgressIndicator();

    final data = snapshot.data!.data() as Map<String, dynamic>?;
    final assignments = (data?['assignments'] as List<dynamic>?) ?? [];

    // Render a card for each assigned school
    return ListView.builder(
      itemCount: assignments.length,
      itemBuilder: (context, index) {
        final assignment = assignments[index] as Map<String, dynamic>;
        return _buildAssignmentCard(assignment); // Shows school name, parish, year
      },
    );
  },
)
```

Tapping an assignment card navigates to `MarkEntryScreen` with the relevant IDs.

---

## 4. How Marks Are Viewed

Marks flow through two screens: entry by the Animator and review by the Admin.

### 4a. Mark Entry (Animator Side)

**File:** `lib/animator/mark_entry_screen.dart`

#### Initialization

The `MarkEntryScreen` receives these named parameters from the dashboard:

| Parameter | Description |
|---|---|
| `unitId` | The unique assignment identifier |
| `parish` | Parish name of the school |
| `sundaySchool` | School name |
| `schoolId` | Firebase UID of the school user |
| `assignmentYear` | Academic year (e.g., `'2026'`) |

The Firestore document ID for marks follows a deterministic pattern:

```dart
// In mark_entry_screen.dart — initState()
final year = widget.assignmentYear ?? DateTime.now().year.toString();
_currentYear = year;
_docId = '${widget.schoolId}_$year'; // e.g., "uid123_2026"
```

Using a deterministic ID means re-opening the screen always finds the same document, enabling **draft saves and re-editing before locking**.

#### Loading Questions and Existing Marks

```dart
// In mark_entry_screen.dart — _fetchData()
Future<void> _fetchData() async {
  // 1. Load the ordered question list from Firestore
  final questionsSnapshot = await _firestore
      .collection('questions')
      .orderBy('order')
      .get();
  _questions = questionsSnapshot.docs;

  // 2. Check for existing mark data (in case the animator saved a draft)
  final markDoc = await _firestore.collection('marks').doc(_docId).get();
  if (markDoc.exists) {
    final data = markDoc.data()!;
    _isLocked = data['locked'] ?? false;  // If true, form becomes read-only

    // Populate the marks map: {questionId: score}
    final savedMarks = data['marks'] as Map<String, dynamic>?;
    savedMarks?.forEach((key, value) {
      if (value is int) _marks[key] = value;
    });

    _pdfUrl = data['pdfUrl']; // Restore previously uploaded proof PDF
  }
}
```

#### Grouping Questions by Part

Questions are organized into Roman-numeral parts (Part I, Part II, … Part XX) using `_groupQuestionsByPart()`:

```dart
// In mark_entry_screen.dart — _groupQuestionsByPart()
Map<String, Map<String, dynamic>> _groupQuestionsByPart(List<QueryDocumentSnapshot> questions) {
  final grouped = <String, Map<String, dynamic>>{};
  for (var doc in questions) {
    final data = doc.data() as Map<String, dynamic>;
    final part = data['part']?.toString() ?? '';   // e.g., 'I', 'II', 'III'
    final partTitle = data['partTitle']?.toString() ?? '';

    grouped.putIfAbsent(part, () => {'title': partTitle, 'questions': <QueryDocumentSnapshot>[]});
    (grouped[part]!['questions'] as List).add(doc);
  }

  // Sort by Roman numeral order: I, II, III, IV, V, ...
  final partOrder = ['I','II','III','IV','V','VI','VII','VIII','IX','X', ...];
  final sortedKeys = grouped.keys.toList()
    ..sort((a, b) {
      int iA = partOrder.indexOf(a), iB = partOrder.indexOf(b);
      if (iA == -1 && iB == -1) return a.compareTo(b);
      if (iA == -1) return 1;
      if (iB == -1) return -1;
      return iA.compareTo(iB);
    });

  return {for (var k in sortedKeys) k: grouped[k]!};
}
```

#### Uploading a PDF Proof

Before submitting, the animator optionally uploads a PDF from their device:

```dart
// In mark_entry_screen.dart — _uploadPdf()
Future<void> _uploadPdf() async {
  // 1. Open the device file picker (PDF only)
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );

  if (result != null && result.files.isNotEmpty) {
    final fileName = result.files.first.name;

    // 2. Reference a unique path in Firebase Storage
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('marks_pdfs')
        .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

    // 3. Upload (supports both web bytes and mobile file paths)
    final uploadTask = result.files.first.bytes != null
        ? storageRef.putData(result.files.first.bytes!)
        : storageRef.putFile(File(result.files.first.path!));

    final snapshot = await uploadTask;

    // 4. Save the download URL for later use in Firestore
    _pdfUrl = await snapshot.ref.getDownloadURL();
  }
}
```

#### Submitting and Locking Marks

```dart
// In mark_entry_screen.dart — _submitMarks()
Future<void> _submitMarks() async {
  if (!_formKey.currentState!.validate()) return;

  await _firestore.collection('marks').doc(_docId).set({
    'unitId':      widget.unitId,
    'schoolId':    widget.schoolId,
    'parish':      widget.parish,
    'sundaySchool':widget.sundaySchool,
    'animatorId':  FirebaseAuth.instance.currentUser?.uid,
    'animatorName':_animatorName,
    'year':        _currentYear,
    'marks':       _marks,          // Map<String, int>  {questionId: score}
    'textValues':  _textValues,     // Map<String, String> for text-based fields
    'remarks':     _remarks,        // General text feedback
    'pdfUrl':      _pdfUrl,         // Download URL or null
    'locked':      true,            // <-- Prevents further edits once submitted
    'submittedAt': FieldValue.serverTimestamp(),
  });

  setState(() => _isLocked = true); // Make the form read-only in the UI
}
```

Once `locked: true`, the form renders all fields as read-only and the submit button is disabled.

---

### 4b. Admin Marks Viewer

**File:** `lib/admin/admin_marks_viewer.dart`

#### Loading Questions for Display

The Admin viewer pre-loads all questions into maps for fast lookup:

```dart
// In admin_marks_viewer.dart — _fetchQuestions()
Future<void> _fetchQuestions() async {
  final snapshot = await _firestore.collection('questions').orderBy('order').get();

  for (var doc in snapshot.docs) {
    final data = doc.data();
    _questionMap[doc.id]    = data['text'] ?? 'Unknown Question';  // ID → question text
    _maxMarkMap[doc.id]     = data['maxMark'];                      // ID → max score
    _partMap[doc.id]        = data['part']?.toString() ?? '';
    _partTitleMap[doc.id]   = data['partTitle']?.toString() ?? '';

    // Handle sub-fields (composite questions)
    if (data['subFields'] is List) {
      for (int i = 0; i < (data['subFields'] as List).length; i++) {
        final sub = (data['subFields'] as List)[i] as Map<String, dynamic>;
        final subId = '${doc.id}_sub_$i'; // e.g., "q1_sub_0", "q1_sub_1"
        _questionMap[subId] = sub['text'] ?? 'Unknown Sub-field';
        _maxMarkMap[subId]  = sub['maxMark'];
        _partMap[subId]     = data['part']?.toString() ?? '';
        _partTitleMap[subId]= data['partTitle']?.toString() ?? '';
      }
    }
  }
}
```

#### Year-Filtered Marks List

The main view uses a `StreamBuilder` filtered by the selected academic year:

```dart
// In admin_marks_viewer.dart — build()
StreamBuilder<QuerySnapshot>(
  stream: _firestore
      .collection('marks')
      .where('year', isEqualTo: _selectedYear)  // Year selector dropdown
      .snapshots(),
  builder: (context, snapshot) {
    final docs = snapshot.data?.docs ?? [];

    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;
        final marks = data['marks'] as Map<String, dynamic>? ?? {};
        final totalMarks = marks.values.fold(0, (sum, val) => sum + (val as int)); // Sum all question scores

        return Card(
          child: ListTile(
            title:    Text(data['sundaySchool'] ?? 'Unknown School'),
            subtitle: Text('${data['parish']} • Animator: ${data['animatorName']}'),
            trailing: Text('Total: $totalMarks'),
            onTap: () => _showMarksDialog(context, data, docs[index].id),
          ),
        );
      },
    );
  },
)
```

#### Detailed Marks Dialog

Tapping a card opens a dialog that shows every question grouped by part:

```dart
// In admin_marks_viewer.dart — _showMarksDialog()
void _showMarksDialog(BuildContext context, Map<String, dynamic> data, String docId) {
  final marks       = (data['marks'] as Map<String, dynamic>?) ?? {};
  final textValues  = (data['textValues'] as Map<String, dynamic>?) ?? {};
  final remarks     = data['remarks'] ?? '';
  final pdfUrl      = data['pdfUrl'];

  showDialog(
    context: context,
    builder: (context) {
      // Group marks by part using _partMap lookup
      // For each part:
      //   - Show part title (e.g., "Part I — Scripture")
      //   - For each question in the part:
      //     - Question text
      //     - Student's score / max score
      //     - Sub-fields if any
      // Show overall remarks
      // Show PDF download button if pdfUrl is not null
      // Show "Generate Report PDF" button
    },
  );
}
```

The PDF report is generated by `AdminMarksPdfGenerator`, which uses the `pdf` package to layout a printable document.

---

## 5. How Events and Updates Are Shown on the Login Screen

**Files:** `lib/login_screen.dart`, `lib/providers/content_provider.dart`

### Overview

The `LoginScreen` is the **public-facing entry point** of the app — no login is required to view it. It shows two live data feeds:

1. **Latest Updates** — from the `broadcasts` Firestore collection
2. **Recent Programs** — from the `events` Firestore collection (public events only)

Both feeds use `ContentProvider`, a `ChangeNotifier`-based state manager registered globally via `Provider`.

### ContentProvider — The Data Engine

`ContentProvider` (in `lib/providers/content_provider.dart`) maintains persistent Firestore stream subscriptions shared across the entire app. It is initialized once when the app starts (registered in `main.dart`).

```dart
// lib/providers/content_provider.dart
class ContentProvider with ChangeNotifier {
  List<QueryDocumentSnapshot> _broadcasts = [];  // Public announcements
  List<QueryDocumentSnapshot> _events = [];      // Public events

  bool _isLoadingBroadcasts = false;
  bool _isLoadingEvents = false;

  StreamSubscription? _broadcastSubscription;    // Persisted stream
  StreamSubscription? _eventSubscription;

  static const int _broadcastLimit = 10;
  static const int _eventLimit = 5;

  ContentProvider() {
    refreshContent(); // Start listening immediately on creation
  }

  void fetchBroadcasts() {
    if (_broadcastSubscription != null) return; // Already listening — skip

    _isLoadingBroadcasts = true;
    notifyListeners();

    _broadcastSubscription = FirebaseFirestore.instance
        .collection('broadcasts')
        .orderBy('timestamp', descending: true) // Newest first
        .limit(_broadcastLimit)                 // Cap at 10
        .snapshots()
        .listen((snapshot) {
          _broadcasts = snapshot.docs;
          _isLoadingBroadcasts = false;
          notifyListeners(); // Rebuild all widgets consuming this provider
        });
  }

  void fetchEvents() {
    if (_eventSubscription != null) return;

    _eventSubscription = FirebaseFirestore.instance
        .collection('events')
        .where('isPublic', isEqualTo: true)     // Only published events
        .orderBy('timestamp', descending: true)
        .limit(_eventLimit)                     // Cap at 5
        .snapshots()
        .listen((snapshot) {
          _events = snapshot.docs;
          _isLoadingEvents = false;
          notifyListeners();
        });
  }
}
```

**Key design choices:**
- **Persistent subscription** — subscribing once and caching avoids creating new Firestore listeners on every screen rebuild.
- **`notifyListeners()`** — all `Consumer<ContentProvider>` widgets rebuild automatically when data changes, providing real-time UI updates.

### The Login Screen Layout

```
LoginScreen (Scaffold)
├── AppBar
│   ├── Left:   Diocese logo
│   ├── Center: App logo
│   └── Right:  "Log In" button → AuthScreen
│
└── Body (scrollable)
    ├── Marquee ticker (_buildAnnouncementMarquee)
    ├── Side-by-side images (_buildTopImagesHeader)
    ├── "Latest Updates" carousel (_buildLatestUpdatesSection)
    ├── "Recent Programs" carousel (_buildRecentProgramsSection)
    └── Bottom navigation bar
        ├── Home
        ├── Resources → Bible, Catechism, Japamala popup
        └── Programs → ProgramsScreen
```

### Section 1 — Scrolling Announcement Marquee

A moving ticker bar reads a single Firestore document for urgent global messages:

```dart
// In login_screen.dart — _buildAnnouncementMarquee()
Widget _buildAnnouncementMarquee() {
  return StreamBuilder<DocumentSnapshot>(
    // Listens to a single well-known document path
    stream: FirebaseFirestore.instance
        .collection('announcements')
        .doc('global_message')
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData || !snapshot.data!.exists) {
        return const SizedBox.shrink(); // Hidden if no message set
      }

      final text = (snapshot.data!.data() as Map<String, dynamic>?)?['text']
          ?? 'Welcome to the Sunday School App!';

      return Marquee(             // Horizontally scrolling ticker
        text: text,
        velocity: 40.0,           // Scroll speed in pixels/second
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Colors.red.shade700,
        ),
      );
    },
  );
}
```

This section is **completely hidden** when the `global_message` document does not exist or has no `text` field.

### Section 2 — Latest Updates (Broadcasts Carousel)

```dart
// In login_screen.dart — _buildLatestUpdatesSection()
Widget _buildLatestUpdatesSection(BuildContext context) {
  // Consumer rebuilds this widget whenever ContentProvider calls notifyListeners()
  return Consumer<ContentProvider>(
    builder: (context, provider, child) {
      if (provider.isLoadingBroadcasts && provider.broadcasts.isEmpty) {
        // Show shimmer skeleton placeholders while loading
        return ShimmerLoadingPlaceholder();
      }

      if (provider.broadcasts.isEmpty) {
        return Text('No updates available.');
      }

      // Auto-playing horizontal carousel
      return CarouselSlider.builder(
        itemCount: provider.broadcasts.length,
        options: CarouselOptions(
          height: 110,
          autoPlay: true,
          viewportFraction: 0.9,          // Each card takes 90% of screen width
          autoPlayInterval: Duration(seconds: 4),
          enableInfiniteScroll: true,
        ),
        itemBuilder: (context, index, realIndex) {
          final data = provider.broadcasts[index].data() as Map<String, dynamic>;
          final title     = data['title'] ?? 'Update';
          final body      = data['body'] ?? '';
          final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
          final imageUrl  = data['imageUrl'] as String?;

          // Choose an icon based on keywords in the title
          final iconData = _getIconData(title);
          // "Lifeline" → red heart  |  "Kalolsavam" → purple celebration
          // "Rally"    → orange groups  |  default → blue event icon

          return _buildUpdateCard(
            context:  context,
            title:    title,
            date:     DateFormat('MMM d, yyyy').format(timestamp),
            iconData: iconData,
            imageUrl: imageUrl,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BroadcastDetailScreen(
                  message: BroadcastMessage(
                    id: provider.broadcasts[index].id,
                    title: title, body: body,
                    timestamp: timestamp, imageUrl: imageUrl,
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
```

**Icon selection logic** (`_getIconData` — called per broadcast card):

| Title contains | Icon | Color |
|---|---|---|
| "lifeline" | `Icons.favorite_rounded` | Red |
| "kalolsavam" | `Icons.celebration_rounded` | Purple |
| "rally" | `Icons.groups_rounded` | Orange |
| "meeting" | `Icons.event_rounded` | Teal |
| "important" / "urgent" | `Icons.priority_high_rounded` | Red |
| *(default)* | `Icons.campaign_rounded` | Blue |

### Section 3 — Recent Programs (Events Carousel)

```dart
// In login_screen.dart — _buildRecentProgramsSection()
Widget _buildRecentProgramsSection(BuildContext context) {
  return Consumer<ContentProvider>(
    builder: (context, provider, child) {
      if (provider.isLoadingEvents && provider.events.isEmpty) {
        return ShimmerLoadingPlaceholder();
      }

      // Auto-playing smaller cards, 2 visible at once
      return CarouselSlider.builder(
        itemCount: provider.events.length,
        options: CarouselOptions(
          height: 140,
          viewportFraction: 0.5,    // Show 2 cards side-by-side
          autoPlay: true,
          autoPlayInterval: Duration(seconds: 5),
          enableInfiniteScroll: true,
        ),
        itemBuilder: (context, index, realIndex) {
          final doc  = provider.events[index];
          final data = doc.data() as Map<String, dynamic>;

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              CustomPageRoute(child: EventDetailScreenFromHome(eventId: doc.id)),
            ),
            child: _buildProgramCard(
              data['imageUrl'],
              data['category'] ?? '',
            ),
          );
        },
      );
    },
  );
}
```

**Category-based gradient colors** (when no image is available):

| Category | Gradient Colors |
|---|---|
| `CML` | Deep violet to blue-purple |
| `SUVARA` | Golden amber to warm yellow |
| *(default)* | Blue 700 to Blue 900 |

### Section 4 — Bottom Navigation Bar

A sticky glassmorphism bar at the bottom provides navigation without requiring login:

```dart
// In login_screen.dart — bottom navigation
Row(
  children: [
    _buildBottomNavItem(Icons.home_rounded,        'Home',      0),
    _buildBottomNavItem(Icons.grid_view_rounded,   'Resources', 1),
    _buildBottomNavItem(Icons.calendar_month_rounded,'Programs', 2),
  ],
)
```

- **Home** — stays on the login screen
- **Resources** — opens a bottom-sheet popup with animated menu items:
  - Bible Reader (`BibleScreen`)
  - Catechism (`CatechismScreen`)
  - Japamala Counter (`JapamalaScreen`)
  - "Yamaprarthanakal" (external app launch via `AppLauncher`)
- **Programs** — navigates to `ProgramsScreen` (active registration programs)

### Summary: Real-Time Update Flow

```
Firestore (broadcasts)          Firestore (events / isPublic=true)
       │                                   │
       ▼  .snapshots() listener            ▼  .snapshots() listener
ContentProvider._broadcasts    ContentProvider._events
       │  notifyListeners()                │  notifyListeners()
       ▼                                   ▼
Consumer<ContentProvider>       Consumer<ContentProvider>
  in LoginScreen                  in LoginScreen
  (_buildLatestUpdatesSection)    (_buildRecentProgramsSection)
       │                                   │
       ▼                                   ▼
 Carousel of broadcast cards     Carousel of event cards
 (auto-play, 4-second interval)  (auto-play, 5-second interval)
```

Any time an Admin publishes a new broadcast or event in Firestore, both carousels update automatically without requiring the user to refresh the screen.

---

## Quick Reference

| Feature | File | Key Function | Firestore Collection |
|---|---|---|---|
| Create Animator | `admin/admin_create_animator.dart` | `_createAnimator()` | `users` |
| Manage Animators | `admin/admin_manage_animators.dart` | `_editAnimator()`, `_deleteAnimator()` | `users` |
| Assign Animator | `admin/admin_assignment_manager.dart` | `_assignButton()` | `animator_assignments` |
| Remove Assignment | `admin/admin_assignment_manager.dart` | `_removeAssignment()` | `animator_assignments` |
| Enter Marks | `animator/mark_entry_screen.dart` | `_submitMarks()`, `_uploadPdf()` | `marks`, Storage |
| View Marks (Admin) | `admin/admin_marks_viewer.dart` | `_fetchQuestions()`, `_showMarksDialog()` | `marks`, `questions` |
| Broadcasts (Login) | `login_screen.dart`, `content_provider.dart` | `_buildLatestUpdatesSection()` | `broadcasts` |
| Events (Login) | `login_screen.dart`, `content_provider.dart` | `_buildRecentProgramsSection()` | `events` |
| Marquee Ticker | `login_screen.dart` | `_buildAnnouncementMarquee()` | `announcements` |
