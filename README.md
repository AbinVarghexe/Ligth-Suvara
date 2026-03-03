<div align="center">
  <img src="assets/images/Logo.png" alt="Light Suvara Logo" width="200"/>
  
  # Light Suvara — Sunday School Management App
  
  ### 🙏 A Comprehensive Event, Program & Spiritual Resource Platform for Sunday Schools
  
  [![Flutter](https://img.shields.io/badge/Flutter-3.8.1-02569B?logo=flutter)](https://flutter.dev)
  [![Firebase](https://img.shields.io/badge/Firebase-Enabled-FFCA28?logo=firebase)](https://firebase.google.com)
  [![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green)]()
  [![License](https://img.shields.io/badge/License-Private-red)]()
</div>

---

## 📖 Overview

**Light Suvara** is a modern, feature-rich Flutter application designed to manage Sunday Schools under the **CML (Christian Mission League)** and **SUVARA** organizations. It provides a unified platform for administrators, parish coordinators, Sunday School units (schools), and animators (evaluators) to manage events, coordinate competitive program registrations, record marks, send notifications, and access spiritual resources.

### 🎯 Key Highlights

- **Multi-Role System**: Four distinct dashboards tailored for Admin, Parish, School, and Animator roles
- **Real-time Event Management**: Create, publish, and track events with live Firestore updates
- **Program Registration Workflow**: End-to-end registration pipeline — school submission → parish approval → admin oversight
- **Marks & Evaluation**: Animators record student marks per question set; PDFs are generated as proof
- **Push Notifications**: FCM-powered broadcasts and targeted per-role/per-user notifications
- **Spiritual Resources**: Bible reader, Catechism study materials, and Japamala (Rosary) counter
- **PDF Report Generation**: Downloadable reports for events and marks
- **Image Optimization**: Automatic JPEG compression for all uploaded images
- **Offline Support**: Firestore local caching for low-bandwidth scenarios

---

## 👥 User Roles & Dashboards

The app uses **role-based access control** stored in Firestore. Each user has a `role` field that determines which dashboard they see after login.

| Role | Dashboard | Primary Responsibilities |
|------|-----------|--------------------------|
| **admin** | Admin Dashboard | Full system control — manage events, programs, animators, parishes, schools, marks, and broadcasts |
| **parish** | Parish Dashboard | Approve/reject school registrations, view events, manage linked Sunday School |
| **school** | Home Screen | Browse events, submit program registrations, view spiritual resources |
| **animator** | Animator Dashboard | Enter student marks, upload PDF proofs, view assigned schools |

---

## ✨ Features

### 🏠 Home Screen (School Role)

- **Event Feed** with carousel slider for featured events
- **Filter & Search**: Filter by category (ALL, CML, SUVARA), search by title or description
- **Sort**: Newest first or alphabetically
- **Programs Panel**: View and register for active competitive programs
- **Spiritual Resources Quick Access**: Bible, Catechism, Japamala
- **Notification Bell** with unread badge

### 📅 Events

- Rich event detail view with images, date, location, and description
- Full-screen image viewer
- Events link to related notifications
- Admin can create, edit, delete, and toggle draft/public status
- Event images are auto-compressed before upload

### 📋 Program Registration Workflow

1. **Admin** creates a `Program` (with name, start/end date, active flag)
2. **School** submits student registrations (individual names or bulk count)
3. **Parish** reviews pending submissions — approves, rejects, or locks them
4. **Admin** has final oversight and can view all registrations and analytics

### 📊 Marks & Evaluation

- **Admin** manages a `Questions` schema (text, max marks, display order)
- **Admin** assigns Animators to Sunday Schools (`animator_assignments`)
- **Animator** enters marks per question for each assigned school
- **Animator** uploads a PDF proof document
- Once submitted, entries can be **locked** to prevent edits
- Admin can view all marks, generate a consolidated PDF report

### 📢 Notifications & Broadcasts

- **Broadcast** (public): Visible to all users including non-logged-in visitors
- **Targeted Notification**: Sent to a specific user UID or all users of a given role (e.g., `role_school`)
- **Read Receipts**: `readBy` array tracks which users have seen each notification
- Admin sends broadcasts via the Admin Notification screen; schools and parishes receive them in their notification feed

### 📖 Spiritual Resources

- **Bible**: Opens an interactive web-view-based Bible reader
- **Catechism**: Study materials and questions via web view
- **Japamala (Rosary)**: Interactive counter with haptic feedback for all 5 prayer groups

### 👤 User Profile

- View and edit profile image
- Display name, school affiliation, parish, forane
- Role-specific information

### 🔐 Authentication & Security

- **Firebase Authentication**: Email/password login
- **Firebase App Check**: Prevents abuse on Android (Play Integrity in release, debug in development)
- **Role-based routing**: `AuthWrapper` reads the Firestore `role` field to redirect to the correct dashboard
- **Firestore Security Rules**: Data access enforced at the backend

---

## 🏗️ Technical Architecture

### Built With

- **Framework**: Flutter 3.8.1+ / Dart SDK ≥3.8.1
- **Backend**: Firebase Suite
  - Firebase Authentication (email/password)
  - Cloud Firestore (real-time database)
  - Firebase Storage (images & PDFs)
  - Firebase Cloud Messaging / FCM (push notifications)
  - Firebase App Check (security)
- **State Management**: Provider (`ChangeNotifierProvider`)
  - `UserDataProvider` — current user profile & role
  - `ContentProvider` — shared content/event data
- **UI Components**: Material Design 3, Google Fonts

### Key Dependencies

```yaml
Firebase & Backend:
  - firebase_core: ^2.27.0
  - cloud_firestore: ^4.15.8
  - firebase_storage: ^11.6.9
  - firebase_auth: ^4.20.0
  - firebase_messaging: ^14.9.4
  - firebase_app_check: ^0.2.1+8

UI / UX:
  - google_fonts: ^6.2.1
  - carousel_slider: ^5.1.1
  - marquee: ^2.3.0
  - shimmer: ^3.0.0
  - lottie: ^3.1.0
  - loading_animation_widget: ^1.2.1
  - liquid_pull_to_refresh: ^3.0.1
  - font_awesome_flutter: ^10.0.0

Media & Files:
  - image_picker: ^1.0.7
  - flutter_image_compress: ^2.3.0
  - file_picker: ^8.0.7
  - pdf: ^3.10.0
  - printing: ^5.13.1
  - open_file: ^3.3.2

Platform & Utilities:
  - provider: ^6.1.2
  - shared_preferences: ^2.5.3
  - path_provider: ^2.1.5
  - path: ^1.9.1
  - url_launcher: ^6.3.2
  - webview_flutter: ^4.10.0
  - permission_handler: ^11.3.1
  - uuid: ^4.5.2
  - rxdart: ^0.27.7
  - collection: ^1.18.0
  - intl: ^0.18.1
  - flutter_native_splash: ^2.4.7
  - flutter_local_notifications: ^20.0.0
  - external_app_launcher: ^4.0.3
  - http: ^1.2.1
```

### Project Structure

```
lib/
├── main.dart                              # App entry point; Firebase & provider setup
├── auth_wrapper.dart                      # Role-based navigation after login
├── animated_splash_screen.dart            # Lottie-animated splash screen
├── firebase_options.dart                  # Generated Firebase configuration
├── firestore_service.dart                 # Shared Firestore helper methods
│
├── providers/                             # State management
│   ├── user_data_provider.dart            # Current user data & role flags
│   └── content_provider.dart             # Shared content/event state
│
├── services/
│   └── notification_service.dart         # FCM token registration & local notifications
│
├── screens (root-level):
│   ├── login_screen.dart                  # Email/password login
│   ├── auth_screen.dart                   # Auth gate
│   ├── homescreen.dart                    # School-role home screen
│   ├── home_events.dart                   # Event list widget for home
│   ├── event_detail_screen.dart           # Event details (admin context)
│   ├── event_detail_screen_from_home.dart # Event details (home context)
│   ├── uploadscreen.dart                  # Create new event
│   ├── edit_event_screen.dart             # Edit existing event
│   ├── admin_dashboard_screen.dart        # Admin main dashboard
│   ├── admin_notification_screen.dart     # Admin broadcast/notification sender
│   ├── notification_screen.dart           # User notification inbox
│   ├── broadcast_screen.dart              # Public broadcast feed
│   ├── profile_screen.dart                # User profile view/edit
│   ├── programs_screen.dart               # Program listing for schools
│   ├── school_selection_screen.dart       # School selector
│   ├── multi_school_selection.dart        # Multi-school picker
│   ├── privacy_policy_screen.dart         # Privacy policy
│   ├── bible.dart                         # Bible web-view reader
│   ├── catechism_screen.dart              # Catechism web-view reader
│   ├── japamala.dart                      # Rosary counter
│   ├── report_generator.dart              # PDF report generation helper
│   ├── custom_app_bar.dart                # Reusable app bar component
│   └── event_details_skelton.dart         # Shimmer loading skeleton
│
├── admin/                                 # Admin-only screens
│   ├── admin_all_events_screen.dart       # View/manage all events
│   ├── admin_animator_menu.dart           # Animator management menu
│   ├── admin_assignment_manager.dart      # Assign animators to schools
│   ├── admin_create_animator.dart         # Create animator accounts
│   ├── admin_create_parish_user.dart      # Create parish accounts
│   ├── admin_manage_animators.dart        # List & manage animators
│   ├── admin_marks_pdf_generator.dart     # Generate marks PDF report
│   ├── admin_marks_viewer.dart            # View all submitted marks
│   ├── admin_observer_management.dart     # Observer (evaluator) management
│   ├── admin_observer_remarks_view.dart   # View observer remarks
│   ├── admin_parish_menu.dart             # Parish management menu
│   ├── admin_program_analytics.dart       # Registration analytics
│   ├── admin_program_manager.dart         # Create/edit programs
│   ├── admin_program_menu.dart            # Programs management menu
│   ├── admin_question_manager.dart        # Manage marks question schema
│   ├── admin_registration_manager.dart    # View all registrations
│   ├── admin_school_menu.dart             # School management menu
│   ├── admin_school_registrations.dart    # Registrations per school
│   ├── admin_teacher_management.dart      # Teacher management
│   ├── admin_theme_programs_manager.dart  # Theme program management
│   ├── observer_remarks_login.dart        # Observer login gate
│   └── observer_remarks_screen.dart       # Observer remarks entry
│
├── animator/                              # Animator-role screens
│   ├── animator_dashboard_screen.dart     # Animator home dashboard
│   ├── animator_profile_screen.dart       # Animator profile
│   ├── mark_entry_screen.dart             # Enter marks per question
│   ├── registration_dashboard.dart        # Registration overview
│   ├── school_my_registrations_screen.dart# View school's registrations
│   └── student_registration_form.dart     # Student registration form
│
├── parish/                                # Parish-role screens
│   ├── parish_dashboard_screen.dart       # Parish home dashboard
│   └── parish_program_list_screen.dart    # Program list for parish
│
├── utils/                                 # Utility helpers
│   ├── app_launcher.dart                  # External app launcher helper
│   ├── downloads_helper.dart              # File download management
│   ├── image_optimizer.dart               # JPEG compression utility
│   ├── pdf_download_helper.dart           # PDF save & open helper
│   └── performance_utils.dart             # Performance optimization helpers
│
└── widgets/
    └── full_screen_image_viewer.dart      # Full-screen image overlay widget
```

---

## 📊 Firebase / Firestore Database Structure

See [`database_structure.md`](database_structure.md) for the full field-level reference. Summary:

| Collection | Purpose |
|---|---|
| `users` | User profiles with role (`admin`, `parish`, `school`, `animator`), FCM token, forane/parish info |
| `events` | School or admin-posted events with title, description, date, image, category, draft flag |
| `programs` | Competitive program definitions — name, registration dates, active flag |
| `program_registrations` | Student registrations with multi-step approval status (`pending_parish` → `approved_parish` → `locked` → `approved_admin`) |
| `notifications` | Targeted or role-based notifications with `readBy` receipt array |
| `broadcasts` | Public-facing announcements visible to all users |
| `animator_assignments` | Maps animators to assigned Sunday Schools (max 2/year) |
| `marks` | Mark entries per school per year, keyed by `{schoolId}_{year}` |
| `questions` | Mark entry schema (question text, max mark, display order) |

### Firebase Storage Paths

| Path | Contents |
|---|---|
| `event_images/` | Optimized JPEG images for events |
| `broadcast_images/` | Banner images for broadcasts and notifications |
| `marks_pdfs/` | Student result proof PDFs uploaded by animators |
| `user_profiles/` | User and school profile pictures |

---

## 🔧 Key Feature Implementations

### 1. Image Optimization
All uploaded images are automatically compressed before saving to Firebase Storage:
- Target maximum size: 500 KB
- Quality: 85%
- Output format: JPEG

### 2. Event Filtering & Search
- Filter by school category: CML, SUVARA, or ALL
- Full-text search on `title_lowercase` field
- Sort by newest-first or alphabetically

### 3. Program Registration Pipeline
- Schools submit individual student entries or bulk counts
- Parish admins approve or reject submissions; "lock" finalizes a batch
- Admin has a final approval step and analytics view

### 4. Marks Workflow
- Admin defines a question schema with max marks per question
- Admin assigns animators to schools via `animator_assignments`
- Animators complete mark entries and upload a PDF proof
- Entries are locked after final submission; admin generates a consolidated PDF report

### 5. Notification System
- FCM tokens are saved on login via `NotificationService`
- Local notifications are dispatched for foreground messages
- Read receipts (`readBy` array) track per-user read status
- Broadcasts use a separate public collection for non-authenticated viewers

### 6. PDF Generation
- `report_generator.dart` and `admin_marks_pdf_generator.dart` use the `pdf` and `printing` packages
- Generated PDFs include branded headers, event or marks data tables, and are opened inline or shared

---

## 🎨 Design System

### Color Palette

| Role | Color | Hex | Meaning |
|---|---|---|---|
| Primary | Royal Blue | `#0D47A1` / `#1E3A8A` | Trust, spirituality |
| Splash / Splash Android 12 | Royal Blue | `#0D47A1` | Brand consistency |
| Accent | Gold / Yellow | — | Light, enlightenment |
| Background | White / Light Grey | — | Clarity |

### Typography

- **Primary Font**: Google Fonts (Poppins / Roboto)
- **Headings**: Bold, 18–24 sp
- **Body**: Regular, 14–16 sp

### UI Patterns

- Shimmer loading skeletons for all async list views
- Lottie animations on the splash screen and empty states
- Liquid pull-to-refresh for event/notification feeds
- Carousel slider for featured events
- Marquee text for long event titles

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK **3.8.1** or higher
- Dart SDK (bundled with Flutter)
- Android Studio or Xcode
- A Firebase project with Authentication, Firestore, Storage, Messaging, and App Check enabled

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/AbinVarghexe/Ligth-Suvara.git
   cd Ligth-Suvara
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Download `google-services.json` from the Firebase Console and place it in `android/app/`
   - Download `GoogleService-Info.plist` and place it in `ios/Runner/`
   - Ensure `lib/firebase_options.dart` matches your Firebase project

4. **Generate App Icons**
   ```bash
   flutter pub run flutter_launcher_icons
   ```

5. **Generate Native Splash Screen**
   ```bash
   flutter pub run flutter_native_splash:create
   ```

6. **Run the App**
   ```bash
   # Development (Android)
   flutter run

   # Development (iOS)
   flutter run -d ios

   # Release build
   flutter build apk --release
   flutter build ios --release
   ```

### Configuration Files

| File | Purpose |
|---|---|
| `pubspec.yaml` | All dependencies, assets, icons, and splash configuration |
| `firebase.json` | Firebase Hosting and Storage emulator settings |
| `flutter_build_config.yaml` | Build environment configuration |
| `database_structure.md` | Full Firestore schema reference |
| `analysis_options.yaml` | Dart/Flutter lint rules |
| `devtools_options.yaml` | Flutter DevTools settings |

---

## 📱 Screenshots

<div align="center">
  <img src="assets/images/Logo.png" alt="App Logo" width="150"/>
  <img src="assets/images/suvara logo wbg.png" alt="Suvara Logo" width="150"/>
  <img src="assets/images/branding.png" alt="Branding" width="150"/>
</div>

> **Note**: Add actual device screenshots here showing each role's dashboard, the event flow, program registration, marks entry, and spiritual resource screens.

---

## 🤝 Contributing

This is a private project. For questions or collaboration inquiries, contact the repository owner.

---

## 📄 License

This project is private and proprietary. All rights reserved.

## 📞 Support

For support, feature requests, or bug reports:
- Open an issue in the GitHub repository
- Contact the development team directly

---

## 🙏 Acknowledgments

- **Firebase** for the robust backend infrastructure
- **Flutter Team** for the cross-platform framework
- **CML & SUVARA Organizations** for the opportunity to serve
- All contributors and testers

---

<div align="center">
  <img src="assets/images/branding.png" alt="Branding" width="300"/>
  
  **Made with ❤️ for Sunday School Communities**
  
  © 2025 Light Suvara. All Rights Reserved.
</div>
