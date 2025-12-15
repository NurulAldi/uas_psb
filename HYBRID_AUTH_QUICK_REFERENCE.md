# Hybrid Authentication - Quick Reference

## Authentication Type Comparison

| Feature | Supabase Auth (Existing) | Custom Auth (New) |
|---------|--------------------------|-------------------|
| **Identifier** | Email | Username |
| **Email Required** | ✅ Yes (validated) | ❌ No (optional) |
| **Password Rules** | Min 6 chars (Supabase enforced) | Custom validation |
| **Session Management** | Supabase JWT | Manual/Custom |
| **Password Reset** | ✅ Built-in | ⚠️ Custom implementation needed |
| **Account Lockout** | ❌ No | ✅ Yes (5 attempts) |
| **Storage Table** | `auth.users` + `profiles` | `custom_users` |
| **RLS Integration** | ✅ Full (`auth.uid()`) | ⚠️ Custom session required |
| **Migration Impact** | ✅ Zero changes | ⚠️ New implementation |

---

## Code Comparison

### Sign Up

#### Supabase Auth (Existing)
```dart
final response = await authRepo.signUpWithSupabaseAuth(
  email: 'user@example.com',
  password: 'password123',
  fullName: 'John Doe',
  phoneNumber: '1234567890',
);
// Email validation required
// Session auto-created
```

#### Custom Auth (New)
```dart
final user = await authRepo.signUpWithCustomAuth(
  username: 'johndoe123',
  password: 'password123',
  email: 'optional@example.com', // OPTIONAL!
  fullName: 'John Doe',
  phoneNumber: '1234567890',
);
// No email validation
// Manual session management
```

### Sign In

#### Supabase Auth (Existing)
```dart
final response = await authRepo.signInWithSupabaseAuth(
  email: 'user@example.com',
  password: 'password123',
);
// Returns: AuthResponse with JWT session
```

#### Custom Auth (New)
```dart
final user = await authRepo.signInWithCustomAuth(
  username: 'johndoe123',
  password: 'password123',
);
// Returns: User data map
// You must create session manually
```

### Get Current User

#### Supabase Auth (Existing)
```dart
final user = supabase.auth.currentUser;
// Automatically available from JWT
```

#### Custom Auth (New)
```dart
final userId = await CustomAuthSession.getUserId();
final profile = await supabase
  .from('custom_users')
  .select()
  .eq('id', userId)
  .single();
```

---

## Database Query Comparison

### Query by Email (Supabase Auth)
```sql
SELECT * FROM profiles 
WHERE email = 'user@example.com' 
AND auth_type = 'supabase_auth';
```

### Query by Username (Custom Auth)
```sql
SELECT * FROM custom_users 
WHERE username = 'johndoe123';
```

### Query All Users (Both Types)
```sql
SELECT * FROM all_users 
ORDER BY created_at DESC;
```

---

## UI Flow Comparison

### Login Screen

```dart
// Toggle between auth modes
enum AuthMode { email, username }

// Email login (Supabase Auth)
if (_authMode == AuthMode.email) {
  TextField(
    controller: _emailController,
    decoration: InputDecoration(
      labelText: 'Email',
      hintText: 'user@example.com',
    ),
    keyboardType: TextInputType.emailAddress,
  );
}

// Username login (Custom Auth)
else {
  TextField(
    controller: _usernameController,
    decoration: InputDecoration(
      labelText: 'Username',
      hintText: 'johndoe123',
    ),
    keyboardType: TextInputType.text,
  );
}
```

---

## When to Use Each Auth Type

### Use Supabase Auth When:
- ✅ Email validation is required
- ✅ Want built-in password reset
- ✅ Need OAuth/social login
- ✅ Want Supabase RLS integration
- ✅ Users prefer email-based accounts

### Use Custom Auth When:
- ✅ Want username-based accounts
- ✅ Don't need email validation
- ✅ Need custom authentication logic
- ✅ Want to avoid email constraints
- ✅ Building gaming/social app

---

## Migration Status Indicators

### Check Auth Type in Code
```dart
if (userProfile.isSupabaseAuthUser) {
  print('This is an existing Supabase Auth user');
  // Use Supabase session
  final session = supabase.auth.currentSession;
} else if (userProfile.isCustomAuthUser) {
  print('This is a new Custom Auth user');
  // Use custom session
  final session = await CustomAuthSession.getSession();
}
```

### Check Auth Type in Database
```sql
-- Count users by auth type
SELECT 
  auth_type,
  COUNT(*) as user_count
FROM all_users
GROUP BY auth_type;

-- Result:
-- auth_type      | user_count
-- supabase_auth  | 150
-- custom         | 25
```

---

## Feature Compatibility Matrix

| Feature | Supabase Auth | Custom Auth | Notes |
|---------|---------------|-------------|-------|
| User Registration | ✅ | ✅ | Both work |
| User Login | ✅ | ✅ | Both work |
| Profile Updates | ✅ | ✅ | Both work |
| Avatar Upload | ✅ | ✅ | Both work |
| Location Features | ✅ | ✅ | Both work |
| Product Listings | ✅ | ✅ | Both work |
| Bookings | ✅ | ✅ | Both work |
| Payments | ✅ | ✅ | Both work |
| Admin Dashboard | ✅ | ✅ | Both work |
| Ban/Unban | ✅ | ✅ | Both work |
| Password Reset | ✅ | ⚠️ | Custom needs implementation |
| Email Verification | ✅ | ❌ | Supabase only |
| OAuth Login | ✅ | ❌ | Supabase only |
| 2FA | ✅ | ⚠️ | Custom needs implementation |

**Legend:**
- ✅ Fully supported
- ⚠️ Requires custom implementation
- ❌ Not available

---

## Common Patterns

### Pattern 1: Unified Profile Fetching
```dart
Future<UnifiedUserProfile?> getProfile(String userId) async {
  // Try Supabase Auth first
  final supabaseProfile = await _supabase
      .from('profiles')
      .select()
      .eq('id', userId)
      .maybeSingle();
  
  if (supabaseProfile != null) {
    return UnifiedUserProfile.fromSupabaseAuth(supabaseProfile);
  }
  
  // Fallback to Custom Auth
  final customProfile = await _supabase
      .from('custom_users')
      .select()
      .eq('id', userId)
      .maybeSingle();
  
  if (customProfile != null) {
    return UnifiedUserProfile.fromCustomAuth(customProfile);
  }
  
  return null;
}
```

### Pattern 2: Unified Authentication Check
```dart
Future<bool> isUserAuthenticated() async {
  // Check Supabase Auth
  if (_supabase.auth.currentUser != null) {
    return true;
  }
  
  // Check Custom Auth
  final customSession = await CustomAuthSession.isValid();
  return customSession;
}
```

### Pattern 3: Unified Logout
```dart
Future<void> logout() async {
  // Sign out from Supabase Auth (if applicable)
  try {
    await _supabase.auth.signOut();
  } catch (_) {
    // User might not be logged in via Supabase Auth
  }
  
  // Clear custom auth session (if applicable)
  await CustomAuthSession.clear();
  
  // Navigate to login
  navigateToLogin();
}
```

---

## Security Checklist

### Supabase Auth Security
- [x] Email validation enforced
- [x] Password strength enforced (6+ chars)
- [x] JWT session tokens
- [x] RLS policies active
- [x] HTTPS only

### Custom Auth Security
- [ ] Username validation (3+ chars, alphanumeric)
- [ ] Password hashing (bcrypt/argon2)
- [ ] Account lockout (5 failed attempts)
- [ ] Session token expiration
- [ ] HTTPS only
- [ ] Rate limiting on login endpoint
- [ ] SQL injection protection

---

## Performance Considerations

### Query Performance
```sql
-- Good: Query specific table
SELECT * FROM profiles WHERE id = 'user-id';
SELECT * FROM custom_users WHERE id = 'user-id';

-- Slower: Query unified view
SELECT * FROM all_users WHERE id = 'user-id';
```

**Recommendation**: Query specific tables when auth type is known.

### Indexing
Both tables have proper indexes:
```sql
-- profiles indexes (existing)
CREATE INDEX idx_profiles_email ON profiles(email);
CREATE INDEX idx_profiles_auth_type ON profiles(auth_type);

-- custom_users indexes (new)
CREATE INDEX idx_custom_users_username ON custom_users(username);
CREATE INDEX idx_custom_users_email ON custom_users(email);
```

---

## Troubleshooting Quick Fixes

### Issue: Can't login with username
**Check:**
```sql
SELECT * FROM custom_users WHERE username = 'your-username';
```
If empty → User doesn't exist or using Supabase Auth

### Issue: Password incorrect for custom user
**Check:**
```dart
// Ensure password hashing matches
final hash = _hashPassword(password);
print('Hash: $hash');
```

### Issue: RLS blocking custom user queries
**Fix:**
```sql
-- Temporarily disable to test
ALTER TABLE custom_users DISABLE ROW LEVEL SECURITY;
-- Test query
-- Re-enable
ALTER TABLE custom_users ENABLE ROW LEVEL SECURITY;
```

### Issue: Session not persisting
**Check:**
```dart
final prefs = await SharedPreferences.getInstance();
print('User ID: ${prefs.getString('userId')}');
print('Auth Type: ${prefs.getString('authType')}');
```

---

## Quick Start Commands

### 1. Run Migration
```sql
-- In Supabase SQL Editor
\i supabase_hybrid_auth_migration.sql
```

### 2. Verify Migration
```sql
SELECT COUNT(*) FROM custom_users;
SELECT COUNT(*) FROM profiles WHERE auth_type = 'supabase_auth';
SELECT * FROM all_users LIMIT 5;
```

### 3. Test Custom Signup
```dart
final user = await hybridAuthRepo.signUpWithCustomAuth(
  username: 'testuser',
  password: 'testpass123',
  fullName: 'Test User',
);
print(user);
```

### 4. Test Custom Login
```dart
final user = await hybridAuthRepo.signInWithCustomAuth(
  username: 'testuser',
  password: 'testpass123',
);
print(user);
```

---

**End of Quick Reference**
