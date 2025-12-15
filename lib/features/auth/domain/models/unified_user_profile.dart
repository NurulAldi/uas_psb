/// Unified User Profile Model
/// Supports both Supabase Auth and Custom Auth users
class UnifiedUserProfile {
  final String id;
  final String? email; // Optional for custom auth users
  final String? username; // Only for custom auth users
  final String? fullName;
  final String? phoneNumber;
  final String? avatarUrl;
  final String role;
  final bool isBanned;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Location fields for 20km radius rental feature
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? city;
  final DateTime? locationUpdatedAt;

  // Auth type identifier
  final String authType; // 'supabase_auth' or 'custom'

  // Custom auth specific fields
  final DateTime? lastLoginAt;

  const UnifiedUserProfile({
    required this.id,
    this.email,
    this.username,
    this.fullName,
    this.phoneNumber,
    this.avatarUrl,
    this.role = 'user',
    this.isBanned = false,
    required this.createdAt,
    required this.updatedAt,
    this.latitude,
    this.longitude,
    this.address,
    this.city,
    this.locationUpdatedAt,
    required this.authType,
    this.lastLoginAt,
  });

  /// Check if user is using Supabase Auth
  bool get isSupabaseAuthUser => authType == 'supabase_auth';

  /// Check if user is using Custom Auth
  bool get isCustomAuthUser => authType == 'custom';

  /// Get user identifier (email for Supabase Auth, username for Custom Auth)
  String get identifier {
    if (isCustomAuthUser && username != null) {
      return username!;
    }
    return email ?? 'Unknown User';
  }

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

  /// Factory constructor for Supabase Auth users (from profiles table)
  factory UnifiedUserProfile.fromSupabaseAuth(Map<String, dynamic> json) {
    return UnifiedUserProfile(
      id: json['id'] as String,
      email: json['email'] as String?,
      username: null, // Supabase Auth users don't have usernames
      fullName: json['full_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String? ?? 'user',
      isBanned: json['is_banned'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      locationUpdatedAt: json['location_updated_at'] != null
          ? DateTime.parse(json['location_updated_at'] as String)
          : null,
      authType: 'supabase_auth',
      lastLoginAt: null,
    );
  }

  /// Factory constructor for Custom Auth users (from custom_users table)
  factory UnifiedUserProfile.fromCustomAuth(Map<String, dynamic> json) {
    return UnifiedUserProfile(
      id: json['id'] as String,
      email: json['email'] as String?, // Optional for custom users
      username: json['username'] as String?,
      fullName: json['full_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String? ?? 'user',
      isBanned: json['is_banned'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      locationUpdatedAt: json['location_updated_at'] != null
          ? DateTime.parse(json['location_updated_at'] as String)
          : null,
      authType: 'custom',
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
    );
  }

  /// Universal factory constructor (auto-detects auth type)
  factory UnifiedUserProfile.fromJson(Map<String, dynamic> json) {
    final authType = json['auth_type'] as String? ?? 'supabase_auth';

    if (authType == 'custom') {
      return UnifiedUserProfile.fromCustomAuth(json);
    } else {
      return UnifiedUserProfile.fromSupabaseAuth(json);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'avatar_url': avatarUrl,
      'role': role,
      'is_banned': isBanned,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'location_updated_at': locationUpdatedAt?.toIso8601String(),
      'auth_type': authType,
      'last_login_at': lastLoginAt?.toIso8601String(),
    };
  }

  UnifiedUserProfile copyWith({
    String? id,
    String? email,
    String? username,
    String? fullName,
    String? phoneNumber,
    String? avatarUrl,
    String? role,
    bool? isBanned,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? latitude,
    double? longitude,
    String? address,
    String? city,
    DateTime? locationUpdatedAt,
    String? authType,
    DateTime? lastLoginAt,
  }) {
    return UnifiedUserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      isBanned: isBanned ?? this.isBanned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      city: city ?? this.city,
      locationUpdatedAt: locationUpdatedAt ?? this.locationUpdatedAt,
      authType: authType ?? this.authType,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  @override
  String toString() {
    return 'UnifiedUserProfile(id: $id, identifier: $identifier, authType: $authType, role: $role)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UnifiedUserProfile &&
        other.id == id &&
        other.email == email &&
        other.username == username &&
        other.authType == authType;
  }

  @override
  int get hashCode {
    return id.hashCode ^ email.hashCode ^ username.hashCode ^ authType.hashCode;
  }
}
