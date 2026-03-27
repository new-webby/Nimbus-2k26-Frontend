import 'package:flutter/material.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

enum AuthStatus { idle, loading, success, error }

// Google OAuth2 config — update CLIENT_ID with your real Google OAuth Client ID
// from https://console.cloud.google.com → APIs & Services → Credentials
const String _googleClientId = 'YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com';
const String _googleRedirectUrl = 'com.example.nimbus_2k26_frontend:/oauth2redirect';

class AuthProvider extends ChangeNotifier {
  // ── API Service ──────────────────────────────────────────────────
  final ApiService _apiService = ApiService();
  final FlutterAppAuth _appAuth = const FlutterAppAuth();

  // ── shared state ─────────────────────────────────────────────────
  AuthStatus _status = AuthStatus.idle;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _isAuthenticated = false;
  Map<String, dynamic>? _userData;

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get obscurePassword => _obscurePassword;
  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get userData => _userData;

  // ── login fields ─────────────────────────────────────────────────
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool rememberMe = false;

  // ── signup fields ────────────────────────────────────────────────
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController signupEmailController = TextEditingController();
  final TextEditingController rollNoController = TextEditingController();
  final TextEditingController signupPassController = TextEditingController();
  bool agreedToTerms = false;

  // ── password strength (0-4) ───────────────────────────────────────
  int _strength = 0;
  int get strength => _strength;

  // ─────────────────────────────────────────────────────────────────

  AuthProvider() {
    _checkExistingAuth();
  }

  /// Check if user is already logged in (token in SharedPreferences)
  Future<void> _checkExistingAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null && token.isNotEmpty) {
      _isAuthenticated = true;
      notifyListeners();
    }
  }

  void toggleObscurePassword() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void setRememberMe(bool val) {
    rememberMe = val;
    notifyListeners();
  }

  void setAgreedToTerms(bool val) {
    agreedToTerms = val;
    notifyListeners();
  }

  void onPasswordChanged(String value) {
    int s = 0;
    if (value.length >= 8) s++;
    if (value.contains(RegExp(r'[A-Z]'))) s++;
    if (value.contains(RegExp(r'[0-9]'))) s++;
    if (value.contains(RegExp(r'[^A-Za-z0-9]'))) s++;
    _strength = s;
    notifyListeners();
  }

  void _setStatus(AuthStatus s, {String? error}) {
    _status = s;
    _errorMessage = error;
    notifyListeners();
  }

  // ── Login ─────────────────────────────────────────────────────────
  Future<bool> login() async {
    _setStatus(AuthStatus.loading);
    try {
      final response = await _apiService.login(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      _userData = response['user'];
      _isAuthenticated = true;
      _setStatus(AuthStatus.success);
      return true;
    } catch (e) {
      _setStatus(AuthStatus.error, error: _cleanError(e.toString()));
      return false;
    }
  }

  // ── Sign Up ───────────────────────────────────────────────────────
  Future<bool> signUp() async {
    _setStatus(AuthStatus.loading);
    try {
      // Combine first + last name — backend only has `full_name` field
      final name =
          '${firstNameController.text.trim()} ${lastNameController.text.trim()}'
              .trim();
      await _apiService.register(
        name: name,
        email: signupEmailController.text.trim(),
        password: signupPassController.text,
      );
      // Auto-login after successful registration
      final loginResponse = await _apiService.login(
        email: signupEmailController.text.trim(),
        password: signupPassController.text,
      );
      _userData = loginResponse['user'];
      _isAuthenticated = true;
      _setStatus(AuthStatus.success);
      return true;
    } catch (e) {
      _setStatus(AuthStatus.error, error: _cleanError(e.toString()));
      return false;
    }
  }

  // ── Google Sign-In via OAuth2 (no Firebase needed) ────────────────
  Future<bool> googleSignIn() async {
    _setStatus(AuthStatus.loading);
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _googleClientId,
          _googleRedirectUrl,
          discoveryUrl:
              'https://accounts.google.com/.well-known/openid-configuration',
          scopes: ['openid', 'email', 'profile'],
          promptValues: ['select_account'],
        ),
      );

      if (result == null || result.idToken == null) {
        _setStatus(AuthStatus.error, error: 'Google sign-in was cancelled');
        return false;
      }

      final response = await _apiService.googleSignIn(
        idToken: result.idToken!,
      );
      _userData = response['user'];
      _isAuthenticated = true;
      _setStatus(AuthStatus.success);
      return true;
    } catch (e) {
      final msg = e.toString().contains('User cancelled')
          ? 'Sign-in cancelled'
          : _cleanError(e.toString());
      _setStatus(AuthStatus.error, error: msg);
      return false;
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _apiService.logout();
    _isAuthenticated = false;
    _userData = null;
    _clearControllers();
    _setStatus(AuthStatus.idle);
  }

  void _clearControllers() {
    emailController.clear();
    passwordController.clear();
    firstNameController.clear();
    lastNameController.clear();
    signupEmailController.clear();
    rollNoController.clear();
    signupPassController.clear();
  }

  void reset() {
    _isAuthenticated = false;
    _setStatus(AuthStatus.idle, error: null);
  }

  /// Strips "Exception: " prefix from error messages for clean UI display
  String _cleanError(String raw) {
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length);
    }
    return raw;
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    signupEmailController.dispose();
    rollNoController.dispose();
    signupPassController.dispose();
    super.dispose();
  }
}
