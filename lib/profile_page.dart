import 'package:flutter/material.dart';
import 'editprofile_customer_page.dart';
import 'editprofile_shop_page.dart';
import ' myCarPage.dart'; // ✅ แก้แล้ว: เดิมชื่อไฟล์ผิด (มีช่องว่างนำหน้า) และ import ซ้ำ 2 บรรทัด
import 'api_service.dart';
import 'settings_page.dart'; // ✅ เพิ่มใหม่: หน้าตั้งค่า
import 'payment_history_page.dart'; // ✅ ประวัติการชำระเงิน
import 'customer_repair_history_page.dart'; // ✅ ประวัติการซ่อมรถ (ลูกค้า)
import 'app_locale.dart'; // ✅ ระบบสลับภาษาไทย/อังกฤษ
import 'main.dart'; // ✅ เพิ่มใหม่: SessionStore + LoginPage สำหรับปุ่มออกจากระบบ
import 'socket_notification_service.dart'; // ✅ เพิ่มใหม่: ตัดการเชื่อมต่อ socket ตอนออกจากระบบ

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final void Function(Map<String, dynamic> newUserData)?
  onUserDataChanged; // ✅ callback บอกหน้าแม่ว่าข้อมูลเปลี่ยน

  const ProfilePage({
    super.key,
    required this.userData,
    this.onUserDataChanged,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Map<String, dynamic> _userData;

  @override
  void initState() {
    super.initState();
    _userData = Map<String, dynamic>.from(widget.userData);
    // ✅ รีบิลด์หน้านี้อัตโนมัติเมื่อผู้ใช้เปลี่ยนภาษาจากหน้าตั้งค่า (แม้เปิดหน้านี้ค้างไว้อยู่)
    AppLocale.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    AppLocale.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  String get _displayName {
    if (_userData['userType'] == 'repair') {
      return _userData['shop_name'] ?? AppLocale.instance.t('profile_shop_fallback');
    }
    final first = _userData['first_name'] ?? '';
    final last = _userData['last_name'] ?? '';
    return '$first $last'.trim().isEmpty
        ? AppLocale.instance.t('profile_name_fallback')
        : '$first $last'.trim();
  }

  // ✅ ดึงข้อมูลใหม่จาก server หลังแก้ไข
  Future<void> _refreshProfile() async {
    final result = await ApiService.getProfile(
      userId: _userData['id'],
      userType: _userData['userType'] ?? 'customer',
    );
    // ✅ เดิมไม่เช็ค mounted ก่อน setState — ถ้าผู้ใช้ออกจากหน้านี้ (เช่น สลับแท็บ)
    // ระหว่างที่ getProfile ยังโหลดไม่เสร็จ จะ crash ตอน request เสร็จแล้วมาเรียก setState
    if (!mounted) return;
    if (result.success && result.data != null) {
      final updatedUser = result.data!['user'];
      setState(() => _userData = updatedUser);
      widget.onUserDataChanged?.call(
        updatedUser,
      ); // ✅ แจ้งหน้าแม่ (HomePage/GarageDashboard) ให้อัปเดตด้วย
    }
  }

  // ✅ เพิ่มใหม่: เปิดหน้าตั้งค่า แล้ว refresh โปรไฟล์ถ้ามีการเปลี่ยนอีเมลจากในนั้น
  Future<void> _openSettings() async {
    final emailChanged = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(userData: _userData),
      ),
    );
    if (emailChanged == true) {
      await _refreshProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocale.instance;
    final isRepair = _userData['userType'] == 'repair';
    final avatarUrl = _userData['avatar'];

    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xff2196F3), Color(0xff1976D2)],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      loc.t('profile_title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: _openSettings, // ✅ เชื่อมแล้ว
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Profile Info
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    // ✅ แสดงรูปจาก DB ถ้ามี ไม่งั้นแสดงตัวอักษร
                    CircleAvatar(
                      radius: 45,
                      backgroundColor: const Color(0xff2196F3),
                      backgroundImage:
                          avatarUrl != null && avatarUrl.toString().isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null || avatarUrl.toString().isEmpty
                          ? Text(
                              _displayName.isNotEmpty
                                  ? _displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 36,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),

                    const SizedBox(height: 12),

                    Text(
                      _displayName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Text(
                      isRepair ? loc.t('profile_type_repair') : loc.t('profile_type_customer'),
                      style: const TextStyle(color: Colors.grey),
                    ),

                    const SizedBox(height: 16),

                    _infoRow(Icons.phone, _userData['phone'] ?? loc.t('profile_phone_fallback')),
                    const SizedBox(height: 10),
                    _infoRow(Icons.email, _userData['email'] ?? loc.t('profile_email_fallback')),

                    if (_userData['address'] != null &&
                        _userData['address'].toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _infoRow(
                        Icons.location_on_outlined,
                        _userData['address'],
                      ),
                    ],

                    if (!isRepair) ...[
                      if (_userData['car_model'] != null &&
                          _userData['car_model'].toString().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _infoRow(
                          Icons.directions_car_outlined,
                          _userData['car_model'],
                        ),
                      ],
                      if (_userData['car_plate'] != null &&
                          _userData['car_plate'].toString().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _infoRow(
                          Icons.card_membership_outlined,
                          _userData['car_plate'],
                        ),
                      ],
                    ],

                    if (isRepair && _userData['owner_name'] != null) ...[
                      const SizedBox(height: 10),
                      _infoRow(
                        Icons.person_outline,
                        '${loc.t('profile_owner_prefix')}: ${_userData['owner_name']}',
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Menu Items
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                    _menuItem(
                      Icons.person_outline,
                      isRepair ? loc.t('profile_edit_shop') : loc.t('profile_edit_personal'),
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => isRepair
                                ? EditProfileShopPage(userData: _userData)
                                : EditProfileCustomerPage(userData: _userData),
                          ),
                        );
                        // ฝั่งลูกค้าคืนค่า true เฉยๆ ส่วนฝั่งอู่คืนค่าเป็น Map
                        // (มีข้อมูลเวลาทำการ/บริการ/เจ้าของร้านติดมาด้วย)
                        final wasSaved =
                            result == true ||
                            (result is Map && result['success'] == true);
                        if (wasSaved) {
                          await _refreshProfile(); // ✅ ดึงข้อมูลใหม่พร้อมรูป
                        }
                      },
                    ),
                    if (!isRepair)
                      _menuItem(
                        Icons.history,
                        loc.t('profile_repair_history'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CustomerRepairHistoryPage(userData: _userData),
                            ),
                          );
                        },
                      ),
                    _menuItem(
                      Icons.receipt_long_outlined,
                      loc.t('profile_payment_history'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PaymentHistoryPage(
                              customerId: isRepair ? null : _userData['id'],
                              garageId: isRepair ? _userData['id'] : null,
                              isGarageView: isRepair,
                            ),
                          ),
                        );
                      },
                    ),
                    if (!isRepair)
                      _menuItem(
                        Icons.directions_car,
                        loc.t('profile_my_cars'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  MyCarPage(userId: _userData['id']),
                            ),
                          );
                        },
                      ),
                    _menuItem(
                      Icons.settings,
                      loc.t('settings_title'),
                      onTap: _openSettings, // ✅ เชื่อมแล้ว
                    ),
                  ],
                ),
                ),
              ),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () async {
                    // ✅ แก้บั๊ก: เดิมใช้ pushNamedAndRemoveUntil('/', ...) แต่แอปไม่เคย
                    // ลงทะเบียน named route ไว้เลย (ดู main.dart) กดออกจากระบบแล้ว
                    // เนวิเกตไม่ไปไหน/พังเงียบๆ — เปลี่ยนมาเปิด LoginPage ตรงๆ แบบเดียว
                    // กับที่ technician_dashboard.dart ใช้อยู่แล้ว พร้อมล้าง session ที่
                    // บันทึกไว้และตัดการเชื่อมต่อ socket เดิมด้วย
                    await SessionStore.clear();
                    SocketNotificationService.disconnect();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.logout),
                  label: Text(loc.t('logout')),
                ),
              ),

              const SizedBox(height: 20),
              Text(
                '${loc.t('version')} 1.0.0',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xffF5F5F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _menuItem(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.blue, size: 20),
      ),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap ?? () {},
    );
  }
}