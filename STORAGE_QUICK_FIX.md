# 🔧 Supabase Storage Quick Fix - Error 400/404

## ⚡ Quick Diagnosis

Jika melihat error seperti ini:
```
❌ Avatar error in HomeScreen: HttpException: Invalid statusCode: 400
```

**Root Cause:** Storage bucket `avatars` belum dikonfigurasi dengan benar di Supabase.

---

## ✅ 5-Minute Fix

### Step 1: Create Storage Bucket (2 min)

1. Buka **Supabase Dashboard**: https://app.supabase.com
2. Pilih project Anda
3. Klik **Storage** di sidebar kiri
4. Klik tombol **"New bucket"**
5. Isi form:
   - **Name:** `avatars` (must be exact)
   - **Public bucket:** ✅ **Toggle ON** (PENTING!)
   - **File size limit:** 5MB (optional)
   - **Allowed MIME types:** image/* (optional)
6. Klik **"Create bucket"**

### Step 2: Verify Bucket (30 sec)

1. Klik pada bucket **"avatars"** yang baru dibuat
2. Pastikan ada label **"PUBLIC"** di samping nama bucket
3. URL bucket harus: `https://[your-project].supabase.co/storage/v1/object/public/avatars`

### Step 3: Set RLS Policies (2 min)

1. Go to **SQL Editor** (sidebar kiri)
2. Click **"+ New query"**
3. Copy-paste SQL berikut:

```sql
-- Public read access (anyone can view avatars)
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

4. Click **"Run"** atau tekan `Ctrl+Enter`
5. Should see "Success. No rows returned"

### Step 4: Test (30 sec)

1. Hot reload Flutter app (`r` di terminal)
2. Login ke aplikasi
3. Go to home screen
4. Avatar should display atau show fallback icon (without error 400)
5. Try upload new avatar di Edit Profile

---

## 🧪 Manual Verification

### Test 1: Upload File via Dashboard

1. Go to **Storage → avatars**
2. Click **"Upload file"**
3. Create folder: Type your user ID (UUID format)
4. Upload any image file
5. Click on uploaded file
6. Click **"Get URL"**
7. Copy URL dan paste di browser
8. **✅ Success:** Image displays
9. **❌ Failed:** See troubleshooting below

### Test 2: Check Policies

1. Go to **Storage → avatars**
2. Click **"Policies"** tab
3. Should see 4 policies:
   - ✅ Public Access (SELECT)
   - ✅ Users can upload own avatar (INSERT)
   - ✅ Users can update own avatar (UPDATE)
   - ✅ Users can delete own avatar (DELETE)

### Test 3: App Upload

1. Run app
2. Login
3. Edit Profile → Upload avatar
4. Check console logs for:
```
📤 AVATAR UPLOAD: Starting upload...
🔍 AVATAR SERVICE: Verifying bucket "avatars"...
✅ AVATAR SERVICE: Bucket found
   Bucket ID: avatars
   Public: true
✅ AVATAR UPLOAD: File uploaded successfully
✅ AVATAR UPLOAD: Public URL generated
```

---

## 🐛 Troubleshooting

### Error: "Bucket not found"

**Symptoms:**
```
❌ AVATAR SERVICE: Bucket verification failed
   Solution: Create bucket "avatars" in Supabase Dashboard
```

**Fix:**
1. Go to Storage → New bucket
2. Name: `avatars` (lowercase, exact spelling)
3. Public: ON
4. Create

### Error: "Bucket is NOT public"

**Symptoms:**
```
⚠️ AVATAR SERVICE: WARNING - Bucket is NOT public!
```

**Fix:**
1. Go to Storage → avatars
2. Click settings icon (⚙️)
3. Toggle **"Public bucket"** to **ON**
4. Save changes

### Error 400: Still getting errors after setup

**Possible causes:**
1. **Bucket not actually public** → Re-check settings
2. **Policies not applied** → Re-run SQL
3. **Cache issue** → Clear browser cache or try incognito
4. **Wrong project** → Verify `.env` has correct Supabase URL

**Debug steps:**
```bash
1. Check .env file:
   SUPABASE_URL=https://xxxxx.supabase.co
   
2. Match xxxxx with Dashboard URL

3. Go to Dashboard → Project Settings → API
   Verify URL matches .env

4. Hot restart app:
   flutter run --hot
```

### Error 404: File not found

**Symptoms:**
```
❌ Avatar load failed: HttpException: Invalid statusCode: 404
```

**Causes:**
- File was deleted from storage
- URL format is wrong
- User uploaded but file didn't save

**Fix:**
1. Check Storage → avatars → [user-id] folder
2. Verify file exists
3. Try re-uploading avatar
4. Check URL format:
   ```
   https://[project].supabase.co/storage/v1/object/public/avatars/[user-id]/avatar_[timestamp].jpg
   ```

### Error 403: Forbidden

**Symptoms:**
```
❌ Avatar load failed: HttpException: Invalid statusCode: 403
```

**Causes:**
- RLS policies too restrictive
- User not authenticated
- Trying to access other user's private folder

**Fix:**
1. Re-run RLS policies SQL
2. Ensure user is logged in
3. Check folder name matches user ID

---

## 📋 Checklist

Before running app, verify:

- [ ] Bucket `avatars` exists in Supabase Storage
- [ ] Bucket is set to **PUBLIC**
- [ ] 4 RLS policies are applied (check Policies tab)
- [ ] `.env` file has correct `SUPABASE_URL`
- [ ] App is hot reloaded/restarted
- [ ] User is authenticated when testing upload

---

## 🎯 Expected Behavior After Fix

### Upload Avatar:
1. ✅ Select image from gallery/camera
2. ✅ See preview immediately
3. ✅ Click "Save Changes"
4. ✅ Console shows upload progress with logs
5. ✅ Success message displayed
6. ✅ Stay on Edit Profile page
7. ✅ Avatar auto-refreshes

### View Avatar:
1. ✅ Avatar displays in home screen (top-right)
2. ✅ Avatar displays in edit profile page
3. ✅ If load fails → shows fallback icon (👤)
4. ✅ Error logged to console (for debugging)
5. ✅ No error 400/404 thrown to user

### Navigation:
1. ✅ Edit profile from home menu
2. ✅ Update profile + avatar
3. ✅ Stay on profile page (not redirect)
4. ✅ Back button → return to home
5. ✅ Avatar visible on home screen

---

## 📱 Testing Checklist

Run these tests after setup:

1. **Fresh Upload:**
   - [ ] New user registers
   - [ ] Edit profile → Upload avatar
   - [ ] Avatar appears immediately

2. **Replace Avatar:**
   - [ ] Existing user with avatar
   - [ ] Edit profile → Change avatar
   - [ ] Old avatar replaced
   - [ ] New avatar displays

3. **Network Error Handling:**
   - [ ] Turn off internet
   - [ ] Open profile page
   - [ ] Should show fallback icon
   - [ ] No app crash

4. **Invalid URL:**
   - [ ] Manually set invalid avatar_url in database
   - [ ] Open profile
   - [ ] Shows fallback icon
   - [ ] Error logged but app works

---

## 🔗 Related Files

### Code Files:
- `lib/features/auth/data/services/avatar_upload_service.dart` - Upload logic
- `lib/features/auth/presentation/widgets/user_avatar.dart` - Display widget
- `lib/features/home/presentation/screens/home_screen.dart` - Home avatar
- `lib/features/auth/presentation/screens/edit_profile_page.dart` - Edit page

### SQL Files:
- `supabase_avatars_storage_setup.sql` - Full setup guide
- `supabase_storage_setup.sql` - Product images setup

### Documentation:
- `AVATAR_DEBUG_GUIDE.md` - Detailed debugging guide
- `STORAGE_QUICK_FIX.md` - This file (quick fix)

---

## 💡 Pro Tips

1. **Always check bucket is PUBLIC** - Most common issue
2. **Use Dashboard upload first** - Verify bucket works before app test
3. **Check console logs** - New detailed logging helps diagnose issues
4. **Clear cache if needed** - Browser/app cache may show old errors
5. **Verify .env matches Dashboard** - Wrong project URL = connection fail

---

## 🆘 Still Not Working?

If avatar still not loading after all steps:

1. **Check logs in Flutter console** - Look for detailed error messages
2. **Test URL in browser** - Copy avatar URL and paste in browser
3. **Verify user ID** - Ensure folder name matches authenticated user ID
4. **Check Supabase project** - Ensure it's not paused/suspended
5. **Try different image** - Some formats may not be supported

**Get the URL from logs:**
```
✅ AVATAR UPLOAD: Public URL generated
   URL: https://xxxxx.supabase.co/storage/v1/object/public/avatars/...
```

Paste URL in browser:
- ✅ **Shows image** → App issue, not storage issue
- ❌ **404/400** → Storage configuration issue

---

## 📞 Need Help?

Check:
1. Supabase Dashboard → Project Settings → API (verify URL)
2. Storage → avatars → Policies (verify 4 policies exist)
3. Storage → avatars → Settings (verify Public is ON)
4. Flutter console logs (look for detailed error messages)

Run bucket verification in app to auto-diagnose issues! 🚀
