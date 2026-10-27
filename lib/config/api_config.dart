import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

class ApiConfig {
  // Override either value at launch when the development machine's address
  // changes, for example:
  // flutter run --dart-define=API_HOST=172.20.10.7
  // flutter run --dart-define=API_BASE_URL=http://172.20.10.7:5000/api
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );
  static const String _androidApiHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: '10.103.135.194',
  );

  static String get ipAddress {
    if (kIsWeb) {
      return 'localhost';
    }
    if (Platform.isAndroid) {
      // Use the development computer's Wi-Fi address so USB is optional.
      // Override API_HOST when the address changes. For USB forwarding use
      // localhost; Android emulators use 10.0.2.2.
      return _androidApiHost;
    }
    if (Platform.isIOS) {
      return 'localhost'; // iOS simulator uses localhost directly
    }
    // Desktop (Windows/macOS/Linux)
    return 'localhost';
  }

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      final value = _configuredBaseUrl.endsWith('/')
          ? _configuredBaseUrl.substring(0, _configuredBaseUrl.length - 1)
          : _configuredBaseUrl;
      if (kReleaseMode && Uri.tryParse(value)?.scheme != 'https') {
        throw StateError('Release API_BASE_URL must use HTTPS');
      }
      return value;
    }

    if (kReleaseMode) {
      throw StateError('API_BASE_URL is required for release builds');
    }

    return 'http://$ipAddress:5000/api';
  }
}
