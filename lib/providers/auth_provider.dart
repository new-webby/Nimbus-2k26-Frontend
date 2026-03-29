import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/profile_model.dart';
import '../services/api_service.dart';

enum AuthStatus { idle, loading, success, error }

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  // ── state ─────────────────────────────────────────────────────────
  AuthStatus _status = AuthStatus.idle;
  String? _errorMessage;
  bool _isAuthenticated = false;
  String? _userName;
  String? _userEmail;

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _isAuthenticated;
  String? get userName => _userName;
  String? get userEmail => _userEmail;

  AuthProvider() {
    _initGoogleSignIn();
    _checkExistingAuth();
  }

  /// Initialize GoogleSignIn singleton — MUST be called once before any use (v7 requirement)
  Future<void> _initGoogleSignIn() async {
    await GoogleSignIn.instance.initialize();
  }

  /// Check existing token on app startup
  Future<void> _checkExistingAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token != null && token.isNotEmpty) {
      _isAuthenticated = true;
      _userName = prefs.getString('user_name');
      _userEmail = prefs.getString('user_email');
      _apiService.setToken(token);
      notifyListeners();

      // Refresh profile silently
      _fetchAndCacheProfile();
    }
  }

  /// Sync the real user name from backend into SharedPreferences
  Future<void> _fetchAndCacheProfile() async {
    try {
      final profileData = await _apiService.getUserProfile();
      final user = profileData['user'] as Map<String, dynamic>?;
      final name = user?['full_name'] as String?;
      final email = user?['email'] as String?;

      if (name != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', name);
        if (email != null) await prefs.setString('user_email', email);
        _userName = name;
        _userEmail = email;
        notifyListeners();
      }
    } catch (_) {
      // Ignore background refresh errors
    }
  }

  /// Push real user name from AuthProvider into ProfileModel
  void syncProfile(ProfileModel profileModel) {
    if (_userName != null && _userName!.isNotEmpty) {
      profileModel.updateName(_userName!);
    }
    if (_userEmail != null && _userEmail!.isNotEmpty) {
      profileModel.updateBio(_userEmail!);
    }
  }

  void _setStatus(AuthStatus s, {String? error}) {
    _status = s;
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    _status = AuthStatus.idle;
    notifyListeners();
  }

  // ── Firebase Google Sign-In (google_sign_in v7.x) ─────────────────
  Future<bool> signInWithGoogle() async {
    _setStatus(AuthStatus.loading);
    try {
      // 1. authenticate() replaces signIn() in v7 — shows system account picker
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      // 2. idToken is now synchronous in v7
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw Exception("Failed to get Google ID token.");
      }

      // 3. accessToken now requires explicit scope authorization in v7
      //    (authentication and authorization are separate in v7)
      const List<String> scopes = ['email', 'profile'];
      final clientAuth =
          await googleUser.authorizationClient.authorizationForScopes(scopes) ??
          await googleUser.authorizationClient.authorizeScopes(scopes);

      // 4. Build Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: clientAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 5. Sign in to Firebase
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception("Firebase sign-in failed.");
      }

      // 6. Get Firebase ID token for backend
      final String? firebaseIdToken = await firebaseUser.getIdToken();
      if (firebaseIdToken == null) {
        throw Exception("Failed to generate Firebase ID token.");
      }

      // 7. Send to Node.js backend
      final response = await _apiService.googleSignIn(firebaseIdToken);

      final token = response['token'] as String;
      final user = response['user'] as Map<String, dynamic>;

      _userName = user['name'] as String?;
      _userEmail = user['email'] as String?;

      // 8. Persist token locally
      final prefs = await SharedPreferences.getInstance();
      if (_userName != null) await prefs.setString('user_name', _userName!);
      if (_userEmail != null) await prefs.setString('user_email', _userEmail!);
      await prefs.setString('auth_token', token);

      _apiService.setToken(token);
      _isAuthenticated = true;
      _setStatus(AuthStatus.success);
      return true;

    } on GoogleSignInException catch (e) {
      // Handle cancellation cleanly without showing an error
      if (e.code == GoogleSignInExceptionCode.canceled) {
        _setStatus(AuthStatus.idle);
        return false;
      }
      await GoogleSignIn.instance.signOut();
      _setStatus(AuthStatus.error, error: e.description ?? 'Google sign-in failed.');
      return false;
    } catch (e) {
      final errorMsg = _cleanError(e.toString());
      await GoogleSignIn.instance.signOut(); // force re-pick on next attempt
      _setStatus(AuthStatus.error, error: errorMsg);
      return false;
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _apiService.logout();
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('auth_token');

    _isAuthenticated = false;
    _userName = null;
    _userEmail = null;
    _setStatus(AuthStatus.idle);
  }

  String _cleanError(String raw) {
    if (raw.startsWith('Exception: ')) return raw.substring(11);
    if (raw.contains('Only @nith.ac.in')) {
      return 'Only @nith.ac.in email addresses are allowed.';
    }
    return raw;
  }
}
