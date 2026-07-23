import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'profile_page.dart';
import 'chat_screen.dart';
import 'search_page.dart'; // ✅ หน้าค้นหาอู่ซ่อมรถ
import 'socket_notification_service.dart'; // ✅ ระบบแจ้งเตือน real-time (Socket.IO)
import 'my_repair_requests_page.dart'; // ✅ หน้าประวัติคำขอซ่อม
import 'repair_tracking_page.dart'; // ✅ หน้าติดตามสถานะการซ่อม (ปุ่ม "ติดตาม" ในการ์ดกำลังซ่อม)
import 'api_service.dart'; // ✅ สำหรับนับ/มาร์คแจ้งเตือนที่ยังไม่อ่าน

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
      ), // ✅ ใช้ _userData แทน widget.userData
      MyRepairRequestsPage(userData: _userData), // ✅ แท็บ "ประวัติ" ตอนนี้โชว์ของจริงแล้ว
      const ChatScreen(),
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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "หน้าหลัก"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "ค้นหา"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "ประวัติ"),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: "แชท"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "โปรไฟล์"),
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

class HomeContent extends StatelessWidget {
  final Map<String, dynamic> userData;
  final int unseenCount;
  final VoidCallback? onNotificationTap;
  final Map<String, dynamic>? activeJob; // ✅ งานที่กำลังซ่อมอยู่ตอนนี้ (ถ้ามี)
  final VoidCallback? onTrackTap; // ✅ กดปุ่ม "ติดตาม" ในการ์ดกำลังซ่อม

  const HomeContent({
    super.key,
    required this.userData,
    this.unseenCount = 0,
    this.onNotificationTap,
    this.activeJob,
    this.onTrackTap,
  });

  @override
  Widget build(BuildContext context) {
    // ดึงชื่อจาก userData (ชื่อเต็มสำหรับลูกค้า, ชื่อร้านสำหรับอู่)
    final firstName = userData['first_name'] ?? '';
    final lastName = userData['last_name'] ?? '';
    final fullName = userData['shop_name'] ??
        (('$firstName $lastName').trim().isEmpty ? 'ผู้ใช้' : '$firstName $lastName'.trim());

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
                            const Text(
                              "สวัสดี",
                              style: TextStyle(color: Colors.white70, fontSize: 20),
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
                      hintText: "ค้นหาอู่ซ่อมรถ...",
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

                  const Text(
                    "ประเภทงานซ่อม",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CategoryItem(
                        icon: FontAwesomeIcons.car,
                        title: "เครื่องยนต์",
                        onTap: () => _openSearch(context, userData, "เครื่องยนต์"),
                      ),
                      CategoryItem(
                        icon: FontAwesomeIcons.circle,
                        title: "ยาง",
                        onTap: () => _openSearch(context, userData, "ยาง"),
                      ),
                      CategoryItem(
                        icon: FontAwesomeIcons.carBattery,
                        title: "แบตเตอรี่",
                        onTap: () => _openSearch(context, userData, "แบตเตอรี่"),
                      ),
                      CategoryItem(
                        icon: FontAwesomeIcons.sprayCanSparkles,
                        title: "ซ่อมสี",
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
                                const Text(
                                  "กำลังซ่อม",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 26,
                                  ),
                                ),
                                Text(
                                  "${activeJob!['shop_name'] ?? 'ไม่ระบุอู่'}\n${activeJob!['problem_category'] ?? ''}",
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
                            child: const Row(
                              children: [
                                Text("ติดตาม"),
                                SizedBox(width: 5),
                                Icon(Icons.arrow_forward_ios, size: 15),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

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
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const CategoryItem({super.key, required this.icon, required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: Colors.blue),
          ),
          const SizedBox(height: 8),
          Text(title),
        ],
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
              child: Image.network(image, height: 180, width: double.infinity, fit: BoxFit.cover),
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