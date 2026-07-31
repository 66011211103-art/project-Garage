import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  ApiResult({required this.success, required this.message, this.data});
}

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:3000/api';

  // ===== REGISTER =====
  static Future<ApiResult> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String password,
    required String userType,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'firstName': firstName,
              'lastName': lastName,
              'phone': phone,
              'email': email,
              'password': password,
              'userType': userType,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResult(
        success: body['success'] == true,
        message: body['message'] ?? 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ',
        data: body['data'],
      );
    } catch (e) {
      return ApiResult(success: false, message: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    }
  }

  // ===== LOGIN =====
  static Future<ApiResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResult(
        success: body['success'] == true,
        message: body['message'] ?? 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ',
        data: body['data'],
      );
    } catch (e) {
      return ApiResult(success: false, message: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    }
  }

  // ===== UPDATE PROFILE =====
  static Future<ApiResult> updateProfile({
    required int userId,
    required String name,
    required String phone,
    required String address,
    required String carModel,
    required String carPlate,
    required String userType,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/user/update'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'name': name,
              'phone': phone,
              'address': address,
              'carModel': carModel,
              'carPlate': carPlate,
              'userType': userType,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResult(
        success: body['success'] == true,
        message: body['message'] ?? 'เกิดข้อผิดพลาด',
        data: body['data'],
      );
    } catch (e) {
      return ApiResult(success: false, message: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    }
  }

  // ===== UPLOAD AVATAR ===== ✅ เพิ่มตรงนี้
  static Future<ApiResult> uploadAvatar({
    required int userId,
    required String userType,
    required String filePath,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/user/avatar'),
      );
      request.fields['userId'] = userId.toString();
      request.fields['userType'] = userType;
      request.files.add(await http.MultipartFile.fromPath('avatar', filePath));

      final response = await request.send().timeout(const Duration(seconds: 30));
      final body = jsonDecode(await response.stream.bytesToString());

      return ApiResult(
        success: body['success'] == true,
        message: body['message'] ?? 'เกิดข้อผิดพลาด',
        data: body['data'],
      );
    } catch (e) {
      return ApiResult(success: false, message: 'อัปโหลดไม่สำเร็จ');
    }
  }
  // ===== GET PROFILE =====
static Future<ApiResult> getProfile({
  required int userId,
  required String userType,
}) async {
  try {
    final response = await http
        .get(Uri.parse('$baseUrl/user/profile?userId=$userId&userType=$userType'))
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return ApiResult(
      success: body['success'] == true,
      message: body['message'] ?? '',
      data: body['data'],
    );
  } catch (e) {
    return ApiResult(success: false, message: 'ไม่สามารถดึงข้อมูลได้');
  }
}
}