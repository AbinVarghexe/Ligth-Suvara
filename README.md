<div align="center">
  <img src="assets/images/Logo.png" alt="Light Suvara Logo" width="200"/>
  
  # Light Suvara - Sunday School App
  
  ### 🙏 A Comprehensive Event Management & Spiritual Resource Platform
  
  [![Flutter](https://img.shields.io/badge/Flutter-3.8.1-02569B?logo=flutter)](https://flutter.dev)
  [![Firebase](https://img.shields.io/badge/Firebase-Enabled-FFCA28?logo=firebase)](https://firebase.google.com)
  [![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green)]()
  [![License](https://img.shields.io/badge/License-Private-red)]()
</div>

---

## 📖 Overview

**Light Suvara** is a modern, feature-rich Flutter application designed for Sunday School event management and spiritual resource sharing. The app serves as a centralized platform for schools under the CML (Christian Mission League) and SUVARA organizations, enabling administrators to manage events, broadcast notifications, and provide spiritual resources to users.

### 🎯 Key Highlights

- **Multi-School Support**: Manage multiple schools (CML & SUVARA) from a single platform
- **Real-time Event Management**: Create, update, and track events with live updates
- **Admin Dashboard**: Comprehensive admin panel for content management
- **Spiritual Resources**: Bible readings, Catechism, and Japamala (Rosary) tools
- **Push Notifications**: Broadcast important announcements to all users
- **Event Reports**: Generate and download detailed event reports in PDF format
- **Image Optimization**: Automatic image compression for optimal performance
- **Offline Support**: Cache management for better user experience

---

## ✨ Features

### 👥 For Users

- **📅 Event Browsing**
  - View upcoming events with rich details
  - Filter events by category (ALL, CML, SUVARA)
  - Search events by name or description
  - Sort events by date or alphabetically
  - Beautiful carousel slider for featured events

- **📖 Spiritual Resources**
  - Interactive Bible reader with web view support
  - Catechism study materials
  - Japamala (Rosary prayer) counter with haptic feedback
  - Downloadable PDF resources

- **🔔 Notifications**
  - Receive real-time event updates
  - View notification history
  - Direct links to event details from notifications

- **👤 User Profile**
  - Personalized school profiles
  - Custom profile images
  - School affiliation display

### 🔐 For Administrators

- **📊 Admin Dashboard**
  - Comprehensive event management interface
  - Quick access to all events across schools
  - Event approval and publishing workflow
  - Advanced search and filtering

- **📝 Event Management**
  - Create and edit events with rich media
  - Upload multiple images with automatic optimization
  - Set event dates, locations, and descriptions
  - Categorize events by school (CML/SUVARA)
  - Delete or archive events

- **📢 Broadcast System**
  - Send notifications to all users
  - Targeted messaging by school category
  - Notification history and analytics

- **📈 Reports & Analytics**
  - Generate PDF reports for events
  - Download event summaries
  - Track user engagement

- **👁️ Observer Management**
  - Assign observers to Sunday Schools by academic year
  - Generate unique access codes for observer login
  - Observers submit visit remarks, total attendance, and absentee details
  - View all observer submissions per school in one place

- **👨‍🏫 Teacher Management**
  - Add and manage teachers linked to specific Sunday Schools
  - Store teacher profiles: name, phone, email, qualification, classes taught, and date of birth
  - Filter teacher records by school and academic year
  - Upload teacher profile images to Firebase Storage

---

## 🏗️ Technical Architecture

### Built With

- **Framework**: Flutter 3.8.1+
- **Backend**: Firebase Suite
  - Firebase Authentication
  - Cloud Firestore
  - Firebase Storage
  - Firebase Cloud Messaging (for notifications)
- **State Management**: Provider Pattern
- **UI Components**: Material Design 3

### Key Dependencies

```yaml
Core:
  - flutter_sdk
  - firebase_core ^2.27.0
  - cloud_firestore ^4.15.8
  - firebase_storage ^11.6.9
  - firebase_auth ^4.20.0

UI/UX:
  - google_fonts ^6.2.1
  - carousel_slider ^5.1.1
  - marquee ^2.3.0
  - shimmer ^3.0.0

Utilities:
  - provider ^6.1.2
  - image_picker ^1.0.7
  - flutter_image_compress ^2.3.0
  - pdf ^3.10.0
  - path_provider ^2.1.5
  - url_launcher ^6.3.2
  - webview_flutter ^4.10.0
```

### Project Structure

```
lib/
├── main.dart                          # App entry point
├── providers/                         # State management
│   └── user_data_provider.dart
├── utils/                             # Utility functions
│   ├── downloads_helper.dart
│   ├── image_optimizer.dart
│   ├── pdf_download_helper.dart
│   └── performance_utils.dart
├── screens/                           # UI Screens
│   ├── auth_screen.dart               # Authentication
│   ├── login_screen.dart              # Login page
│   ├── homescreen.dart                # Main home screen
│   ├── profile_screen.dart            # User profile
│   ├── notification_screen.dart       # Notifications
│   ├── admin_dashboard_screen.dart    # Admin panel
│   ├── uploadscreen.dart              # Event creation
│   ├── edit_event_screen.dart         # Event editing
│   ├── event_detail_screen.dart       # Event details
│   ├── broadcast_screen.dart          # Broadcast messages
│   ├── bible.dart                     # Bible reader
│   ├── catechism_screen.dart          # Catechism
│   └── japamala.dart                  # Rosary counter
├── admin/
│   ├── admin_observer_management.dart # Observer assignment & access code generation
│   ├── admin_observer_remarks_view.dart # View observer submissions
│   ├── admin_teacher_management.dart  # Teacher profile management
│   ├── observer_remarks_screen.dart   # Observer visit remarks entry
│   └── observer_remarks_login.dart    # Observer access-code login
├── components/
│   ├── custom_app_bar.dart            # Reusable app bar
│   └── event_details_skelton.dart     # Loading skeleton
└── services/
    ├── firestore_service.dart         # Firestore operations
    └── firebase_options.dart          # Firebase config
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.8.1 or higher)
- Dart SDK (included with Flutter)
- Android Studio / Xcode (for mobile development)
- Firebase account and project setup
- Git

### Installation

1. **Clone the Repository**
   ```bash
   git clone https://github.com/AbinVarghexe/Ligth-Suvara.git
   cd Light_suvara
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration**
   - Add your `google-services.json` to `android/app/`
   - Add your `GoogleService-Info.plist` to `ios/Runner/`
   - Update `lib/firebase_options.dart` with your Firebase config

4. **Generate App Icons**
   ```bash
   flutter pub run flutter_launcher_icons
   ```

5. **Generate Splash Screen**
   ```bash
   flutter pub run flutter_native_splash:create
   ```

6. **Run the App**
   ```bash
   # For Android
   flutter run

   # For iOS
   flutter run -d ios
   
   # For release build
   flutter build apk --release
   flutter build ios --release
   ```

### Configuration Files

#### `firebase.json`
Configure Firebase Hosting and Storage rules.

#### `pubspec.yaml`
All dependencies and asset configurations are defined here.

#### `flutter_build_config.yaml`
Build configuration for different environments.

---

## 📱 Screenshots

<div align="center">
  <img src="assets/images/Logo.png" alt="App Logo" width="150"/>
  <img src="assets/images/appicon.png" alt="App Icon" width="150"/>
  <img src="assets/images/suvara logo wbg.png" alt="Suvara Logo" width="150"/>
</div>

> **Note**: Add actual app screenshots here showing:
> - Login Screen
> - Home Screen with Events
> - Event Details
> - Admin Dashboard
> - Bible/Catechism Readers
> - Notification Screen

---

## 🔧 Key Features Implementation

### 1. Image Optimization
The app automatically compresses uploaded images to reduce storage costs and improve performance:
- Maximum file size: 500KB
- Quality: 85%
- Format: JPEG

### 2. Event Filtering & Search
Users can:
- Filter events by school category (CML, SUVARA, or ALL)
- Search events by title or description
- Sort events by newest first or alphabetically

### 3. Offline Caching
- Event data is cached locally using Firestore's built-in caching
- Images are cached for faster loading
- Optimized for low-bandwidth scenarios

### 4. Admin Role Management
- Role-based access control via Firestore
- Separate admin dashboard with elevated permissions
- Admin-only features: event creation, editing, deletion, and broadcasting

### 5. PDF Report Generation
Generate detailed event reports with:
- Event information
- Participant lists
- Statistics and analytics
- Downloadable PDF format

---

## 🔐 Authentication & Security

- **Firebase Authentication**: Secure email/password authentication
- **Firestore Security Rules**: Role-based data access
- **Data Validation**: Input sanitization and validation
- **Secure Storage**: Sensitive data stored in Firebase

### User Roles

| Role     | Permissions |
|----------|-------------|
| User     | View events, receive notifications, access spiritual resources |
| Admin    | All user permissions + create/edit/delete events, send broadcasts, manage observers and teachers |
| Observer | Log in with an access code to submit visit remarks and attendance for assigned Sunday Schools |
| Teacher  | Associated with a Sunday School; profile managed by admin |

---

## 📊 Firebase Structure

### Firestore Collections

```
users/
  └── {userId}
      ├── email: string
      ├── schoolName: string
      ├── role: string (user/admin)
      ├── profileImageUrl: string
      └── createdAt: timestamp

events/
  └── {eventId}
      ├── title: string
      ├── description: string
      ├── date: timestamp
      ├── location: string
      ├── category: string (CML/SUVARA)
      ├── images: array
      ├── createdBy: string
      └── createdAt: timestamp

notifications/
  └── {notificationId}
      ├── title: string
      ├── message: string
      ├── eventId: string (optional)
      ├── category: string
      └── timestamp: timestamp

assignments/
  └── {assignmentId}
      ├── teacherId: string
      ├── teacherName: string
      ├── teacherPhone: string
      ├── sourceSchoolId: string
      ├── sourceSchoolName: string
      ├── targetSchoolId: string
      ├── targetSchoolName: string
      ├── academicYear: string
      ├── accessCode: string
      ├── remarks: string (optional)
      ├── totalAttendance: number (optional)
      ├── absentees: string (optional)
      └── submittedAt: timestamp (optional)
```

---

## 🎨 Design System

### Color Palette

- **Primary**: Blue (#0D47A1) - Trust, spirituality
- **Accent**: Gold/Yellow - Light, enlightenment
- **Background**: White/Light Grey - Clarity
- **Text**: Dark Grey/Black - Readability

### Typography

- **Primary Font**: Google Fonts (Poppins/Roboto)
- **Headings**: Bold, 18-24px
- **Body**: Regular, 14-16px

---

## 🤝 Contributing

This is a private project. For any questions or collaboration inquiries, please contact the repository owner.

---

## 📄 License

This project is private and proprietary. All rights reserved.


## 📞 Support

For support, feature requests, or bug reports:
- Create an issue in the GitHub repository
- Contact the development team

---

## 🙏 Acknowledgments

- **Firebase** for the robust backend infrastructure
- **Flutter Team** for the amazing cross-platform framework
- **CML & SUVARA Organizations** for the opportunity to serve
- All contributors and testers who helped improve this app

---

<div align="center">
  <img src="assets/images/branding.png" alt="Branding" width="300"/>
  
  **Made with ❤️ for Sunday School Communities**
  
  © 2025 Light Suvara. All Rights Reserved.
</div>
