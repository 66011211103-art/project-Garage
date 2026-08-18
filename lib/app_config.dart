/// ✅ จุดเดียวที่ต้องแก้เวลาต้องเปลี่ยน host ของ backend — เดิม api_service.dart และ
/// socket_notification_service.dart ต่างก็ hardcode IP เครื่อง dev ไว้แยกกันคนละที่
/// (ต้องจำไปแก้ให้ตรงกันทั้งสองไฟล์เอง) พอสลับ WiFi/เครือข่ายหรือรันบนเครื่องอื่นแล้ว
/// ลืมแก้ไฟล์ใดไฟล์หนึ่ง แอปก็เชื่อมต่อ backend ไม่ได้แบบเงียบๆ
///
/// ตอนนี้รวมเป็นค่าคงที่จุดเดียวในไฟล์นี้ ไฟล์อื่นทั้งหมด import แล้วอ้างอิงจากที่นี่
///
/// ✅ อัปเดต 18 ส.ค. 2026 — deploy backend ขึ้น Render แล้ว ใช้ host จริงแบบ public
/// (ทำงานได้ทุก WiFi/เครือข่ายมือถือ ไม่ต้องอยู่ WiFi เดียวกับเครื่อง dev อีกต่อไป)
class AppConfig {
  static const String _apiHost = 'good-garage-backend.onrender.com';
  static const String _scheme = 'https';

  static const String apiBaseUrl = '$_scheme://$_apiHost/api';
  static const String socketUrl = '$_scheme://$_apiHost';
}
