/// User Profile Model (Manual Authentication)
/// NO Supabase Auth - uses custom users table with username/password
class UserProfile {
  final String id;
  final String username; // PRIMARY identifier for login
  final String? fullName; // Optional - fallback to username if not set
  final String? email; // OPTIONAL - no validation needed
  final String? phoneNumber;
  final String? avatarUrl;
  final String role;
  final bool isBanned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt; // Track last login

  // Location fields for 20km radius rental feature
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? city;

  const UserProfile({
    required this.id,
    required this.username,
    this.fullName, // Optional now
    this.email, // Optional
    this.phoneNumber,
    this.avatarUrl,
    this.role = 'user',
    this.isBanned = false,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
    this.latitude,
    this.longitude,
    this.address,
    this.city,
  });

  /// Display name with fallback to username if fullName is not set
  String get displayName =>
      fullName?.trim().isNotEmpty == true ? fullName! : username;

  /// Check if user has set their location
  bool get hasLocation => latitude != null && longitude != null;

  /// Check if user has a valid avatar URL
  bool get hasValidAvatar {
    if (avatarUrl == null || avatarUrl!.isEmpty) return false;

    // Basic URL validation
    try {
      final uri = Uri.parse(avatarUrl!);
      // Check if it's a valid URL with http/https scheme
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: json['username'] as String,
      fullName: json['full_name'] as String?, // Optional now
      email: json['email'] as String?, // Optional
      phoneNumber: json['phone_number'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String? ?? 'user',
      isBanned: json['is_banned'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      address: json['address'] as String?,
      city: json['city'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'email': email,
      'phone_number': phoneNumber,
      'avatar_url': avatarUrl,
      'role': role,
      'is_banned': isBanned,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_login_at': lastLoginAt?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
    };
  }

  UserProfile copyWith({
    String? id,
    String? username,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? avatarUrl,
    String? role,
    bool? isBanned,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
    double? latitude,
    double? longitude,
    String? address,
    String? city,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      isBanned: isBanned ?? this.isBanned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      city: city ?? this.city,
    );
  }
}
