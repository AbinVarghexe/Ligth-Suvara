# Database Structure Overview

This document outlines the Firestore collection structure for the Sunday School Management app. It includes detailed field descriptions and logic for targeted features like notifications and registration workflows.

## Collections

### 1. `users`
Stores profile information and determines system permissions.
- **Document ID**: Firebase Auth UID
- **Fields**:
  - `uid`: String - Same as Document ID.
  - `name`: String - Display name (User's full name or Sunday School name).
  - `email`: String - Primary login email.
  - `phone`: String - Contact number.
  - `role`: String - One of: `admin`, `school`, `parish`, `animator`. Determines UI access and notification targeting.
  - `forane`: String - Forane name the user belongs to.
  - `parish`: String - Parish name.
  - `address`: String - Physical/postal address.
  - `parishId`: String - UID of the associated parish user document (used for filtering registrations).
  - `parishName`: String - Name of the associated parish.
  - `fcmToken`: String - Firebase Cloud Messaging token for push notifications.
  - `createdAt`: serverTimestamp - Account creation date (mainly for Animators).
  - `createdBy`: String - UID of the Admin who created the account (for Animators).

### 2. `events`
School-specific or Admin-posted announcements/events.
- **Fields**:
  - `title`: String - Event title.
  - `title_lowercase`: String - lowercase version for Case-Insensitive search.
  - `place`: String - Event location.
  - `description`: String - Full event details (markdown supported).
  - `timestamp`: Timestamp - Scheduled date and time.
  - `imageUrl`: String - URL to optimized image in Storage.
  - `category`: String - Filter category (e.g., 'CML', 'Suvara', 'General').
  - `forane`: String - Forane context (used to filter events by region).
  - `creatorId`: String - UID of the user who posted the event.
  - `isPublic`: Boolean - If `false`, the event is considered a "Draft" and only visible to the creator/admin.

### 3. `programs`
Defines active registration programs (e.g., competitive events).
- **Fields**:
  - `name`: String - Program title.
  - `startDate`: Timestamp - When registration opens.
  - `endDate`: Timestamp - When registration closes.
  - `isActive`: Boolean - Global toggle to hide/show the program.
  - `createdAt`: serverTimestamp - Audit log for when the program was defined.

### 4. `program_registrations`
Stores student entries. Features several status levels for a workflow.
- **Fields**:
  - `programId`: String - Reference to a `programs` document.
  - `programName`: String - Redundant name for display optimization.
  - `schoolUserId`: String - UID of the submitting School.
  - `schoolName`: String - Name of the submitting School.
  - `parishUserId`: String - UID of the associated Parish for approval.
  - `parishName`: String - Name of the associated Parish.
  - `isCountOnly`: Boolean - If `true`, only `studentCount` is relevant (no individual names).
  - `studentCount`: Number - Total count for bulk registration.
  - `studentName`: String - Individual student name.
  - `studentPhone`: String - Contact for the student/parent.
  - `studentAddress`: String - Optional physical address.
  - `studentClass`: String - Optional grade level.
  - `status`: String - Workflow status: 
    - `pending_parish`: Initial state after school submission.
    - `approved_parish`: Approved by the Parish admin.
    - `rejected`: Rejected by either Parish or Admin.
    - `locked`: Finalized by Parish; the School can no longer edit.
    - `approved_admin`: Final oversight approval.
  - `submittedAt`: serverTimestamp - Date of submission.

### 5. `notifications` (Targeted)
Crucial for private or role-specific messaging.
- **Fields**:
  - `title`: String - Notification heading.
  - `body`: String - Main message content.
  - `timestamp`: Timestamp - Creation time.
  - `imageUrl`: String - Optional banner image.
  - `recipientId`: String - Targeting logic:
    - `[User_UID]`: Specific to one user.
    - `role_school`: Visible to **all** users with the `school` role.
  - `readBy`: List<String> - **Read Receipts Logic**: This array contains the UIDs of users who have viewed/tapped the notification. A notification is "Unread" for a user if their UID is **not** in this list.
  - `isBroadcast`: Boolean - Set to `true` if it's sent to a role group (e.g., `role_school`), `false` for direct person-to-person.

### 6. `animator_assignments`
Maps animators to the Sunday Schools they are responsible for (max 2 per year).
- **Document ID**: UID of the Animator.
- **Fields**:
  - `assignments`: List<Map> - Array of assignment objects.
    - `unitId`: String - Unique identifier for the assignment (e.g., '1a2b3c4d').
    - `schoolUserId`: String - UID of the assigned School.
    - `sundaySchool`: String - Name of the School for display.
    - `parish`: String - Name of the School's Parish.
    - `forane`: String - Name of the School's Forane.
    - `year`: String - Academic year (e.g., '2026').

### 7. `marks`
Stores student result data entered by animators.
- **Document ID**: `${schoolId}_${year}` (e.g., 'uid123_2026')
- **Fields**:
  - `unitId`: String - Reference to a specific assignment unit.
  - `schoolId`: String - UID of the Sunday School.
  - `parish`: String - Parish name.
  - `sundaySchool`: String - School name.
  - `animatorId`: String - UID of the marking Animator.
  - `animatorName`: String - Name of the Animator.
  - `year`: String - Academic year.
  - `marks`: Map<String, Number> - Map of Question IDs to their assigned scores.
  - `remarks`: String - Overall feedback for the entry.
  - `pdfUrl`: String - URL to the verified proof PDF in Storage.
  - `locked`: Boolean - If `true`, marks are finalized and cannot be edited.
  - `submittedAt`: serverTimestamp - Date of final submission.

### 8. `questions`
Defines the mark entry schema for the app.
- **Fields**:
  - `text`: String - The question or task description.
  - `maxMark`: Number - Maximum possible score.
  - `order`: Number - Display order in the list.

### 9. `broadcasts` (Public)
Announcements visible to all users, including non-logged-in visitors.
- **Fields**:
  - `title`: String
  - `body`: String
  - `timestamp`: Timestamp
  - `imageUrl`: String
  - `readBy`: List<String> - Same read receipt logic as `notifications`.

### 10. `teachers`
Stores teacher profiles for each Sunday School.
- **Fields**:
  - `name`: String - Full name of the teacher.
  - `phone`: String - Contact number.
  - `email`: String - Email address.
  - `dob`: Timestamp - Date of birth.
  - `qualification`: String - Academic/professional qualification.
  - `classes`: String - Classes or subjects taught.
  - `academicYear`: String - Academic year (e.g., `'2024-25'`).
  - `schoolId`: String - UID of the associated Sunday School user.
  - `schoolName`: String - Name of the Sunday School.
  - `photoUrl`: String - Optional URL to the teacher's profile photo in Storage.
  - `addedAt`: serverTimestamp - Date the record was created.

### 11. `assignments`
Stores observer assignments that link a teacher from one school to another school's exam.
- **Fields**:
  - `type`: String - Always `'Observer'` for this use case.
  - `teacherId`: String - Document ID of the assigned teacher from the `teachers` collection.
  - `teacherName`: String - Redundant name for display.
  - `teacherPhone`: String - Contact number of the observer.
  - `sourceSchoolId`: String - UID of the school the observer belongs to.
  - `sourceSchoolName`: String - Name of that school.
  - `targetSchoolId`: String - UID of the school being observed.
  - `targetSchoolName`: String - Name of the observed school.
  - `accessCode`: String - 6-digit numeric code used by the observer to log in to the Observer Portal.
  - `academicYear`: String - Academic year for this assignment.
  - `assignedAt`: serverTimestamp - Date the assignment was created.
  - `remarks`: String - Written exam remarks submitted by the observer.
  - `totalAttendance`: Number - Total student attendance count submitted by the observer.
  - `absentees`: String - Names or details of absentees submitted by the observer.
  - `remarksSubmittedAt`: serverTimestamp - Date the observer submitted the report.

## Firebase Storage Structure
- `event_images/`: Optimized JPEG files for `events`.
- `broadcast_images/`: Banner images for `broadcasts` or `notifications`.
- `marks_pdfs/`: Student result proof documents (PDFs).
- `user_profiles/`: Optional user/school profile pictures.

