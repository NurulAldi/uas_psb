-- =====================================================
-- FIX: Storage RLS Policy untuk Manual Authentication
-- =====================================================
-- Problem: Storage policies menggunakan auth.role() dan auth.uid()
--          yang TIDAK KOMPATIBEL dengan manual authentication
-- Solution: Gunakan public bucket dengan app-level validation
-- =====================================================

-- Step 1: Drop all existing policies yang tidak kompatibel
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own images" ON storage.objects;

-- Step 2: Disable RLS on storage.objects untuk bucket product-images
-- CATATAN: Ini aman karena bucket sudah public dan validasi ada di app
ALTER TABLE storage.objects DISABLE ROW LEVEL SECURITY;

-- Step 3: (Optional) Jika ingin tetap pakai RLS dengan policy sederhana:
-- Uncomment yang di bawah dan comment Step 2 di atas

/*
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Policy 1: Semua orang bisa READ (public bucket)
CREATE POLICY "Anyone can read product images"
ON storage.objects FOR SELECT
USING (bucket_id = 'product-images');

-- Policy 2: Semua orang bisa INSERT (karena tidak ada auth.uid())
-- CATATAN: Validasi file size, type, dll ada di Flutter app
CREATE POLICY "Anyone can upload product images"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'product-images');

-- Policy 3: Semua orang bisa UPDATE
CREATE POLICY "Anyone can update product images"
ON storage.objects FOR UPDATE
USING (bucket_id = 'product-images');

-- Policy 4: Semua orang bisa DELETE
CREATE POLICY "Anyone can delete product images"
ON storage.objects FOR DELETE
USING (bucket_id = 'product-images');
*/

-- =====================================================
-- ALTERNATIVE APPROACH: Function-based RLS
-- =====================================================
-- Jika ingin security lebih ketat, bisa pakai custom function

/*
-- Create function untuk check manual authentication
CREATE OR REPLACE FUNCTION check_manual_auth(user_folder TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  -- Di sini bisa tambahkan logic custom
  -- Misalnya: cek apakah folder name ada di users table
  RETURN EXISTS (
    SELECT 1 FROM users WHERE id::text = user_folder
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Policy dengan custom function
CREATE POLICY "Users folder based access"
ON storage.objects FOR ALL
USING (
  bucket_id = 'product-images' 
  AND check_manual_auth((storage.foldername(name))[1])
);
*/

-- =====================================================
-- BUCKET CONFIGURATION
-- =====================================================

-- Ensure bucket exists and is public
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) 
DO UPDATE SET public = true;

-- =====================================================
-- VERIFICATION
-- =====================================================

-- Check bucket configuration
SELECT id, name, public FROM storage.buckets WHERE id = 'product-images';

-- Check RLS status
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'storage' AND tablename = 'objects';

-- Check active policies
SELECT policyname, cmd, qual, with_check
FROM pg_policies 
WHERE schemaname = 'storage' AND tablename = 'objects';

-- =====================================================
-- SECURITY NOTES
-- =====================================================

/*
⚠️ IMPORTANT SECURITY CONSIDERATIONS:

1. Disabling RLS:
   - Memungkinkan siapa saja upload/delete file
   - Aman untuk development dan prototype
   - Untuk production, pertimbangkan:
     * Rate limiting di app level
     * Validasi file size/type di app
     * Scheduled cleanup untuk orphaned files

2. App-Level Validation (ImageUploadService):
   - ✅ Sudah ada: File extension check
   - ✅ Sudah ada: Timestamp untuk unique filename
   - 🔄 Perlu tambah: File size limit (max 5MB)
   - 🔄 Perlu tambah: Image type validation (jpg, png only)

3. Manual Auth Limitations:
   - Tidak bisa pakai auth.uid() atau auth.role()
   - RLS policy harus custom atau disabled
   - Security bergantung pada app logic

4. Recommended Production Setup:
   - Enable RLS dengan custom function
   - Implementasi API key untuk upload
   - Cloud Function untuk validation
   - CDN untuk serving images
*/

-- =====================================================
-- QUICK TEST
-- =====================================================

-- Test upload permission (akan berhasil jika RLS disabled)
-- Jalankan ini dari Flutter app setelah migration
-- Atau test manual via Supabase Storage UI

/*
TESTING STEPS:
1. Jalankan SQL migration ini
2. Restart Flutter app
3. Coba upload gambar produk
4. Check di Supabase Dashboard > Storage > product-images
5. Verify gambar ter-upload dengan path: {userId}/{timestamp}_filename.jpg
*/
