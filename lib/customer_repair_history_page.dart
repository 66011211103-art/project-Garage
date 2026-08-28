// ============================================================
// 📄 ไฟล์: customer_repair_history_page.dart
// 📌 หน้า/ฟีเจอร์: "ประวัติการซ่อมรถ" ฝั่งลูกค้า (ตาม Figma ที่ส่งมา)
// 📝 คำอธิบาย: ต่างจาก my_repair_requests_page.dart (ที่โชว์ทุกสถานะ รวมงาน
//     ที่ยังไม่เสร็จ) หน้านี้กรองมาเฉพาะงานที่ "เสร็จแล้ว" เท่านั้น เพื่อดูสรุป
//     ประวัติการซ่อมทั้งหมดที่ผ่านมา พร้อมยอดที่จ่ายไปทั้งหมด — กด "ดูรายละเอียด"
//     แต่ละรายการเพื่อเปิด repair_request_detail_page.dart (มีอยู่แล้ว)
// ============================================================

import 'package:flutter/material.dart';
import 'api_service.dart';
import 'repair_request_detail_page.dart';
import 'app_locale.dart';

class CustomerRepairHistoryPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const CustomerRepairHistoryPage({super.key, required this.userData});

  @override
  State<CustomerRepairHistoryPage> createState() => _CustomerRepairHistoryPageState();
}

class _CustomerRepairHistoryPageState extends State<CustomerRepairHistoryPage> {
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
    final result = await ApiService.getRepairRequests(customerId: widget.userData['id']);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      final all = result.success && result.data != null
          ? List<Map<String, dynamic>>.from(result.data!['requests'] ?? [])
          : <Map<String, dynamic>>[];
      _jobs = all.where((r) => r['status']?.toString() == 'completed').toList()
        ..sort((a, b) => (b['completed_at']?.toString() ?? '').compareTo(a['completed_at']?.toString() ?? ''));
    });
  }

  double get _totalSpent => _jobs.fold<double>(
      0, (sum, j) => sum + (double.tryParse(j['payment_amount']?.toString() ?? '0') ?? 0));

  String _formatDateHeader(String? isoString) {
    final dt = DateTime.tryParse(isoString ?? '');
    if (dt == null) return '-';
    const months = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    final buddhistYear = dt.year + 543;
    return '${dt.day} ${months[dt.month - 1]} $buddhistYear';
  }

  @override
  Widget build(BuildContext context) {
    // ✅ จัดกลุ่มตามวันที่ (แสดงหัวข้อวันที่คั่นระหว่างกลุ่ม เหมือนดีไซน์ตัวอย่าง)
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final job in _jobs) {
      final key = _formatDateHeader(job['completed_at']?.toString());
      grouped.putIfAbsent(key, () => []).add(job);
    }

    final loc = AppLocale.instance;
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: Text(loc.t('crh_page_title'), style: const TextStyle(color: Colors.white)),
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
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ---------- แถบสรุป ----------
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xff2196F3), Color(0xff1976D2)]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_jobs.length}',
                                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                            Text(loc.t('crh_count_unit'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('฿${_totalSpent.toStringAsFixed(0)}',
                                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                            Text(loc.t('crh_total_spent_label'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text(loc.t('crh_all_items_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 12),

                  if (_jobs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Text(loc.t('crh_empty_state'), style: const TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    ...grouped.entries.expand((entry) sync* {
                      yield Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(entry.key, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      );
                      for (final job in entry.value) {
                        yield _jobCard(job);
                      }
                    }),
                ],
              ),
      ),
    );
  }

  Widget _jobCard(Map<String, dynamic> job) {
    final loc = AppLocale.instance;
    final shopName = job['shop_name']?.toString() ?? loc.t('myreq_shop_name_fallback');
    final garageAvatar = job['garage_avatar']?.toString();
    final amount = double.tryParse(job['payment_amount']?.toString() ?? '0') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xffE3F2FD),
                backgroundImage: (garageAvatar != null && garageAvatar.isNotEmpty) ? NetworkImage(garageAvatar) : null,
                child: (garageAvatar == null || garageAvatar.isEmpty)
                    ? const Icon(Icons.store, color: Color(0xff2196F3), size: 18)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(shopName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.build_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(job['problem_category']?.toString() ?? '-',
                    style: const TextStyle(fontSize: 13, color: Colors.black87)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (amount > 0)
                Text('฿${amount.toStringAsFixed(0)}',
                    style: const TextStyle(color: Color(0xff4CAF50), fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xffE8F5E9), borderRadius: BorderRadius.circular(20)),
                child: Text(loc.t('tech_status_completed'),
                    style: const TextStyle(color: Color(0xff4CAF50), fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RepairRequestDetailPage(request: job)),
                );
              },
              icon: const Icon(Icons.arrow_forward, size: 15),
              label: Text(loc.t('garage_view_details')),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xff2196F3),
                side: const BorderSide(color: Color(0xff2196F3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
