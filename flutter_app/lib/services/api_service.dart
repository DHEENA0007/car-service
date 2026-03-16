import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
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
    required XFile imageFile,
    Uint8List? imageBytes,
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
    if (kIsWeb && imageBytes != null) {
      final filename = imageFile.name.isNotEmpty ? imageFile.name : 'image.jpg';
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: filename,
      ));
    } else {
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    }

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

  static Future<String?> getCachedUserRole() async {
    final userData = await getCachedUserData();
    return userData?['role'] as String?;
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

  // ============ Bookings ============

  static Future<Map<String, dynamic>> createBooking(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/bookings/'),
      headers: _headers(),
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getMyBookings() async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/bookings/'),
      headers: _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getAvailableBookings() async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/bookings/available/'),
      headers: _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getBookingDetail(int bookingId) async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/bookings/$bookingId/'),
      headers: _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> acceptBooking(int bookingId) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/bookings/$bookingId/accept/'),
      headers: _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateBookingStatus(int bookingId, String newStatus) async {
    final response = await http.put(
      Uri.parse('${AppConstants.baseUrl}/bookings/$bookingId/status/'),
      headers: _headers(),
      body: jsonEncode({'status': newStatus}),
    );
    return jsonDecode(response.body);
  }

  // ============ Charge Sheets ============

  static Future<Map<String, dynamic>> createChargeSheet(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/charge-sheets/'),
      headers: _headers(),
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getChargeSheet(int bookingId) async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/charge-sheets/$bookingId/'),
      headers: _headers(),
    );
    return jsonDecode(response.body);
  }

  // ============ Payments ============

  static Future<Map<String, dynamic>> createPaymentOrder(int bookingId) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/payments/create-order/'),
      headers: _headers(),
      body: jsonEncode({'booking_id': bookingId}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> verifyPayment({
    required int bookingId,
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/payments/verify/'),
      headers: _headers(),
      body: jsonEncode({
        'booking_id': bookingId,
        'razorpay_payment_id': paymentId,
        'razorpay_order_id': orderId,
        'razorpay_signature': signature,
      }),
    );
    return jsonDecode(response.body);
  }

  // ============ Admin ============

  static Future<Map<String, dynamic>> getAdminStats() async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/admin/stats/'),
      headers: _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getAdminUsers({String? role}) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/admin/users/')
        .replace(queryParameters: role != null ? {'role': role} : null);
    final response = await http.get(uri, headers: _headers());
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateUserRole(int userId, String role) async {
    final response = await http.put(
      Uri.parse('${AppConstants.baseUrl}/admin/users/$userId/role/'),
      headers: _headers(),
      body: jsonEncode({'role': role}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getAdminAgents() async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/admin/agents/'),
      headers: _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> createAgentByAdmin(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/admin/agents/create/'),
      headers: _headers(),
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> approveAgent(int agentId, bool isApproved) async {
    final response = await http.put(
      Uri.parse('${AppConstants.baseUrl}/admin/agents/$agentId/approve/'),
      headers: _headers(),
      body: jsonEncode({'is_approved': isApproved}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getAdminScans() async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/admin/scans/'),
      headers: _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getAdminBookings({String? statusFilter}) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/admin/bookings/')
        .replace(queryParameters: statusFilter != null ? {'status': statusFilter} : null);
    final response = await http.get(uri, headers: _headers());
    return jsonDecode(response.body);
  }

  // ============ Vehicle Data (local asset, NHTSA fallback) ============

  static Map<String, dynamic>? _vehicleData;

  static Future<Map<String, dynamic>> _loadVehicleData() async {
    _vehicleData ??= jsonDecode(
      await rootBundle.loadString('assets/vehicle_data.json'),
    ) as Map<String, dynamic>;
    return _vehicleData!;
  }

  static Future<List<String>> getCarMakes() async {
    try {
      final data = await _loadVehicleData();
      final makes = (data['makes'] as List?)?.cast<String>() ?? [];
      return makes;
    } catch (_) {}
    // fallback to network
    try {
      final response = await http.get(
        Uri.parse('https://vpic.nhtsa.dot.gov/api/vehicles/getallmakes?format=json'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['Results'] as List? ?? [];
        return results
            .map((e) => (e['Make_Name'] as String).trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<String>> getCarModels(String make) async {
    if (make.isEmpty) return [];
    try {
      final data = await _loadVehicleData();
      final modelsMap = data['models'] as Map<String, dynamic>? ?? {};
      // Case-insensitive lookup
      final key = modelsMap.keys.firstWhere(
        (k) => k.toLowerCase() == make.toLowerCase(),
        orElse: () => '',
      );
      if (key.isNotEmpty) {
        return (modelsMap[key] as List).cast<String>();
      }
    } catch (_) {}
    // fallback to network for makes not in local asset
    try {
      final response = await http.get(
        Uri.parse('https://vpic.nhtsa.dot.gov/api/vehicles/getmodelsformake/$make?format=json'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['Results'] as List? ?? [];
        return results
            .map((e) => (e['Model_Name'] as String).trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
      }
    } catch (_) {}
    return [];
  }
}
