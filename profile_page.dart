import 'package:flutter/material.dart';
import 'package:flutter_goodgarage/editprofile_page.dart';
import 'api_service.dart';

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ProfilePage({super.key, required this.userData});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Map<String, dynamic> _userData;

  @override
  void initState() {
    super.initState();
    _userData = Map<String, dynamic>.from(widget.userData);
  }

  String get _displayName {
    if (_userData['userType'] == 'repair') {
      return _userData['shop_name'] ?? 'ไม่ระบุชื่อร้าน';
    }
    final first = _userData['first_name'] ?? '';
    final last = _userData['last_name'] ?? '';
    return '$first $last'.trim().isEmpty ? 'ไม่ระบุชื่อ' : '$first $last'.trim();
  }

  // ✅ ดึงข้อมูลใหม่จาก server หลังแก้ไข
  Future<void> _refreshProfile() async {
    final result = await ApiService.getProfile(
      userId: _userData['id'],
      userType: _userData['userType'] ?? 'customer',
    );
    if (result.success && result.data != null) {
      setState(() => _userData = result.data!['user']);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    const Text(
                      "โปรไฟล์",
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: () {},
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
                      backgroundImage: avatarUrl != null && avatarUrl.toString().isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null || avatarUrl.toString().isEmpty
                          ? Text(
                              _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?',
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
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),

                    Text(
                      isRepair ? 'อู่ซ่อมรถ' : 'ลูกค้า',
                      style: const TextStyle(color: Colors.grey),
                    ),

                    const SizedBox(height: 16),

                    _infoRow(Icons.phone, _userData['phone'] ?? 'ไม่ระบุเบอร์'),
                    const SizedBox(height: 10),
                    _infoRow(Icons.email, _userData['email'] ?? 'ไม่ระบุอีเมล'),

                    if (_userData['address'] != null && _userData['address'].toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _infoRow(Icons.location_on_outlined, _userData['address']),
                    ],

                    if (!isRepair) ...[
                      if (_userData['car_model'] != null && _userData['car_model'].toString().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _infoRow(Icons.directions_car_outlined, _userData['car_model']),
                      ],
                      if (_userData['car_plate'] != null && _userData['car_plate'].toString().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _infoRow(Icons.card_membership_outlined, _userData['car_plate']),
                      ],
                    ],

                    if (isRepair && _userData['owner_name'] != null) ...[
                      const SizedBox(height: 10),
                      _infoRow(Icons.person_outline, 'เจ้าของ: ${_userData['owner_name']}'),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Menu Items
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _menuItem(
                      Icons.person_outline,
                      "แก้ไขข้อมูลส่วนตัว",
                      onTap: () async {
                        final updated = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditProfilePage(userData: _userData),
                          ),
                        );
                        if (updated == true) {
                          await _refreshProfile(); // ✅ ดึงข้อมูลใหม่พร้อมรูป
                        }
                      },
                    ),
                    _menuItem(Icons.history, "ประวัติการซ่อม"),
                    if (!isRepair) _menuItem(Icons.directions_car, "รถของฉัน"),
                    _menuItem(Icons.settings, "ตั้งค่า"),
                    _menuItem(Icons.help_outline, "ช่วยเหลือ"),
                  ],
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text("ออกจากระบบ"),
                ),
              ),

              const SizedBox(height: 20),
              const Text("เวอร์ชัน 1.0.0", style: TextStyle(color: Colors.grey)),
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