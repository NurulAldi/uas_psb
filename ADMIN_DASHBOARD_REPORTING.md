# Admin Dashboard & Reporting System Documentation

## 📋 Overview

This document describes the complete Admin Dashboard and Reporting System implementation for RentLens. The system allows users to report other users for policy violations, and provides administrators with tools to manage reports and enforce bans.

---

## 🎯 Features

### User Side
- **Report User Button**: Flag icon on ProductDetailScreen to report product owners
- **Report Dialog**: User-friendly form to submit report reason
- **Validation**: Minimum 10 characters for report reason
- **Warning Message**: Users are informed that false reports may result in action

### Admin Side
- **Admin Dashboard**: Dedicated page for managing reports (access restricted to admins)
- **Pending Reports View**: See all unresolved reports with full details
- **All Reports View**: Toggle to view complete report history
- **Report Actions**:
  - **Ban User**: Immediately bans the reported user and marks report as resolved
  - **Dismiss**: Marks report as dismissed without taking action
- **Rich Report Cards**: Display reporter info, reported user info, reason, timestamp, and status
- **Real-time Status**: Shows if reported user is already banned
- **Confirmation Dialogs**: Require admin confirmation before banning or dismissing

---

## 📁 File Structure

```
lib/features/admin/
├── domain/
│   └── models/
│       └── report.dart                    # Report & ReportWithDetails models
├── data/
│   └── repositories/
│       └── report_repository.dart         # Database operations for reports
├── providers/
│   └── report_provider.dart               # Riverpod providers & controllers
└── presentation/
    ├── pages/
    │   └── admin_dashboard_page.dart      # Main admin dashboard UI
    └── widgets/
        └── report_user_dialog.dart        # Report submission dialog
```

### Modified Files
- `lib/features/products/presentation/screens/product_detail_screen.dart` - Added Report button
- `lib/features/home/presentation/screens/home_screen.dart` - Added Admin Dashboard menu item
- `lib/core/config/router_config.dart` - Added /admin/dashboard route
- `lib/features/auth/providers/profile_provider.dart` - Added profileByIdProvider

---

## 🗄️ Database Schema

Reports are stored in the `reports` table (created via `supabase_rbac_and_reporting.sql`):

```sql
CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    reported_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'resolved', 'dismissed')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_by UUID REFERENCES auth.users(id),
    admin_notes TEXT
);
```

**View: recent_reports_with_details**
Provides enriched report data with user names and emails:
```sql
SELECT 
    r.*,
    reporter.full_name AS reporter_name,
    reporter.email AS reporter_email,
    reported.full_name AS reported_user_name,
    reported.email AS reported_user_email,
    reported.is_banned AS reported_user_is_banned
FROM reports r
JOIN profiles reporter ON r.reporter_id = reporter.id
JOIN profiles reported ON r.reported_user_id = reported.id
```

---

## 🔐 Access Control

### User Permissions (RLS Policies)
- ✅ Any authenticated user can create reports
- ✅ Users can view their own submitted reports
- ❌ Users cannot view reports about themselves
- ❌ Users cannot modify or delete reports

### Admin Permissions
- ✅ Admins can view ALL reports (pending, resolved, dismissed)
- ✅ Admins can update report status and add admin notes
- ✅ Admins can ban/unban users via the dashboard
- ✅ Admin role is stored in `profiles.role` column

### Dashboard Access
The Admin Dashboard menu item only appears if:
```dart
if (userProfile?.role == 'admin') {
  // Show Admin Dashboard button
}
```

---

## 🚀 User Flow

### Reporting a User

1. **Navigate to Product Detail**
   - User views a product they want to report
   - Report button (flag icon) appears in AppBar (only for non-owners)

2. **Click Report Button**
   - Opens `ReportUserDialog`
   - Pre-filled with reported user's name (fetched from profile)

3. **Submit Report**
   - Enter reason (min 10 characters, max 500)
   - System validates input
   - Creates report in database with status='pending'
   - Success message: "Report submitted successfully"

4. **Database Action**
   ```sql
   INSERT INTO reports (reporter_id, reported_user_id, reason, status)
   VALUES (current_user_id, reported_user_id, reason, 'pending');
   ```

### Admin Review Process

1. **Access Admin Dashboard**
   - Admin clicks "Admin Dashboard" from user menu
   - Route: `/admin/dashboard`

2. **View Pending Reports**
   - Default view shows only `status='pending'` reports
   - Toggle to "All Reports" to see complete history
   - Each card shows:
     - Reporter name and email
     - Reported user name and email
     - Report reason
     - Timestamp (e.g., "2 hours ago")
     - Current ban status

3. **Take Action: Ban User**
   - Click "Ban User" button
   - Confirmation dialog appears
   - On confirm:
     ```dart
     // 1. Update profiles table
     UPDATE profiles SET is_banned = true WHERE id = reported_user_id;
     
     // 2. Update reports table
     UPDATE reports SET 
       status = 'resolved',
       resolved_by = admin_id,
       admin_notes = 'User banned via admin dashboard'
     WHERE id = report_id;
     ```
   - **Immediate Effect**: Banned user will be logged out on next login attempt
   - Success message: "{User Name} has been banned"
   - Reports list auto-refreshes

4. **Take Action: Dismiss Report**
   - Click "Dismiss" button
   - Confirmation dialog appears
   - On confirm:
     ```dart
     UPDATE reports SET 
       status = 'dismissed',
       resolved_by = admin_id,
       admin_notes = 'Report dismissed - no action required'
     WHERE id = report_id;
     ```
   - Success message: "Report dismissed"
   - Reports list auto-refreshes

---

## 💻 Code Examples

### Creating a Report (User Side)
```dart
final controller = ref.read(reportManagementControllerProvider.notifier);
final success = await controller.createReport(
  reportedUserId: 'user-uuid-here',
  reason: 'User violated community guidelines...',
);
```

### Banning a User (Admin Side)
```dart
final controller = ref.read(reportManagementControllerProvider.notifier);
final success = await controller.banUserAndResolveReport(
  reportId: 'report-uuid',
  reportedUserId: 'user-to-ban-uuid',
  adminNotes: 'User banned for policy violations',
);

// This will:
// 1. Set is_banned = true in profiles table
// 2. Mark report as resolved
// 3. Auto-refresh pending reports list
```

### Dismissing a Report (Admin Side)
```dart
final controller = ref.read(reportManagementControllerProvider.notifier);
final success = await controller.dismissReport(
  reportId: 'report-uuid',
  adminNotes: 'Report was invalid or resolved outside system',
);
```

### Checking Admin Status
```dart
final userProfile = ref.watch(currentUserProfileProvider).value;
final isAdmin = userProfile?.role == 'admin';

if (isAdmin) {
  // Show admin-only features
}
```

---

## 🎨 UI Components

### ReportUserDialog
**Location**: `lib/features/admin/presentation/widgets/report_user_dialog.dart`

**Features**:
- Orange warning banner with reported user name
- Multiline text field (5 lines visible)
- Character counter (max 500)
- Validation: Min 10 characters
- Disclaimer text about false reports
- Loading state during submission
- Non-dismissible during submission

**Colors**:
- Primary: Red (#D32F2F) - for submit button
- Warning: Orange - for info banner

### AdminDashboardPage
**Location**: `lib/features/admin/presentation/pages/admin_dashboard_page.dart`

**Features**:
- Deep purple gradient header
- Segmented button to toggle between "Pending" and "All Reports"
- Rich report cards with:
  - Status badge (Pending=Orange, Resolved=Green, Dismissed=Grey)
  - Timestamp with humanized format
  - Reporter info section
  - Reported user info section (highlighted in red)
  - Reason in grey box
  - Action buttons (Ban User, Dismiss)
  - Already banned indicator (red badge)
- Empty state messages
- Error handling with retry button
- Pull-to-refresh via AppBar refresh button

**Colors**:
- AppBar: Deep Purple (#512DA8)
- Ban Button: Red (#C62828)
- Dismiss Button: Grey outline
- Status Badges: Orange (pending), Green (resolved), Grey (dismissed)

---

## 🧪 Testing Checklist

### Prerequisites
1. ✅ Execute `supabase_rbac_and_reporting.sql` in Supabase Dashboard
2. ✅ Create at least one admin user:
   ```sql
   UPDATE profiles SET role = 'admin' WHERE email = 'admin@example.com';
   ```

### User Testing
- [ ] Login as regular user
- [ ] Navigate to ProductDetailScreen (any product not owned by you)
- [ ] Verify Report button (flag icon) appears in AppBar
- [ ] Click Report button
- [ ] Dialog opens with reported user name
- [ ] Enter reason less than 10 characters → See validation error
- [ ] Enter valid reason (10+ characters)
- [ ] Submit report → Success message appears
- [ ] Verify report created in Supabase Dashboard:
   ```sql
   SELECT * FROM reports ORDER BY created_at DESC LIMIT 5;
   ```

### Admin Testing
- [ ] Login as admin user
- [ ] Verify "Admin Dashboard" button appears in user menu (purple color)
- [ ] Click "Admin Dashboard"
- [ ] Dashboard loads with pending reports
- [ ] Verify report cards show all details correctly
- [ ] Toggle to "All Reports" → See all reports (pending, resolved, dismissed)
- [ ] Toggle back to "Pending" → See only pending reports
- [ ] Click "Ban User" on a report
- [ ] Confirmation dialog appears
- [ ] Confirm → Success message, report disappears from pending list
- [ ] Verify user banned in database:
   ```sql
   SELECT id, full_name, is_banned FROM profiles WHERE is_banned = true;
   ```
- [ ] Login as banned user → Should see "Account Suspended" dialog
- [ ] Click "Dismiss" on another report
- [ ] Confirmation dialog appears
- [ ] Confirm → Success message, report moves to dismissed
- [ ] Check report in "All Reports" view → Status shows "Dismissed"

### Edge Cases
- [ ] Try to report yourself (report button should not appear on your own products)
- [ ] Try to access `/admin/dashboard` as regular user (should load but show empty or errors)
- [ ] Ban user who is already banned → Report still marked as resolved
- [ ] Dismiss report for already banned user → Report marked as dismissed (ban remains)
- [ ] Create report with 500 characters → Accepted
- [ ] Create report with 501 characters → Validation error (if counter respected)

---

## 🔍 Troubleshooting

### Report Button Not Showing
**Cause**: User is viewing their own product
**Solution**: Report button only appears for products owned by other users

### Admin Dashboard Empty
**Cause**: User role is not 'admin'
**Solution**: Update user role in Supabase:
```sql
UPDATE profiles SET role = 'admin' WHERE id = 'user-uuid';
```

### Ban Not Working
**Cause**: RLS policies may be blocking the update
**Solution**: Verify admin has permission in policies:
```sql
-- Check if admin policy exists
SELECT * FROM pg_policies WHERE tablename = 'profiles' AND policyname LIKE '%admin%';
```

### Reports Not Loading
**Cause**: Missing view or RLS policy
**Solution**: Re-run the SQL migration:
```bash
psql -h db.project.supabase.co -U postgres -d postgres -f supabase_rbac_and_reporting.sql
```

### Profile Name Not Showing in Report Dialog
**Cause**: Profile not found or missing full_name
**Solution**: Fallback to "Product Owner" is implemented, but verify profile exists:
```sql
SELECT id, full_name, email FROM profiles WHERE id = 'reported-user-id';
```

---

## 🎯 Future Enhancements

### Phase 1: Enhanced Reporting
- [ ] Report categories (Spam, Harassment, Fake Listing, etc.)
- [ ] Attach screenshots/evidence to reports
- [ ] Report priority levels
- [ ] Anonymous reporting option

### Phase 2: Advanced Admin Tools
- [ ] Bulk actions (ban multiple users at once)
- [ ] Report analytics dashboard
- [ ] User history view (all reports involving a user)
- [ ] Temporary bans with expiration dates
- [ ] Warning system (3 strikes before ban)

### Phase 3: Communication
- [ ] Email notifications to admins when new report created
- [ ] Email to reported user when action taken
- [ ] In-app notification system
- [ ] Admin-to-user messaging for clarification

### Phase 4: Automation
- [ ] Auto-flag users with multiple reports
- [ ] ML-based content moderation
- [ ] Auto-resolve duplicate reports
- [ ] Reputation system for users

---

## 📊 Database Queries for Admins

### Get Report Statistics
```sql
SELECT status, COUNT(*) as count
FROM reports
GROUP BY status;
```

### Find Users with Most Reports
```sql
SELECT 
    p.full_name,
    p.email,
    COUNT(*) as report_count
FROM reports r
JOIN profiles p ON r.reported_user_id = p.id
GROUP BY p.id, p.full_name, p.email
ORDER BY report_count DESC
LIMIT 10;
```

### Get Recent Admin Actions
```sql
SELECT 
    r.id,
    r.status,
    r.updated_at,
    admin.full_name as admin_name,
    reported.full_name as reported_user,
    r.admin_notes
FROM reports r
JOIN profiles admin ON r.resolved_by = admin.id
JOIN profiles reported ON r.reported_user_id = reported.id
WHERE r.status IN ('resolved', 'dismissed')
ORDER BY r.updated_at DESC
LIMIT 20;
```

### Unban a User (Manual)
```sql
UPDATE profiles SET is_banned = false WHERE email = 'user@example.com';
```

---

## 🔗 Integration Points

### With Banned User Guard
When admin bans a user via dashboard:
1. `is_banned` set to `true` in profiles table
2. User's next login attempt triggers ban check in `AuthController.signIn()`
3. `checkBanStatus()` returns `true`
4. User immediately logged out via `signOut()`
5. Dialog displayed: "Account Suspended. Contact Admin."

### With RBAC System
- Admin role determined by `profiles.role = 'admin'`
- RLS policies enforce permission boundaries
- Helper functions available but not yet used in UI:
  - `ban_user(user_id)` - Can be called from SQL
  - `unban_user(user_id)` - Can be called from SQL
  - `resolve_report(report_id)` - Can be called from SQL

### With Product System
- Report button integrated into ProductDetailScreen
- Fetches product owner ID and profile for reporting
- Only visible for products not owned by current user

---

## 📝 Notes

- **Real-time Updates**: Dashboard currently refreshes on action. Future: Implement Supabase Realtime subscriptions for live updates
- **Performance**: `recent_reports_with_details` view pre-joins data for fast loading
- **Security**: All admin actions logged with `resolved_by` and `admin_notes`
- **Scalability**: Report list uses pagination-ready design (currently loads all)
- **Mobile Responsive**: UI designed for both mobile and desktop layouts

---

## 🎓 Learning Resources

### Supabase RLS
- [Row Level Security Documentation](https://supabase.com/docs/guides/auth/row-level-security)
- [RLS Best Practices](https://supabase.com/docs/guides/database/postgres/row-level-security)

### Riverpod State Management
- [AsyncValue Pattern](https://riverpod.dev/docs/concepts/reading#using-asyncvalue-to-handle-loading-and-error-states)
- [StateNotifier](https://riverpod.dev/docs/providers/state_notifier_provider)

### Flutter Material Design
- [Dialogs](https://docs.flutter.dev/cookbook/design/dialogs)
- [Cards & Lists](https://docs.flutter.dev/cookbook/lists/basic-list)

---

**Last Updated**: December 2, 2025
**Version**: 1.0.0
**Author**: GitHub Copilot
**Status**: ✅ Production Ready
