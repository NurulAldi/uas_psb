# 🚀 Quick Setup Instructions

## Step 1: Create Storage Bucket (REQUIRED)

Before testing image upload, you MUST create the Storage bucket:

### Option A: Via Supabase Dashboard (Recommended)

1. Open your Supabase project dashboard
2. Click **Storage** in left sidebar
3. Click **"New Bucket"** button
4. Enter bucket name: `product-images`
5. Toggle **"Public bucket"** to ON
6. Click **"Create bucket"**

That's it! Policies will be auto-applied for public buckets.

### Option B: Via SQL Editor (Advanced)

If you want custom policies:

1. Open **SQL Editor** in Supabase Dashboard
2. Open `supabase_storage_setup.sql` file
3. Copy and paste the SQL code
4. Click **"Run"**

---

## Step 2: Verify Setup

Run this query in SQL Editor to verify:

```sql
-- Should return 1 row with bucket details
SELECT * FROM storage.buckets WHERE id = 'product-images';
```

Expected result:
```
id: product-images
name: product-images
public: true
```

---

## Step 3: Test the Features

### Test Image Upload

1. Run the app: `flutter run`
2. Login/Register
3. Go to **"My Listings"**
4. Tap **FAB "Add Product"** or **"+" button** in app bar
5. Tap the **image area** (gray box with camera icon)
6. Select an image from gallery
7. Fill in product details
8. Tap **"Add Product"**

**Expected Result:**
- Loading indicator appears during upload
- Product created with image
- Redirects to My Listings
- Product appears in list with image

### Test Edit

1. From My Listings, tap **"Edit"** button on any product
2. Change some fields (name, price, etc.)
3. (Optional) Tap image to change it
4. Tap **"Update Product"**

**Expected Result:**
- Product updates successfully
- Old image replaced if new one selected
- Returns to My Listings with updated data

### Test Delete

1. From My Listings, tap **"Delete"** button
2. Confirm deletion in dialog

**Expected Result:**
- Confirmation dialog appears
- Product deleted from database
- List refreshes automatically
- Product removed from view

---

## Troubleshooting

### "Failed to upload image"

**Cause:** Storage bucket doesn't exist or is not public

**Fix:**
1. Go to Supabase Dashboard → Storage
2. Check if `product-images` bucket exists
3. If not, create it (see Step 1)
4. If exists, verify it's PUBLIC (click bucket → Settings → Public toggle ON)

### "Permission denied" when uploading

**Cause:** Not logged in or RLS policies not set

**Fix:**
1. Ensure you're logged in (check home screen shows username)
2. Go to Supabase Dashboard → SQL Editor
3. Run query to check policies:
```sql
SELECT * FROM storage.policies WHERE bucket_id = 'product-images';
```
4. If no policies, run `supabase_storage_setup.sql`

### "Cannot delete product"

**Cause:** You're not the owner or product doesn't exist

**Fix:**
1. Verify you created the product (check owner_id in database)
2. Try refreshing the list (tap refresh icon in app bar)
3. Check database: `SELECT * FROM products WHERE id = '<product-id>';`

### Image not showing in list

**Cause:** Image URL is null or invalid

**Fix:**
1. Check product record: `SELECT image_url FROM products WHERE id = '<product-id>';`
2. Verify URL is accessible (copy-paste in browser)
3. Check Storage bucket files: Dashboard → Storage → product-images

---

## What Happens Behind the Scenes

### When you add a product with image:

```
1. User selects image from gallery
   → File path: /storage/emulated/0/DCIM/camera.jpg

2. ImageUploadService.uploadProductImage()
   → Generates path: {userId}/1703001234567_camera.jpg
   → Uploads to Supabase Storage

3. Get public URL
   → https://your-project.supabase.co/storage/v1/object/public/product-images/userId/1703001234567_camera.jpg

4. ProductRepository.createProduct()
   → Saves product with imageUrl to database
   → Auto-fills owner_id from currentUserId

5. Success!
   → Product has image URL
   → RLS ensures only owner can edit/delete
```

### When you edit a product and change image:

```
1. AddProductPage opens in Edit mode
   → Pre-fills form with existing data
   → Shows existing network image

2. User selects new image
   → Preview updates to show new file

3. On save:
   → ImageUploadService.replaceProductImage()
   → Uploads new image
   → Deletes old image from Storage
   → Returns new public URL

4. ProductRepository.updateProduct()
   → Updates product with new imageUrl

5. Success!
   → Product has new image
   → Old image removed from Storage (cleanup)
```

---

## File Organization in Storage

Your images will be organized like this:

```
product-images/
├── {user-id-1}/
│   ├── 1703001234567_camera.jpg
│   ├── 1703001345678_drone.jpg
│   └── 1703001456789_lens.jpg
├── {user-id-2}/
│   ├── 1703002234567_mirrorless.jpg
│   └── 1703002345678_tripod.jpg
└── ...
```

**Benefits:**
- Easy to find a user's images
- Easy to delete all images when user deletes account
- Timestamp prevents filename conflicts
- Clean organization

---

## Security Notes

✅ **What's Protected:**
- Only authenticated users can upload images
- Only image owners can update/delete their images
- RLS policies enforce owner-only product updates/deletes
- owner_id is auto-filled from session (can't be forged)

✅ **What's Public:**
- Anyone can view product images (for marketplace browsing)
- Anyone can view product details (for marketplace browsing)

❌ **What's NOT Protected:**
- Image URLs are public (anyone with URL can view)
- This is intentional for marketplace functionality

---

## Performance Tips

1. **Image Size:** Keep images under 5MB for fast upload
2. **Resolution:** 1920x1080 is enough for product photos
3. **Format:** JPEG has best compression, PNG for transparency
4. **Caching:** App uses `cached_network_image` for efficient loading

---

## Next Steps After Setup

1. ✅ Create Storage bucket
2. ✅ Test Add Product with image
3. ✅ Test Edit Product (change image)
4. ✅ Test Delete Product
5. ✅ Test Toggle Availability
6. ✅ Verify images load in product list
7. ✅ Verify images load in product detail

---

**Ready to go!** 🎉

If you encounter any issues, check:
1. Storage bucket exists and is public
2. User is logged in
3. Policies are applied
4. Database migration completed (owner_id column exists)

For detailed implementation info, see `CRUD_IMPLEMENTATION_GUIDE.md`
