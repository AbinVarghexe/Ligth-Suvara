<div align="center">
  <img src="assets/images/Logo.png" alt="Light Suvara Logo" width="200"/>
  
  # Light Suvara — Sunday School Management App
  
  ### 🙏 A Comprehensive Event, Program & Spiritual Resource Platform for Sunday Schools
  
  [![Flutter](https://img.shields.io/badge/Flutter-3.8.1-02569B?logo=flutter)](https://flutter.dev)
  [![Firebase](https://img.shields.io/badge/Firebase-Enabled-FFCA28?logo=firebase)](https://firebase.google.com)
  [![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows-green)]()
  [![License](https://img.shields.io/badge/License-Private-red)]()
</div>

---

## 📖 Overview

**Light Suvara** is a modern, elaborately feature-rich Flutter application designed to scale and digitally manage Sunday Schools operating under the **CML (Christian Mission League)** and **SUVARA** organizations. Designed from the ground up for seamless communication, event hosting, and administrative oversight, the app provides tailored platforms for administrators, parish coordinators, Sunday School units (schools), evaluators (animators), and exam observers. 

It handles everything from multi-stage competitive program registrations to marks evaluation, push notifications, and spiritual resources, all fully synchronized in real-time through Firebase.

### 🎯 Key Highlights
*   **5-Tier Hybrid Role Architecture**: Granular dashboards for Admin, Parish, School, and Animator, supplemented by a unique anonymous "Observer Portal."
*   **Dynamic Event Hub**: A real-time hub for hosting public and draft events separated by organizational tags.
*   **3-Stage Program Registration Engine**: Transparent and trackable registration workflow encompassing School Submission, Parish Review, and Admin Oversight.
*   **Comprehensive Evaluation & Marks Engine**: Custom schema-driven marking system with PDF proof generation.
*   **Real-time Push & Broadcast System**: Target specific users, roles, or broadcast universally using FCM.
*   **Offline Data Resilience**: Built-in caching enabling rapid loading and operations in low-bandwidth network environments.
*   **Internal Logging Mechanism**: Silent activity tracking monitoring user sign-in flows and critical events entirely within Firebase.

---

## 👥 Elaborative Role System & Dashboards

The app relies heavily on **role-based routing**, controlled through Firestore data points. Each validated app user is navigated securely to a role-specific interface to prevent unauthorized data access.

### 1. The Admin (`admin`)
The **Admin Dashboard** serves as the omnipotent control room for the entire network. From here, administrators have access to:
*   **Master Event Management**: Post, edit, draft, and publish events targeted at specific subgroups.
*   **Dynamic Program Management**: Launch new Sunday School programs, set timeframes, and oversee analytics of registrations.
*   **Role Management & User Provisioning**: Create Parish user accounts, configure Animator accounts, and assign evaluators to specific individual schools.
*   **Global Notifications**: Send push notifications or broad "Broadcasts" to notify the entire network of urgent updates.
*   **Schema & Exam Control**: Define the scoring rubrics (Questions) and oversee marks submitted across the network.
*   **Theme & Content Management**: Edit dynamic content elements (e.g., Theme of the Year) appearing on the login menus. 
*   **Teacher & Observer Operations**: Manage the roster for teachers and assign specific educators as anonymous Observers for external testing environments. 

### 2. The Animator / Evaluator (`animator`)
The **Animator Dashboard** is focused strictly on evaluation operations.
*   **Assignment Tracking**: View Sunday Schools explicitly assigned to their evaluating roster for the year.
*   **Dynamic Mark Entry**: Enter specific student marks against the custom schema defined by the Admin.
*   **Proof Validation**: Mandatory PDF upload requirement for evaluated sheets ensuring transparent marking.
*   **Execution Locks**: Once submitted, inputs are actively "Locked" in Firestore preventing tampering post-grading.

### 3. The Parish Coordinator (`parish`)
The **Parish Dashboard** acts as the crucial middle-tier verifier.
*   **Queue Management**: Monitors pending school program registration submissions filtering up from connected Sunday Schools.
*   **Decision Gateway**: Review documentation and approve or reject school submissions before they proceed to Admin review.
*   **Unit Lock-in**: Locks approved submissions to freeze modifications from the school-side, ensuring integrity during the pipeline transition.

### 4. The Sunday School Unit (`school`)
The **Home Dashboard** is the primary face of the app geared towards localized units and their respective students.
*   **Visual Event Feeds**: Interactive carousels highlighting latest news, sorted by organization (CML, SUVARA).
*   **Registration Portal**: Browse active programs and submit forms for participating student bodies.
*   **Spiritual Toolkit**: One-tap access to daily Biblical liturgy, Catechism curriculum integration, and an interactive digital Japamala (Rosary) counter system.
*   **Notification Repository**: An isolated "Inbox" tracking targeted pings explicitly sent to their unit.

### 5. Access Check Observers (`observer`)
The **Observer Portal** is a stateless environment distinct from Firebase Auth.
*   **Token Access**: Logging in utilizes a 6-digit dynamic password (token) generated explicitly by the Admin.
*   **Role Purpose**: Dedicated exclusively to reporting. Used for external invigilation during exams.
*   **Feedback Loops**: Submits attendance logs, explicit absentee rosters, and structured remark reports back directly to Admins securely. 

---

## ✨ Exhaustive Feature Breakdown

### 📸 Full-Featured Media & Event Tools
- **Auto-Optimizing Assets**: Native image and document picking utilizing the `flutter_image_compress` package. Heavy event posters are automatically compressed (85% Quality, JPG Format, 500KB cap) before being piped to Firebase Storage, saving excessive CDN bandwidth.
- **Marquee & Real-time Feeds**: Events support scrolling `Marquee` banners for lengthy titles and implement `liquid_pull_to_refresh` for natural, tactile reloading inside the feeds.
- **Full-Screen Immersion**: Integrated media viewers allowing zero-distraction zoomable views of event posters.

### 📋 The Three-Stage Registration Pipeline Architecture
Registrations aren't just single forms; they operate as a complete state-machine funnel in the backend:
1.  **Drafting (School)**: Users build bulk or specific student registration entries on active Programs. 
2.  **Pending Parish Approval (Parish)**: Forms are pipelined up. A Parish coordinator either Rejects (kicking it back) or Approves.
3.  **Final Security Lock (Parish/Admin)**: The data is structurally "Locked" terminating any further edits and preparing the schema for final Admin oversight charts.

### 👨‍🏫 Administrative Human Resources Engine
- **Teacher Ledger**: Integrated management of teachers allowing mapping explicitly to assigned schools, contact details, subject class assignments, and photo logs—segmented specifically by Academic Year logic.
- **Examiner Overlaps**: Utilizes the teacher base to map out complex "Observer Assignments"—where an educator from *School A* is secretly routed an Access Token to observe the final exams at *School B*.

### 📊 PDF Engine & Deep Analytics
Combining the parsing algorithms with Flutter's `printing` toolkit allows for:
- **Instant Reporting**: Compiling all evaluation Marks from Animators into neatly formatted PDF documents strictly generated on-the-fly depending on user selection arrays right from the Admin interface.
- **Analytics Visualization**: Real-time program registration statistics updating synchronously as approvals proceed up the pipeline.

### ✝️ Highly-Interactive Spiritual Resources Module
To boost utility outside administration context, light client utilities persist directly within the app:
- **Rich-Text Bible Viewer**: Embedded views of scripture contexts.
- **Catechism Guides**: Prepackaged study notes and interactive guides.
- **Smart Japamala (Rosary)**: An explicit feature encompassing all 5 prayer groups (Joyful, Sorrowful, Glorious, Luminous). Includes tactile UI feedback and auto-increments saving place progression.

### 🔔 Centralized Communications Node
Instead of relying squarely on WhatsApp groups, the application leverages FCM correctly:
- **Broadcasting Engine**: Capable of sending non-targeted global application blasts to visual news interfaces in the app.
- **Direct FCM Notification**: Leveraging generated FCM UUIDs locally. Admins can filter their entire database routing a message strictly to `School Units`, `Animators`, or an explicitly identified `User UUID`.
- **Read-Receipt Analytics**: Native Firestore array-checks tracking exactly who has acknowledged critical memo elements.

### 🔒 Transparent Security & Silent Internal Auditing
- **Silenced LogService**: Logs and parses user activity flows (such as authentication sequences, session tracking, and user modifications) pushing synchronously to dedicated, non-public Firestore `logs` collections for deep administrative tracking invisible from the front end.
- **Firebase App Check**: Hardened on Android through Google Play Integrity pipelines effectively locking API utilization against non-certified clones trying to hit the backend directly.

---

## 🏗️ Technical Architecture & Developer Reference

### Built With 
- **Core SDK**: Flutter 3.8.1+ / Dart `^3.8.1`
- **Dependency Injections**: Built actively employing `Provider` Architecture handling states globally (such as `UserDataProvider` resolving instantaneous role data after logins) minimizing massive prop-drilling.

### Explicit Firebase Topology
*  **Cloud Firestore (NoSQL)**: Engineered relying heavily on sub-collections to enforce security rule scaling and indexed queries (`teachers`, `assignments`, `marks`, `events`, `programs`).
*  **Authentication Integration**: Core layer binding `FirebaseAuth` UID's explicitly against parallel identically-keyed `users` documents encapsulating additional data (like custom roles that natively aren't supported easily inside Firebase JWT claims).

### Data Modeling Highlights
- **Indexes**: More than 10 heavily composite-indexed arrays optimizing sorting sequences like `title_lowercase`+`timestamp` (for fuzzy case-insensitive active sorting), `isActive`+`createdAt`, and explicit permission intersections grouping `recipientId`+`timestamp` to render low-cost inbox reads.
- **Scalability**: By utilizing UUID mapping strategies across sub-collections (`{schoolId}_{year}` key pairs for marks) the data remains sharded linearly protecting against hard quota exhaustion.

---

## 🚀 Deployment & Installation

### Core Prerequisites
- Flutter Environment Configured (`3.8.1+`)
- Configured Native Build Pipelines (Android SDK Command-Line / Target Xcode configurations)
- Initialized Firebase Stack matching required topologies.

### Execution Instructions
1. **Pull the Repository**:
   ```bash
   git clone https://github.com/AbinVarghexe/Ligth-Suvara.git
   cd Ligth-Suvara
   ```

2. **Synchronize Dependencies**:
   ```bash
   flutter clean && flutter pub get
   ```

3. **Incorporate Firebase Assets**:
   Download your valid `google-services.json` and inject it directly into the `android/app/` subdirectory. Do the equivalent for `GoogleService-Info.plist` at `ios/Runner/`.

4. **Regenerate Platform Hooks**:
   Synchronize launcher icons and the specific lottie native splash components natively:
   ```bash
   flutter pub run flutter_launcher_icons
   flutter pub run flutter_native_splash:create
   ```

5. **Deploy Targets**:
   ```bash
   # Development
   flutter run -d chrome     # Web Context Testing
   flutter run -d emulator   # Target Android VM Context

   # Production Release Compilations
   flutter build appbundle --release  # AAB for Google Play Console 
   flutter build ios --release        # IPA Archiving Prep 
   ```

---

<div align="center">
  <img src="assets/images/branding.png" alt="Branding Block" width="300" style="margin-top: 30px;"/>
  
  <br>

  **Engineered Seamlessly with ❤️ for Sunday School Communities & CML Entities.**
  
  © 2026 Light Suvara Development Team. All Rights Reserved.
</div>
