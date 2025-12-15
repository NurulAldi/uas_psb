import 'package:flutter/material.dart';
import 'package:rentlens/features/auth/data/repositories/hybrid_auth_repository.dart';
import 'package:rentlens/features/auth/domain/models/unified_user_profile.dart';

/// Example implementation of hybrid authentication UI
///
/// This file demonstrates how to integrate both Supabase Auth and Custom Auth
/// in your Flutter application.

// ============================================================
// EXAMPLE 1: HYBRID LOGIN SCREEN
// ============================================================

class HybridLoginScreen extends StatefulWidget {
  const HybridLoginScreen({Key? key}) : super(key: key);

  @override
  State<HybridLoginScreen> createState() => _HybridLoginScreenState();
}

class _HybridLoginScreenState extends State<HybridLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepo = HybridAuthRepository();

  AuthMode _authMode = AuthMode.email;
  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_authMode == AuthMode.email) {
        // Login with Supabase Auth
        final response = await _authRepo.signInWithSupabaseAuth(
          email: _identifierController.text.trim(),
          password: _passwordController.text,
        );

        if (response.session != null) {
          _showSuccess('Welcome back!');
          _navigateToHome();
        } else {
          _showError('Please check your email to confirm your account');
        }
      } else {
        // Login with Custom Auth
        final user = await _authRepo.signInWithCustomAuth(
          username: _identifierController.text.trim(),
          password: _passwordController.text,
        );

        // Store custom auth session
        await _storeCustomSession(user);
        _showSuccess('Welcome back, ${user['username']}!');
        _navigateToHome();
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _storeCustomSession(Map<String, dynamic> user) async {
    // TODO: Implement proper session storage
    // Example: SharedPreferences or secure storage
  }

  void _navigateToHome() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Auth mode selector
                SegmentedButton<AuthMode>(
                  segments: const [
                    ButtonSegment(
                      value: AuthMode.email,
                      label: Text('Email'),
                      icon: Icon(Icons.email),
                    ),
                    ButtonSegment(
                      value: AuthMode.username,
                      label: Text('Username'),
                      icon: Icon(Icons.person),
                    ),
                  ],
                  selected: {_authMode},
                  onSelectionChanged: (Set<AuthMode> newSelection) {
                    setState(() {
                      _authMode = newSelection.first;
                      _identifierController.clear();
                    });
                  },
                ),
                const SizedBox(height: 24),

                // Dynamic identifier field
                TextFormField(
                  controller: _identifierController,
                  decoration: InputDecoration(
                    labelText:
                        _authMode == AuthMode.email ? 'Email' : 'Username',
                    hintText: _authMode == AuthMode.email
                        ? 'user@example.com'
                        : 'johndoe123',
                    prefixIcon: Icon(
                      _authMode == AuthMode.email ? Icons.email : Icons.person,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: _authMode == AuthMode.email
                      ? TextInputType.emailAddress
                      : TextInputType.text,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your ${_authMode == AuthMode.email ? "email" : "username"}';
                    }
                    if (_authMode == AuthMode.username && value.length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password field
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Forgot password (Supabase Auth only)
                if (_authMode == AuthMode.email)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _navigateToPasswordReset(),
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                const SizedBox(height: 24),

                // Login button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Login', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 16),

                // Sign up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    TextButton(
                      onPressed: () => _navigateToSignup(),
                      child: const Text('Sign Up'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToSignup() {
    Navigator.pushNamed(context, '/signup', arguments: _authMode);
  }

  void _navigateToPasswordReset() {
    Navigator.pushNamed(context, '/password-reset');
  }
}

// ============================================================
// EXAMPLE 2: HYBRID SIGNUP SCREEN
// ============================================================

class HybridSignupScreen extends StatefulWidget {
  final AuthMode? initialAuthMode;

  const HybridSignupScreen({Key? key, this.initialAuthMode}) : super(key: key);

  @override
  State<HybridSignupScreen> createState() => _HybridSignupScreenState();
}

class _HybridSignupScreenState extends State<HybridSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _authRepo = HybridAuthRepository();

  late AuthMode _authMode;
  bool _isLoading = false;
  bool _isCheckingUsername = false;

  @override
  void initState() {
    super.initState();
    _authMode = widget.initialAuthMode ?? AuthMode.email;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_authMode == AuthMode.email) {
        // Sign up with Supabase Auth
        final response = await _authRepo.signUpWithSupabaseAuth(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _fullNameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
        );

        if (response.session != null) {
          _showSuccess('Account created! Welcome to RentLens.');
          _navigateToHome();
        } else {
          _showSuccess('Please check your email to confirm your account.');
          _navigateToLogin();
        }
      } else {
        // Sign up with Custom Auth
        final user = await _authRepo.signUpWithCustomAuth(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          fullName: _fullNameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
        );

        _showSuccess('Account created! Welcome, ${user['username']}!');

        // Auto-login after signup
        final loginUser = await _authRepo.signInWithCustomAuth(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
        await _storeCustomSession(loginUser);
        _navigateToHome();
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkUsernameAvailability(String username) async {
    if (username.length < 3) return;

    setState(() => _isCheckingUsername = true);

    try {
      final isAvailable = await _authRepo.isUsernameAvailable(username);
      if (!isAvailable) {
        _showError('Username is already taken');
      }
    } finally {
      setState(() => _isCheckingUsername = false);
    }
  }

  Future<void> _storeCustomSession(Map<String, dynamic> user) async {
    // TODO: Implement session storage
  }

  void _navigateToHome() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _navigateToLogin() {
    Navigator.pop(context);
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Auth mode selector
                SegmentedButton<AuthMode>(
                  segments: const [
                    ButtonSegment(
                      value: AuthMode.email,
                      label: Text('Email Account'),
                      icon: Icon(Icons.email),
                    ),
                    ButtonSegment(
                      value: AuthMode.username,
                      label: Text('Username Account'),
                      icon: Icon(Icons.person),
                    ),
                  ],
                  selected: {_authMode},
                  onSelectionChanged: (Set<AuthMode> newSelection) {
                    setState(() => _authMode = newSelection.first);
                  },
                ),
                const SizedBox(height: 16),

                // Info card
                Card(
                  color: _authMode == AuthMode.email
                      ? Colors.blue.shade50
                      : Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      _authMode == AuthMode.email
                          ? '📧 Email accounts require email verification and allow password reset.'
                          : '👤 Username accounts are simpler - no email required!',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Email field (required for Supabase Auth, optional for Custom Auth)
                if (_authMode == AuthMode.email)
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'user@example.com',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Email is required';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  )
                else
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email (Optional)',
                      hintText: 'user@example.com',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                      helperText: 'Optional - for account recovery',
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                const SizedBox(height: 16),

                // Username field (Custom Auth only)
                if (_authMode == AuthMode.username)
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      hintText: 'johndoe123',
                      prefixIcon: const Icon(Icons.person),
                      suffixIcon: _isCheckingUsername
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      helperText: 'Letters, numbers, and underscores only',
                    ),
                    onChanged: (value) {
                      if (value.length >= 3) {
                        _checkUsernameAvailability(value);
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Username is required';
                      }
                      if (value.length < 3) {
                        return 'Username must be at least 3 characters';
                      }
                      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                        return 'Only letters, numbers, and underscores allowed';
                      }
                      return null;
                    },
                  ),
                if (_authMode == AuthMode.username) const SizedBox(height: 16),

                // Full name field
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'John Doe',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Full name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone field (optional)
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    hintText: '081234567890',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                // Password field
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm password field
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Sign up button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignup,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Create Account',
                          style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 16),

                // Login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? '),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Login'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ENUMS & MODELS
// ============================================================

enum AuthMode { email, username }
