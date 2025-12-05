-- =====================================================
-- Supabase Storage Setup for Product Images
-- Run this in Supabase SQL Editor OR Dashboard Storage UI
-- =====================================================

-- NOTE: Storage buckets are typically created via Dashboard UI,
-- but policies can be set via SQL.

-- If bucket doesn't exist yet, create it manually in Dashboard:
-- 1. Go to Storage in Supabase Dashboard
-- 2. Create new bucket: 'product-images'
-- 3. Set to PUBLIC bucket
-- 4. Then run the policies below

-- =====================================================
-- STORAGE POLICIES FOR 'product-images' BUCKET
-- =====================================================

-- Policy: Anyone can view/download product images (public bucket)
CREATE POLICY "Public Access"
ON storage.objects FOR SELECT
USING (bucket_id = 'product-images');

-- Policy: Authenticated users can upload images
CREATE POLICY "Authenticated users can upload"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'product-images' 
  AND auth.role() = 'authenticated'
);

-- Policy: Users can update their own images (optional)
CREATE POLICY "Users can update own images"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'product-images'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy: Users can delete their own images
CREATE POLICY "Users can delete own images"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'product-images'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- =====================================================
-- ALTERNATIVE: Create bucket via SQL (if supported)
-- =====================================================
-- Uncomment if your Supabase version supports this:
/*
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO NOTHING;
*/

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Check if bucket exists
-- SELECT * FROM storage.buckets WHERE id = 'product-images';

-- Check policies
-- SELECT * FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage';

-- =====================================================
-- MANUAL SETUP INSTRUCTIONS (Recommended)
-- =====================================================

/*
1. Open Supabase Dashboard
2. Go to Storage section (left sidebar)
3. Click "Create Bucket"
4. Bucket name: product-images
5. Set to PUBLIC (toggle the switch)
6. Click Create
7. The policies above will be auto-applied for public buckets
*/

-- =====================================================
-- FOLDER STRUCTURE RECOMMENDATION
-- =====================================================

/*
Recommended path format in app:
/product-images/{userId}/{timestamp}_{filename}

Example:
/product-images/44e6712c-668e-46c5-ac36-8caac001693c/1701518400000_camera.jpg

Benefits:
- Easy to find user's images
- Easy to delete user's images
- Timestamp prevents conflicts
*/
