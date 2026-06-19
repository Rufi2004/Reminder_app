import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();

  Stream<bool> get onConnectivityChanged async* {
    yield await _initialStatus();
    await for (final result in _connectivity.onConnectivityChanged) {
      yield _isConnected(result);
    }
  }

  bool _isConnected(dynamic result) {
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }
    if (result is List<ConnectivityResult>) {
      return result.any((value) => value != ConnectivityResult.none);
    }
    return false;
  }

  Future<bool> _initialStatus() async {
    final result = await _connectivity.checkConnectivity();
    return _isConnected(result);
  }

  Future<bool> isOnline() => _initialStatus();
}
