/// App-wide constants and theme configuration
class AppConstants {
  // API Configuration - Change this to your server IP
  static const String serverUrl = 'http://127.0.0.1:8000'; // Android emulator
  // static const String serverUrl = 'http://localhost:8000'; // iOS simulator
  // static const String serverUrl = 'http://YOUR_IP:8000'; // Physical device

  static const String baseUrl = '$serverUrl/api';

  // App Info
  static const String appName = 'AutoDiagno';
  static const String appTagline = 'AI-Powered Vehicle Diagnosis';
  static const String appVersion = '1.0.0';
}
