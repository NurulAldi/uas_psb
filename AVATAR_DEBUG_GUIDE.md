# Avatar Upload & Display Debug Guide

## 🔍 Problem: Avatar tidak muncul (Error 400 atau 404)

### Root Cause Analysis

Error 400/404 saat load avatar biasanya disebabkan oleh:

1. **Storage bucket `avatars` belum dibuat**
2. **Bucket tidak diset sebagai PUBLIC**
3. **RLS Policies tidak diterapkan dengan benar**
4. **URL format salah atau file tidak exist**

---

## ✅ Fix Implementation

### 1. **Edit Profile Page - Stay on Page After Update**

**Problem:** Setelah update profile, aplikasi redirect ke home

**Solution:** Remove `context.pop()` dan reset local state

```dart
// BEFORE (❌)
if (success && mounted) {
  ScaffoldMessenger.of(context).showSnackBar(...);
  context.pop(true); // ❌ This redirects to previous page
}

// AFTER (✅)
if (success && mounted) {
  ScaffoldMessenger.of(context).showSnackBar(...);
  // Stay on the page - profile auto-refresh via provider
  setState(() {
    _hasChanges = false;
    _selectedImageFile = null;
  });
}
```

### 2. **Avatar Loading - Better Error Handling**

**Problem:** `CachedNetworkImageProvider` tidak menampilkan error dengan jelas

**Solution:** Gunakan `CachedNetworkImage` widget dengan `errorWidget`

```dart
// BEFORE (❌)
backgroundImage: CachedNetworkImageProvider(avatarUrl)

// AFTER (✅)
child: CachedNetworkImage(
  imageUrl: avatarUrl,
  imageBuilder: (context, imageProvider) => Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
    ),
  ),
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) {
    print('❌ Avatar load error: $error');
    print('   Avatar URL: $url');
    return Icon(Icons.person);
  },
)
```

### 3. **Avatar Upload Service - Enhanced Debugging**

Added comprehensive logging untuk track upload process:

```dart
print('📤 AVATAR UPLOAD: Starting upload...');
print('   User ID: $userId');
print('   File: ${imageFile.path}');
print('   Target path: $filePath');
// ... upload ...
print('✅ AVATAR UPLOAD: Public URL generated');
print('   URL: $publicUrl');
```

---

## 🛠️ Setup Checklist

### Step 1: Create Storage Bucket

1. Buka **Supabase Dashboard** → https://app.supabase.com
2. Pilih project Anda
3. Klik **Storage** (sidebar kiri)
4. Klik tombol **"New bucket"**
5. Isi form:
   - **Name:** `avatars` (harus exact)
   - **Public bucket:** ✅ ON (toggle switch)
6. Klik **"Create bucket"**

### Step 2: Verify Bucket

1. Klik bucket **avatars**
2. Pastikan bisa melihat empty folder view
3. URL bucket: `https://[project-ref].supabase.co/storage/v1/object/public/avatars`

### Step 3: Apply RLS Policies

Buka **SQL Editor** dan run:

```sql
-- Public read access
CREATE POLICY "Public Access"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

-- Users can upload to their own folder
CREATE POLICY "Users can upload own avatar"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'avatars' 
  AND auth.role() = 'authenticated'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Users can update their own files
CREATE POLICY "Users can update own avatar"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Users can delete their own files
CREATE POLICY "Users can delete own avatar"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

### Step 4: Test Upload

1. Run aplikasi
2. Login dengan user
3. Go to Edit Profile
4. Upload foto
5. Check logs untuk debug output

---

## 🐛 Troubleshooting

### Error 400: Bad Request

**Kemungkinan penyebab:**
- Bucket tidak diset PUBLIC
- File path format salah
- RLS policy terlalu strict

**Fix:**
```bash
1. Go to Storage → avatars bucket
2. Click settings (gear icon)
3. Ensure "Public" is toggled ON
4. Check RLS policies applied
```

### Error 404: Not Found

**Kemungkinan penyebab:**
- Bucket `avatars` belum dibuat
- Bucket name typo
- File doesn't exist

**Fix:**
```bash
1. Verify bucket exists: Storage → check "avatars" bucket
2. Check bucket name exactly: "avatars" (lowercase)
3. Try manual upload in Dashboard first
```

### Error 403: Forbidden

**Kemungkinan penyebab:**
- RLS policies tidak applied
- User tidak authenticated
- Trying to access other user's folder

**Fix:**
```sql
-- Re-run policies in SQL Editor
-- Check auth.uid() matches folder name
```

### Avatar tidak muncul setelah upload

**Debug steps:**
1. Check Flutter logs untuk error messages
2. Verify URL format:
   ```
   https://[project].supabase.co/storage/v1/object/public/avatars/[user-id]/avatar_[timestamp].jpg
   ```
3. Test URL di browser - should show image
4. Check if `currentUserProfileProvider` invalidated

---

## 📝 Debug Logs

Saat upload avatar, logs akan seperti ini:

```
📤 AVATAR UPLOAD: Starting upload...
   User ID: 44e6712c-668e-46c5-ac36-8caac001693c
   File: /data/user/0/.../image_picker123.jpg
   Target path: 44e6712c-668e-46c5-ac36-8caac001693c/avatar_1734712345678.jpg
✅ AVATAR UPLOAD: File uploaded successfully
✅ AVATAR UPLOAD: Public URL generated
   URL: https://hyufqtxfjgfcobdsjkjr.supabase.co/storage/v1/object/public/avatars/44e6712c-668e-46c5-ac36-8caac001693c/avatar_1734712345678.jpg
```

Jika load gagal:
```
❌ Avatar load error: HttpException: Invalid statusCode: 400
   Avatar URL: https://...
```

---

## 🎯 Quick Test

### Manual Test Upload

1. **Supabase Dashboard:**
   - Go to Storage → avatars
   - Click "Upload file"
   - Create folder dengan format UUID user
   - Upload test image
   - Copy public URL

2. **Test URL:**
   - Paste URL di browser
   - Should display image immediately
   - If 404/400: Bucket not PUBLIC

3. **Test in App:**
   - Update user profile di database dengan URL
   - Refresh app
   - Avatar should display

---

## 🔄 Files Modified

1. **`lib/features/auth/presentation/screens/edit_profile_page.dart`**
   - ✅ Remove `context.pop()` - stay on page after update
   - ✅ Replace `CachedNetworkImageProvider` with `CachedNetworkImage` widget
   - ✅ Add error handling and debugging

2. **`lib/features/home/presentation/screens/home_screen.dart`**
   - ✅ Replace `CachedNetworkImageProvider` with `CachedNetworkImage` widget
   - ✅ Add error widget for avatar loading failures

3. **`lib/features/auth/data/services/avatar_upload_service.dart`**
   - ✅ Add comprehensive logging
   - ✅ Add URL validation
   - ✅ Better error messages

4. **`supabase_avatars_storage_setup.sql`**
   - ✅ Enhanced setup instructions
   - ✅ Added troubleshooting guide

---

## 📱 Expected Behavior

### After Fix:

1. **Upload avatar:**
   - Select image dari gallery/camera
   - See preview immediately
   - Click "Save Changes"
   - Show success snackbar
   - **Stay on Edit Profile page** (not redirect to home)
   - Avatar auto-refresh

2. **View avatar:**
   - Avatar displays in home screen top-right
   - Avatar displays in edit profile page
   - If load fails, show fallback icon
   - Error logged to console

3. **Navigation:**
   - Edit profile from home menu
   - Update profile
   - **Stay on profile page**
   - Back button returns to home

---

## 🔗 Related Files

- **Edit Profile:** `lib/features/auth/presentation/screens/edit_profile_page.dart`
- **Home Screen:** `lib/features/home/presentation/screens/home_screen.dart`
- **Upload Service:** `lib/features/auth/data/services/avatar_upload_service.dart`
- **Storage Setup:** `supabase_avatars_storage_setup.sql`

---

## ⚡ Next Steps

1. **Run the app** dengan hot reload
2. **Check Supabase Dashboard** - ensure `avatars` bucket exists and is PUBLIC
3. **Apply RLS policies** dari SQL file
4. **Test upload** dan monitor logs
5. **Verify avatar displays** di home dan profile page

Jika masih error, check logs dan verify storage bucket setup! 🎯
