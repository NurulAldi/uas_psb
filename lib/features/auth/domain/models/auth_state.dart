import 'package:rentlens/features/auth/domain/models/user_profile.dart';

/// Authentication Status Enum
/// Represents the current state of authentication in the app
enum AuthStatus {
  /// App is checking for existing session (startup initialization)
  initializing,

  /// User is not logged in
  unauthenticated,

  /// User is logged in with complete profile data
  authenticated,
}

/// Complete Authentication State
/// Single source of truth for all auth-related data
/// Manual Auth (NO Supabase Auth) - validates against users table
class AuthState {
  final AuthStatus status;
  final UserProfile? user;
  final String? error;

  const AuthState({
    required this.status,
    this.user,
    this.error,
  });

  // Convenience getters
  bool get isInitializing => status == AuthStatus.initializing;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;
  bool get hasError => error != null;

  // Backwards compatibility
  UserProfile? get userProfile => user;

  // Factory constructors for common states
  const AuthState.initializing({String? error})
      : status = AuthStatus.initializing,
        user = null,
        error = error;

  const AuthState.unauthenticated([String? errorMessage])
      : status = AuthStatus.unauthenticated,
        user = null,
        error = errorMessage;

  const AuthState.authenticated(UserProfile userProfile)
      : status = AuthStatus.authenticated,
        user = userProfile,
        error = null;

  // Legacy factory methods for backwards compatibility
  factory AuthState.initial() => const AuthState.initializing();

  factory AuthState.loading() => const AuthState.initializing();

  factory AuthState.authenticatedWithProfile(UserProfile profile) =>
      AuthState.authenticated(profile);

  factory AuthState.error(String message) => AuthState.unauthenticated(message);

  // CopyWith for state updates
  AuthState copyWith({
    AuthStatus? status,
    UserProfile? user,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }

  @override
  String toString() {
    return 'AuthState(status: $status, user: ${user?.username}, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AuthState &&
        other.status == status &&
        other.user == user &&
        other.error == error;
  }

  @override
  int get hashCode => status.hashCode ^ user.hashCode ^ error.hashCode;
}
