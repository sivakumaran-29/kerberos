import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase;

  AuthService(this._supabase);

  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;

  bool get isAuthenticated => _supabase.auth.currentUser != null;

  String get userDisplayName {
    final user = _supabase.auth.currentUser;
    if (user == null) return 'Anonymous Agent';
    final meta = user.userMetadata;
    if (meta != null && meta['display_name'] != null && meta['display_name'].toString().trim().isNotEmpty) {
      return meta['display_name'].toString().trim();
    }
    if (meta != null && meta['name'] != null && meta['name'].toString().trim().isNotEmpty) {
      return meta['name'].toString().trim();
    }
    if (user.email != null && user.email!.contains('@')) {
      return user.email!.split('@').first;
    }
    return 'Agent';
  }

  String get userEmail {
    return _supabase.auth.currentUser?.email ?? '';
  }

  /// Sign in with email and password.
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      throw Exception("Please enter a valid email address.");
    }
    if (password.isEmpty) {
      throw Exception("Password cannot be empty.");
    }

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains("invalid login credentials")) {
        throw Exception("Invalid credentials. The email does not exist or the password is incorrect.");
      } else if (e.message.toLowerCase().contains("email not confirmed")) {
        throw Exception("Please confirm your email address before signing in.");
      }
      throw Exception(e.message);
    } catch (e) {
      throw Exception("Authentication failed: ${e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')}");
    }
  }

  /// Sign up a new user account with display name and password.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cleanEmail = email.trim();
    final cleanName = displayName.trim();

    if (cleanName.isEmpty) {
      throw Exception("Please enter your display name.");
    }
    if (cleanEmail.isEmpty || !cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      throw Exception("Please enter a valid email address.");
    }
    if (password.length < 6) {
      throw Exception("Password must be at least 6 characters long.");
    }

    try {
      final response = await _supabase.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {
          'display_name': cleanName,
          'name': cleanName,
        },
      );
      return response;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains("already registered")) {
        throw Exception("This email is already registered. Please sign in instead or reset your password.");
      }
      throw Exception(e.message);
    } catch (e) {
      throw Exception("Registration failed: ${e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')}");
    }
  }

  /// Send password recovery link to the user's email.
  Future<void> resetPasswordForEmail(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      throw Exception("Please enter a valid email address to reset password.");
    }

    try {
      await _supabase.auth.resetPasswordForEmail(cleanEmail);
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception("Password reset failed: ${e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')}");
    }
  }

  /// Sign out current user.
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
