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
  static const String baseUrl = 'http://10.160.75.155:3000/api';

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
    List<dynamic>? services, // ✅ รองรับทั้ง List<String> เดิม และ List<Map> ใหม่ที่มีชื่อ+ราคา
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

  // ===== SEARCH / LIST GARAGES (สำหรับหน้าค้นหาฝั่งลูกค้า) =====
  // service: กรองตามหมวดบริการ เช่น "ยาง" (null หรือ "" = ไม่กรอง)
  // keyword: ค้นหาจากชื่อร้าน
  static Future<ApiResult> searchGarages({String? service, String? keyword}) async {
    try {
      final queryParams = <String, String>{};
      if (service != null && service.isNotEmpty) queryParams['service'] = service;
      if (keyword != null && keyword.isNotEmpty) queryParams['keyword'] = keyword;

      final uri = Uri.parse('$baseUrl/garages').replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 15));
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

  // ===== SUBMIT REPAIR REQUEST (ส่งคำขอซ่อมรถ พร้อมรูปภาพ) =====
  static Future<ApiResult> submitRepairRequest({
    required int customerId,
    required int garageId,
    required String vehicleType,
    required String problemCategory,
    required String description,
    required String address,
    double? latitude,
    double? longitude,
    List<Uint8List> photos = const [],
    List<String> photoNames = const [],
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/repair-requests'),
      );
      request.fields['customerId'] = customerId.toString();
      request.fields['garageId'] = garageId.toString();
      request.fields['vehicleType'] = vehicleType;
      request.fields['problemCategory'] = problemCategory;
      request.fields['description'] = description;
      request.fields['address'] = address;
      if (latitude != null) request.fields['latitude'] = latitude.toString();
      if (longitude != null) request.fields['longitude'] = longitude.toString();

      for (var i = 0; i < photos.length; i++) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'photos',
            photos[i],
            filename: i < photoNames.length ? photoNames[i] : 'photo_$i.jpg',
          ),
        );
      }

      final response = await request.send().timeout(const Duration(seconds: 30));
      final body = jsonDecode(await response.stream.bytesToString());

      return ApiResult(
        success: body['success'] == true,
        message: body['message'] ?? 'เกิดข้อผิดพลาด',
        data: body['data'],
      );
    } catch (e) {
      return ApiResult(success: false, message: 'ส่งคำขอไม่สำเร็จ กรุณาลองใหม่');
    }
  }

  // ===== GET REPAIR REQUESTS (ฝั่งอู่ ดูคำขอที่ลูกค้าส่งเข้ามา) =====
  static Future<ApiResult> getRepairRequests({int? garageId, int? customerId, int? technicianId}) async {
    try {
      final uri = Uri.parse('$baseUrl/repair-requests').replace(
        queryParameters: {
          if (garageId != null) 'garageId': garageId.toString(),
          if (customerId != null) 'customerId': customerId.toString(),
          if (technicianId != null) 'technicianId': technicianId.toString(),
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
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

  // ===== UPDATE REPAIR REQUEST STATUS (รับงาน / ปฏิเสธ / เสร็จงาน) =====
  static Future<ApiResult> updateRepairRequestStatus({
    required int requestId,
    required String status, // 'accepted' | 'rejected' | 'done'
    String? reason, // ใช้ตอน status == 'rejected' เท่านั้น
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/repair-requests/$requestId/status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'status': status,
              if (reason != null) 'reason': reason,
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

  // ===== นับจำนวนคำขอที่อู่ตอบกลับแล้ว แต่ลูกค้ายังไม่ได้เปิดดู (โชว์ที่กระดิ่ง) =====
  // ===== เพิ่มบัญชีช่างใหม่ (ฝั่งอู่) =====
  static Future<ApiResult> createTechnician({
    required int garageId,
    required String name,
    required String phone,
    required String email,
    required String password,
    String? specialties,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/technicians'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'garageId': garageId,
              'name': name,
              'phone': phone,
              'email': email,
              'password': password,
              if (specialties != null) 'specialties': specialties,
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

  // ===== ดูรายชื่อช่างในสังกัดอู่ =====
  static Future<ApiResult> getTechnicians({required int garageId}) async {
    try {
      final uri = Uri.parse('$baseUrl/technicians').replace(
        queryParameters: {'garageId': garageId.toString()},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
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

  // ===== เปิด/ปิดการใช้งานบัญชีช่าง =====
  static Future<ApiResult> updateTechnicianStatus({
    required int technicianId,
    required String status, // 'active' | 'inactive'
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/technicians/$technicianId/status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'status': status}),
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

  // ===== มอบหมายงานให้ช่าง =====
  static Future<ApiResult> assignTechnician({
    required int requestId,
    required int technicianId,
    String? assignmentDate,
    String? assignmentNote,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/repair-requests/$requestId/assign'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'technicianId': technicianId,
              if (assignmentDate != null) 'assignmentDate': assignmentDate,
              if (assignmentNote != null) 'assignmentNote': assignmentNote,
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

  // ===== ช่างอัปเดตสถานะงาน (เริ่มซ่อม / ซ่อมเสร็จ) =====
  static Future<ApiResult> updateTechnicianJobStatus({
    required int requestId,
    required String status, // 'in_progress' | 'completed'
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/repair-requests/$requestId/technician-status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'status': status}),
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

  // ===== ช่างบันทึกความคืบหน้างานซ่อม (โน้ต + อะไหล่ + รูป) =====
  static Future<ApiResult> createRepairLog({
    required int repairRequestId,
    required int technicianId,
    required String note,
    required String partsUsed,
    List<Uint8List> photos = const [],
    List<String> photoNames = const [],
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/repair-logs'),
      );
      request.fields['repairRequestId'] = repairRequestId.toString();
      request.fields['technicianId'] = technicianId.toString();
      request.fields['note'] = note;
      request.fields['partsUsed'] = partsUsed;

      for (var i = 0; i < photos.length; i++) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'photos',
            photos[i],
            filename: i < photoNames.length ? photoNames[i] : 'log_$i.jpg',
          ),
        );
      }

      final response = await request.send().timeout(const Duration(seconds: 30));
      final body = jsonDecode(await response.stream.bytesToString());
      return ApiResult(
        success: body['success'] == true,
        message: body['message'] ?? 'เกิดข้อผิดพลาด',
        data: body['data'],
      );
    } catch (e) {
      return ApiResult(success: false, message: 'บันทึกไม่สำเร็จ กรุณาลองใหม่');
    }
  }

  // ===== ดูไทม์ไลน์ความคืบหน้าของงานซ่อม =====
  static Future<ApiResult> getRepairLogs({required int repairRequestId}) async {
    try {
      final uri = Uri.parse('$baseUrl/repair-logs').replace(
        queryParameters: {'repairRequestId': repairRequestId.toString()},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
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

  static Future<ApiResult> getUnseenRequestCount({required int customerId}) async {
    try {
      final uri = Uri.parse('$baseUrl/repair-requests/unseen-count').replace(
        queryParameters: {'customerId': customerId.toString()},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
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

  // ===== มาร์คว่าลูกค้าเปิดดูคำขอทั้งหมดแล้ว (เรียกตอนกดเข้ากระดิ่ง/หน้าประวัติ) =====
  static Future<ApiResult> markRequestsSeen({required int customerId}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/repair-requests/mark-seen'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'customerId': customerId}),
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

  // ===== CREATE QUOTATION (อู่สร้างใบเสนอราคา) =====
  static Future<ApiResult> createQuotation({
    required int repairRequestId,
    required List<Map<String, dynamic>> items,
    required double laborCost,
    double? totalPrice, // ✅ ยอดรวมสุทธิที่รวม VAT 7% แล้ว (คำนวณจาก Flutter ฝั่งอู่)
    String? estimatedStartDate, // 'YYYY-MM-DD'
    String? estimatedEndDate,
    String? notes,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/quotations'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'repairRequestId': repairRequestId,
              'items': items,
              'laborCost': laborCost,
              if (totalPrice != null) 'totalPrice': totalPrice,
              'estimatedStartDate': estimatedStartDate,
              'estimatedEndDate': estimatedEndDate,
              'notes': notes,
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
      return ApiResult(success: false, message: 'สร้างใบเสนอราคาไม่สำเร็จ');
    }
  }

  // ===== UPDATE QUOTATION (อู่แก้ไขใบเสนอราคาที่ส่งไปแล้ว) =====
  // ⚠️ ต้องมี endpoint ฝั่ง backend รองรับด้วย: PUT /api/quotations/:id
  static Future<ApiResult> updateQuotation({
    required int quotationId,
    required List<Map<String, dynamic>> items,
    required double laborCost,
    double? totalPrice, // ✅ ยอดรวมสุทธิที่รวม VAT 7% แล้ว
    String? estimatedStartDate, // 'YYYY-MM-DD'
    String? estimatedEndDate,
    String? notes,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/quotations/$quotationId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'items': items,
              'laborCost': laborCost,
              if (totalPrice != null) 'totalPrice': totalPrice,
              'estimatedStartDate': estimatedStartDate,
              'estimatedEndDate': estimatedEndDate,
              'notes': notes,
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
      return ApiResult(success: false, message: 'แก้ไขใบเสนอราคาไม่สำเร็จ');
    }
  }

  // ===== GET QUOTATION (ดูใบเสนอราคาของคำขอซ่อมหนึ่งรายการ) =====
  static Future<ApiResult> getQuotation({required int repairRequestId}) async {
    try {
      final uri = Uri.parse('$baseUrl/quotations').replace(
        queryParameters: {'repairRequestId': repairRequestId.toString()},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
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

  // ===== RESPOND TO QUOTATION (ลูกค้ายืนยัน/ปฏิเสธใบเสนอราคา) =====
  static Future<ApiResult> respondToQuotation({
    required int quotationId,
    required String status, // 'confirmed' | 'rejected'
    String? reason,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/quotations/$quotationId/respond'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'status': status,
              if (reason != null) 'reason': reason,
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

  // ===== ลูกค้าให้คะแนน/รีวิวอู่ซ่อม (ทำได้เมื่องานซ่อม status = 'completed' แล้วเท่านั้น) =====
  static Future<ApiResult> submitReview({
    required int repairRequestId,
    required int customerId,
    required int rating,
    int? qualityRating,
    int? priceRating,
    int? serviceRating,
    String? comment,
    List<Uint8List> photos = const [],
    List<String> photoNames = const [],
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/reviews'));
      request.fields['repairRequestId'] = repairRequestId.toString();
      request.fields['customerId'] = customerId.toString();
      request.fields['rating'] = rating.toString();
      if (qualityRating != null) request.fields['qualityRating'] = qualityRating.toString();
      if (priceRating != null) request.fields['priceRating'] = priceRating.toString();
      if (serviceRating != null) request.fields['serviceRating'] = serviceRating.toString();
      if (comment != null) request.fields['comment'] = comment;

      for (var i = 0; i < photos.length; i++) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'photos',
            photos[i],
            filename: i < photoNames.length ? photoNames[i] : 'review_$i.jpg',
          ),
        );
      }

      final response = await request.send().timeout(const Duration(seconds: 30));
      final body = jsonDecode(await response.stream.bytesToString()) as Map<String, dynamic>;
      return ApiResult(
        success: body['success'] == true,
        message: body['message'] ?? 'เกิดข้อผิดพลาด',
        data: body['data'],
      );
    } catch (e) {
      return ApiResult(success: false, message: 'ส่งรีวิวไม่สำเร็จ กรุณาลองใหม่');
    }
  }

  // ===== ดูรีวิว — ส่ง repairRequestId (เช็กว่างานนี้รีวิวหรือยัง) หรือ garageId (รีวิวทั้งหมดของอู่ + คะแนนเฉลี่ย) =====
  static Future<ApiResult> getReviews({int? garageId, int? repairRequestId}) async {
    try {
      final uri = Uri.parse('$baseUrl/reviews').replace(
        queryParameters: {
          if (garageId != null) 'garageId': garageId.toString(),
          if (repairRequestId != null) 'repairRequestId': repairRequestId.toString(),
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
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

  // ===== อู่ตอบกลับรีวิวของลูกค้า =====
  static Future<ApiResult> replyToReview({
    required int reviewId,
    required int garageId,
    required String reply,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/reviews/$reviewId/reply'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'garageId': garageId, 'reply': reply}),
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

  // ===== ลูกค้าแจ้งชำระเงิน (แนบสลิป) =====
  static Future<ApiResult> submitPayment({
    required int repairRequestId,
    required int customerId,
    required int garageId,
    required double amount,
    required String method, // bank_transfer | qr | credit_card
    required Uint8List slipBytes,
    required String slipName,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/payments'));
      request.fields['repairRequestId'] = repairRequestId.toString();
      request.fields['customerId'] = customerId.toString();
      request.fields['garageId'] = garageId.toString();
      request.fields['amount'] = amount.toString();
      request.fields['method'] = method;
      request.files.add(http.MultipartFile.fromBytes('slip', slipBytes, filename: slipName));

      final response = await request.send().timeout(const Duration(seconds: 30));
      final body = jsonDecode(await response.stream.bytesToString()) as Map<String, dynamic>;
      return ApiResult(
        success: body['success'] == true,
        message: body['message'] ?? 'เกิดข้อผิดพลาด',
        data: body['data'],
      );
    } catch (e) {
      return ApiResult(success: false, message: 'แจ้งชำระเงินไม่สำเร็จ กรุณาลองใหม่');
    }
  }

  // ===== ดูข้อมูลการชำระเงิน — ระบุ repairRequestId, customerId, หรือ garageId =====
  static Future<ApiResult> getPayments({int? repairRequestId, int? customerId, int? garageId}) async {
    try {
      final uri = Uri.parse('$baseUrl/payments').replace(
        queryParameters: {
          if (repairRequestId != null) 'repairRequestId': repairRequestId.toString(),
          if (customerId != null) 'customerId': customerId.toString(),
          if (garageId != null) 'garageId': garageId.toString(),
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
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

  // ===== อู่ยืนยัน/ปฏิเสธการชำระเงิน =====
  static Future<ApiResult> confirmPayment({required int paymentId, required int garageId}) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/payments/$paymentId/confirm'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'garageId': garageId}),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResult(success: body['success'] == true, message: body['message'] ?? 'เกิดข้อผิดพลาด');
    } catch (e) {
      return ApiResult(success: false, message: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    }
  }

  static Future<ApiResult> rejectPayment({
    required int paymentId,
    required int garageId,
    required String reason,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/payments/$paymentId/reject'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'garageId': garageId, 'reason': reason}),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResult(success: body['success'] == true, message: body['message'] ?? 'เกิดข้อผิดพลาด');
    } catch (e) {
      return ApiResult(success: false, message: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    }
  }

  // ===== อู่ตั้งค่าบัญชีธนาคารสำหรับรับชำระเงิน =====
  static Future<ApiResult> updateBankDetails({
    required int garageId,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
    String? promptpayId, // ✅ เบอร์โทร/เลขบัตรประชาชน สำหรับสร้าง QR พร้อมเพย์
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/garages/$garageId/bank-details'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'bankName': bankName,
              'bankAccountNumber': bankAccountNumber,
              'bankAccountName': bankAccountName,
              'promptpayId': promptpayId,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResult(success: body['success'] == true, message: body['message'] ?? 'เกิดข้อผิดพลาด');
    } catch (e) {
      return ApiResult(success: false, message: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    }
  }

  // ===== แชท — หาบทสนทนาเดิม หรือสร้างใหม่ =====
  static Future<ApiResult> getOrCreateConversation({required int customerId, required int garageId}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/conversations'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'customerId': customerId, 'garageId': garageId}),
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

  // ===== แชท — ลิสต์บทสนทนาทั้งหมด (ระบุ customerId หรือ garageId) =====
  static Future<ApiResult> getConversations({int? customerId, int? garageId}) async {
    try {
      final uri = Uri.parse('$baseUrl/conversations').replace(
        queryParameters: {
          if (customerId != null) 'customerId': customerId.toString(),
          if (garageId != null) 'garageId': garageId.toString(),
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
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

  // ===== แชท — ดึงประวัติข้อความ (viewerType มาร์คข้อความของอีกฝ่ายว่าอ่านแล้ว) =====
  static Future<ApiResult> getMessages({required int conversationId, required String viewerType}) async {
    try {
      final uri = Uri.parse('$baseUrl/messages').replace(
        queryParameters: {'conversationId': conversationId.toString(), 'viewerType': viewerType},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
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

  // ===== แชท — ส่งข้อความ (แนบรูปได้) =====
  static Future<ApiResult> sendMessage({
    required int conversationId,
    required int senderId,
    required String senderType, // 'customer' | 'repair'
    String? message,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/messages'));
      request.fields['conversationId'] = conversationId.toString();
      request.fields['senderId'] = senderId.toString();
      request.fields['senderType'] = senderType;
      if (message != null) request.fields['message'] = message;
      if (imageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes('image', imageBytes, filename: imageName ?? 'chat_image.jpg'),
        );
      }

      final response = await request.send().timeout(const Duration(seconds: 30));
      final body = jsonDecode(await response.stream.bytesToString()) as Map<String, dynamic>;
      return ApiResult(
        success: body['success'] == true,
        message: body['message'] ?? 'เกิดข้อผิดพลาด',
        data: body['data'],
      );
    } catch (e) {
      return ApiResult(success: false, message: 'ส่งข้อความไม่สำเร็จ กรุณาลองใหม่');
    }
  }
}