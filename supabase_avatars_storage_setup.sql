-- =====================================================
-- Supabase Storage Setup for User Avatars
-- Run this in Supabase Dashboard (Storage section)
-- =====================================================

-- =====================================================
-- MANUAL SETUP INSTRUCTIONS (Recommended)
-- =====================================================

/*
1. Open Supabase Dashboard
2. Go to Storage section (left sidebar)
3. Click "Create Bucket"
4. Bucket name: avatars
5. Set to PUBLIC (toggle the switch)
6. Click Create
7. The policies below will be auto-applied for public buckets
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
