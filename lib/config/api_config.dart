import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  /// Automatically determines the correct backend URL based on platform:
  /// - Web (Chrome): uses localhost
  /// - Android Emulator: uses 10.0.2.2 (special alias for host machine)
  /// - Physical Device: uses localhost (via ADB reverse) or LAN IP
  ///
  /// TIP: To avoid changing IP on physical devices, use ADB port forwarding:
  ///   Run in terminal: adb reverse tcp:5000 tcp:5000
  ///   Then the physical device can also use 'localhost'

  // Only needed if NOT using ADB reverse (for physical device testing)
  static const String _physicalDeviceIp = '10.135.155.194';

  static String get ipAddress {
    if (kIsWeb) {
      return 'localhost';
    }
    if (Platform.isAndroid) {
      // 'localhost' works if you ran: adb reverse tcp:5000 tcp:5000
      // Otherwise change 'localhost' below to _physicalDeviceIp
      return 'localhost';
    }
    if (Platform.isIOS) {
      return 'localhost'; // iOS simulator uses localhost directly
    }
    // Desktop (Windows/macOS/Linux)
    return 'localhost';
  }

  static String get baseUrl => 'http://$ipAddress:5000/api';
}
