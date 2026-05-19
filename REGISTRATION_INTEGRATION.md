# Registration Data Integration Guide

This document explains how to handle and display the new fields added to the Public Registration form in your web/admin dashboard.

## Updated Firestore Schema

The `public_registrations` collection now includes the following key-value pairs:

| Field Key | Data Type | Description | Example Value |
| :--- | :--- | :--- | :--- |
| `name` | String | User's Full Name | "John Doe" |
| `phone` | String | **International Format** (Code + Number) | "+919876543210" |
| `qualification` | String | Highest Educational Qualification | "Master of Divinity" |
| `currentStatus` | String | Occupational/Professional Status | "Working Professional" |
| `email` | String | Email Address | "john@example.com" |
| `address` | String | Residential Address | "123 Grace St, Kerala" |
| `programId` | String | ID of the registered program | "PRG123" |
| `timestamp` | Timestamp | Server-generated registration date | `March 28, 2026` |

---

## Web Integration Tips

### 1. Handling International Phone Numbers
The `phone` field now includes the country code as a prefix. When displaying this in your web table or admin panel:
- **Direct Display**: You can display it exactly as stored (e.g., `+919876543210`).
- **Formatting**: If you use a library like `libphonenumber`, it will automatically recognize the prefix and format it beautifully.

### 2. Displaying the New Fields
When building the "Registrations Table" in your admin portal, ensure you include the columns for **Qualification** and **Current Status**.

```javascript
// Example: Mapping your table columns
const columns = [
  { title: 'Name', dataIndex: 'name' },
  { title: 'Status', dataIndex: 'currentStatus' }, // NEW
  { title: 'Qualification', dataIndex: 'qualification' }, // NEW
  { title: 'Phone', dataIndex: 'phone' },
  { title: 'Date', dataIndex: 'timestamp' },
];
```

### 3. Filtering and Searching
You can now create more granular reports by filtering users based on their `currentStatus` (e.g., "Show me all Students who registered for this event").

---

## Critical Considerations

> [!IMPORTANT]
> **Backward Compatibility**: Registrations made before this update will NOT have the `qualification` or `currentStatus` fields. Your web code should handle these cases using a default value or checking for null/undefined:
> `user.qualification || "N/A"`

> [!TIP]
> **Exporting to Excel/CSV**: If you have an "Export" feature, remember to update the export script to include these new columns so they appear in your final registration reports.
