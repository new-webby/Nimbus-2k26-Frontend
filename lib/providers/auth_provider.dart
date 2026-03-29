import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Holds all authentication state for the app.
///
/// Flow:
///   1. User taps "Sign in with Google".
///   2. [signInWithGoogle] triggers the native Google Sign-In sheet.
///   3. The Google ID token is sent to POST /api/users/auth/google on our backend.
///   4. Backend verifies it, upserts the user, and returns a JWT.
///   5. JWT is persisted in SharedPreferences and used for every subsequent request.
class AuthProvider extends ChangeNotifier {
  // ── Configuration ──────────────────────────────────────────────────────────
  // Replace with your actual backend base URL.
  static const String _baseUrl =
      'https://nimbus-2k26-backend-2.onrender.com'; // or http://10.0.2.2:3000 for local

  // Replace with your Google OAuth 2.0 Web Client ID from Google Cloud Console.
  // For Android you also need the SHA-1 fingerprint registered; for iOS add the
  // reversed client ID to Info.plist.
  static const String _googleClientId =
      'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';

  // ── State ───────────────────────────────────────────────────────────────────
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _jwtToken;
  Map<String, dynamic>? _user;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get jwtToken => _jwtToken;
  Map<String, dynamic>? get user => _user;
  String get userName => _user?['name'] ?? '';
  String get userEmail => _user?['email'] ?? '';

  // ── Google Sign-In instance ──────────────────────────────────────────────────
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // serverClientId is required so we get an idToken.
    // Must match the Web Client ID in Google Cloud Console.
    serverClientId: _googleClientId,
    scopes: ['email', 'profile'],
  );

  // ── Init: restore session ────────────────────────────────────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _jwtToken = prefs.getString('jwt_token');
    final userJson = prefs.getString('user');
    if (_jwtToken != null && userJson != null) {
      _user = jsonDecode(userJson) as Map<String, dynamic>;
      _isAuthenticated = true;
      notifyListeners();
    }
  }

  // ── Google Sign-In ───────────────────────────────────────────────────────────
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      // 1. Trigger the Google sign-in sheet
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled
        _setLoading(false);
        return false;
      }

      // 2. Get auth tokens
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        _errorMessage = 'Failed to get Google ID token';
        _setLoading(false);
        notifyListeners();
        return false;
      }

      // 3. Send ID token to our backend
      final response = await http.post(
        Uri.parse('$_baseUrl/api/users/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        await _persistSession(body['token'] as String, body['user'] as Map<String, dynamic>);
        _setLoading(false);
        return true;
      } else {
        _errorMessage = (body['error'] as String?) ?? 'Authentication failed';
        await _googleSignIn.signOut(); // clean up Google session on failure
        _setLoading(false);
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Sign-in error: ${e.toString()}';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  // ── Sign Out ─────────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _clearSession();
    notifyListeners();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  Future<void> _persistSession(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setString('user', jsonEncode(user));
    _jwtToken = token;
    _user = user;
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user');
    _jwtToken = null;
    _user = null;
    _isAuthenticated = false;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
