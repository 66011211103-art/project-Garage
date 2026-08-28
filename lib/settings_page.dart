import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ ใช้ Clipboard คัดลอกอีเมล
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'change_email_sheet.dart';
import 'forgot_password_page.dart';
import 'help_page.dart';
import 'app_locale.dart'; // ✅ ระบบสลับภาษาไทย/อังกฤษ
import 'main.dart'; // ✅ เพิ่มใหม่: SessionStore + LoginPage สำหรับปุ่มออกจากระบบ
import 'socket_notification_service.dart'; // ✅ เพิ่มใหม่: ตัดการเชื่อมต่อ socket ตอนออกจากระบบ

class SettingsPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SettingsPage({super.key, required this.userData});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _kNotificationsEnabled = 'notifications_enabled';
  static const _appVersion = '1.0.0';
  static const _supportEmail = 'support@goodgarage.com';

  bool _notificationsEnabled = true;
  bool _emailChanged = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationSetting();
    AppLocale.instance.load();
  }

  Future<void> _loadNotificationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = prefs.getBool(_kNotificationsEnabled) ?? true;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotificationsEnabled, value);
    setState(() => _notificationsEnabled = value);
  }

  Future<void> _handleChangeEmail() async {
    final newEmail = await showChangeEmailSheet(
      context,
      userId: widget.userData['id'],
    );
    if (newEmail != null && mounted) {
      // ✅ เดิมไม่อัปเดต widget.userData['email'] เลย ทำให้ subtitle ใต้หัวข้อ
      // "เปลี่ยนอีเมล" ยังโชว์อีเมลเก่าค้างอยู่จนกว่าจะออกจากหน้านี้แล้วเข้าใหม่
      setState(() {
        _emailChanged = true;
        widget.userData['email'] = newEmail;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocale.instance.t('epc_email_change_success')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _handleChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
    );
  }

  Future<void> _handleSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_accounts');
    List<Map<String, dynamic>> accounts = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        accounts = decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } catch (_) {
        accounts = [];
      }
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SavedAccountsSheet(initialAccounts: accounts),
    );
  }

  Future<void> _handleContactSupport() async {
    final loc = AppLocale.instance;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.t('contact_us')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              _supportEmail,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              loc.t('no_mail_app'),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: _supportEmail));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(loc.t('contact_email_copied'))),
                );
              }
            },
            child: Text(loc.t('copy_email')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final uri = Uri(
                scheme: 'mailto',
                path: _supportEmail,
                query:
                    'subject=${Uri.encodeComponent(loc.t('settings_contact_subject'))}',
              );
              await launchUrl(uri);
            },
            child: Text(loc.t('try_open_mail_app')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.t('close')),
          ),
        ],
      ),
    );
  }

  Future<void> _showLanguagePicker() async {
    final loc = AppLocale.instance;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return AnimatedBuilder(
          animation: loc,
          builder: (context, _) {
            // ✅ แก้บัค: ห่อด้วย Material(color: Colors.white) กัน ListTile ขึ้น
            // warning เรื่อง ink splash อาจมองไม่เห็น ตอนกดใน showModalBottomSheet
            return Material(
              color: Colors.white,
              child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text(
                      loc.t('choose_language'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.language,
                      color: Color(0xff2196F3),
                    ),
                    title: Text(loc.t('thai')),
                    trailing: loc.locale == 'th'
                        ? const Icon(Icons.check, color: Color(0xff2196F3))
                        : null,
                    onTap: () async {
                      await loc.setLocale('th');
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.language,
                      color: Color(0xff2196F3),
                    ),
                    title: Text(loc.t('english')),
                    trailing: loc.locale == 'en'
                        ? const Icon(Icons.check, color: Color(0xff2196F3))
                        : null,
                    onTap: () async {
                      await loc.setLocale('en');
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAboutDialog() {
    final loc = AppLocale.instance;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.t('about_app')),
        content: Text(loc.t('about_body').replaceAll('%v', _appVersion)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.t('close')),
          ),
        ],
      ),
    );
  }

  void _showPolicyDialog(String titleKey, String bodyKey) {
    final loc = AppLocale.instance;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.t(titleKey)),
        content: SingleChildScrollView(child: Text(loc.t(bodyKey))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.t('close')),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteAccount() async {
    final loc = AppLocale.instance;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.t('delete_account_title')),
        content: Text(loc.t('delete_account_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              loc.t('contact_support_action'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _handleContactSupport();
    }
  }

  Future<void> _handleLogout() async {
    // ✅ แก้บั๊ก: เดิมใช้ pushNamedAndRemoveUntil('/', ...) แต่แอปไม่เคยลงทะเบียน
    // named route ไว้เลย (ดู main.dart) กดออกจากระบบแล้วเนวิเกตไม่ไปไหน/พังเงียบๆ
    // เปลี่ยนมาเปิด LoginPage ตรงๆ พร้อมล้าง session ที่บันทึกไว้และตัดการเชื่อมต่อ socket เดิม
    await SessionStore.clear();
    SocketNotificationService.disconnect();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLocale.instance,
      builder: (context, _) {
        final loc = AppLocale.instance;

        return Scaffold(
          backgroundColor: const Color(0xffF5F5F5),
          appBar: AppBar(
            backgroundColor: const Color(0xff2196F3),
            title: Text(
              loc.t('settings_title'),
              style: const TextStyle(color: Colors.white),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context, _emailChanged),
            ),
            elevation: 0,
          ),
          body: ListView(
            children: [
              _sectionHeader(loc.t('account_section')),
              _tile(
                icon: Icons.email_outlined,
                title: loc.t('change_email'),
                subtitle: widget.userData['email']?.toString(),
                onTap: _handleChangeEmail,
              ),
              _tile(
                icon: Icons.lock_outline,
                title: loc.t('change_password'),
                onTap: _handleChangePassword,
              ),
              _tile(
                icon: Icons.devices_outlined,
                title: loc.t('saved_accounts'),
                subtitle: loc.t('saved_accounts_sub'),
                onTap: _handleSavedAccounts,
              ),

              _sectionHeader(loc.t('settings_section')),
              Material(
                color: Colors.white,
                child: SwitchListTile(
                  secondary: const Icon(
                    Icons.notifications_outlined,
                    color: Color(0xff2196F3),
                  ),
                  title: Text(loc.t('notifications')),
                  subtitle: Text(loc.t('notifications_sub')),
                  value: _notificationsEnabled,
                  activeColor: const Color(0xff2196F3),
                  onChanged: _toggleNotifications,
                ),
              ),
              _tile(
                icon: Icons.language_outlined,
                title: loc.t('language'),
                subtitle: loc.isThai ? loc.t('thai') : loc.t('english'),
                onTap: _showLanguagePicker,
              ),

              _sectionHeader(loc.t('help_section')),
              _tile(
                icon: Icons.help_outline,
                title: loc.t('help_center'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    // ✅ ส่ง userData ต่อไปด้วย ให้หน้าศูนย์ช่วยเหลือใช้แจ้งข้อร้องเรียนจริงได้
                    builder: (context) => HelpPage(userData: widget.userData),
                  ),
                ),
              ),
              _tile(
                icon: Icons.mail_outline,
                title: loc.t('contact_us'),
                onTap: _handleContactSupport,
              ),
              _tile(
                icon: Icons.description_outlined,
                title: loc.t('terms'),
                onTap: () => _showPolicyDialog('terms', 'terms_body'),
              ),
              _tile(
                icon: Icons.privacy_tip_outlined,
                title: loc.t('privacy'),
                onTap: () => _showPolicyDialog('privacy', 'privacy_body'),
              ),
              _tile(
                icon: Icons.info_outline,
                title: loc.t('about_app'),
                subtitle: '${loc.t('version')} $_appVersion',
                onTap: _showAboutDialog,
              ),

              _sectionHeader(loc.t('account_danger_section')),
              _tile(
                icon: Icons.delete_outline,
                title: loc.t('delete_account'),
                titleColor: Colors.red,
                onTap: _handleDeleteAccount,
              ),

              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: OutlinedButton(
                  onPressed: _handleLogout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(loc.t('logout')),
                ),
              ),

              const SizedBox(height: 24),
              Center(
                child: Text(
                  '${loc.t('auth_app_name')} v$_appVersion',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title) {
    return Container(
      width: double.infinity,
      color: const Color(0xffEFEFEF),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    // ✅ เดิมใช้ Container(color: ...) ห่อ ListTile ตรงๆ ทำให้ Container ทึบแสงบัง
    // เอฟเฟกต์ ink splash ของ ListTile ไว้ (ListTile ต้องการ Material ancestor
    // ที่ไม่มีอะไรทึบแสงคั่นกลาง) เปลี่ยนเป็น Material ถึงจะไม่มี error/warning
    // "ListTile background color or ink splashes may be invisible" ขึ้นซ้ำๆ อีก
    return Material(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: titleColor ?? const Color(0xff2196F3)),
        title: Text(title, style: TextStyle(color: titleColor)),
        subtitle: subtitle != null
            ? Text(subtitle, style: const TextStyle(fontSize: 12))
            : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}

class _SavedAccountsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> initialAccounts;
  const _SavedAccountsSheet({required this.initialAccounts});

  @override
  State<_SavedAccountsSheet> createState() => _SavedAccountsSheetState();
}

class _SavedAccountsSheetState extends State<_SavedAccountsSheet> {
  late List<Map<String, dynamic>> _accounts;

  @override
  void initState() {
    super.initState();
    _accounts = List<Map<String, dynamic>>.from(widget.initialAccounts);
  }

  Future<void> _remove(int index) async {
    setState(() => _accounts.removeAt(index));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_accounts', jsonEncode(_accounts));
  }

  @override
  Widget build(BuildContext context) {
    // ✅ แก้บัค: ห่อด้วย Material(color: Colors.white) กัน ListTile ขึ้น warning
    // เรื่อง ink splash อาจมองไม่เห็น ตอนกดใน showModalBottomSheet
    return Material(
      color: Colors.white,
      child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocale.instance.t('saved_accounts'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_accounts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                AppLocale.instance.t('saved_accounts_empty'),
                style: const TextStyle(color: Colors.grey),
              ),
            )
          else
            ..._accounts.asMap().entries.map((entry) {
              final email = entry.value['email']?.toString() ?? '';
              return ListTile(
                leading: const Icon(Icons.account_circle, color: Colors.blue),
                title: Text(email),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _remove(entry.key),
                ),
              );
            }),
          const SizedBox(height: 10),
        ],
      ),
      ),
    );
  }
}
