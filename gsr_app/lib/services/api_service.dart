import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _base = 'http://43.204.43.71:8000';
const _tokenKey = 'gsr_token';
const _roleKey = 'gsr_role';

class ApiService {
  static Future<void> saveToken(String token, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_roleKey, role);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
  }

  static Future<Map<String, dynamic>> adminLogin(
      String username, String password, String totpCode) async {
    final res = await http
        .post(
          Uri.parse('$_base/auth/admin/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': username,
            'password': password,
            'totp_code': totpCode,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return body;
    throw ApiException(body['detail']?.toString() ?? 'Login failed');
  }

  static Future<List<Map<String, dynamic>>> kycPending() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$_base/admin/kyc/pending'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    throw ApiException(body['detail']?.toString() ?? 'Failed to load KYC list');
  }

  static Future<void> kycApprove(String ownerId) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$_base/admin/kyc/$ownerId/approve'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(body['detail']?.toString() ?? 'Approve failed');
    }
  }

  static Future<void> kycReject(String ownerId, String reason) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$_base/admin/kyc/$ownerId/reject'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'reason': reason}),
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(body['detail']?.toString() ?? 'Reject failed');
    }
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}
