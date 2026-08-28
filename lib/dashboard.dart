import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'profile_page.dart';
import 'chat_screen.dart';
import 'chat_list_page.dart'; // ✅ ลิสต์บทสนทนาจริง (แทนที่ ChatScreen() เดี่ยวๆ เดิม)
import 'search_page.dart'; // ✅ หน้าค้นหาอู่ซ่อมรถ
import 'socket_notification_service.dart'; // ✅ ระบบแจ้งเตือน real-time (Socket.IO)
import 'my_repair_requests_page.dart'; // ✅ หน้าประวัติคำขอซ่อม
import 'repair_tracking_page.dart'; // ✅ หน้าติดตามสถานะการซ่อม (ปุ่ม "ติดตาม" ในการ์ดกำลังซ่อม)
import 'garage_detail_page.dart'; // ✅ กดจากการ์ด "อู่แนะนำ" แล้วเปิดหน้ารายละเอียดอู่
import 'api_service.dart'; // ✅ สำหรับนับ/มาร์คแจ้งเตือนที่ยังไม่อ่าน
import 'network_image_helper.dart';
import 'app_locale.dart'; // ✅ ระบบสลับภาษาไทย/อังกฤษ
import 'category_icons.dart'; // ✅ ไอคอนหมวดงานซ่อมแบบสมจริง

class HomePage extends StatefulWidget {
  final Map<String, dynamic> userData; // ✅ รับ userData

  const HomePage({super.key, required this.userData});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _bodyIndex = 0; // ดัชนีของหน้าเนื้อหาจริง (Home / ประวัติ / แชท / โปรไฟล์) ไม่รวมแท็บค้นหา
  late Map<String, dynamic> _userData; // ✅ เก็บ userData เป็น state ของหน้านี้เอง

  // แผนที่: ตำแหน่งปุ่มด้านล่าง (5 ปุ่ม) -> ดัชนีหน้าเนื้อหาจริง (4 หน้า)
  // ปุ่ม "ค้นหา" (nav index 1) ไม่ได้ผูกกับหน้าเนื้อหาใน pages เพราะเปิดแบบ push (มีปุ่มย้อนกลับ)
  static const Map<int, int> _navIndexToBodyIndex = {0: 0, 2: 1, 3: 2, 4: 3};

  @override
  void initState() {
    super.initState();
    _userData = widget.userData;
    _setupPushNotifications();
    _fetchUnseenCount();
    _fetchActiveJob();
    _fetchRecommendedGarages();
    // ✅ รีบิลด์หน้าแรกอัตโนมัติเมื่อผู้ใช้เปลี่ยนภาษาจากหน้าตั้งค่า
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

  // ✅ อู่แนะนำหน้าแรก — เรียงตามคะแนนรีวิวเฉลี่ยสูงสุดก่อน (4.9, 4.8, 4.7, ...)
  List<Map<String, dynamic>> _recommendedGarages = [];

  Future<void> _fetchRecommendedGarages() async {
    final result = await ApiService.searchGarages();
    if (!mounted) return;
    if (result.success && result.data != null) {
      final garages = List<Map<String, dynamic>>.from(result.data!['garages'] ?? []);
      garages.sort((a, b) {
        final ra = (a['rating'] as num?)?.toDouble() ?? 0;
        final rb = (b['rating'] as num?)?.toDouble() ?? 0;
        return rb.compareTo(ra);
      });
      setState(() => _recommendedGarages = garages.take(5).toList());
    }
  }

  // ✅ งานที่กำลังซ่อมอยู่ตอนนี้ (มีช่างรับผิดชอบแล้ว ยังไม่เสร็จ) — ใช้โชว์ในการ์ด "กำลังซ่อม" หน้าแรก
  Map<String, dynamic>? _activeJob;

  Future<void> _fetchActiveJob() async {
    final result = await ApiService.getRepairRequests(customerId: _userData['id']);
    if (!mounted) return;
    if (result.success && result.data != null) {
      final requests = List<Map<String, dynamic>>.from(result.data!['requests'] ?? []);
      // เอางานที่มีช่างรับผิดชอบแล้วและยังไม่เสร็จ (เรียงตาม created_at DESC มาจาก backend อยู่แล้ว
      // เลยตัวแรกที่เจอคืองานล่าสุด)
      final active = requests.where((r) {
        final status = r['status']?.toString() ?? '';
        return r['assigned_technician_id'] != null && status != 'completed' && status != 'done';
      }).toList();
      setState(() => _activeJob = active.isNotEmpty ? active.first : null);
    }
  }

  // ✅ ตัวเลขแจ้งเตือนที่กระดิ่ง (คำขอที่อู่ตอบกลับแล้ว แต่ลูกค้ายังไม่ได้เปิดดู)
  int _unseenCount = 0;

  Future<void> _fetchUnseenCount() async {
    final result = await ApiService.getUnseenRequestCount(customerId: _userData['id']);
    if (!mounted) return;
    if (result.success && result.data != null) {
      setState(() => _unseenCount = result.data!['count'] ?? 0);
    }
  }

  void _openTracking() {
    if (_activeJob == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RepairTrackingPage(job: _activeJob!, isCustomerView: true),
      ),
    );
  }

  // ✅ กดกระดิ่งแล้ว: เคลียร์ตัวเลขทันที (responsive) + มาร์คว่าอ่านแล้วที่ backend + เปิดหน้าประวัติ
  Future<void> _openNotifications() async {
    setState(() => _unseenCount = 0);
    ApiService.markRequestsSeen(customerId: _userData['id']);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyRepairRequestsPage(userData: _userData),
      ),
    );
    _fetchUnseenCount(); // เผื่อมีคำขอใหม่ที่อู่ตอบกลับมาระหว่างที่เปิดหน้านั้นอยู่
    _fetchActiveJob();
  }

  // ✅ ขอ permission + เก็บ FCM token + ตั้งค่าให้กดแจ้งเตือนแล้วพาไปหน้าที่ถูกต้อง
  Future<void> _setupPushNotifications() async {
    await SocketNotificationService.setup(
      userId: _userData['id'],
      userType: 'customer',
      onNotificationTap: (data) {
        if (data['type'] == 'repair_status') {
          final requestId = int.tryParse(data['requestId']?.toString() ?? '');
          setState(() => _unseenCount = 0);
          ApiService.markRequestsSeen(customerId: _userData['id']);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MyRepairRequestsPage(
                userData: _userData,
                highlightRequestId: requestId,
              ),
            ),
          ).then((_) { _fetchUnseenCount(); _fetchActiveJob(); });
        }
      },
    );

    // ✅ ฟังอีเวนต์เดิม ('notification') ตรงๆ เพิ่มอีกชุด แยกจาก onNotificationTap
    // ด้านบน (ซึ่งทำงานเฉพาะตอนลูกค้า "กด" ที่ตัวแจ้งเตือน) — อันนี้ทำงานทันทีที่
    // ช่างกดส่งอัปเดต ไม่ต้องรอลูกค้าเปิดแจ้งเตือน การ์ด "กำลังซ่อม" หน้าแรกจะ
    // เปลี่ยนข้อความ (เช่น "ช่างกำลังเดินทาง") ให้ทันทีแบบ real-time
    SocketNotificationService.socket?.on('notification', (data) {
      if (!mounted || data is! Map) return;
      final map = Map<String, dynamic>.from(data);
      final notifData = (map['data'] is Map) ? Map<String, dynamic>.from(map['data']) : <String, dynamic>{};
      if (notifData['type'] == 'repair_status') {
        _fetchActiveJob();
      }
    });
  }

  // ✅ เรียกจาก ProfilePage เมื่อข้อมูลถูกแก้ไข เพื่ออัปเดตทุกหน้าพร้อมกันทันที
  void _handleUserDataUpdated(Map<String, dynamic> newUserData) {
    setState(() => _userData = newUserData);
  }

  void _handleNavTap(int navIndex) {
    if (navIndex == 1) {
      // ปุ่ม "ค้นหา" -> เปิดหน้า Search แบบ push (มีปุ่มย้อนกลับ) ไม่สลับแท็บ
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SearchPage(userData: _userData)),
      );
      return;
    }
    if (navIndex == 2 && _unseenCount > 0) {
      // แท็บ "ประวัติ" -> เคลียร์ตัวเลขแจ้งเตือนเหมือนกดกระดิ่ง
      setState(() => _unseenCount = 0);
      ApiService.markRequestsSeen(customerId: _userData['id']);
    }
    setState(() => _bodyIndex = _navIndexToBodyIndex[navIndex] ?? 0);
  }

  // แปลง _bodyIndex กลับเป็นตำแหน่งปุ่มด้านล่าง เพื่อไฮไลต์ปุ่มที่ถูกต้อง
  int get _selectedNavIndex =>
      _navIndexToBodyIndex.entries.firstWhere((e) => e.value == _bodyIndex).key;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeContent(
        userData: _userData,
        unseenCount: _unseenCount,
        onNotificationTap: _openNotifications,
        activeJob: _activeJob,
        onTrackTap: _openTracking,
        recommendedGarages: _recommendedGarages,
      ), // ✅ ใช้ _userData แทน widget.userData
      MyRepairRequestsPage(
        userData: _userData,
        onBack: () => setState(() => _bodyIndex = 0), // ✅ ปุ่มย้อนกลับพากลับไปแท็บ "หน้าหลัก"
      ), // ✅ แท็บ "ประวัติ" ตอนนี้โชว์ของจริงแล้ว
      ChatListPage(userData: _userData), // ✅ แท็บ "แชท" ตอนนี้เป็นลิสต์บทสนทนาจริงแล้ว
      ProfilePage(
        userData: _userData,
        onUserDataChanged: _handleUserDataUpdated, // ✅ ส่ง callback ไปให้
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      body: pages[_bodyIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedNavIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: _handleNavTap,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home), label: AppLocale.instance.t('nav_home')),
          BottomNavigationBarItem(icon: const Icon(Icons.search), label: AppLocale.instance.t('nav_search')),
          BottomNavigationBarItem(icon: const Icon(Icons.history), label: AppLocale.instance.t('nav_history')),
          BottomNavigationBarItem(icon: const Icon(Icons.chat_bubble_outline), label: AppLocale.instance.t('nav_chat')),
          BottomNavigationBarItem(icon: const Icon(Icons.person_outline), label: AppLocale.instance.t('profile_title')),
        ],
      ),
    );
  }
}

void _openSearch(BuildContext context, Map<String, dynamic> userData, String service) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SearchPage(userData: userData, initialService: service),
    ),
  );
}

// ✅ ข้อความหัวการ์ด "กำลังซ่อม" หน้าแรก — เปลี่ยนตามสถานะจริงที่ช่างอัปเดตล่าสุด
// (เดิม const Text("กำลังซ่อม") ฝังตายตัว ไม่เคยอ่านสถานะจริงเลย)
String _activeJobStatusLabel(String? status) {
  final loc = AppLocale.instance;
  switch (status) {
    case 'assigned':
      return loc.t('dash_status_assigned');
    case 'checking':
      return loc.t('dash_status_checking');
    case 'in_progress':
      return loc.t('dash_status_in_progress');
    case 'waiting_parts':
      return loc.t('dash_status_waiting_parts');
    default:
      return loc.t('dash_status_in_progress');
  }
}

class HomeContent extends StatelessWidget {
  final Map<String, dynamic> userData;
  final int unseenCount;
  final VoidCallback? onNotificationTap;
  final Map<String, dynamic>? activeJob; // ✅ งานที่กำลังซ่อมอยู่ตอนนี้ (ถ้ามี)
  final VoidCallback? onTrackTap; // ✅ กดปุ่ม "ติดตาม" ในการ์ดกำลังซ่อม
  final List<Map<String, dynamic>> recommendedGarages; // ✅ อู่แนะนำ เรียงตามคะแนนรีวิว

  const HomeContent({
    super.key,
    required this.userData,
    this.unseenCount = 0,
    this.onNotificationTap,
    this.activeJob,
    this.onTrackTap,
    this.recommendedGarages = const [],
  });

  // ===== คำนวณระยะทางจากตำแหน่งลูกค้า -> อู่ ด้วยสูตร Haversine (แบบเดียวกับ search_page.dart) =====
  double? _distanceKmTo(Map<String, dynamic> garage) {
    final myLat = double.tryParse(userData['latitude']?.toString() ?? '');
    final myLng = double.tryParse(userData['longitude']?.toString() ?? '');
    final gLat = double.tryParse(garage['latitude']?.toString() ?? '');
    final gLng = double.tryParse(garage['longitude']?.toString() ?? '');
    if (myLat == null || myLng == null || gLat == null || gLng == null) return null;

    const r = 6371.0;
    double deg2rad(double d) => d * (math.pi / 180);
    final dLat = deg2rad(gLat - myLat);
    final dLon = deg2rad(gLng - myLng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(deg2rad(myLat)) * math.cos(deg2rad(gLat)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocale.instance;
    // ดึงชื่อจาก userData (ชื่อเต็มสำหรับลูกค้า, ชื่อร้านสำหรับอู่)
    final firstName = userData['first_name'] ?? '';
    final lastName = userData['last_name'] ?? '';
    final fullName = userData['shop_name'] ??
        (('$firstName $lastName').trim().isEmpty ? loc.t('dash_user_fallback') : '$firstName $lastName'.trim());

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [

            //================ Header ===================
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xff2196F3), Color(0xff1976D2)],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.t('dash_greeting'),
                              style: const TextStyle(color: Colors.white70, fontSize: 20),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              fullName, // ✅ ใช้ชื่อเต็มจาก DB
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ✅ ปุ่มแจ้งเตือน -> พาไปหน้าประวัติคำขอซ่อม พร้อมตัวเลขแจ้งเตือนที่ยังไม่อ่าน
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                              onPressed: onNotificationTap ??
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => MyRepairRequestsPage(userData: userData),
                                      ),
                                    );
                                  },
                            ),
                          ),
                          if (unseenCount > 0)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                child: Text(
                                  unseenCount > 9 ? '9+' : '$unseenCount',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  TextField(
                    readOnly: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SearchPage(userData: userData),
                        ),
                      );
                    },
                    decoration: InputDecoration(
                      hintText: loc.t('dash_search_hint'),
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            //================ Categories ==================
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text(
                    loc.t('dash_categories_heading'),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CategoryItem(
                        customIcon: buildEngineIcon(),
                        color: const Color(0xff2196F3),
                        title: loc.t('cat_engine'),
                        onTap: () => _openSearch(context, userData, "เครื่องยนต์"),
                      ),
                      CategoryItem(
                        customIcon: buildTireIcon(),
                        color: const Color(0xff546E7A),
                        title: loc.t('cat_tires'),
                        onTap: () => _openSearch(context, userData, "ยาง"),
                      ),
                      CategoryItem(
                        customIcon: buildBatteryIcon(),
                        color: const Color(0xff43A047),
                        title: loc.t('cat_battery'),
                        onTap: () => _openSearch(context, userData, "แบตเตอรี่"),
                      ),
                      CategoryItem(
                        customIcon: buildPaintIcon(),
                        color: const Color(0xffFB8C00),
                        title: loc.t('cat_paint'),
                        onTap: () => _openSearch(context, userData, "ซ่อมสี"),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // ✅ การ์ด "กำลังซ่อม" ตอนนี้ใช้ข้อมูลจริงจาก activeJob เท่านั้น
                  // ถ้าลูกค้าไม่มีงานที่กำลังซ่อมอยู่ (ยังไม่มีช่างรับผิดชอบ/ซ่อมเสร็จหมดแล้ว) จะไม่โชว์การ์ดนี้เลย
                  if (activeJob != null)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xff42A5F5), Color(0xff1E88E5)],
                        ),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: const BoxDecoration(
                              color: Colors.white24,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.build, color: Colors.white, size: 35),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _activeJobStatusLabel(activeJob!['status']?.toString()),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 26,
                                  ),
                                ),
                                Text(
                                  "${activeJob!['shop_name'] ?? loc.t('dash_garage_fallback')}\n${activeJob!['problem_category'] ?? ''}",
                                  style: const TextStyle(color: Colors.white, fontSize: 18),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white24,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: onTrackTap,
                            child: Row(
                              children: [
                                Text(loc.t('dash_track_button')),
                                const SizedBox(width: 5),
                                const Icon(Icons.arrow_forward_ios, size: 15),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ===== อู่แนะนำ — เรียงตามคะแนนรีวิวสูงสุด =====
                  if (recommendedGarages.isNotEmpty) ...[
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(loc.t('dash_recommended_heading'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => SearchPage(userData: userData)),
                          ),
                          child: Text(loc.t('dash_see_all'), style: const TextStyle(color: Color(0xff2196F3), fontSize: 14)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...recommendedGarages.map((garage) {
                      final avatar = garage['avatar']?.toString();
                      final name = garage['shop_name']?.toString() ?? loc.t('profile_shop_fallback');
                      final rating = (garage['rating'] as num?)?.toDouble() ?? 0;
                      final reviewCount = (garage['review_count'] as num?)?.toInt() ?? 0;
                      final distanceKm = _distanceKmTo(garage);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GarageDetailPage(garage: garage, userData: userData),
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                  child: (avatar != null && avatar.isNotEmpty)
                                      ? NetImage(avatar, height: 130, width: double.infinity, fit: BoxFit.cover)
                                      : Container(
                                          height: 130,
                                          width: double.infinity,
                                          color: Colors.grey.shade200,
                                          child: Icon(Icons.home_repair_service, size: 40, color: Colors.grey.shade400),
                                        ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          if (reviewCount > 0) ...[
                                            const Icon(Icons.star, size: 16, color: Color(0xffFFC107)),
                                            const SizedBox(width: 4),
                                            Text(rating.toStringAsFixed(1),
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                            const SizedBox(width: 4),
                                            Text('($reviewCount)',
                                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                          ],
                                          const Spacer(),
                                          if (distanceKm != null) ...[
                                            Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                                            const SizedBox(width: 2),
                                            Text('${distanceKm.toStringAsFixed(1)} ${loc.t('dash_km_unit')}',
                                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryItem extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon; // ✅ ใช้กราฟิกกำหนดเองแทน Icon ธรรมดา เช่น ไอคอนยางที่ประกอบเอง
  final Color color;
  final String title;
  final VoidCallback? onTap;

  const CategoryItem({
    super.key,
    this.icon,
    this.customIcon,
    required this.title,
    this.color = const Color(0xff2196F3),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(35),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: customIcon ?? Icon(icon, color: color, size: 30),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xff424242)),
            ),
          ],
        ),
      ),
    );
  }
}

class GarageCard extends StatelessWidget {
  final String image;
  final String title;
  final String rating;
  final String reviews;
  final String distance;

  const GarageCard({
    super.key,
    required this.image,
    required this.title,
    required this.rating,
    required this.reviews,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: NetImage(image, height: 180, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: 15),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 5),
                Text("$rating ($reviews)", style: const TextStyle(fontSize: 18)),
                const Spacer(),
                const Icon(Icons.location_on, color: Colors.grey),
                Text(distance),
              ],
            ),
          ],
        ),
      ),
    );
  }
}