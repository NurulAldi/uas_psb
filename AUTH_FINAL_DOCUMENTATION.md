# 🔐 RentLens - Clean Authentication System

## Overview

This document describes the **FINAL** authentication system for RentLens.
All previous hybrid/Supabase Auth approaches have been **COMPLETELY REMOVED**.

---

## 🚫 What We DON'T Use

| Feature | Status |
|---------|--------|
| Supabase Auth (`auth.users`) | ❌ NOT USED |
| Supabase `signUp()` / `signInWithPassword()` | ❌ NOT USED |
| Email verification | ❌ NOT USED |
| Magic links | ❌ NOT USED |
| OAuth providers | ❌ NOT USED |
| `profiles` table | ❌ DEPRECATED |
| `hybrid_auth_repository.dart` | ❌ DELETED |

---

## ✅ What We USE

### Single `users` Table

All authentication is handled through a single `public.users` table:

```sql
CREATE TABLE public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Authentication
    username TEXT UNIQUE NOT NULL,    -- Login identifier
    password_hash TEXT NOT NULL,      -- SHA-256 hashed password
    
    -- Profile
    full_name TEXT NOT NULL,
    email TEXT,                       -- Optional, display only
    phone_number TEXT,
    avatar_url TEXT,
    
    -- Role & Status
    role TEXT DEFAULT 'user',         -- 'user' or 'admin'
    is_banned BOOLEAN DEFAULT FALSE,
    
    -- Location
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    address TEXT,
    city TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_login_at TIMESTAMPTZ
);
```

---

## 🔑 Authentication Flow

### Registration

```
User Input                    Flutter App                     Supabase (PostgreSQL)
-----------                   -----------                     --------------------
username, password,    --->   PasswordHelper.hashPassword()   
fullName, email?              (SHA-256)
                                    |
                                    v
                              RPC: register_user()     --->   INSERT INTO users
                                    |                              |
                                    v                              v
                              Save to SharedPreferences       Return user data
                              (userId, username, role)
```

### Login

```
User Input                    Flutter App                     Supabase (PostgreSQL)
-----------                   -----------                     --------------------
username, password     --->   PasswordHelper.hashPassword()   
                              (SHA-256)
                                    |
                                    v
                              RPC: login_user()        --->   SELECT FROM users
                                    |                         WHERE username = ?
                                    v                         AND password_hash = ?
                              Save to SharedPreferences            |
                              (userId, username, role)             v
                                                              Return user data
                                                              + Update last_login_at
```

### Session Management

- **Storage**: `SharedPreferences` (local device storage)
- **Keys**: `user_id`, `username`, `full_name`, `user_role`
- **Logout**: Clear all keys from SharedPreferences

---

## 🛡️ Role-Based Access

### Roles

| Role | Description | How to Assign |
|------|-------------|---------------|
| `user` | Default role for all registrations | Automatic |
| `admin` | Administrator with elevated privileges | **Manual via SQL only** |

### Making a User Admin

```sql
-- In Supabase SQL Editor:
UPDATE public.users 
SET role = 'admin' 
WHERE username = 'targetusername';
```

**There is NO UI for admin registration or role upgrade. This is intentional.**

### Checking Admin Status in Flutter

```dart
// In any screen/widget
final currentUser = ref.watch(currentUserProfileProvider);
final isAdmin = currentUser?.role == 'admin';

if (isAdmin) {
  // Show admin features
}
```

---

## 📁 File Structure

```
lib/features/auth/
├── controllers/
│   └── auth_controller.dart       # State management (Riverpod)
├── data/
│   ├── repositories/
│   │   ├── auth_repository.dart   # ✅ MAIN - Manual auth logic
│   │   └── profile_repository.dart
│   └── services/
│       └── avatar_upload_service.dart
├── domain/
│   └── models/
│       ├── user_profile.dart      # ✅ User model
│       └── auth_state.dart        # Auth state model
├── presentation/
│   ├── screens/
│   │   ├── login_screen.dart      # Login UI
│   │   ├── register_screen.dart   # Registration UI
│   │   ├── profile_screen.dart
│   │   └── edit_profile_page.dart
│   └── widgets/
│       └── user_avatar.dart
└── providers/
    ├── auth_provider.dart         # Auth providers
    ├── auth_repository_provider.dart
    └── profile_provider.dart
```

### Deleted Files (No Longer Needed)

- ❌ `hybrid_auth_repository.dart` - Used Supabase Auth
- ❌ `hybrid_auth_examples.dart` - Demo for hybrid system

---

## 🧪 Test Accounts

After running the SQL migration, these accounts are available:

| Username | Password | Role | Purpose |
|----------|----------|------|---------|
| `admin` | `admin123` | admin | Testing admin features |
| `demo` | `password123` | user | Testing user features |
| `user1` | `user123` | user | Additional test user |

---

## 🔄 Migration Steps

### 1. Run SQL Migration

Open **Supabase SQL Editor** and run:

```
supabase_FINAL_clean_auth.sql
```

This will:
- Drop old policies, triggers, functions
- Create fresh `users` table
- Create `register_user()` and `login_user()` functions
- Insert demo accounts
- Update foreign key references

### 2. Verify in Flutter

The Flutter app is already configured. Just:

1. Run `flutter pub get`
2. Run `flutter run`
3. Try logging in with `demo` / `password123`

---

## 🔐 Security Notes

### Password Hashing

We use **SHA-256** for password hashing:

```dart
// lib/core/utils/password_helper.dart
import 'package:crypto/crypto.dart';
import 'dart:convert';

class PasswordHelper {
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
```

**⚠️ Note**: SHA-256 is used for simplicity in this demo/academic application. 
For production, use `bcrypt` or `argon2`.

### Session Security

- Sessions stored locally in `SharedPreferences`
- No JWT tokens (since we don't use Supabase Auth)
- User must re-login after app data is cleared

---

## 🎯 Summary

| Aspect | Implementation |
|--------|----------------|
| User Storage | `public.users` table |
| Authentication | PostgreSQL RPC functions |
| Password Security | SHA-256 hashing |
| Session Storage | SharedPreferences |
| Admin Creation | Manual SQL only |
| Email Verification | None (not required) |
| Supabase Auth | **COMPLETELY UNUSED** |

---

## 📞 Quick Reference

### Providers

```dart
// Get current user
final user = ref.watch(currentUserProfileProvider);

// Check if logged in
final isLoggedIn = user != null;

// Check if admin
final isAdmin = user?.role == 'admin';

// Auth controller for login/logout
final authController = ref.read(authControllerProvider.notifier);
await authController.signIn(username, password);
await authController.signOut();
```

### Repository Methods

```dart
final repo = AuthRepository();

// Login
final user = await repo.signInWithUsername(
  username: 'demo',
  password: 'password123',
);

// Register
final newUser = await repo.signUpWithUsername(
  username: 'newuser',
  password: 'securepass',
  fullName: 'New User',
);

// Logout
await repo.signOut();
```

---

**Last Updated**: December 2024
**Status**: FINAL - No Supabase Auth
