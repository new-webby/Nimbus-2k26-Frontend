import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/room_model.dart';

/// HTTP client for the Nimbus Mafia backend.
/// JWT is read from SharedPreferences (key: 'jwt_token').
/// Base URL is read from env or falls back to the Render deployment.
class GameApi {
  GameApi._();
  static final GameApi instance = GameApi._();

  static const String _baseUrl =
      String.fromEnvironment('API_BASE_URL',
          defaultValue: 'https://nimbus-2k26-backend.onrender.com');

  // ─── TOKEN ──────────────────────────────────────────────────────────────────

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // ─── ROOM STATE (Reconnect entry point) ─────────────────────────────────────

  /// GET /api/game/rooms/:code
  /// Returns [RoomModel] with [myRole] and [timeRemaining] populated.
  /// Throws [GameApiException] on failure.
  Future<RoomModel> getRoomState(String roomCode) async {
    final token = await _getToken();
    if (token == null) throw const GameApiException('Not authenticated', 401);

    final uri = Uri.parse('$_baseUrl/api/game/rooms/$roomCode');
    final response = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return RoomModel.fromJson(json);
    } else if (response.statusCode == 404) {
      throw const GameApiException('Room not found', 404);
    } else {
      final body = _tryDecodeError(response.body);
      throw GameApiException(body, response.statusCode);
    }
  }

  // ─── ACTIVE ROOM PERSISTENCE ────────────────────────────────────────────────

  /// Persists the room code so reconnect works on app relaunch.
  Future<void> saveActiveRoom(String roomCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_room_code', roomCode);
  }

  /// Returns the persisted room code, or null if none.
  Future<String?> getActiveRoomCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('active_room_code');
  }

  /// Clears the persisted room code (call on game-ended or home navigation).
  Future<void> clearActiveRoom() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_room_code');
  }

  // ─── HELPERS ────────────────────────────────────────────────────────────────

  String _tryDecodeError(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['error'] as String? ?? 'Unknown error';
    } catch (_) {
      return body;
    }
  }
}

// ─── EXCEPTION ────────────────────────────────────────────────────────────────

class GameApiException implements Exception {
  final String message;
  final int statusCode;

  const GameApiException(this.message, this.statusCode);

  @override
  String toString() => 'GameApiException($statusCode): $message';
}
