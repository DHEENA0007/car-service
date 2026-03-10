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
    double? latitude,
    double? longitude,
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
    if (latitude != null) {
      request.fields['latitude'] = latitude.toString();
    }
    if (longitude != null) {
      request.fields['longitude'] = longitude.toString();
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

  static Future<Map<String, dynamic>> getPlaceDetail(String eloc) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/place-detail/$eloc/'),
        headers: _headers(),
      );
      return jsonDecode(response.body);
    } catch (_) {
      return {'success': false, 'data': {}};
    }
  }

  /// Reverse geocode coordinates to a human-readable address using Mappls.
  /// Returns map with formatted_address, locality, city, state, pincode.
  static Future<Map<String, dynamic>> reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}/reverse-geocode/')
          .replace(queryParameters: {'lat': lat.toString(), 'lng': lng.toString()});
      final response = await http.get(uri, headers: _headers());
      final body = jsonDecode(response.body);
      if (body['success'] == true) return body['data'] as Map<String, dynamic>;
    } catch (_) {}
    return {};
  }

  /// Get turn-by-turn route from user location to a service center via Mappls Route API.
  /// [eloc] is preferred over [destLat]/[destLng] for accuracy.
  /// Returns map with steps[], distance_text, duration_text, overview_polyline,
  /// destination_lat, destination_lng — or {} on failure.
  static Future<Map<String, dynamic>> getRoute({
    required double originLat,
    required double originLng,
    String? eloc,
    double? destLat,
    double? destLng,
  }) async {
    try {
      final params = <String, String>{
        'origin_lat': originLat.toString(),
        'origin_lng': originLng.toString(),
        if (eloc != null && eloc.isNotEmpty) 'eloc': eloc,
        if (destLat != null) 'dest_lat': destLat.toString(),
        if (destLng != null) 'dest_lng': destLng.toString(),
      };
      final uri = Uri.parse('${AppConstants.baseUrl}/route/')
          .replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers());
      final body = jsonDecode(response.body);
      if (body['success'] == true) return body['data'] as Map<String, dynamic>;
    } catch (_) {}
    return {};
  }

  // ============ Auth – Forgot Password ============

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/forgot-password/'),
      headers: _headers(withAuth: false),
      body: jsonEncode({'email': email}),
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

  // ============ Garage – Vehicles ============

  static Future<Map<String, dynamic>> getVehicles() async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/garage/vehicles/'),
      headers: _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addVehicle(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/garage/vehicles/'),
      headers: _headers(),
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateVehicle(int vehicleId, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('${AppConstants.baseUrl}/garage/vehicles/$vehicleId/'),
      headers: _headers(),
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> deleteVehicle(int vehicleId) async {
    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/garage/vehicles/$vehicleId/'),
      headers: _headers(),
    );
    return jsonDecode(response.body);
  }

  // ============ Garage – Service Records ============

  static Future<Map<String, dynamic>> getServiceRecords(int vehicleId) async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/garage/vehicles/$vehicleId/records/'),
      headers: _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addServiceRecord({
    required int vehicleId,
    required Map<String, dynamic> data,
    File? billImage,
  }) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConstants.baseUrl}/garage/vehicles/$vehicleId/records/'),
    );
    request.headers['Authorization'] = 'Token $token';
    data.forEach((key, value) {
      if (value != null) request.fields[key] = value.toString();
    });
    if (billImage != null) {
      request.files.add(await http.MultipartFile.fromPath('bill_image', billImage.path));
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateServiceRecord({
    required int vehicleId,
    required int recordId,
    required Map<String, dynamic> data,
    File? billImage,
  }) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('${AppConstants.baseUrl}/garage/vehicles/$vehicleId/records/$recordId/'),
    );
    request.headers['Authorization'] = 'Token $token';
    data.forEach((key, value) {
      if (value != null) request.fields[key] = value.toString();
    });
    if (billImage != null) {
      request.files.add(await http.MultipartFile.fromPath('bill_image', billImage.path));
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> deleteServiceRecord(int vehicleId, int recordId) async {
    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/garage/vehicles/$vehicleId/records/$recordId/'),
      headers: _headers(),
    );
    return jsonDecode(response.body);
  }
}
