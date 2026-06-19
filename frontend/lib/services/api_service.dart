import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Low-level HTTP client for the Django backend.
/// UI and controllers must not call this directly — use [ReminderService].
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Override on a physical device, e.g. `http://192.168.1.10:8000`.
  static String baseUrl = 'http://10.42.8.253:8000';

  /// GET http://localhost:8000/
  Future<bool> checkHome() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[API] Home check failed: $e');
      return false;
    }
  }

  /// POST http://localhost:8000/sync-vm-status/
  Future<bool> syncVmStatus({
    required String userId,
    required String reminderId,
    required String vmStatus,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sync-vm-status/'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'reminder_id': reminderId,
          'vmStatus': vmStatus,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint(
          '[API] sync-vm-status failed: ${response.statusCode} ${response.body}',
        );
        return false;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['success'] == true;
    } catch (e) {
      debugPrint('[API] sync-vm-status error: $e');
      return false;
    }
  }

  /// GET http://localhost:8000/generate-audio/{userId}/{reminderId}/
  Future<Map<String, dynamic>?> generateAudio({
    required String userId,
    required String reminderId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/generate-audio/$userId/$reminderId/'),
      );

      if (response.statusCode != 200) {
        debugPrint(
          '[API] generate-audio failed: ${response.statusCode} ${response.body}',
        );
        return null;
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[API] generate-audio error: $e');
      return null;
    }
  }

  /// Rewrites backend localhost URLs so audio works on emulators/devices.
  String resolveAudioUrl(String audioUrl) {
    final audioUri = Uri.parse(audioUrl);
    final apiUri = Uri.parse(baseUrl);
    return audioUri
        .replace(scheme: apiUri.scheme, host: apiUri.host, port: apiUri.port)
        .toString();
  }
}
