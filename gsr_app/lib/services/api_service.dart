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

  // ── Owner auth ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> ownerLogin(
      String mobile, String password) async {
    final res = await http
        .post(
          Uri.parse('$_base/owner/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'mobile': mobile, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return body;
    throw ApiException(body['detail']?.toString() ?? 'Login failed');
  }

  // ── Menu ──────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getMenu() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$_base/owner/menu'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    throw ApiException(body['detail']?.toString() ?? 'Failed to load menu');
  }

  static Future<Map<String, dynamic>> addMenuItem(
      Map<String, dynamic> item) async {
    final token = await getToken();
    final res = await http
        .post(
          Uri.parse('$_base/owner/menu/item'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(item),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 201) return body;
    throw ApiException(body['detail']?.toString() ?? 'Failed to add item');
  }

  static Future<Map<String, dynamic>> updateMenuItem(
      String id, Map<String, dynamic> item) async {
    final token = await getToken();
    final res = await http
        .put(
          Uri.parse('$_base/owner/menu/item/$id'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(item),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return body;
    throw ApiException(body['detail']?.toString() ?? 'Failed to update item');
  }

  static Future<void> toggleAvailability(String id) async {
    final token = await getToken();
    final res = await http.patch(
      Uri.parse('$_base/owner/menu/item/$id/availability'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(body['detail']?.toString() ?? 'Toggle failed');
    }
  }

  static Future<void> deleteMenuItem(String id) async {
    final token = await getToken();
    final res = await http.delete(
      Uri.parse('$_base/owner/menu/item/$id'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(body['detail']?.toString() ?? 'Delete failed');
    }
  }

  // ── Customer ──────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> searchRestaurants(
      String pincode) async {
    final res = await http.get(
      Uri.parse('$_base/customer/restaurants?pincode=$pincode'),
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    throw ApiException(
        body['detail']?.toString() ?? 'Failed to search restaurants');
  }

  static Future<Map<String, dynamic>> getRestaurantMenu(
      String restaurantId) async {
    final res = await http.get(
      Uri.parse('$_base/customer/restaurant/$restaurantId/menu'),
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    throw ApiException(body['detail']?.toString() ?? 'Failed to load menu');
  }

  // ── Orders (customer) ─────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> placeOrder(
      Map<String, dynamic> payload) async {
    final res = await http
        .post(
          Uri.parse('$_base/orders'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 201) return body;
    throw ApiException(body['detail']?.toString() ?? 'Failed to place order');
  }

  // ── Orders (owner) ────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getOwnerOrders(
      {String statusFilter = ''}) async {
    final token = await getToken();
    final uri = statusFilter.isEmpty
        ? Uri.parse('$_base/orders/owner')
        : Uri.parse('$_base/orders/owner?status_filter=$statusFilter');
    final res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    throw ApiException(body['detail']?.toString() ?? 'Failed to load orders');
  }

  static Future<Map<String, dynamic>> getOrderStatus(String orderId) async {
    final res = await http.get(
      Uri.parse('$_base/orders/$orderId'),
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    throw ApiException(body['detail']?.toString() ?? 'Order not found');
  }

  static Future<String?> getPincodeFromCoords(double lat, double lon) async {
    try {
      final res = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json'),
        headers: {'User-Agent': 'BossBite/1.0'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        return address?['postcode'] as String?;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> updateOrderStatus(
      String orderId, String status) async {
    final token = await getToken();
    final res = await http
        .patch(
          Uri.parse('$_base/orders/owner/$orderId/status'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'status': status}),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(
          body['detail']?.toString() ?? 'Failed to update status');
    }
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}
