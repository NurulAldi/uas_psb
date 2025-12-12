# Multiple Images & Zoom Feature - Quick Guide

## 🎯 Overview
Implementasi fitur upload multiple images (hingga 5 gambar) untuk produk dengan tampilan full-scale (tidak ada crop) dan kemampuan zoom in/out.

## 📋 What's Changed

### 1. **Product Model Update**
- ✅ Menambahkan `List<String> imageUrls` untuk support multiple images
- ✅ Backward compatible dengan `imageUrl` yang lama
- ✅ Auto-migration dari single image ke array

### 2. **Image Upload Service**
- ✅ `uploadMultipleProductImages()` - Upload batch images
- ✅ `deleteMultipleProductImages()` - Hapus multiple images
- ✅ Higher quality (85% compression vs 50%)

### 3. **Add/Edit Product Page**
- ✅ Multi-image picker (hingga 5 gambar)
- ✅ Horizontal scrollable preview
- ✅ Individual remove button per image
- ✅ Visual counter (X/5 images)
- ✅ Grid layout untuk preview images

### 4. **Product Detail Screen**
- ✅ Image gallery dengan PageView
- ✅ Thumbnail navigation di bawah
- ✅ Image counter (1/5)
- ✅ Zoom hint icon
- ✅ Full-scale display (fit: BoxFit.contain)
- ✅ Tap untuk buka fullscreen viewer

### 5. **Zoomable Image Viewer**
- ✅ Fullscreen image viewer
- ✅ Pinch to zoom (0.5x - 4x)
- ✅ Pan/drag image saat zoomed
- ✅ Swipe untuk ganti gambar
- ✅ Thumbnail navigation
- ✅ Image counter di AppBar

## 🗄️ Database Migration

### Run SQL Migration:
```sql
-- File: supabase_product_multiple_images.sql
-- Adds image_urls column and migrates existing data
```

**Steps:**
1. Buka Supabase Dashboard
2. Go to SQL Editor
3. Copy & paste `supabase_product_multiple_images.sql`
4. Run Query
5. Verify dengan: `SELECT id, name, image_url, image_urls FROM products LIMIT 10;`

## 🎨 Features

### Upload Multiple Images (Max 5)
- User bisa pilih multiple images sekaligus
- Visual feedback dengan counter (X/5)
- Preview grid horizontal scrollable
- Individual remove button

### Full-Scale Display (No Crop)
- Gambar ditampilkan dengan `BoxFit.contain`
- Tidak ada bagian yang ke-crop
- Aspect ratio tetap terjaga
- Background dengan warna neutral

### Zoom In/Out
- Tap gambar → fullscreen viewer
- Pinch gesture untuk zoom
- Min: 0.5x, Max: 4.0x
- Pan/drag saat zoomed
- Smooth transitions

### Gallery Navigation
- Swipe untuk ganti gambar
- Thumbnail navigation di bawah
- Selected thumbnail dengan border putih tebal
- Image counter (current/total)

## 📁 New Files

### 1. `lib/features/products/presentation/widgets/zoomable_image_viewer.dart`
Full-screen zoomable image viewer dengan:
- InteractiveViewer untuk zoom & pan
- PageView untuk multiple images
- Thumbnail navigation
- CachedNetworkImage untuk performance

### 2. `supabase_product_multiple_images.sql`
Database migration untuk:
- Add `image_urls TEXT[]` column
- Migrate existing `image_url` to array
- Add GIN index untuk performance

## 📝 Modified Files

### 1. `lib/features/products/domain/models/product.dart`
- Add `imageUrls` field
- Update `fromJson()` untuk support both formats
- Update `toJson()` untuk save both formats
- Update `copyWith()` method

### 2. `lib/features/products/data/services/image_upload_service.dart`
- Add `uploadMultipleProductImages()`
- Add `deleteMultipleProductImages()`
- Higher quality compression (85%)

### 3. `lib/features/products/data/repositories/product_repository.dart`
- Add `imageUrls` parameter di `createProduct()`
- Add `imageUrls` parameter di `updateProduct()`

### 4. `lib/features/products/providers/my_products_provider.dart`
- Add `imageUrls` parameter di controller methods

### 5. `lib/features/products/presentation/screens/add_product_page.dart`
- Replace single image picker dengan multiple
- New UI dengan grid preview
- Update upload logic untuk handle multiple images
- Visual counter (X/5)

### 6. `lib/features/products/presentation/screens/product_detail_screen.dart`
- Replace single image dengan gallery
- Add `_ImageGallery` widget
- PageView untuk swipe between images
- Thumbnail navigation
- Zoom hint icon
- Tap to open fullscreen

## 🚀 Usage

### For Product Owners (Adding Product):
1. Tap "Add Product"
2. Tap "Tap to select images" → pilih multiple images (max 5)
3. Preview muncul di horizontal scroll
4. Tap ❌ di gambar untuk remove
5. Tap "Add more images" jika belum 5
6. Fill form & save

### For Renters (Viewing Product):
1. Buka product detail
2. Swipe gambar atau tap thumbnail
3. Tap gambar untuk fullscreen
4. Pinch zoom untuk perbesar
5. Pan/drag saat zoomed
6. Swipe atau tap thumbnail untuk ganti gambar

## ✅ Benefits

### Untuk User:
- ✅ Informasi lebih lengkap (multiple angles)
- ✅ Tidak ada gambar terpotong
- ✅ Bisa zoom detail produk
- ✅ Smooth navigation antar gambar

### Untuk Owner:
- ✅ Upload hingga 5 gambar
- ✅ Showcase produk lebih baik
- ✅ Tingkatkan kepercayaan calon penyewa
- ✅ Easy to manage images

## 🔧 Technical Details

### Image Quality:
- Compression: 85% (vs 50% sebelumnya)
- Max dimensions: 1920x1080
- Format: Preserve original

### Zoom Levels:
- Min: 0.5x (zoom out)
- Default: 1.0x (fit screen)
- Max: 4.0x (zoom in)

### Performance:
- CachedNetworkImage untuk caching
- GIN index di database
- Lazy loading images
- Optimized thumbnails

## 🐛 Troubleshooting

### Images not showing?
1. Check Supabase Storage bucket exists
2. Verify RLS policies allow public read
3. Check image URLs in database

### Can't upload multiple images?
1. Run database migration SQL
2. Restart app after migration
3. Check internet connection

### Images cropped?
- Tidak akan terjadi! Semua images menggunakan `BoxFit.contain`

## 📊 Database Schema

```sql
-- Products table
CREATE TABLE products (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  description TEXT,
  price_per_day NUMERIC NOT NULL,
  image_url TEXT,              -- Legacy: single image
  image_urls TEXT[],           -- New: multiple images array
  is_available BOOLEAN DEFAULT TRUE,
  owner_id UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for performance
CREATE INDEX idx_products_image_urls ON products USING GIN (image_urls);
```

## 🎯 Next Steps

Optional enhancements:
- [ ] Add image reordering (drag & drop)
- [ ] Add image captions
- [ ] Add video support
- [ ] Add AR preview
- [ ] Add image filters

---

**Status:** ✅ Completed & Ready to Use
**Migration Required:** Yes (run `supabase_product_multiple_images.sql`)
**Breaking Changes:** No (backward compatible)
