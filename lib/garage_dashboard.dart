import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'profile_page.dart';
import 'api_service.dart';
import 'all_repair_requests_page.dart'; // ✅ หน้ารายการคำขอซ่อมทั้งหมด
import 'reject_reason_dialog.dart'; // ✅ popup เลือกเหตุผลปฏิเสธ

class GarageDashboard extends StatefulWidget {
  final Map<String, dynamic> userData; // ✅ รับ userData

  const GarageDashboard({super.key, required this.userData});

  @override
  State<GarageDashboard> createState() => _GarageDashboardState();
}

class _GarageDashboardState extends State<GarageDashboard> {
  int currentIndex = 0;
  late Map<String, dynamic> _userData; // ✅ เก็บ userData เป็น state ของหน้านี้เอง

  @override
  void initState() {
    super.initState();
    _userData = widget.userData;
    _fetchRequests();
  }

  // ✅ เรียกจาก ProfilePage เมื่อข้อมูลถูกแก้ไข เพื่ออัปเดตทุกหน้าพร้อมกันทันที
  void _handleUserDataUpdated(Map<String, dynamic> newUserData) {
    setState(() => _userData = newUserData);
  }

  bool _isLoadingRequests = true;
  List<Map<String, dynamic>> _requests = []; // คำขอทั้งหมดที่ดึงมาจาก server

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
    final result = await ApiService.updateRepairRequestStatus(
      requestId: requestId,
      status: status,
      reason: reason,
    );
    if (!mounted) return;
    if (result.success) {
      _fetchRequests(); // โหลดรายการใหม่หลังอัปเดตสถานะ
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.red),
      );
    }
  }

  // ===== แปลงชื่อประเภทรถให้อ่านง่าย =====
  String _vehicleLabel(String? value) {
    switch (value) {
      case 'sedan':
        return 'รถเก๋ง';
      case 'suv':
        return 'SUV';
      case 'pickup':
        return 'กระบะ';
      default:
        return 'ไม่ระบุ';
    }
  }

  // ===== ข้อความเวลาแบบ "x นาทีที่แล้ว" =====
  String _timeAgo(String? createdAt) {
    if (createdAt == null) return '';
    final created = DateTime.tryParse(createdAt);
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
      final created = DateTime.tryParse(r['created_at']?.toString() ?? '');
      return created != null &&
          created.year == now.year &&
          created.month == now.month &&
          created.day == now.day;
    }).length;
  }

  int get _inProgressCount => _requests.where((r) => r['status'] == 'accepted').length;

  int get _doneCount => _requests.where((r) => r['status'] == 'done').length;

  @override
  Widget build(BuildContext context) {
    final shopName = _userData['shop_name'] ?? 'อู่ซ่อมรถ';

    final List<Widget> pages = [
      _buildDashboard(shopName),
      const Center(child: Text("งาน", style: TextStyle(fontSize: 24))),
      const Center(child: Text("ประวัติ", style: TextStyle(fontSize: 24))),
      const Center(child: Text("รีวิว", style: TextStyle(fontSize: 24))),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xff2196F3),
        child: const Icon(Icons.add, color: Colors.white),
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.home_work, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
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
                  Stack(
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
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_outline, color: Colors.white),
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
                  _statCard(icon: Icons.attach_money, value: '0', label: 'รายได้วันนี้', color: const Color(0xff9C27B0)),
                ],
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
                  _quickMenu(icon: Icons.assignment, label: 'จัดการงาน'),
                  _quickMenu(icon: Icons.receipt_long, label: 'สร้างใบเสนอราคา'),
                  _quickMenu(icon: Icons.chat_bubble_outline, label: 'แชทลูกค้า'),
                  _quickMenu(icon: Icons.refresh, label: 'อัปเดตสถานะ'),
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

  Widget _statCard({required IconData icon, required String value, required String label, required Color color}) {
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
                  onPressed: () => _handleReject(id),
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
                  onPressed: () => _respondToRequest(id, 'accepted'),
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

  Widget _quickMenu({required IconData icon, required String label}) {
    return Container(
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
    );
  }
}