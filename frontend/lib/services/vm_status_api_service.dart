import 'api_service.dart';

/// Backward-compatible wrapper. Prefer [ApiService] or [ReminderService].
@Deprecated('Use ApiService or ReminderService instead')
class VmStatusApiService {
  static final VmStatusApiService _instance =
      VmStatusApiService._internal();

  factory VmStatusApiService() => _instance;

  VmStatusApiService._internal();

  static String get baseUrl => ApiService.baseUrl;
  static set baseUrl(String value) => ApiService.baseUrl = value;

  final ApiService _api = ApiService();

  Future<bool> syncVmStatus({
    required String userId,
    required String reminderId,
    required String vmStatus,
  }) {
    return _api.syncVmStatus(
      userId: userId,
      reminderId: reminderId,
      vmStatus: vmStatus,
    );
  }

  Future<Map<String, dynamic>?> generateAudio({
    required String userId,
    required String reminderId,
  }) {
    return _api.generateAudio(userId: userId, reminderId: reminderId);
  }

  Future<bool> checkBackendConnection() {
    return _api.checkHome();
  }
}
