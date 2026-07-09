import 'dart:convert';
import 'package:http/http.dart' as http;

/// ผลลัพธ์มาตรฐานจากการเรียก API
class ApiResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  ApiResult({required this.success, required this.message, this.data});
}

class ApiService {
  // TODO: แก้ให้ตรงกับของจริงในโปรเจกต์คุณ
  // - รันบน Android Emulator ให้ใช้ 10.0.2.2 แทน localhost
  // - รันบนเครื่องจริง/เว็บให้ใช้ IP หรือ domain จริงของ server
  static const String baseUrl = 'http://localhost:3000/api';

  // ===== LOGIN =====
  static Future<ApiResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final body = jsonDecode(response.body);

      return ApiResult(
        success: body['success'] ?? false,
        message: body['message'] ?? 'เกิดข้อผิดพลาด',
        data: body['data'],
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้',
      );
    }
  }

  // ===== GOOGLE LOGIN ===== ✅ เพิ่มใหม่
  // ส่ง idToken ที่ได้จาก Google Sign-In ไปให้ backend ตรวจสอบที่
  // endpoint /api/auth/google-login (ตามที่ตั้งไว้ฝั่ง server.js)
  // backend จะเป็นคนตัดสินว่าจะผูกกับ user เดิม หรือสร้าง user ใหม่ประเภท customer
  static Future<ApiResult> googleLogin({required String idToken}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/google-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      final body = jsonDecode(response.body);

      return ApiResult(
        success: body['success'] ?? false,
        message: body['message'] ?? 'เกิดข้อผิดพลาด',
        data: body['data'],
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้',
      );
    }
  }

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
      final response = await http.post(
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
      );

      final body = jsonDecode(response.body);

      return ApiResult(
        success: body['success'] ?? false,
        message: body['message'] ?? 'เกิดข้อผิดพลาด',
        data: body['data'],
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้',
      );
    }
  }

  // ===== UPDATE PROFILE =====
  static Future<ApiResult> updateProfile({
    required dynamic userId,
    required String name,
    required String phone,
    required String address,
    required String carModel,
    required String carPlate,
    required String userType,
  }) async {
    try {
      final response = await http.put(
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
      );

      final body = jsonDecode(response.body);

      return ApiResult(
        success: body['success'] ?? false,
        message: body['message'] ?? 'เกิดข้อผิดพลาด',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้',
      );
    }
  }

  // ===== GET PROFILE =====
  static Future<ApiResult> getProfile({
    required dynamic userId,
    required String userType,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/profile?userId=$userId&userType=$userType'),
      );

      final body = jsonDecode(response.body);

      return ApiResult(
        success: body['success'] ?? false,
        message: body['message'] ?? 'เกิดข้อผิดพลาด',
        data: body['data'],
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้',
      );
    }
  }

  // ===== UPLOAD AVATAR =====
  static Future<ApiResult> uploadAvatar({
    required dynamic userId,
    required String userType,
    required String filePath,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/user/avatar');
      final request = http.MultipartRequest('POST', uri)
        ..fields['userId'] = userId.toString()
        ..fields['userType'] = userType
        ..files.add(await http.MultipartFile.fromPath('avatar', filePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final body = jsonDecode(response.body);

      return ApiResult(
        success: body['success'] ?? false,
        message: body['message'] ?? 'เกิดข้อผิดพลาด',
        data: body['data'],
      );
    } catch (e) {
      return ApiResult(success: false, message: 'อัปโหลดรูปไม่สำเร็จ');
    }
  }

  // ===== FORGOT PASSWORD (ขอ OTP) =====
  static Future<ApiResult> forgotPassword({required String email}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final body = jsonDecode(response.body);

      return ApiResult(
        success: body['success'] ?? false,
        message: body['message'] ?? 'เกิดข้อผิดพลาด',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้',
      );
    }
  }

  // ===== RESET PASSWORD (ยืนยัน OTP + ตั้งรหัสผ่านใหม่) =====
  static Future<ApiResult> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp': otp,
          'newPassword': newPassword,
        }),
      );

      final body = jsonDecode(response.body);

      return ApiResult(
        success: body['success'] ?? false,
        message: body['message'] ?? 'เกิดข้อผิดพลาด',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้',
      );
    }
  }
}