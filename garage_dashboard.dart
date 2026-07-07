import 'package:flutter/material.dart';
import 'profile_page.dart';

class GarageDashboard extends StatefulWidget {
  final Map<String, dynamic> userData; // ✅ รับ userData

  const GarageDashboard({super.key, required this.userData});

  @override
  State<GarageDashboard> createState() => _GarageDashboardState();
}

class _GarageDashboardState extends State<GarageDashboard> {
  int currentIndex = 0;

  final List<Map<String, dynamic>> _requests = [
    {
      'name': 'สมชาย ใจดี',
      'time': '10 นาทีที่แล้ว',
      'car': 'รถเก๋ง',
      'distance': '2.5 กม.',
      'problem': 'ปัญหา: เครื่องยนต์ติดยาก มีเสียงผิดปกติ',
      'color': const Color(0xff2196F3),
    },
    {
      'name': 'สมหญิง รักดี',
      'time': '25 นาทีที่แล้ว',
      'car': 'SUV',
      'distance': '4.2 กม.',
      'problem': 'ปัญหา: ยางรั่ว ต้องการเปลี่ยนยางใหม่',
      'color': const Color(0xffFF9800),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final shopName = widget.userData['shop_name'] ?? 'อู่ซ่อมรถ';

    final List<Widget> pages = [
      _buildDashboard(shopName),
      const Center(child: Text("งาน", style: TextStyle(fontSize: 24))),
      const Center(child: Text("ประวัติ", style: TextStyle(fontSize: 24))),
      const Center(child: Text("รีวิว", style: TextStyle(fontSize: 24))),
      ProfilePage(userData: widget.userData),
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
                  _statCard(icon: Icons.calendar_today, value: '8', label: 'งานวันนี้', color: const Color(0xff2196F3)),
                  _statCard(icon: Icons.build, value: '5', label: 'กำลังดำเนินการ', color: const Color(0xffFF9800)),
                  _statCard(icon: Icons.check_circle, value: '3', label: 'เสร็จแล้ว', color: const Color(0xff4CAF50)),
                  _statCard(icon: Icons.attach_money, value: '12.5K', label: 'รายได้วันนี้', color: const Color(0xff9C27B0)),
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
                    onPressed: () {},
                    child: const Text('ดูทั้งหมด', style: TextStyle(color: Colors.blue)),
                  ),
                ],
              ),
            ),

            ..._requests.map((r) => _requestCard(r)).toList(),

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

  Widget _requestCard(Map<String, dynamic> r) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: r['color'], radius: 20, child: const Icon(Icons.person, color: Colors.white)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(r['time'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(20)),
                child: const Text('ใหม่', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.directions_car, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(r['car'], style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(width: 16),
              const Icon(Icons.location_on, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(r['distance'], style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xffF5F5F5), borderRadius: BorderRadius.circular(8)),
            child: Text(r['problem'], style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('รายละเอียด'),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.red), borderRadius: BorderRadius.circular(8)),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () {},
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
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