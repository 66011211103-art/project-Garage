import 'dart:convert';
import 'dart:typed_data';
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
  // หมายเหตุ: ownerName / hoursWeekday / hoursWeekend / services เป็นพารามิเตอร์
  // เสริมสำหรับฝั่งอู่ซ่อม (userType == 'repair') เท่านั้น ไม่ใส่ก็ได้สำหรับฝั่งลูกค้า
  // latitude / longitude ใช้ได้ทั้งฝั่งลูกค้าและอู่ (มาจากการค้นหาที่อยู่แบบแชท)
  static Future<ApiResult> updateProfile({
    required int userId,
    required String name,
    required String phone,
    required String address,
    required String carModel,
    required String carPlate,
    required String userType,
    String? ownerName,
    String? hoursWeekday,
    String? hoursWeekend,
    List<String>? services,
    double? latitude,
    double? longitude,
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
              if (ownerName != null) 'ownerName': ownerName,
              if (hoursWeekday != null) 'hoursWeekday': hoursWeekday,
              if (hoursWeekend != null) 'hoursWeekend': hoursWeekend,
              if (services != null) 'services': services,
              if (latitude != null) 'latitude': latitude,
              if (longitude != null) 'longitude': longitude,
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

  // ===== REQUEST EMAIL CHANGE (ส่ง OTP ไปอีเมลใหม่) =====
  static Future<ApiResult> requestEmailChange({
    required int userId,
    required String newEmail,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/request-email-change'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'newEmail': newEmail}),
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

  // ===== CONFIRM EMAIL CHANGE (ยืนยัน OTP แล้วเปลี่ยนอีเมลจริง) =====
  static Future<ApiResult> confirmEmailChange({
    required int userId,
    required String otp,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/confirm-email-change'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'otp': otp}),
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

  // ===== UPLOAD AVATAR ===== ✅ รองรับทั้ง Web และมือถือด้วย bytes
  static Future<ApiResult> uploadAvatar({
    required int userId,
    required String userType,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/user/avatar'),
      );
      request.fields['userId'] = userId.toString();
      request.fields['userType'] = userType;
      request.files.add(
        http.MultipartFile.fromBytes('avatar', fileBytes, filename: fileName),
      );

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

  // ===== GET CARS =====
  static Future<ApiResult> getCars({required int userId}) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/cars?userId=$userId'))
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResult(
        success: body['success'] == true,
        message: body['message'] ?? '',
        data: body['data'],
      );
    } catch (e) {
      return ApiResult(success: false, message: 'ไม่สามารถดึงข้อมูลรถได้');
    }
  }

  // ===== ADD CAR =====
  static Future<ApiResult> addCar({
    required int userId,
    required String carModel,
    required String carPlate,
    String? carBrand,
    String? carColor,
    int? carYear,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/cars'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'carModel': carModel,
              'carPlate': carPlate,
              'carBrand': carBrand,
              'carColor': carColor,
              'carYear': carYear,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResult(
        success: body['success'] == true,
        message: body['message'] ?? '',
        data: body['data'],
      );
    } catch (e) {
      return ApiResult(success: false, message: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    }
  }

  // ===== UPDATE CAR =====
  static Future<ApiResult> updateCar({
    required int carId,
    required String carModel,
    required String carPlate,
    String? carBrand,
    String? carColor,
    int? carYear,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/cars/$carId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'carModel': carModel,
              'carPlate': carPlate,
              'carBrand': carBrand,
              'carColor': carColor,
              'carYear': carYear,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResult(
        success: body['success'] == true,
        message: body['message'] ?? '',
        data: body['data'],
      );
    } catch (e) {
      return ApiResult(success: false, message: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    }
  }

  // ===== DELETE CAR =====
  static Future<ApiResult> deleteCar({required int carId}) async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/cars/$carId'))
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResult(
        success: body['success'] == true,
        message: body['message'] ?? '',
        data: body['data'],
      );
    } catch (e) {
      return ApiResult(success: false, message: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    }
  }

  // ===== FORGOT PASSWORD (ขอ OTP) =====
  static Future<ApiResult> forgotPassword({required String email}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/forgot-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
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

  // ===== RESET PASSWORD (ยืนยัน OTP + ตั้งรหัสผ่านใหม่) =====
  static Future<ApiResult> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/reset-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'otp': otp,
              'newPassword': newPassword,
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
}