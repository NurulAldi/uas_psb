/// Product Category Enum
enum ProductCategory {
  dslr('DSLR'),
  mirrorless('Mirrorless'),
  drone('Drone'),
  lens('Lens');

  final String value;
  const ProductCategory(this.value);

  /// Create ProductCategory from string
  static ProductCategory fromString(String value) {
    return ProductCategory.values.firstWhere(
      (category) => category.value.toLowerCase() == value.toLowerCase(),
      orElse: () => ProductCategory.dslr,
    );
  }
}

/// Product Domain Model
class Product {
  final String id;
  final String name;
  final ProductCategory category;
  final String? description;
  final double pricePerDay;
  final String? imageUrl; // Deprecated: kept for backward compatibility
  final List<String> imageUrls; // New: support multiple images
  final bool isAvailable;
  final String?
      ownerId; // P2P: Owner of this product (nullable until migration)
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    required this.pricePerDay,
    this.imageUrl,
    this.imageUrls = const [],
    required this.isAvailable,
    this.ownerId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create Product from JSON (Supabase response)
  factory Product.fromJson(Map<String, dynamic> json) {
    // Parse image URLs (support both old single image and new multiple images)
    List<String> imageUrls = [];
    if (json['image_urls'] != null) {
      imageUrls = List<String>.from(json['image_urls'] as List);
    } else if (json['image_url'] != null &&
        (json['image_url'] as String).isNotEmpty) {
      imageUrls = [json['image_url'] as String];
    }

    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      category: ProductCategory.fromString(json['category'] as String),
      description: json['description'] as String?,
      pricePerDay: (json['price_per_day'] as num).toDouble(),
      imageUrl: imageUrls.isNotEmpty ? imageUrls.first : null,
      imageUrls: imageUrls,
      isAvailable: json['is_available'] as bool? ?? true,
      ownerId: json['owner_id'] as String?, // Nullable until migration
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert Product to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.value,
      'description': description,
      'price_per_day': pricePerDay,
      'image_url': imageUrls.isNotEmpty ? imageUrls.first : null,
      'image_urls': imageUrls,
      'is_available': isAvailable,
      'owner_id': ownerId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Format price as IDR
  String get formattedPrice {
    return 'Rp ${pricePerDay.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
  }

  /// Get short price in Indonesian format (e.g., Rp 70.000, Rp 3,2 juta)
  String get shortPrice {
    if (pricePerDay >= 1000000) {
      // Format: Rp 3,2 juta
      final millions = pricePerDay / 1000000;
      return 'Rp ${millions.toStringAsFixed(millions % 1 == 0 ? 0 : 1).replaceAll('.', ',')} juta';
    } else if (pricePerDay >= 1000) {
      // Format: Rp 70.000
      return 'Rp ${pricePerDay.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]}.',
          )}';
    }
    return 'Rp ${pricePerDay.toStringAsFixed(0)}';
  }

  /// Copy with method for immutability
  Product copyWith({
    String? id,
    String? name,
    ProductCategory? category,
    String? description,
    double? pricePerDay,
    String? imageUrl,
    List<String>? imageUrls,
    bool? isAvailable,
    String? ownerId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      pricePerDay: pricePerDay ?? this.pricePerDay,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      isAvailable: isAvailable ?? this.isAvailable,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, category: ${category.value}, pricePerDay: $pricePerDay, isAvailable: $isAvailable)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
