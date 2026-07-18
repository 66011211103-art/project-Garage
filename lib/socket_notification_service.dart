import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

/// ระบบแจ้งเตือนแบบ real-time โดยใช้ Socket.IO (แทน Firebase Cloud Messaging)
///
/// วิธีทำงาน:
/// 1. เชื่อมต่อไปที่ backend (server.js) ผ่าน Socket.IO
/// 2. ส่ง event "register" บอกว่า userId/userType ของเราคือใคร
/// 3. ฟัง event "notification" ที่ backend ส่งมา แล้วโชว์เป็น local notification บนเครื่อง
///
/// ข้อจำกัด (ต่างจาก Firebase): ต้องเปิดแอปทิ้งไว้ (อย่างน้อยอยู่เบื้องหลัง)
/// ถึงจะได้รับแจ้งเตือน ถ้าปิดแอปสนิทจะไม่ได้รับ เพราะไม่มี OS-level push
class SocketNotificationService {
  static socket_io.Socket? _socket;
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _localNotifInitialized = false;

  // ✅ เปลี่ยนเป็น URL ของ backend จริงตอน deploy (ตอนนี้ใช้ localhost สำหรับ dev)
  static const String _serverUrl = 'http://172.20.10.2:3000';

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
        final map = Map<String, dynamic>.from(data);
        final title = map['title']?.toString() ?? 'แจ้งเตือน';
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
    } catch (e) {
      print('⚠️ ตั้งค่า Socket.IO notification ไม่สำเร็จ: $e');
    }
  }

  static void Function(Map<String, dynamic> data)? _onNotificationTapCallback;

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'garage_app_channel',
      'การแจ้งเตือนคำขอซ่อม',
      channelDescription: 'แจ้งเตือนสถานะคำขอซ่อม/ใบเสนอราคา',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // id ไม่ซ้ำกันในแต่ละครั้ง
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
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
