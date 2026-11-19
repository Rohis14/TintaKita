import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Otomatis pakai localhost di Web, dan IPv4 laptop di HP fisik
  static String get baseUrl =>
      kIsWeb ? 'http://localhost:5000/api' : 'http://10.44.21.186:5000/api';

  static const _sessionKeys = ['token', 'user_id', 'nama', 'email', 'role'];

  // ── Sesi lokal ──────────────────────────────────────────────
  static Future<void> saveSession(
    String token,
    Map<String, dynamic> user,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setInt('user_id', user['id']);
    await prefs.setString('nama', user['nama'] ?? '');
    await prefs.setString('email', user['email'] ?? '');
    await prefs.setString('role', user['role'] ?? 'PELANGGAN');
  }

  static Future<Map<String, dynamic>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) return null;

    return {
      'token': token,
      'id': prefs.getInt('user_id'),
      'nama': prefs.getString('nama') ?? '',
      'email': prefs.getString('email') ?? '',
      'role': prefs.getString('role') ?? 'PELANGGAN',
    };
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in _sessionKeys) {
      await prefs.remove(k);
    }
  }

  // ── Helper internal ─────────────────────────────────────────
  static Future<Map<String, String>> _authHeaders() async {
    final session = await getSession();
    return {
      'Content-Type': 'application/json',
      if (session != null) 'Authorization': 'Bearer ${session['token']}',
    };
  }

  static Map<String, dynamic> _parseResponse(http.Response res) {
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return {
        'success': false,
        'message': 'Respon server tidak valid (HTTP ${res.statusCode})',
      };
    }
  }

  /// Menjalankan request dengan timeout. Tidak pernah melempar error:
  /// kegagalan jaringan dikembalikan sebagai {success: false, message: ...}
  static Future<Map<String, dynamic>> _guard(
    Future<http.Response> Function() call, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      final res = await call().timeout(timeout);
      if (res.statusCode == 401) await clearSession();
      return _parseResponse(res);
    } catch (_) {
      return {
        'success': false,
        'message': 'Tidak dapat terhubung ke server. Periksa koneksi internet.',
      };
    }
  }

  static Future<Map<String, dynamic>> _multipart(
    String method,
    String path,
    Map<String, String> fields, {
    String? fileField,
    XFile? file,
  }) {
    return _guard(() async {
      final session = await getSession();
      final request = http.MultipartRequest(method, Uri.parse('$baseUrl$path'));
      if (session != null) {
        request.headers['Authorization'] = 'Bearer ${session['token']}';
      }
      request.fields.addAll(fields);
      if (file != null && fileField != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            fileField,
            await file.readAsBytes(),
            filename: file.name,
          ),
        );
      }
      return http.Response.fromStream(await request.send());
    }, timeout: const Duration(seconds: 60));
  }

  // ── Autentikasi ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String email, String password) {
    return _guard(
      () => http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ),
    );
  }

  static Future<Map<String, dynamic>> register(
    String nama,
    String email,
    String password,
    String hp,
  ) {
    return _guard(
      () => http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nama': nama,
          'email': email,
          'password': password,
          'hp': hp,
        }),
      ),
    );
  }

  // ── Produk ──────────────────────────────────────────────────
  static Future<List<dynamic>> getProducts({
    bool includeInactive = false,
  }) async {
    final path = includeInactive ? '/products?all=true' : '/products';
    final body = await _guard(() => http.get(Uri.parse('$baseUrl$path')));
    if (body['success'] == true && body['data'] is List) {
      return body['data'] as List<dynamic>;
    }
    throw Exception(body['message'] ?? 'Gagal memuat produk');
  }

  static Future<Map<String, dynamic>> saveProduct({
    int? id,
    required String name,
    required String deskripsi,
    required String unit,
    required String harga,
    bool isActive = true,
    XFile? thumbnailFile,
  }) {
    return _multipart(
      id == null ? 'POST' : 'PATCH',
      id == null ? '/products' : '/products/$id',
      {
        'name': name,
        'deskripsi': deskripsi,
        'unit': unit,
        'harga': harga,
        'is_active': isActive.toString(),
      },
      fileField: 'thumbnail',
      file: thumbnailFile,
    );
  }

  static Future<Map<String, dynamic>> deleteProduct(int id) {
    return _guard(
      () async => http.delete(
        Uri.parse('$baseUrl/products/$id'),
        headers: await _authHeaders(),
      ),
    );
  }

  // ── Pesanan ─────────────────────────────────────────────────
  static Future<List<dynamic>> getOrders() async {
    final body = await _guard(
      () async =>
          http.get(Uri.parse('$baseUrl/orders'), headers: await _authHeaders()),
    );
    if (body['success'] == true && body['data'] is List) {
      return body['data'] as List<dynamic>;
    }
    throw Exception(body['message'] ?? 'Gagal memuat pesanan');
  }

  static Future<Map<String, dynamic>> createOrder({
    required int produkId,
    required String quantity,
    required String notes,
    required XFile designFile,
  }) {
    return _multipart(
      'POST',
      '/orders',
      {'produk_id': produkId.toString(), 'quantity': quantity, 'notes': notes},
      fileField: 'design_image',
      file: designFile,
    );
  }

  static Future<Map<String, dynamic>> updateOrderStatus({
    required int orderId,
    required String status,
    String? rejectReason,
    XFile? resultFile,
  }) {
    return _multipart(
      'PATCH',
      '/orders/$orderId/status',
      {
        'status': status,
        if (rejectReason != null && rejectReason.isNotEmpty)
          'reject_reason': rejectReason,
      },
      fileField: 'result_image',
      file: resultFile,
    );
  }

  static Future<Map<String, dynamic>> cancelOrder(int orderId) {
    return _guard(
      () async => http.delete(
        Uri.parse('$baseUrl/orders/$orderId'),
        headers: await _authHeaders(),
      ),
    );
  }
}
