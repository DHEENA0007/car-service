import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ApiService {
  static String? _token;

  static Future<String?> getToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    return _token;
  }

  static Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Map<String, String> _headers({bool withAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (withAuth && _token != null) {
      headers['Authorization'] = 'Token $_token';
    }
    return headers;
  }

  // ============ Auth ============

  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String password,
    required String confirmPassword,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/register/'),
      headers: _headers(withAuth: false),
      body: jsonEncode({
        'username': username,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'password': password,
        'confirm_password': confirmPassword,
      }),
    );
    final data = jsonDecode(response.body);
    if (data['success'] == true) {
      await setToken(data['data']['token']);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(data['data']['user']));
    }
    return data;
  }

  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/login/'),
      headers: _headers(withAuth: false),
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );
    final data = jsonDecode(response.body);
    if (data['success'] == true) {
      await setToken(data['data']['token']);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(data['data']['user']));
    }
    return data;
  }

  static Future<void> logout() async {
    try {
      await http.post(
        Uri.parse('${AppConstants.baseUrl}/auth/logout/'),
        headers: _headers(),
      );
    } catch (_) {}
    await clearToken();
  }

  // ============ Profile ============

  static Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/auth/profile/'),
      headers: _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('${AppConstants.baseUrl}/auth/profile/'),
      headers: _headers(),
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  // ============ Scan / AI Analysis ============

  static Future<Map<String, dynamic>> analyzeImage({
    required File imageFile,
    String? description,
  }) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConstants.baseUrl}/scan/analyze/'),
    );

    request.headers['Authorization'] = 'Token $token';
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    if (description != null && description.isNotEmpty) {
      request.fields['description'] = description;
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return jsonDecode(response.body);
  }

  // ============ Scan History ============

  static Future<Map<String, dynamic>> getScanHistory() async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/scan/history/'),
      headers: _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getScanDetail(int scanId) async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/scan/$scanId/'),
      headers: _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> deleteScan(int scanId) async {
    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/scan/$scanId/delete/'),
      headers: _headers(),
    );
    return jsonDecode(response.body);
  }

  // ============ Service Centers ============

  static Future<Map<String, dynamic>> getServiceCenters(int scanId) async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/scan/$scanId/service-centers/'),
      headers: _headers(),
    );
    return jsonDecode(response.body);
  }

  // ============ User Data ============

  static Future<Map<String, dynamic>?> getCachedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_data');
    if (userData != null) {
      return jsonDecode(userData);
    }
    return null;
  }
}
