import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  // 🔧 Backend URL
  static const String _baseUrl =
      'https://nimbus-2k26-backend-2.onrender.com';

  // ⚠️ Replace this with your actual Web Client ID
  static const String _googleClientId =
      'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';

  // ── State ──
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

  // ── Google Sign-In ──
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _googleClientId,
    scopes: ['email', 'profile'],
  );

  // ── Init ──
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _jwtToken = prefs.getString('jwt_token');
    final userJson = prefs.getString('user');

    if (_jwtToken != null && userJson != null) {
      _user = jsonDecode(userJson);
      _isAuthenticated = true;
      notifyListeners();
    }
  }

  // ── Google Sign-In ──
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        _setLoading(false);
        return false;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        _errorMessage = 'Failed to get Google ID token';
        _setLoading(false);
        notifyListeners();
        return false;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/api/users/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        await _persistSession(
          body['token'],
          body['user'],
        );
        _setLoading(false);
        return true;
      } else {
        _errorMessage = body['error'] ?? 'Authentication failed';
        await _googleSignIn.signOut();
        _setLoading(false);
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Sign-in error: $e';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  // ✅ FIXED: logout method (this was missing in your error)
  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _clearSession();
    notifyListeners();
  }

  // ── Helpers ──
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