# Sample Products for Testing

Run this SQL in Supabase SQL Editor to add sample products for testing:

```sql
-- Insert sample products
INSERT INTO products (name, category, description, price_per_day, image_url, is_available) VALUES
(
  'Canon EOS R5',
  'Mirrorless',
  'Professional full-frame mirrorless camera with 45MP sensor. Perfect for both photography and videography. Excellent in low light conditions with 8K video capability.',
  150000,
  'https://images.unsplash.com/photo-1606980707486-c4326b7d8f82?w=800',
  true
),
(
  'Sony A7 IV',
  'Mirrorless',
  'Versatile full-frame mirrorless camera with 33MP sensor. Outstanding hybrid performance for both photo and video. Great autofocus system.',
  120000,
  'https://images.unsplash.com/photo-1526170375885-4d8ecf77b99f?w=800',
  true
),
(
  'Nikon D850',
  'DSLR',
  'Professional DSLR with 45.7MP sensor. Exceptional image quality with robust build. Ideal for landscape and studio photography.',
  100000,
  'https://images.unsplash.com/photo-1502920917128-1aa500764cbd?w=800',
  true
),
(
  'DJI Mavic 3',
  'Drone',
  'Professional drone with Hasselblad camera. 5.1K video recording with 46-minute flight time. Omnidirectional obstacle sensing.',
  200000,
  'https://images.unsplash.com/photo-1473968512647-3e447244af8f?w=800',
  true
),
(
  'Canon RF 24-70mm f/2.8L',
  'Lens',
  'Professional standard zoom lens. Outstanding sharpness across the entire zoom range. Weather-sealed construction.',
  50000,
  'https://images.unsplash.com/photo-1606800052052-7c7c5d9e4d85?w=800',
  true
),
(
  'Sony FE 70-200mm f/2.8 GM',
  'Lens',
  'Professional telephoto zoom lens. Exceptional bokeh and sharpness. Advanced optical design with nano coating.',
  80000,
  'https://images.unsplash.com/photo-1606851199112-4f5349cfa6a6?w=800',
  true
),
(
  'Fujifilm X-T5',
  'Mirrorless',
  'APS-C mirrorless camera with 40MP sensor. Classic design with modern features. Excellent color science and film simulations.',
  90000,
  'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?w=800',
  true
),
(
  'DJI Mini 3 Pro',
  'Drone',
  'Compact drone with 48MP camera. Lightweight design under 249g. Perfect for travel and outdoor photography.',
  120000,
  'https://images.unsplash.com/photo-1508444845599-5c89863b1c44?w=800',
  true
),
(
  'Canon EOS 5D Mark IV',
  'DSLR',
  'Full-frame DSLR with 30.4MP sensor. Reliable workhorse for professionals. Dual Pixel autofocus and 4K video.',
  95000,
  'https://images.unsplash.com/photo-1514621166532-aa7eb1a3a2f4?w=800',
  false
),
(
  'Sigma 35mm f/1.4 Art',
  'Lens',
  'Professional prime lens. Exceptional sharpness wide open. Perfect for environmental portraits and street photography.',
  40000,
  'https://images.unsplash.com/photo-1617005082133-548c4dd27f35?w=800',
  true
);
```

## Product Categories
- **DSLR**: Traditional DSLR cameras
- **Mirrorless**: Mirrorless cameras
- **Drone**: Camera drones
- **Lens**: Camera lenses and accessories

## Image URLs
The sample uses free Unsplash images. You can replace them with your own images or products.

## Verification Query
After inserting, verify the data:

```sql
SELECT id, name, category, price_per_day, is_available 
FROM products 
ORDER BY created_at DESC;
```

## Notes
- All prices are in Indonesian Rupiah (IDR)
- The last product (Canon 5D Mark IV) is marked as unavailable for testing
- Image URLs are from Unsplash (free to use)
- One product is marked as unavailable to test the UI handling
