5.2.1  Guest Portal and Authentication Flow
The application implements a robust two-tier landing system to balance public engagement with secure administrative access.

*   **Guest Home (Latest Updates)**: Users not logged in are directed to a feature-rich portal (`login_screen.dart`). This screen serves as a real-time news hub, utilizing a `CarouselSlider` and custom `ContentProvider`. It fetches data from the `broadcasts` and `announcements` collections. Performance is optimized using `RepaintBoundary` for background blobs and `shimmer` for skeleton loading during `LiquidPullToRefresh` actions. A global marquee built with the `marquee` package provides urgent updates directly from the admin console.
*   **Authentication & Role Resolution**: The `AuthScreen` captures credentials and interfaces with Firebase Auth. Post-authentication, the `AuthGate` in `auth_wrapper.dart` acts as a traffic controller. It resolves user roles by querying the `users` collection. The `resolveRoleAndNavigate` function then routes the user to the appropriate module, while a `UserDataProvider` broadcasts the user's institutional metadata (parish ID, school name) across the widget tree for role-based UI filtering.

[ Fig. 5.1: Guest Portal – Public Event Feed and Updates – Insert screenshot here ]
[ Fig. 5.2: Secure Login Interface – Role-based Access Control – Insert screenshot here ]

5.2.2  Admin Dashboard Module
The Admin Dashboard (`admin_dashboard_screen.dart`) provides a high-level command center utilizing a `CustomScrollView` and glassmorphic UI elements (implemented via `BackdropFilter`).

*   **Real-time Analytics**: A dedicated `_fetchAndSetStatistics` method retrieves counts for events, programs, and schools. Data is categorized into `ALL`, `CML`, and `SUVARA` segments. Skelton screens (`EventListSkeleton`) ensure a smooth UX during initial data sync.
*   **Notification Engine**: The `AdminNotificationScreen` implements a sophisticated targeting system. Admins can select between **Public Broadcasts** (stored in `broadcasts`), **Institutional Notifications** (targeted to `role_school`), or **Specific Recipients** (filtering individual school IDs). All multi-write operations are wrapped in a `WriteBatch` to guarantee data consistency. It also includes an image management system integrated with Firebase Storage.
*   **Management Sub-menus**: The architecture uses specialized menu components (`AdminAnimatorMenu`, `AdminSchoolMenu`, etc.) to isolate management logic. Teacher management (`AdminTeacherManagementScreen`) features robust CRUD operations, including profile picture handling and school-to-teacher relational mapping in Firestore.

[ Fig. 5.3: Admin Dashboard – Home Screen and Analytics – Insert screenshot here ]
[ Fig. 5.4: Admin – Notification Composer and Target Selection – Insert screenshot here ]
[ Fig. 5.5: Admin – Animator and Teacher Management Interface – Insert screenshot here ]

5.2.3  School Module
The School portal is designed for operational efficiency, localized in `homescreen.dart` and specialized registration screens.

*   **Institutional Event Creation**: School users can post community-specific updates through the `UploadScreen`. This utilizes the `ImagePicker` and `Firebase Storage` APIs, with download URLs stored in the `events` collection alongside visibility flags.
*   **Dynamic Registration Engine**: The `StudentRegistrationForm` employs a flexible state management approach. It maintains a `List<Map<String, TextEditingController>>` to dynamically generate student entry fields. The `_updateStudentEntriesCount` listener adds or disposes of controllers in real-time based on the user-entered count, ensuring low memory overhead.
*   **Approval & Lock Mechanism**: Registrations are submitted with an initial `pending_parish` status. A `_checkLockStatus` guard prevents modifications once the program has reached a `locked` state, preserving original submission data for official records.

[ Fig. 5.6: School Dashboard – Event Creation and Feed – Insert screenshot here ]
[ Fig. 5.7: School – Program Registration and Management – Insert screenshot here ]
[ Fig. 5.8: School – Notification Center and Profile View – Insert screenshot here ]

5.2.4  Parish Module
The Parish module (`parish_dashboard_screen.dart`) serves as the localized verification layer.

*   **Cross-Stream Integration**: The dashboard uses `Rx.combineLatest2` (from the `rxdart` package) to merge personal notifications with global broadcasts, providing a unified inbox for parish administrators.
*   **Regional Oversight**: Parishes view filtered feeds based on their linked `schoolId`. The approval workflow is split into a tri-tab layout (Pending, Approved, Rejected) using a `TabController`. Approval actions update the registration document and trigger notification alerts for the submitting school.

[ Fig. 5.9: Parish Dashboard – Regional Event Overview – Insert screenshot here ]
[ Fig. 5.10: Parish – Registration Approval Queue and Status Tracking – Insert screenshot here ]

5.2.5  Animator Module
The Animator role focuses on technical evaluation through the `AnimatorDashboardScreen` and `MarkEntryScreen`.

*   **Dynamic Marks Schema**: The evaluation interface fetches a `marksSchema` from Firestore, dynamically rendering input fields for various contest components (e.g., theory, practicals, viva).
*   **Technical Sorting & Validation**: Questions are grouped and displayed using a custom Roman numeral sorting algorithm (`_groupQuestionsByPart`). Real-time validation ensures that marks entered do not exceed the `maxMark` defined by the admin.
*   **Evidence Persistence**: Evaluation integrity is maintained by requiring a PDF upload for mark sheets. The module uses the `file_picker` package and Firebase Storage, storing the final `pdfUrl` in the `marks` document upon successful `locked` submission.

[ Fig. 5.11: Animator – Assignment Dashboard – Insert screenshot here ]
[ Fig. 5.12: Animator – Dynamic Mark Entry and PDF Upload – Insert screenshot here ]

5.2.6  Observer Module
The Observer portal (`observer_remarks_screen.dart`) provides a secure, PIN-protected audit layer.

*   **Secure Access**: Access is controlled via a 6-digit PIN login screen (`ObserverRemarksLogin`) featuring auto-focusing numeral fields and custom keyboard overlay triggers.
*   **Operational Reporting**: Observers submit reports via a structured form that captures attendance metrics, absentee lists, and qualitative conduct remarks. Data is stored in the `observer_reports` collection, indexed by program and date for easy admin auditing.

[ Fig. 5.13: Observer – Multi-digit PIN Login Interface – Insert screenshot here ]
[ Fig. 5.14: Observer – Exam Conduct and Reporting Form – Insert screenshot here ]

5.2.7  Resources Section
The application includes a centralized Resources hub initiated via an animated popup menu (using `showGeneralDialog` for a glassmorphic effect). This module provides specialized tools for spiritual and educational growth:
*   **Japamala (Rosary)**: Uses the `CustomPaint` API to render a responsive bead layout. It features haptic feedback (`HapticFeedback.lightImpact`) and maintains state using `AnimationController`, with prayer progress persisted via `SharedPreferences`.
*   **Catechism & Bible**: Features integrated viewers for religious texts (POC Bible) with support for offline access through local caching strategies and categorized navigation.
*   **Yamaprarthanakal Integration**: A key feature of the Resources section is the deep integration with the external "Yama Prarthanakal" application. This is implemented using the `external_app_launcher` package (via the `LaunchApp` class).
    *   **Logic**: The system first attempts to launch the app using its package name (`org.praarthana.syromalabaryaamapraarthanakal`). If the app is not detected as installed (`LaunchApp.isAppInstalled`), the module gracefully redirects the user to the Google Play Store using the `url_launcher` package, ensuring accessibility even if the user hasn't yet installed the companion app.

[ Fig. 5.15: Resources – Interactive Spiritual and Educational Hub – Insert screenshot here ]
