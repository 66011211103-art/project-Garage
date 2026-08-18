import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'profile_page.dart';
import 'api_service.dart';
import 'all_repair_requests_page.dart'; // ✅ หน้ารายการคำขอซ่อมทั้งหมด
import 'reject_reason_dialog.dart'; // ✅ popup เลือกเหตุผลปฏิเสธ
import 'socket_notification_service.dart'; // ✅ ระบบแจ้งเตือน real-time (Socket.IO)
import 'manage_technicians_page.dart'; // ✅ หน้าจัดการช่าง
import 'garage_reviews_page.dart'; // ✅ หน้ารีวิวจากลูกค้า
import 'garage_completed_jobs_page.dart'; // ✅ ประวัติงานซ่อมที่เสร็จแล้ว (ดูอย่างเดียว)
import 'payment_history_page.dart'; // ✅ จัดการ/ยืนยันการชำระเงิน (แยกจากหน้าประวัติ)
import 'bank_settings_page.dart'; // ✅ ตั้งค่าบัญชีธนาคารรับชำระเงิน
import 'garage_chat_list_page.dart'; // ✅ แชทกับลูกค้า
import 'garage_tracking_list_page.dart'; // ✅ อัปเดตสถานะ/ติดตามงานที่กำลังซ่อม
import 'garage_wallet_page.dart'; // ✅ Wallet ของอู่ — ดูยอดคงเหลือ/เติมเงิน
import ' myCarPage.dart' show vehicleTypeLabel; // ✅ ใช้ label กลางที่รองรับรถตู้/มอเตอร์ไซค์/อื่นๆ ด้วย

class GarageDashboard extends StatefulWidget {
  final Map<String, dynamic> userData; // ✅ รับ userData

  const GarageDashboard({super.key, required this.userData});

  @override
  State<GarageDashboard> createState() => _GarageDashboardState();
}

class _GarageDashboardState extends State<GarageDashboard> {
  int currentIndex = 0;
  late Map<String, dynamic> _userData; // ✅ เก็บ userData เป็น state ของหน้านี้เอง

  // ✅ ยอด wallet — โชว์ banner เตือนบนแดชบอร์ดถ้าติดลบ (จุดที่ขาดหายไปเดิม)
  double? _walletBalance;

  @override
  void initState() {
    super.initState();
    _userData = widget.userData;
    _fetchRequests();
    _setupPushNotifications();
    _fetchWalletBalance();
  }

  Future<void> _fetchWalletBalance() async {
    final result = await ApiService.getWallet(garageId: _userData['id']);
    if (!mounted) return;
    if (result.success && result.data != null) {
      setState(() {
        _walletBalance = double.tryParse(result.data!['wallet_balance']?.toString() ?? '0') ?? 0;
      });
    }
  }

  // ✅ ขอ permission + เก็บ FCM token + ตั้งค่าให้กดแจ้งเตือนแล้วพาไปหน้ารายการคำขอซ่อม
  Future<void> _setupPushNotifications() async {
    await SocketNotificationService.setup(
      userId: _userData['id'],
      userType: 'repair',
      onNotificationTap: (data) {
        if (data['type'] == 'new_request') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AllRepairRequestsPage(userData: _userData),
            ),
          ).then((_) => _fetchRequests());
        }
      },
    );
  }

  // ✅ เรียกจาก ProfilePage เมื่อข้อมูลถูกแก้ไข เพื่ออัปเดตทุกหน้าพร้อมกันทันที
  void _handleUserDataUpdated(Map<String, dynamic> newUserData) {
    setState(() => _userData = newUserData);
  }

  bool _isLoadingRequests = true;
  List<Map<String, dynamic>> _requests = []; // คำขอทั้งหมดที่ดึงมาจาก server
  // ✅ กันกดปุ่ม "รับงาน"/"ปฏิเสธ" รัวๆ ยิง request ซ้ำซ้อนต่อ 1 คำขอ
  final Set<int> _respondingIds = {};

  Future<void> _fetchRequests() async {
    setState(() => _isLoadingRequests = true);
    final result = await ApiService.getRepairRequests(garageId: _userData['id']);
    if (!mounted) return;
    setState(() {
      _isLoadingRequests = false;
      _requests = result.success && result.data != null
          ? List<Map<String, dynamic>>.from(result.data!['requests'] ?? [])
          : [];
    });
  }

  Future<void> _respondToRequest(int requestId, String status, {String? reason}) async {
    if (_respondingIds.contains(requestId)) return; // ✅ กันกดซ้ำระหว่างรอผลก่อนหน้า
    setState(() => _respondingIds.add(requestId));
    final result = await ApiService.updateRepairRequestStatus(
      requestId: requestId,
      garageId: _userData['id'],
      status: status,
      reason: reason,
    );
    if (!mounted) return;
    setState(() => _respondingIds.remove(requestId));
    if (result.success) {
      _fetchRequests(); // โหลดรายการใหม่หลังอัปเดตสถานะ
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.red),
      );
    }
  }

  // ===== แปลงชื่อประเภทรถให้อ่านง่าย — ใช้ label กลางที่รองรับรถตู้/มอเตอร์ไซค์/
  // อื่นๆ ด้วย (ของเดิมรองรับแค่ sedan/suv/pickup แล้ว fallback เป็น "ไม่ระบุ") =====
  String _vehicleLabel(String? value) => vehicleTypeLabel(value);

  // ===== ข้อความเวลาแบบ "x นาทีที่แล้ว" =====
  String _timeAgo(String? createdAt) {
    if (createdAt == null) return '';
    // ✅ .toLocal() ไม่จำเป็นสำหรับผลต่างเวลา (DateTime.difference คำนวณจาก
    // instant จริงอยู่แล้ว ไม่ว่าจะเป็น UTC หรือ local) แต่ใส่ไว้ให้สอดคล้องกับ
    // จุดอื่นๆ ที่ต้องแปลงเป็นเวลาไทยก่อนใช้งานเสมอ กันสับสน/ลืมทีหลัง
    final created = DateTime.tryParse(createdAt)?.toLocal();
    if (created == null) return '';
    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return '${diff.inHours} ชั่วโมงที่แล้ว';
    return '${diff.inDays} วันที่แล้ว';
  }

  // ===== ระยะทางจากอู่ (ตำแหน่งอู่) ไปยังตำแหน่งที่ลูกค้าส่งคำขอมา =====
  String _distanceLabel(Map<String, dynamic> r) {
    final myLat = double.tryParse(_userData['latitude']?.toString() ?? '');
    final myLng = double.tryParse(_userData['longitude']?.toString() ?? '');
    final rLat = double.tryParse(r['latitude']?.toString() ?? '');
    final rLng = double.tryParse(r['longitude']?.toString() ?? '');
    if (myLat == null || myLng == null || rLat == null || rLng == null) return '-';

    const radius = 6371.0;
    double deg2rad(double d) => d * (math.pi / 180);
    final dLat = deg2rad(rLat - myLat);
    final dLon = deg2rad(rLng - myLng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(deg2rad(myLat)) * math.cos(deg2rad(rLat)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return '${(radius * c).toStringAsFixed(1)} กม.';
  }

  Widget _detailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }

  Future<void> _handleReject(int requestId) async {
    final reason = await showRejectReasonDialog(context);
    if (reason == null) return; // ผู้ใช้กดยกเลิก
    await _respondToRequest(requestId, 'rejected', reason: reason);
  }

  Color _avatarColor(int index) {
    const colors = [Color(0xff2196F3), Color(0xffFF9800), Color(0xff4CAF50), Color(0xff9C27B0)];
    return colors[index % colors.length];
  }

  List<Map<String, dynamic>> get _pendingRequests =>
      _requests.where((r) => r['status'] == 'pending').toList();

  int get _pendingCount => _pendingRequests.length;

  int get _todayCount {
    final now = DateTime.now();
    return _requests.where((r) {
      // ✅ ต้อง .toLocal() ก่อนเทียบ year/month/day — created_at จาก backend เป็น
      // UTC ISO string ถ้าไม่แปลงก่อน ช่วง 00:00-07:00 เวลาไทยจะถูกนับเป็น "เมื่อวาน"
      // (เพราะวันที่แบบ UTC ยังไม่ข้ามวัน) ทำให้ยอด "วันนี้" ขาดหายไปช่วงเช้ามืด
      final created = DateTime.tryParse(r['created_at']?.toString() ?? '')?.toLocal();
      return created != null &&
          created.year == now.year &&
          created.month == now.month &&
          created.day == now.day;
    }).length;
  }

  // ✅ "กำลังดำเนินการ" = งานที่มอบหมายช่างแล้วแต่ยังไม่เสร็จ (เดิมเช็คแค่ status
  // == 'accepted' ซึ่งเป็นแค่ขั้น "อู่รับงาน" ไม่ใช่ขั้นกำลังซ่อมจริงๆ เลยขึ้น 0
  // ตลอด ทั้งที่มีงานกำลังซ่อมอยู่จริง)
  static const List<String> _inRepairStatuses = ['assigned', 'checking', 'in_progress', 'waiting_parts'];
  int get _inProgressCount => _requests.where((r) => _inRepairStatuses.contains(r['status'])).length;

  // ✅ "เสร็จแล้ว" ต้องเช็ค status == 'completed' (สถานะจริงที่ช่างกดตอนซ่อมเสร็จ)
  // ไม่ใช่ 'done' ซึ่งเป็นสถานะเก่าที่ไม่มีการใช้งานจริงในระบบแล้ว
  int get _doneCount => _requests.where((r) => r['status'] == 'completed').length;

  // ✅ "รายได้วันนี้" คำนวณจริงจากรายการที่อู่ยืนยันรับเงินแล้ว (payment_status ==
  // confirmed) และแจ้งชำระเงินเข้ามาวันนี้ (เดิม hardcode เป็น '0' ตลอด ไม่เคยคำนวณจริง)
  double get _todayRevenue {
    final now = DateTime.now();
    return _requests.where((r) {
      if (r['payment_status']?.toString() != 'confirmed') return false;
      // ✅ .toLocal() เหตุผลเดียวกับ _todayCount — payment_submitted_at เป็น UTC
      final submitted = DateTime.tryParse(r['payment_submitted_at']?.toString() ?? '')?.toLocal();
      return submitted != null &&
          submitted.year == now.year &&
          submitted.month == now.month &&
          submitted.day == now.day;
    }).fold<double>(0, (sum, r) => sum + (double.tryParse(r['payment_amount']?.toString() ?? '0') ?? 0));
  }

  // ✅ ค่าคอมมิชชั่นที่ระบบหักจาก wallet ไปแล้ววันนี้ — แยกจาก "รายได้วันนี้" ข้างบน
  // เพราะเป็นคนละบัญชีกัน (รายได้ = เงินเต็มจำนวนที่เข้าธนาคารอู่ / คอมมิชชั่น = หักจาก
  // wallet ต่างหาก) โชว์คู่กันให้เห็นชัดว่าเงินหายไปไหน กันงงเวลาเทียบกับ wallet ที่ติดลบ
  double get _todayCommission {
    final now = DateTime.now();
    return _requests.where((r) {
      if (r['payment_status']?.toString() != 'confirmed') return false;
      // ✅ .toLocal() เหตุผลเดียวกับ _todayCount — payment_submitted_at เป็น UTC
      final submitted = DateTime.tryParse(r['payment_submitted_at']?.toString() ?? '')?.toLocal();
      return submitted != null &&
          submitted.year == now.year &&
          submitted.month == now.month &&
          submitted.day == now.day;
    }).fold<double>(0, (sum, r) => sum + (double.tryParse(r['commission_amount']?.toString() ?? '0') ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    final shopName = _userData['shop_name'] ?? 'อู่ซ่อมรถ';

    final List<Widget> pages = [
      _buildDashboard(shopName),
      AllRepairRequestsPage(userData: _userData, embedded: true), // ✅ แท็บ "งาน" ตอนนี้โชว์ของจริงแล้ว
      GarageCompletedJobsPage(userData: _userData, embedded: true),
      GarageReviewsPage(garageId: _userData['id'], embedded: true),
      ProfilePage(
        userData: _userData,
        onUserDataChanged: _handleUserDataUpdated, // ✅ ส่ง callback ไปให้
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      body: pages[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.build_outlined), label: 'งาน'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'ประวัติ'),
          BottomNavigationBarItem(icon: Icon(Icons.star_border), label: 'รีวิว'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'โปรไฟล์'),
        ],
      ),
    );
  }

  Widget _buildDashboard(String shopName) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ===== Header =====
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xff2196F3), Color(0xff1976D2)],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      shopName, // ✅ ชื่อร้านจริงจาก DB
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // ✅ กระดิ่งกดได้แล้ว พาไปหน้า "รายการคำขอซ่อม" เดียวกับปุ่ม "ดูทั้งหมด"
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AllRepairRequestsPage(userData: _userData),
                        ),
                      );
                      _fetchRequests();
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.notifications_outlined, color: Colors.white),
                        ),
                        if (_pendingCount > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              child: Text(
                                '$_pendingCount',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ===== Stats =====
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _statCard(icon: Icons.calendar_today, value: '$_todayCount', label: 'งานวันนี้', color: const Color(0xff2196F3)),
                  _statCard(icon: Icons.build, value: '$_inProgressCount', label: 'กำลังดำเนินการ', color: const Color(0xffFF9800)),
                  _statCard(icon: Icons.check_circle, value: '$_doneCount', label: 'เสร็จแล้ว', color: const Color(0xff4CAF50)),
                  _statCard(
                    icon: Icons.attach_money,
                    value: '฿${_todayRevenue.toStringAsFixed(0)}',
                    label: 'รายได้วันนี้',
                    color: const Color(0xff9C27B0),
                    subtitle: _todayCommission > 0
                        ? 'สุทธิ ฿${(_todayRevenue - _todayCommission).toStringAsFixed(0)}'
                        : null,
                  ),
                ],
              ),
            ),

            // ✅ Banner เตือนทันทีถ้า wallet ติดลบ — จุดที่ขาดหายไปเดิม (เดิมอู่ไม่มีทาง
            // รู้เลยว่าตัวเองติดค้างค่าคอมมิชชั่นอยู่ จนกว่าจะโดนบล็อกไม่ให้รับงานใหม่)
            if (_walletBalance != null && _walletBalance! < 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => GarageWalletPage(garageId: _userData['id'])),
                  ).then((_) => _fetchWalletBalance()),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xffFFEBEE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xffE53935).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xffE53935), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Wallet ติดลบ ฿${_walletBalance!.abs().toStringAsFixed(2)} — แตะเพื่อเติมเงิน ก่อนถูกระงับรับงานใหม่',
                            style: const TextStyle(color: Color(0xffC62828), fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Color(0xffE53935), size: 18),
                      ],
                    ),
                  ),
                ),
              ),

            // ===== คำขอซ่อมล่าสุด =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('คำขอซ่อมล่าสุด', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AllRepairRequestsPage(userData: _userData),
                        ),
                      );
                      _fetchRequests(); // กลับมาแล้วรีเฟรชเผื่อมีการรับ/ปฏิเสธงานในหน้านั้น
                    },
                    child: const Text('ดูทั้งหมด', style: TextStyle(color: Colors.blue)),
                  ),
                ],
              ),
            ),

            if (_isLoadingRequests)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              ..._pendingRequests.asMap().entries.map((e) => _requestCard(e.value, e.key)),
              if (_pendingRequests.isEmpty) _emptyRequestsState(),
            ],

            // ===== เมนูด่วน =====
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text('เมนูด่วน', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _quickMenu(
                    icon: Icons.engineering_outlined,
                    label: 'จัดการช่าง',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ManageTechniciansPage(userData: _userData),
                        ),
                      );
                    },
                  ),
                  _quickMenu(
                    icon: Icons.chat_bubble_outline,
                    label: 'แชทลูกค้า',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GarageChatListPage(userData: _userData),
                        ),
                      );
                    },
                  ),
                  _quickMenu(
                    icon: Icons.refresh,
                    label: 'อัปเดตสถานะ',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GarageTrackingListPage(userData: _userData),
                        ),
                      );
                      _fetchRequests();
                    },
                  ),
                  _quickMenu(
                    icon: Icons.payments_outlined,
                    label: 'การชำระเงิน',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PaymentHistoryPage(
                            garageId: _userData['id'],
                            isGarageView: true,
                          ),
                        ),
                      );
                    },
                  ),
                  _quickMenu(
                    icon: Icons.account_balance_outlined,
                    label: 'บัญชีรับเงิน',
                    onTap: () async {
                      final saved = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BankSettingsPage(userData: _userData),
                        ),
                      );
                      if (saved == true) {
                        // ✅ อัปเดต userData ในตัวเองด้วยเผื่อค่าที่แก้ไปมีการใช้อีก (เช่น เปิดหน้านี้ซ้ำ)
                        setState(() {});
                      }
                    },
                  ),
                  // ✅ Wallet ของอู่ — ดูยอดคงเหลือ/เติมเงิน (จุดที่ขาดหายไปเดิม อู่ไม่เคย
                  // เห็นยอด wallet ของตัวเองเลย ทั้งที่ระบบหักค่าคอมมิชชั่นอัตโนมัติทุกงาน)
                  _quickMenu(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Wallet',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GarageWalletPage(garageId: _userData['id']),
                        ),
                      );
                      _fetchWalletBalance();
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _emptyRequestsState() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'ยังไม่มีคำขอซ่อมเข้ามา',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 4),
          Text(
            'คำขอจากลูกค้าจะแสดงที่นี่',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _statCard({required IconData icon, required String value, required String label, required Color color, String? subtitle}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            // ✅ ยอดสุทธิหลังหักค่าคอมมิชชั่น — โชว์เฉพาะการ์ดที่ส่ง subtitle มา (การ์ดรายได้)
            // ให้เห็นชัดว่าเงินส่วนหนึ่งถูกหักไป wallet แล้ว ไม่ใช่ตัวเลขเดียวกับที่เข้าธนาคารสุทธิ
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 9.5, color: Color(0xff4CAF50), fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> r, int index) {
    final id = r['id'];
    final name = '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.description_outlined, size: 18, color: Color(0xff2196F3)),
                  const SizedBox(width: 6),
                  Text('#REQ${id.toString().padLeft(6, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xff4CAF50).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('ใหม่',
                    style: TextStyle(color: Color(0xff4CAF50), fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _detailRow(Icons.person_outline, name.isEmpty ? 'ไม่ระบุชื่อ' : name),
          const SizedBox(height: 6),
          _detailRow(Icons.directions_car_outlined, _vehicleLabel(r['vehicle_type']?.toString())),
          const SizedBox(height: 6),
          _detailRow(Icons.build_outlined, r['problem_category']?.toString() ?? '-'),
          const SizedBox(height: 6),
          _detailRow(Icons.access_time, _timeAgo(r['created_at']?.toString())),
          const SizedBox(height: 6),
          _detailRow(Icons.location_on_outlined, _distanceLabel(r)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRequestDetail(r, index),
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                  label: const Text('ดูรายละเอียด'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _respondingIds.contains(id) ? null : () => _handleReject(id),
                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                  label: const Text('ปฏิเสธ', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _respondingIds.contains(id) ? null : () => _respondToRequest(id, 'accepted'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.check, color: Colors.white, size: 16),
                  label: const Text('รับงาน', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRequestDetail(Map<String, dynamic> r, int index) {
    final name = '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim();
    final photos = (r['photos'] is List) ? List<dynamic>.from(r['photos']) : [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name.isEmpty ? 'ไม่ระบุชื่อ' : name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('ประเภทรถ: ${_vehicleLabel(r['vehicle_type']?.toString())}',
                  style: const TextStyle(color: Colors.grey)),
              Text('ประเภทปัญหา: ${r['problem_category'] ?? '-'}', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              Text(r['description']?.toString().isNotEmpty == true
                  ? r['description'].toString()
                  : 'ไม่มีรายละเอียดเพิ่มเติม'),
              const SizedBox(height: 12),
              Text('ที่อยู่: ${r['address'] ?? 'ไม่ระบุ'}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              if ((r['rejection_reason']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xffFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('เหตุผลที่ปฏิเสธ: ${r['rejection_reason']}',
                      style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              ],
              if (photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: photos.map((url) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(url.toString(), width: 90, height: 90, fit: BoxFit.cover),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickMenu({required IconData icon, required String label, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.blue, size: 26),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}