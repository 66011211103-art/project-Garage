import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // ✅ เพิ่มใหม่: FCM — แจ้งเตือนได้แม้ปิดแอปสนิท
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'app_config.dart';
import 'app_locale.dart';
import 'api_service.dart';

/// ระบบแจ้งเตือน — ใช้ 2 ทางคู่กัน:
/// 1. Socket.IO — real-time, ได้รับทันทีตอนเปิดแอปอยู่ (foreground) แต่ต้องเปิดแอป
///    ทิ้งไว้อย่างน้อยเบื้องหลังถึงจะได้รับ ถ้าปิดแอปสนิทจะไม่ได้รับเลย
/// 2. Firebase Cloud Messaging (FCM) — ระบบปฏิบัติการ (Android) เป็นคนโชว์แจ้งเตือน
///    ให้เองโดยตรง แม้แอปจะถูกปิดสนิทไปแล้วก็ตาม (ไม่ต้องมีโค้ด Dart รันอยู่เลย)
///
/// วิธีทำงาน:
/// 1. เชื่อมต่อไปที่ backend (server.js) ผ่าน Socket.IO + ลงทะเบียน FCM token ไว้ที่ backend
/// 2. ส่ง event "register" บอกว่า userId/userType ของเราคือใคร (สำหรับ Socket.IO)
/// 3. ฟัง event "notification" ที่ backend ส่งมา แล้วโชว์เป็น local notification บนเครื่อง
///    — แต่โชว์เฉพาะตอนแอปอยู่ foreground เท่านั้น (ถ้าไม่ได้ foreground ปล่อยให้ระบบ
///    ปฏิบัติการโชว์แจ้งเตือนจาก FCM แทน กันไม่ให้ขึ้นซ้ำ 2 อัน)
/// 4. เมื่อผู้ใช้กดแจ้งเตือนที่มาจาก FCM ตอนแอปอยู่เบื้องหลัง/ปิดสนิท จะพาไปหน้าที่ถูกต้อง
///    ผ่าน callback ตัวเดียวกับที่ใช้กับแจ้งเตือนจาก Socket.IO (onNotificationTap)
class SocketNotificationService {
  static socket_io.Socket? _socket;

  /// ✅ เปิดให้หน้าแชท (chat_screen.dart) เข้าถึง socket ตัวเดียวกันนี้ได้โดยตรง
  /// เพื่อฟัง event 'chat_message' แบบ real-time โดยไม่ต้องเชื่อมต่อซ้ำซ้อน
  static socket_io.Socket? get socket => _socket;
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _localNotifInitialized = false;

  // ✅ ย้ายไป app_config.dart จุดเดียว — เดิม hardcode แยกจาก api_service.dart ทำให้ต้อง
  // แก้ 2 ที่ให้ตรงกันเองเวลาเปลี่ยน IP/host ตอนนี้อ้างอิงจุดเดียวกันแล้ว ไม่มีทางลืมแก้ไฟล์ใดไฟล์หนึ่ง
  static const String _serverUrl = AppConfig.socketUrl;

  /// เรียกครั้งเดียวตอนแอปเปิด (ก่อน setup ก็ได้) เพื่อเตรียมระบบ local notification
  static Future<void> _initLocalNotifications() async {
    if (_localNotifInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      // ✅ เรียกทุกครั้งที่ผู้ใช้กดที่ notification ที่โชว์บนเครื่อง
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final data = _decodePayload(response.payload);
        _onNotificationTapCallback?.call(data);
      },
    );

    // ✅ แก้บั๊กจริง: "ไม่แจ้งเตือนเลย" — Android 13 (API 33) ขึ้นไปถือว่าการแจ้งเตือนเป็น
    // สิทธิ์ที่ต้องขอผู้ใช้ตอน runtime (เหมือนกล้อง/ตำแหน่ง) ไม่ใช่แค่ประกาศใน manifest
    // เฉยๆ — ถ้าไม่ขอ ตัวปลั๊กอินจะเรียก .show() สำเร็จแบบไม่มี error แต่ OS จะไม่โชว์
    // อะไรให้เห็นเลยสักครั้งเดียว ต้องขอสิทธิ์นี้ก่อนอย่างน้อยหนึ่งครั้งต่อการติดตั้ง
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _localNotifInitialized = true;
  }

  /// เรียกครั้งเดียวหลังล็อกอินสำเร็จ (มี userId + userType แล้ว)
  static Future<void> setup({
    required int userId,
    required String userType,
    required void Function(Map<String, dynamic> data) onNotificationTap,
  }) async {
    try {
      await _initLocalNotifications();

      // ปิด socket เก่าก่อนเผื่อมีการเรียก setup ซ้ำ (เช่น สลับบัญชี)
      _socket?.dispose();

      _socket = socket_io.io(
        _serverUrl,
        socket_io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .build(),
      );

      _socket!.connect();

      _socket!.onConnect((_) {
        print('🔌 เชื่อมต่อ Socket.IO สำเร็จ');
        // ✅ บอก backend ว่า userId/userType ไหนกำลังออนไลน์อยู่ที่ socket นี้
        _socket!.emit('register', {'userId': userId, 'userType': userType});
      });

      _socket!.on('notification', (data) async {
        if (data is! Map) return;

        // ✅ กันแจ้งเตือนขึ้นซ้ำ 2 อัน — ตอนนี้ backend ส่งทั้ง Socket.IO และ FCM คู่กันเสมอ
        // ถ้าแอปไม่ได้อยู่ foreground (ถูกย่อ/พับหน้าจอ) ให้ปล่อยให้ระบบปฏิบัติการโชว์
        // แจ้งเตือนจาก FCM แทน (โชว์เองอัตโนมัติ ไม่ต้องพึ่งโค้ดตรงนี้เลย)
        if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
          return;
        }

        final map = Map<String, dynamic>.from(data);
        final title = map['title']?.toString() ?? AppLocale.instance.t('sns_notification_fallback_title');
        final body = map['body']?.toString() ?? '';
        final notifData = (map['data'] is Map)
            ? Map<String, dynamic>.from(map['data'])
            : <String, dynamic>{};

        await _showLocalNotification(title: title, body: body, payload: notifData);
      });

      _socket!.onDisconnect((_) => print('🔌 Socket.IO หลุดการเชื่อมต่อ'));
      _socket!.onConnectError((err) => print('⚠️ เชื่อมต่อ Socket.IO ไม่สำเร็จ: $err'));

      // เก็บ callback ไว้ใช้ตอนกด notification
      _onNotificationTapCallback = onNotificationTap;

      // ✅ เพิ่มใหม่: ตั้งค่า FCM คู่กับ Socket.IO ไปเลย (ให้ได้รับแจ้งเตือนแม้ปิดแอปสนิท)
      await _setupFcm(userId: userId, userType: userType);
    } catch (e) {
      print('⚠️ ตั้งค่า Socket.IO notification ไม่สำเร็จ: $e');
    }
  }

  // ✅ เพิ่มใหม่: ตั้งค่า Firebase Cloud Messaging (FCM)
  // 1) ขอสิทธิ์แจ้งเตือน (ส่วนใหญ่มีผลกับ iOS/เว็บ — Android ใช้สิทธิ์ POST_NOTIFICATIONS
  //    ที่ flutter_local_notifications ขอไปแล้วใน _initLocalNotifications())
  // 2) ขอ token ของเครื่องนี้ แล้วส่งไปเก็บที่ backend (ดู PUT /api/users/:id/fcm-token)
  // 3) ฟัง token รีเฟรช (เกิดขึ้นเป็นระยะๆ ตามธรรมชาติของ FCM) ส่งอัปเดตไปที่ backend ทุกครั้ง
  // 4) ฟังตอนผู้ใช้กดแจ้งเตือนที่ระบบปฏิบัติการโชว์ให้ (แอปอยู่เบื้องหลัง/ปิดสนิท) แล้วพา
  //    ไปหน้าที่ถูกต้องผ่าน callback เดียวกับที่ใช้กับ Socket.IO
  static bool _fcmListenersAttached = false;

  static Future<void> _setupFcm({required int userId, required String userType}) async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token != null) {
        await ApiService.updateFcmToken(userId: userId, fcmToken: token);
        print('✅ บันทึก FCM token สำเร็จ');
      }

      // ✅ ผูก listener แค่ครั้งเดียวพอ (ไม่งั้นถ้าเรียก setup() ซ้ำ เช่น สลับบัญชี จะได้
      // callback ซ้อนกันหลายชุด) — ใช้ _onNotificationTapCallback ตัวล่าสุดเสมอผ่าน getter ด้านล่าง
      if (!_fcmListenersAttached) {
        _fcmListenersAttached = true;

        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
          final id = _currentUserId;
          if (id != null) {
            ApiService.updateFcmToken(userId: id, fcmToken: newToken);
          }
        });

        // ✅ แอปเปิดอยู่ (foreground) ตอนแจ้งเตือนมาถึง — ไม่ต้องทำอะไร เพราะ Socket.IO
        // ด้านบนโชว์ local notification ให้อยู่แล้วตอน foreground (กันไม่ให้ขึ้นซ้ำ)
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          print('📩 FCM message (foreground, ไม่โชว์ซ้ำ เพราะ Socket.IO โชว์ให้แล้ว): ${message.messageId}');
        });

        // ✅ ผู้ใช้กดแจ้งเตือนตอนแอปอยู่เบื้องหลัง (ไม่ได้ปิดสนิท) -> พาไปหน้าที่ถูกต้อง
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          _onNotificationTapCallback?.call(Map<String, dynamic>.from(message.data));
        });

        // ✅ แอปถูกปิดสนิท แล้วผู้ใช้กดแจ้งเตือนเปิดแอปขึ้นมาใหม่ (cold start) -> เช็คว่า
        // มีข้อความที่พาแอปเปิดขึ้นมาไหม แล้วพาไปหน้าที่ถูกต้องเหมือนกัน
        final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          _onNotificationTapCallback?.call(Map<String, dynamic>.from(initialMessage.data));
        }
      }

      _currentUserId = userId;
    } catch (e) {
      print('⚠️ ตั้งค่า FCM ไม่สำเร็จ (จะยังพึ่ง Socket.IO อย่างเดียวตอนเปิดแอปอยู่): $e');
    }
  }

  // ✅ เก็บ userId ล่าสุดไว้ใช้ตอน token รีเฟรช (เผื่อรีเฟรชหลังตั้งค่าเสร็จแล้วนานๆ)
  static int? _currentUserId;

  static void Function(Map<String, dynamic> data)? _onNotificationTapCallback;

  // ✅ ใหม่ — โลโก้แอปที่ใช้โชว์ในตัวแจ้งเตือนเอง (ไม่ใช่แค่ไอคอนเล็กบนสถานะบาร์)
  // เดิมแจ้งเตือนโชว์แค่ไอคอนเล็กสีเดียว (Android บังคับให้ small icon เป็นภาพขาว-ทึบ
  // เท่านั้น สีจริงของโลโก้เลยหายไปหมด ดูจืดจาง ไม่ดึงดูดสายตา) — เพิ่ม "largeIcon"
  // (Android) และ "attachment" รูปภาพ (iOS) โดยดึงจาก images/logo.png ที่มีอยู่แล้ว
  // ในโปรเจกต์ ไม่ต้องเพิ่มไฟล์ภาพใหม่ ให้ขึ้นเป็นโลโก้อู่สีเต็มๆ เหมือนแอปแชท/โซเชียลทั่วไป
  static Uint8List? _logoBytesCache;
  static String? _logoFilePathCache;

  static Future<Uint8List?> _loadLogoBytes() async {
    if (_logoBytesCache != null) return _logoBytesCache;
    try {
      final data = await rootBundle.load('images/logo.png');
      _logoBytesCache = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      return _logoBytesCache;
    } catch (e) {
      // ✅ โหลดรูปไม่สำเร็จไม่เป็นไร ปล่อยให้แจ้งเตือนขึ้นแบบไม่มีโลโก้ใหญ่ ดีกว่าไม่ขึ้นเลย
      print('⚠️ โหลดโลโก้สำหรับแจ้งเตือนไม่สำเร็จ: $e');
      return null;
    }
  }

  // ✅ iOS ต้องการ path ไฟล์จริงบนเครื่อง (ไม่รับ asset bundle ตรงๆ) — เขียนโลโก้ลง
  // temp directory ของเครื่องแค่ครั้งแรกครั้งเดียว แล้วแคช path ไว้ใช้ซ้ำ
  static Future<String?> _getLogoFilePathForIos() async {
    if (_logoFilePathCache != null && File(_logoFilePathCache!).existsSync()) {
      return _logoFilePathCache;
    }
    try {
      final bytes = await _loadLogoBytes();
      if (bytes == null) return null;
      final file = File('${Directory.systemTemp.path}/goodgarage_notif_logo.png');
      await file.writeAsBytes(bytes, flush: true);
      _logoFilePathCache = file.path;
      return _logoFilePathCache;
    } catch (e) {
      print('⚠️ เตรียมไฟล์โลโก้สำหรับแจ้งเตือน iOS ไม่สำเร็จ: $e');
      return null;
    }
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    final logoBytes = await _loadLogoBytes();

    final androidDetails = AndroidNotificationDetails(
      'garage_app_channel',
      AppLocale.instance.t('sns_channel_name'),
      channelDescription: AppLocale.instance.t('sns_channel_description'),
      importance: Importance.high,
      priority: Priority.high,
      // ✅ ไอคอนเล็กบนสถานะบาร์ (บังคับเป็นภาพขาว-ทึบตาม Android guideline อยู่แล้ว)
      icon: '@mipmap/ic_launcher',
      // ✅ ใหม่ — โลโก้สีเต็มขนาดใหญ่ที่ขึ้นในตัวแจ้งเตือน ดึงดูดสายตากว่าเดิมมาก
      largeIcon: logoBytes != null ? ByteArrayAndroidBitmap(logoBytes) : null,
      // ✅ สีเน้น (สีฟ้าแบรนด์) ให้ไอคอน/แถบด้านข้างของแจ้งเตือนเด่นขึ้น
      color: const Color(0xff2196F3),
      // ✅ ข้อความยาวจะขยายอ่านได้เต็มๆ เวลาปัดขยายแจ้งเตือน (เดิมโดนตัดสั้น)
      styleInformation: BigTextStyleInformation(body, contentTitle: title),
    );

    final iosAttachmentPath = await _getLogoFilePathForIos();
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      // ✅ ใหม่ — แนบรูปโลโก้ไปกับแจ้งเตือนฝั่ง iOS ให้เห็นภาพเด่นชัดในศูนย์การแจ้งเตือน
      attachments: iosAttachmentPath != null
          ? [DarwinNotificationAttachment(iosAttachmentPath)]
          : null,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // id ไม่ซ้ำกันในแต่ละครั้ง
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: _encodePayload(payload),
    );
  }

  static String _encodePayload(Map<String, dynamic> data) {
    // เก็บง่ายๆ เป็น "key1=value1&key2=value2" พอ ไม่ต้องพึ่ง dart:convert เพิ่ม
    return data.entries.map((e) => '${e.key}=${e.value}').join('&');
  }

  static Map<String, dynamic> _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return {};
    final map = <String, dynamic>{};
    for (final pair in payload.split('&')) {
      final parts = pair.split('=');
      if (parts.length == 2) map[parts[0]] = parts[1];
    }
    return map;
  }

  /// ปิดการเชื่อมต่อ (เรียกตอน logout)
  static void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
