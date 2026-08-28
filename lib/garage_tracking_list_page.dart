// ============================================================
// 📄 ไฟล์: garage_tracking_list_page.dart
// 📌 หน้า/ฟีเจอร์: "อัปเดตสถานะ" ฝั่งอู่ — ลิสต์เฉพาะงานที่กำลังซ่อมอยู่ (มอบหมายช่าง
//     แล้ว แต่ยังไม่เสร็จ) ให้อู่กดดูสถานะของลูกค้าแต่ละคนตามที่ช่างอัปเดตในระบบ
// 📝 คำอธิบาย: ต่างจากหน้า "งาน" (all_repair_requests_page.dart) ตรงที่หน้านั้น
//     โชว์ทุกสถานะ (รอดำเนินการ/เสนอราคา/ฯลฯ) ส่วนหน้านี้กรองมาเฉพาะงานที่กำลัง
//     ซ่อมอยู่จริงเท่านั้น แล้วพาไปหน้า RepairTrackingPage (isCustomerView: false)
//     ซึ่งเป็นหน้าเดียวกับที่ลูกค้าใช้ดู — อู่จะเห็นสถานะล่าสุดที่ช่างอัปเดตมาเป๊ะๆ
// ============================================================

import 'package:flutter/material.dart';
import 'api_service.dart';
import 'repair_tracking_page.dart';
import 'app_locale.dart';

class GarageTrackingListPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const GarageTrackingListPage({super.key, required this.userData});

  @override
  State<GarageTrackingListPage> createState() => _GarageTrackingListPageState();
}

class _GarageTrackingListPageState extends State<GarageTrackingListPage> {
  static const List<String> _inRepairStatuses = ['assigned', 'checking', 'in_progress', 'waiting_parts'];

  bool _isLoading = true;
  List<Map<String, dynamic>> _jobs = [];

  @override
  void initState() {
    super.initState();
    _fetchJobs();
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

  Future<void> _fetchJobs() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getRepairRequests(garageId: widget.userData['id']);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      final all = result.success && result.data != null
          ? List<Map<String, dynamic>>.from(result.data!['requests'] ?? [])
          : <Map<String, dynamic>>[];
      _jobs = all.where((r) => _inRepairStatuses.contains(r['status']?.toString())).toList();
    });
  }

  String _statusLabel(String? status) {
    final loc = AppLocale.instance;
    switch (status) {
      case 'assigned':
        return loc.t('myreq_status_assigned');
      case 'checking':
        return loc.t('dash_status_checking');
      case 'in_progress':
        return loc.t('dash_status_in_progress');
      case 'waiting_parts':
        return loc.t('dash_status_waiting_parts');
      default:
        return status ?? '-';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'assigned':
        return const Color(0xff2196F3);
      case 'checking':
        return const Color(0xff9C27B0);
      case 'in_progress':
        return const Color(0xffFF9800);
      case 'waiting_parts':
        return const Color(0xff795548);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocale.instance;
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: Text(loc.t('gtl_page_title'), style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchJobs,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _jobs.isEmpty
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 80),
                        child: Center(
                          child: Text(loc.t('gtl_empty_state'),
                              style: const TextStyle(color: Colors.grey)),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _jobs.length,
                    itemBuilder: (context, index) {
                      final job = _jobs[index];
                      final status = job['status']?.toString();
                      final name = '${job['first_name'] ?? ''} ${job['last_name'] ?? ''}'.trim();
                      final technicianName = job['technician_name']?.toString();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                        ),
                        child: InkWell(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RepairTrackingPage(job: job, isCustomerView: false),
                              ),
                            );
                            _fetchJobs();
                          },
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _statusColor(status).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.build_circle_outlined, color: _statusColor(status), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name.isEmpty ? loc.t('profile_name_fallback') : name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    const SizedBox(height: 2),
                                    Text(job['problem_category']?.toString() ?? '-',
                                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                    if (technicianName != null) ...[
                                      const SizedBox(height: 2),
                                      Text(loc.t('gtl_technician_prefix').replaceAll('%s', technicianName),
                                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
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
                                  const SizedBox(height: 6),
                                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
