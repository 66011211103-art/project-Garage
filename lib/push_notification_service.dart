import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';

/// ต้องเรียกก่อนสิ่งอื่นใดใน main() เพื่อเชื่อมต่อ Firebase
/// (ค่า config อ่านมาจาก android/app/google-services.json และ
///  ios/Runner/GoogleService-Info.plist โดยอัตโนมัติ ไม่ต้องเซ็ตอะไรเพิ่มตรงนี้)
Future<void> initFirebase() async {
  await Firebase.initializeApp();
}

/// ต้องเป็น top-level function (อยู่นอกคลาส) ตามข้อกำหนดของ Firebase
/// ทำงานเมื่อมี notification เข้ามาตอนแอปถูกปิดสนิท/อยู่เบื้องหลัง
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // ไม่ต้องทำอะไรมาก แค่ให้ระบบมี handler รองรับไว้ ระบบปฏิบัติการจะโชว์ notification ให้เอง
  print('📩 ได้รับ notification ตอนแอปอยู่เบื้องหลัง: ${message.notification?.title}');
}

/// เรียกหลังล็อกอินสำเร็จ เพื่อขอ permission + เก็บ FCM token ไปเก็บที่ backend
/// และตั้งค่าการกดแจ้งเตือนให้พาไปหน้าที่ถูกต้อง
class PushNotificationService {
  static final _messaging = FirebaseMessaging.instance;

  /// เรียกครั้งเดียวหลังล็อกอินสำเร็จ (มี userId + userType แล้ว)
  static Future<void> setup({
    required int userId,
    required String userType,
    required void Function(Map<String, dynamic> data) onNotificationTap,
  }) async {
    // ===== ขอ permission แจ้งเตือน (จำเป็นสำหรับ iOS, Android 13+) =====
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // ===== ดึง FCM token ของเครื่องนี้ แล้วส่งไปเก็บที่ backend =====
    final token = await _messaging.getToken();
    if (token != null) {
      await ApiService.saveFcmToken(userId: userId, userType: userType, fcmToken: token);
    }

    // ===== ถ้า token เปลี่ยน (เช่น ล้างแอปแล้วติดตั้งใหม่) ให้ส่งค่าใหม่ไปอัปเดตด้วย =====
    _messaging.onTokenRefresh.listen((newToken) {
      ApiService.saveFcmToken(userId: userId, userType: userType, fcmToken: newToken);
    });

    // ===== ตอนแอปเปิดอยู่ (foreground) แล้วมี notification เข้ามา =====
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Firebase ไม่โชว์ notification tray ให้อัตโนมัติตอนแอปเปิดอยู่ (ต่างจาก background)
      // ตรงนี้ปล่อยไว้ก่อน ถ้าต้องการโชว์ในแอปเอง (เช่น SnackBar) ค่อยเพิ่มทีหลัง
      print('📩 ได้รับ notification ตอนแอปเปิดอยู่: ${message.notification?.title}');
    });

    // ===== ตอนกดแจ้งเตือนแล้วแอปเปิดขึ้นมาจากพื้นหลัง (ไม่ได้ถูกปิดสนิท) =====
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      onNotificationTap(message.data);
    });

    // ===== กรณีแอปถูกปิดสนิท แล้วกดแจ้งเตือนเปิดแอปขึ้นมาใหม่เลย =====
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      // หน่วงเล็กน้อยให้แอป build UI เสร็จก่อน ค่อย navigate
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onNotificationTap(initialMessage.data);
      });
    }
  }
}
