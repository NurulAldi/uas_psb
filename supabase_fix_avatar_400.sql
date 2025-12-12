-- =====================================================
-- FIX: Avatar Storage Error 400
-- Run this if you're getting 400 errors even with policies
-- =====================================================

-- Step 1: Drop ALL existing policies for avatars bucket
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own avatar" ON storage.objects;

-- Step 2: Recreate policies with correct permissions

-- Public read access (MUST include TO public)
CREATE POLICY "Public Access"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'avatars');

-- Authenticated users can upload to their own folder
CREATE POLICY "Users can upload own avatar"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'avatars' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Users can update their own files
CREATE POLICY "Users can update own avatar"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Users can delete their own files
CREATE POLICY "Users can delete own avatar"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Check if policies are applied correctly
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'objects'
  AND policyname LIKE '%avatar%'
ORDER BY policyname;

-- Expected output:
-- Should see 4 policies:
-- 1. Public Access (SELECT, {public})
-- 2. Users can delete own avatar (DELETE, {authenticated})
-- 3. Users can update own avatar (UPDATE, {authenticated})
-- 4. Users can upload own avatar (INSERT, {authenticated})

-- =====================================================
-- ALTERNATIVE: Check bucket configuration
-- =====================================================

-- Verify bucket exists and is public
SELECT 
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
FROM storage.buckets
WHERE name = 'avatars';

-- Expected output:
-- public column should be: true
-- If public = false, run this:
-- UPDATE storage.buckets SET public = true WHERE name = 'avatars';

