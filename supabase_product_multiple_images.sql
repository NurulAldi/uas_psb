-- =====================================================
-- MIGRATION: Add Multiple Images Support to Products
-- =====================================================
-- This migration adds support for multiple product images
-- by adding an image_urls column (array of text)
-- while keeping the old image_url column for backward compatibility
-- =====================================================

-- Add image_urls column to products table
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS image_urls TEXT[] DEFAULT '{}';

-- Migrate existing single images to image_urls array
UPDATE products 
SET image_urls = ARRAY[image_url]
WHERE image_url IS NOT NULL 
  AND image_url != '' 
  AND image_urls = '{}';

-- Add index for better query performance
CREATE INDEX IF NOT EXISTS idx_products_image_urls 
ON products USING GIN (image_urls);

-- Update RLS policies if needed (inherit from existing policies)
-- No changes needed as we're just adding a column

COMMENT ON COLUMN products.image_urls IS 'Array of product image URLs supporting up to 5 images';

-- Verification query (optional - run separately to check migration)
-- SELECT id, name, image_url, image_urls FROM products LIMIT 10;
