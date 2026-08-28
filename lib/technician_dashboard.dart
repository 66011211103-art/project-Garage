// ============================================================
// 📄 ไฟล์: technician_dashboard.dart
// 📌 หน้า/ฟีเจอร์: หน้าหลักของ "ช่าง" (Mechanic Dashboard) — หน้าแรกหลัง login
// 📝 คำอธิบาย: การ์ดสวัสดีช่างแบบ gradient, การ์ดสรุปสถิติงาน 3 ช่อง
//     (งานทั้งหมด/กำลังทำ/เสร็จแล้ว), รายการงานพร้อมปุ่มโทรหาลูกค้า +
//     ดูรายละเอียด กดเข้าไปหน้า technician_job_detail_page.dart ได้
// ⚠️ หมายเหตุ: ปุ่ม "โทร" ใช้แพ็กเกจ url_launcher — ถ้ายังไม่มีในโปรเจกต์
//     ต้องเพิ่ม `url_launcher: ^6.x` ใน pubspec.yaml ก่อน ไม่งั้น build ไม่ผ่าน
// ============================================================

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'socket_notification_service.dart';
import 'technician_job_detail_page.dart';
import 'main.dart'; // ✅ ใช้ LoginPage สำหรับปุ่มล็อกเอาท์
import 'app_locale.dart'; // ✅ ระบบสลับภาษาไทย/อังกฤษ

const List<String> _thaiMonthsAbbr = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];

/// หน้าหลักของ "ช่าง" — ดูงานที่ได้รับมอบหมายจากอู่
class TechnicianDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const TechnicianDashboard({super.key, required this.userData});

  @override
  State<TechnicianDashboard> createState() => _TechnicianDashboardState();
}

class _TechnicianDashboardState extends State<TechnicianDashboard> {
  late Map<String, dynamic> _userData;
  bool _isLoading = true;
  List<Map<String, dynamic>> _jobs = [];

  /// ตัวกรองสถานะที่กำลังแสดง: null = ทั้งหมด
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _userData = widget.userData;
    _fetchJobs();
    _setupPushNotifications();
    // ✅ รีบิลด์แดชบอร์ดช่างอัตโนมัติเมื่อผู้ใช้เปลี่ยนภาษาจากหน้าตั้งค่า
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

  Future<void> _setupPushNotifications() async {
    await SocketNotificationService.setup(
      userId: _userData['id'],
      userType: 'technician',
      onNotificationTap: (data) {
        if (data['type'] == 'new_assignment' || data['type'] == 'repair_status') {
          _fetchJobs();
        }
      },
    );
  }

  Future<void> _fetchJobs() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getRepairRequests(technicianId: _userData['id']);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _jobs = result.success && result.data != null
          ? List<Map<String, dynamic>>.from(result.data!['requests'] ?? [])
          : [];
    });
  }

  Future<void> _callCustomer(String? phone) async {
    final loc = AppLocale.instance;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.t('tech_no_customer_phone')), backgroundColor: Colors.red),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.t('tech_call_failed').replaceAll('%s', phone))),
      );
    }
  }

  Future<void> _handleLogout() async {
    final loc = AppLocale.instance;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.t('logout')),
        content: Text(loc.t('tech_logout_confirm_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(loc.t('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.t('logout'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // ✅ เพิ่มใหม่: ล้าง session ที่บันทึกไว้ (ดู SessionStore ใน main.dart) ไม่งั้นแอปจะ
    // auto-login กลับเข้าบัญชีเดิมทันทีตอนเปิดแอปครั้งถัดไป
    await SessionStore.clear();
    SocketNotificationService.disconnect();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  String _vehicleLabel(String? value) {
    final loc = AppLocale.instance;
    switch (value) {
      case 'sedan':
        return loc.t('tech_vehicle_sedan');
      case 'suv':
        return 'SUV';
      case 'pickup':
        return loc.t('tech_vehicle_pickup');
      default:
        return loc.t('tech_vehicle_unspecified');
    }
  }

  String _statusLabel(String status) {
    final loc = AppLocale.instance;
    switch (status) {
      case 'assigned':
        return loc.t('tech_status_assigned');
      case 'checking':
        return loc.t('dash_status_checking');
      case 'in_progress':
        return loc.t('dash_status_in_progress');
      case 'waiting_parts':
        return loc.t('dash_status_waiting_parts');
      case 'completed':
        return loc.t('tech_status_completed');
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'assigned':
        return const Color(0xffFF9800);
      case 'checking':
        return const Color(0xff9C27B0);
      case 'in_progress':
        return const Color(0xff2196F3);
      case 'waiting_parts':
        return const Color(0xff795548);
      case 'completed':
        return const Color(0xff4CAF50);
      default:
        return Colors.grey;
    }
  }

  String _formatThaiDateTime(String? isoString) {
    if (isoString == null) return '-';
    // ✅ backend ส่งเวลาเป็น UTC ISO string — ต้อง .toLocal() ก่อนอ่าน .hour/.day
    final dt = DateTime.tryParse(isoString)?.toLocal();
    if (dt == null) return '-';
    final buddhistYear2Digit = (dt.year + 543) % 100;
    final month = _thaiMonthsAbbr[dt.month - 1];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} $month ${buddhistYear2Digit.toString().padLeft(2, '0')}, $hh:$mm';
  }

  // ✅ สถิติสรุปด้านบน — คำนวณจากรายการงานจริงที่ดึงมา (ไม่ได้ผูกกับ "วันนี้"
  // ตามตัวอักษร เพราะ API ปัจจุบันไม่ได้ระบุวันนัดหมายแยกจาก created_at)
  int get _totalActiveCount => _jobs.where((j) => j['status'] != 'completed').length;
  int get _inProgressCount => _jobs.where((j) => j['status'] == 'in_progress').length;
  int get _completedCount => _jobs.where((j) => j['status'] == 'completed').length;

  List<Map<String, dynamic>> get _filteredJobs {
    if (_statusFilter == null) return _jobs;
    return _jobs.where((j) => j['status'] == _statusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocale.instance;
    final name = _userData['name']?.toString() ?? loc.t('tech_name_fallback');
    final avatarUrl = (_userData['avatar_url'] ?? _userData['avatar'])?.toString();

    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchJobs,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // ---------- การ์ดสวัสดีช่าง ----------
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xff2196F3), Color(0xff1976D2)],
                  ),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white24,
                      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null || avatarUrl.isEmpty
                          ? const Icon(Icons.person, color: Colors.white, size: 28)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(loc.t('dash_greeting'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          Text(name,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _handleLogout,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.logout, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              // ---------- การ์ดสถิติ 3 ช่อง (ยกขึ้นมาทับขอบล่างของ header) ----------
              Transform.translate(
                offset: const Offset(0, -20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(child: _statCard(Icons.assignment_outlined, loc.t('tech_stat_total'), _totalActiveCount, const Color(0xff2196F3))),
                      const SizedBox(width: 10),
                      Expanded(child: _statCard(Icons.hourglass_bottom, loc.t('dash_status_in_progress'), _inProgressCount, const Color(0xffFF9800))),
                      const SizedBox(width: 10),
                      Expanded(child: _statCard(Icons.check_circle_outline, loc.t('garage_stat_done'), _completedCount, const Color(0xff4CAF50))),
                    ],
                  ),
                ),
              ),

              // ---------- หัวข้อ + ตัวกรอง ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(loc.t('tech_my_jobs_heading'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    PopupMenuButton<String?>(
                      icon: const Icon(Icons.filter_list, color: Color(0xff2196F3)),
                      onSelected: (v) => setState(() => _statusFilter = v),
                      itemBuilder: (context) => [
                        PopupMenuItem(value: null, child: Text(loc.t('tech_filter_all'))),
                        PopupMenuItem(value: 'assigned', child: Text(loc.t('tech_status_assigned'))),
                        PopupMenuItem(value: 'checking', child: Text(loc.t('dash_status_checking'))),
                        PopupMenuItem(value: 'in_progress', child: Text(loc.t('dash_status_in_progress'))),
                        PopupMenuItem(value: 'waiting_parts', child: Text(loc.t('dash_status_waiting_parts'))),
                        PopupMenuItem(value: 'completed', child: Text(loc.t('garage_stat_done'))),
                      ],
                    ),
                  ],
                ),
              ),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_filteredJobs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.build_circle_outlined, size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(loc.t('tech_empty_jobs'), style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: _filteredJobs.map(_jobCard).toList(),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _jobCard(Map<String, dynamic> job) {
    final loc = AppLocale.instance;
    final status = job['status']?.toString() ?? 'assigned';
    final customerName = '${job['first_name'] ?? ''} ${job['last_name'] ?? ''}'.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, size: 15, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(customerName.isEmpty ? loc.t('profile_name_fallback') : customerName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_statusLabel(status),
                    style: TextStyle(
                        color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.directions_car_outlined, size: 15, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(_vehicleLabel(job['vehicle_type']?.toString()),
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(width: 12),
              Icon(Icons.build_outlined, size: 15, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(job['problem_category']?.toString() ?? '-',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.access_time, size: 15, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(_formatThaiDateTime(job['created_at']?.toString()),
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _callCustomer(job['customer_phone']?.toString()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xff2196F3),
                    side: const BorderSide(color: Color(0xff2196F3)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.call_outlined, size: 16),
                  label: Text(loc.t('tech_call_button')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TechnicianJobDetailPage(job: job, userData: _userData),
                      ),
                    );
                    _fetchJobs();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff2196F3),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(loc.t('garage_view_details'), style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}