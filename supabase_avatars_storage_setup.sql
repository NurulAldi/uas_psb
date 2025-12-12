-- =====================================================
-- Supabase Storage Setup for User Avatars
-- Run this in Supabase Dashboard (Storage section)
-- =====================================================

-- =====================================================
-- MANUAL SETUP INSTRUCTIONS (Recommended)
-- =====================================================

/*
STEP 1: CREATE BUCKET
1. Open Supabase Dashboard (https://app.supabase.com)
2. Select your project
3. Go to Storage section (left sidebar)
4. Click "New bucket" button
5. Bucket name: avatars (exactly as shown)
6. Set to PUBLIC (toggle the "Public bucket" switch ON)
7. Click "Create bucket"

STEP 2: VERIFY BUCKET
1. Click on the "avatars" bucket
2. You should see an empty folder view
3. The bucket URL should be: https://[your-project].supabase.co/storage/v1/object/public/avatars

STEP 3: SET POLICIES (Run SQL below)
1. Go to SQL Editor (left sidebar)
2. Copy and paste the policies below
3. Click "Run"

TROUBLESHOOTING:
- If getting 404 errors: Bucket doesn't exist, recreate it
- If getting 400 errors: Check if bucket is set to PUBLIC
- If getting 403 errors: Check RLS policies below are applied
- To test: Upload a test image manually in the Storage UI
*/

-- =====================================================
-- STORAGE POLICIES FOR 'avatars' BUCKET
-- =====================================================

-- Policy: Anyone can view avatars (public bucket)
CREATE POLICY "Public Access"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

-- Policy: Authenticated users can upload their own avatar
CREATE POLICY "Users can upload own avatar"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'avatars' 
  AND auth.role() = 'authenticated'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Users can update their own avatar
CREATE POLICY "Users can update own avatar"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Users can delete their own avatar
CREATE POLICY "Users can delete own avatar"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- =====================================================
-- FOLDER STRUCTURE
-- =====================================================

/*
Recommended path format:
/avatars/{userId}/avatar_{timestamp}.jpg

Example:
/avatars/44e6712c-668e-46c5-ac36-8caac001693c/avatar_1703001234567.jpg

Benefits:
- One folder per user
- Easy to delete old avatars
- Timestamp prevents caching issues
*/

-- =====================================================
-- VERIFICATION
-- =====================================================

-- Check if bucket exists
-- SELECT * FROM storage.buckets WHERE id = 'avatars';

-- Check policies
-- SELECT * FROM storage.policies WHERE bucket_id = 'avatars';
