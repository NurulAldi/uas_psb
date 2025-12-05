# 🚀 Admin Dashboard & Reporting - Quick Start Guide

## ⚡ Setup (5 minutes)

### 1. Database Setup
Run SQL migration in Supabase Dashboard:
```sql
-- Already done! Check: supabase_rbac_and_reporting.sql
-- This created:
-- ✅ reports table
-- ✅ recent_reports_with_details view
-- ✅ RLS policies
```

### 2. Create Admin User
```sql
UPDATE profiles 
SET role = 'admin' 
WHERE email = 'your-admin-email@example.com';
```

### 3. Done! ✨
All UI components are already integrated.

---

## 🎯 User Side: How to Report

1. **Open any product** (that you don't own)
2. **Look for flag icon** in top-right corner
3. **Click flag** → Report dialog opens
4. **Enter reason** (minimum 10 characters)
5. **Submit** → Done!

**What happens next?**
- Report saved to database with status="pending"
- Admin receives notification (in dashboard)
- Your identity is recorded but shown only to admin

---

## 👑 Admin Side: How to Manage Reports

### Access Dashboard
1. **Login as admin**
2. **Click user menu** (avatar in top-right)
3. **Select "Admin Dashboard"** (purple text)

### View Reports
- **Pending tab**: Unresolved reports only
- **All Reports tab**: Complete history

### Take Action

#### Option A: Ban User
```
1. Click "Ban User" button (red)
2. Confirm in dialog
3. User banned immediately
4. Report marked as "resolved"
```

**Result**: User cannot login anymore (see ban dialog)

#### Option B: Dismiss Report
```
1. Click "Dismiss" button (grey)
2. Confirm in dialog
3. Report marked as "dismissed"
4. No action taken
```

**Result**: Report closed without banning

---

## 🧪 Test It Now!

### Test Reporting (2 minutes)
```bash
# 1. Login as User A
# 2. Find product owned by User B
# 3. Click flag icon → Submit report
# 4. Check database:
```
```sql
SELECT * FROM reports ORDER BY created_at DESC LIMIT 1;
```

### Test Admin Dashboard (3 minutes)
```bash
# 1. Set yourself as admin:
```
```sql
UPDATE profiles SET role = 'admin' WHERE email = 'your-email@example.com';
```
```bash
# 2. Logout and login again
# 3. Check user menu → Should see "Admin Dashboard"
# 4. Click it → See your test report
# 5. Try "Ban User" → Check user got banned:
```
```sql
SELECT email, is_banned FROM profiles WHERE is_banned = true;
```

### Test Ban Enforcement (1 minute)
```bash
# 1. Logout
# 2. Try logging in as banned user
# 3. Should see: "Account Suspended. Contact Admin."
```

---

## 📊 Quick SQL Queries

### View All Reports
```sql
SELECT 
    reporter_email,
    reported_user_email,
    reason,
    status,
    created_at
FROM recent_reports_with_details
ORDER BY created_at DESC;
```

### Ban a User (Manual)
```sql
UPDATE profiles SET is_banned = true WHERE email = 'bad-user@example.com';
```

### Unban a User (Manual)
```sql
UPDATE profiles SET is_banned = false WHERE email = 'unbanned-user@example.com';
```

### Get Report Stats
```sql
SELECT status, COUNT(*) FROM reports GROUP BY status;
```

---

## 🎨 UI Overview

### Report Button (User)
- **Location**: ProductDetailScreen AppBar
- **Icon**: Flag (red color)
- **Visibility**: Only on other users' products

### Report Dialog (User)
- **Title**: "Report User" with flag icon
- **Fields**: Reason (10-500 chars)
- **Buttons**: Cancel | Submit Report (red)

### Admin Dashboard
- **Header**: Deep purple gradient
- **Tabs**: Pending | All Reports
- **Actions**: Ban User (red) | Dismiss (grey)
- **Status**: Color-coded badges

---

## ⚠️ Common Issues

### "Admin Dashboard not showing"
**Fix**: Update your role to admin
```sql
UPDATE profiles SET role = 'admin' WHERE id = 'YOUR-USER-ID';
```

### "Report button missing"
**Reason**: You're viewing your own product (can't report yourself)

### "Ban not working"
**Check**: RLS policies are active
```sql
SELECT * FROM pg_policies WHERE tablename = 'profiles';
```

### "Reports not loading"
**Fix**: Re-run migration
```bash
# In Supabase SQL Editor:
# Paste content of supabase_rbac_and_reporting.sql
# Execute
```

---

## 🎯 Next Steps

### For Users
- Browse products and report violations
- Check your own reports (future feature)
- Appeal bans (future feature)

### For Admins
- Review pending reports daily
- Document ban reasons in admin_notes
- Monitor report statistics
- Create admin workflows

### For Developers
- Add email notifications
- Implement real-time updates
- Add report analytics
- Build user reputation system

---

## 📞 Quick Reference

| Action | Route | Access |
|--------|-------|--------|
| Report User | Product Detail → Flag Icon | Any User |
| Admin Dashboard | Home Menu → "Admin Dashboard" | Admin Only |
| Ban User | Dashboard → Report Card → "Ban User" | Admin Only |
| Dismiss Report | Dashboard → Report Card → "Dismiss" | Admin Only |

| Database Table | Purpose |
|---------------|---------|
| `reports` | Store all user reports |
| `profiles` | User data (includes role, is_banned) |
| `recent_reports_with_details` | View for dashboard (pre-joined) |

| Status | Meaning |
|--------|---------|
| pending | Awaiting admin review |
| resolved | Admin took action (ban) |
| dismissed | Admin rejected report |

---

**🎉 You're all set!** Start managing your community like a pro.

**Questions?** Check `ADMIN_DASHBOARD_REPORTING.md` for full documentation.

**Last Updated**: December 2, 2025
