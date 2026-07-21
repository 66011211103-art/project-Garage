import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ตัวจัดการภาษาแบบง่ายๆ สำหรับสลับไทย/อังกฤษ
/// (ไม่ได้ใช้ flutter_localizations เต็มรูปแบบ เพราะแอปนี้มีหลายสิบหน้าที่ยัง
/// เป็นข้อความไทยแข็งอยู่ ทำเต็มระบบทีเดียวใหญ่เกินไป — ไฟล์นี้เป็นโครงพื้นฐาน
/// ให้ค่อยๆ แปลทีละหน้าได้ตามต้องการ โดยไม่กระทบหน้าที่ยังไม่ได้แปล)
///
/// วิธีใช้ในแต่ละหน้าที่อยากแปลเพิ่ม:
/// 1. ห่อ Scaffold ใน build() ด้วย AnimatedBuilder(animation: AppLocale.instance, builder: (context, _) { ... })
/// 2. เพิ่มคำแปลใหม่ใน _dict ด้านล่าง แล้วเรียก AppLocale.instance.t('key') แทนข้อความไทยตรงๆ
class AppLocale extends ChangeNotifier {
  AppLocale._();
  static final AppLocale instance = AppLocale._();

  static const _prefsKey = 'app_locale';

  String _locale = 'th'; // 'th' หรือ 'en'
  String get locale => _locale;
  bool get isThai => _locale == 'th';

  /// เรียกตอนแอปเริ่มทำงาน (แนะนำเรียกใน main() ก่อน runApp) เพื่อโหลดภาษา
  /// ที่ผู้ใช้เคยเลือกไว้ล่าสุดกลับมา
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _locale = prefs.getString(_prefsKey) ?? 'th';
    notifyListeners();
  }

  Future<void> setLocale(String value) async {
    if (value != 'th' && value != 'en') return;
    if (_locale == value) return;
    _locale = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, value);
  }

  Future<void> toggle() => setLocale(_locale == 'th' ? 'en' : 'th');

  /// พจนานุกรมคำแปล — เพิ่ม key ใหม่ตรงนี้เวลาจะแปลหน้าอื่นเพิ่ม
  static const Map<String, Map<String, String>> _dict = {
    'settings_title': {'th': 'ตั้งค่า', 'en': 'Settings'},
    'account_section': {'th': 'บัญชีของฉัน', 'en': 'My Account'},
    'change_email': {'th': 'เปลี่ยนอีเมล', 'en': 'Change Email'},
    'change_password': {'th': 'เปลี่ยนรหัสผ่าน', 'en': 'Change Password'},
    'saved_accounts': {'th': 'บัญชีที่จดจำไว้', 'en': 'Saved Accounts'},
    'saved_accounts_sub': {
      'th': 'จัดการบัญชีที่บันทึกไว้บนเครื่องนี้',
      'en': 'Manage accounts saved on this device',
    },
    'settings_section': {'th': 'การตั้งค่า', 'en': 'Preferences'},
    'notifications': {'th': 'การแจ้งเตือน', 'en': 'Notifications'},
    'notifications_sub': {
      'th': 'แจ้งเตือนเมื่อสถานะงานซ่อมเปลี่ยนแปลง',
      'en': 'Notify when repair status changes',
    },
    'language': {'th': 'ภาษา / Language', 'en': 'Language / ภาษา'},
    'help_section': {'th': 'ช่วยเหลือ', 'en': 'Support'},
    'help_center': {'th': 'ศูนย์ช่วยเหลือ', 'en': 'Help Center'},
    'contact_us': {'th': 'ติดต่อเรา', 'en': 'Contact Us'},
    'terms': {'th': 'ข้อกำหนดการใช้งาน', 'en': 'Terms of Service'},
    'terms_body': {
      'th': 'การใช้งานแอปอู่ที่ไว้วางใจถือว่าคุณยอมรับเงื่อนไขการให้บริการที่เกี่ยวข้องกับ '
          'การค้นหาอู่ซ่อมรถ การส่งคำขอซ่อม และการสื่อสารระหว่างลูกค้ากับอู่ผ่านระบบ',
      'en': 'By using the Trusted Garage app, you agree to the terms of service related to '
          'searching for garages, submitting repair requests, and communicating with garages through the system.',
    },
    'privacy': {'th': 'นโยบายความเป็นส่วนตัว', 'en': 'Privacy Policy'},
    'privacy_body': {
      'th': 'ข้อมูลส่วนตัว ตำแหน่งที่ตั้ง และรายละเอียดคำขอซ่อมของคุณจะถูกใช้เพื่อให้บริการ '
          'จับคู่กับอู่ซ่อมรถที่เลือกเท่านั้น ไม่มีการแชร์ข้อมูลให้บุคคลภายนอกโดยไม่ได้รับความยินยอม',
      'en': 'Your personal information, location, and repair request details are used only to '
          'match you with your chosen garage. No data is shared with third parties without consent.',
    },
    'about_app': {'th': 'เกี่ยวกับแอป', 'en': 'About App'},
    'about_body': {
      'th': 'อู่ที่ไว้วางใจ\nเวอร์ชัน %v\n\n'
          'แอปพลิเคชันช่วยให้ลูกค้าค้นหาและเลือกอู่ซ่อมรถได้สะดวกขึ้น '
          'พร้อมติดตามสถานะงานซ่อมแบบเรียลไทม์',
      'en': 'Trusted Garage\nVersion %v\n\n'
          'An app that helps customers find and choose repair garages easily, '
          'with real-time repair status tracking.',
    },
    'version': {'th': 'เวอร์ชัน', 'en': 'Version'},
    'account_danger_section': {'th': 'บัญชี', 'en': 'Account'},
    'delete_account': {'th': 'ลบบัญชีผู้ใช้', 'en': 'Delete Account'},
    'delete_account_body': {
      'th': 'การลบบัญชีจะลบข้อมูลของคุณออกจากระบบถาวรและไม่สามารถกู้คืนได้ '
          'กรุณาติดต่อฝ่ายสนับสนุนเพื่อดำเนินการยืนยันตัวตนก่อนลบบัญชี ต้องการดำเนินการต่อหรือไม่?',
      'en': 'Deleting your account will permanently remove your data and cannot be undone. '
          'Please contact support to verify your identity before deletion. Continue?',
    },
    'delete_account_title': {'th': 'ลบบัญชีผู้ใช้', 'en': 'Delete Account'},
    'contact_support_action': {'th': 'ติดต่อฝ่ายสนับสนุน', 'en': 'Contact Support'},
    'logout': {'th': 'ออกจากระบบ', 'en': 'Log Out'},
    'choose_language': {'th': 'เลือกภาษา', 'en': 'Choose Language'},
    'thai': {'th': 'ไทย', 'en': 'Thai'},
    'english': {'th': 'อังกฤษ', 'en': 'English'},
    'cancel': {'th': 'ยกเลิก', 'en': 'Cancel'},
    'close': {'th': 'ปิด', 'en': 'Close'},
    'contact_email_copied': {'th': 'คัดลอกอีเมลแล้ว', 'en': 'Email copied'},
    'no_mail_app': {
      'th': 'ไม่พบโปรแกรมอีเมลในเครื่องนี้ กดคัดลอกอีเมลไปวางเองได้เลย',
      'en': 'No email app found on this device. Copy the address and use it manually.',
    },
    'try_open_mail_app': {'th': 'ลองเปิดโปรแกรมอีเมล', 'en': 'Open Email App'},
    'copy_email': {'th': 'คัดลอกอีเมล', 'en': 'Copy Email'},
  };

  String t(String key) => _dict[key]?[_locale] ?? key;
}
