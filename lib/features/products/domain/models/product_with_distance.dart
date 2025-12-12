import 'package:rentlens/features/products/domain/models/product.dart';

/// Product with Distance Model
/// Used for location-based product listing (20km radius feature)
class ProductWithDistance extends Product {
  final String ownerName;
  final String ownerCity;
  final String? ownerAvatar;
  final double distanceKm;

  const ProductWithDistance({
    required super.id,
    required super.name,
    required super.category,
    super.description,
    required super.pricePerDay,
    super.imageUrl,
    super.imageUrls = const [],
    required super.isAvailable,
    super.ownerId,
    required super.createdAt,
    required super.updatedAt,
    required this.ownerName,
    required this.ownerCity,
    this.ownerAvatar,
    required this.distanceKm,
  });

  /// Create ProductWithDistance from JSON (from get_nearby_products RPC)
  factory ProductWithDistance.fromJson(Map<String, dynamic> json) {
    // Parse image URLs (support both old single image and new multiple images)
    List<String> imageUrls = [];
    if (json['image_urls'] != null) {
      imageUrls = List<String>.from(json['image_urls'] as List);
    } else if (json['image_url'] != null &&
        (json['image_url'] as String).isNotEmpty) {
      imageUrls = [json['image_url'] as String];
    }

    return ProductWithDistance(
      id: json['id'] as String,
      name: json['name'] as String,
      category: ProductCategory.fromString(json['category'] as String),
      description: json['description'] as String?,
      pricePerDay: (json['price_per_day'] as num).toDouble(),
      imageUrl: imageUrls.isNotEmpty ? imageUrls.first : null,
      imageUrls: imageUrls,
      isAvailable: json['is_available'] as bool? ?? true,
      ownerId: json['owner_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      ownerName: json['owner_name'] as String? ?? 'Unknown',
      ownerCity: json['owner_city'] as String? ?? 'Unknown',
      ownerAvatar: json['owner_avatar'] as String?,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Convert to JSON (includes distance)
  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'owner_name': ownerName,
      'owner_city': ownerCity,
      'owner_avatar': ownerAvatar,
      'distance_km': distanceKm,
    });
    return json;
  }

  /// Format distance for display
  /// Examples: "1.5 km", "12 km", "500 m"
  String get formattedDistance {
    if (distanceKm < 1) {
      final meters = (distanceKm * 1000).round();
      return '$meters m';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceKm.round()} km';
    }
  }

  /// Get estimated travel time (assumes 30 km/h average speed)
  String get estimatedTravelTime {
    const avgSpeedKmh = 30.0;
    final hours = distanceKm / avgSpeedKmh;
    final minutes = (hours * 60).round();

    if (minutes < 5) {
      return '< 5 mins';
    } else if (minutes < 60) {
      return '$minutes mins';
    } else {
      final hrs = (minutes / 60).floor();
      final mins = minutes % 60;
      return mins > 0 ? '$hrs hr $mins mins' : '$hrs hr';
    }
  }

  /// Check if within rental radius (20km)
  bool get isWithinRentalRadius => distanceKm <= 20.0;

  /// Copy with additional parameters
  @override
  ProductWithDistance copyWith({
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
    String? ownerName,
    String? ownerCity,
    String? ownerAvatar,
    double? distanceKm,
  }) {
    return ProductWithDistance(
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
      ownerName: ownerName ?? this.ownerName,
      ownerCity: ownerCity ?? this.ownerCity,
      ownerAvatar: ownerAvatar ?? this.ownerAvatar,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }
}
