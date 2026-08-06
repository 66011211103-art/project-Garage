// ============================================================
// 📄 ไฟล์: garage_completed_jobs_page.dart
// 📌 หน้า/ฟีเจอร์: แท็บ "ประวัติ" ฝั่งอู่ — ลิสต์งานซ่อมที่ "เสร็จแล้ว" ของลูกค้า
//     ทุกคน พร้อมป้ายสถานะการชำระเงินของแต่ละงาน (ดูอย่างเดียว ไม่มีปุ่มยืนยันในนี้)
// 📝 สร้างขึ้นบนโครงสร้างที่พิสูจน์แล้วว่าใช้งานได้จริง (ทดสอบด้วยเวอร์ชัน debug
//     ก่อนหน้านี้ยืนยันว่าดึงข้อมูล + แสดงผลถูกต้อง) — จงใจไม่ใช้ 3 อย่างนี้ที่เคย
//     พิสูจน์แล้วว่าไปชนบั๊ก Flutter framework: CustomScrollView/Sliver,
//     TextField/InputDecorator, AnimatedContainer
// ============================================================

import 'package:flutter/material.dart';
import 'api_service.dart';
import 'garage_job_detail_page.dart';

class GarageCompletedJobsPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool embedded;

  const GarageCompletedJobsPage({super.key, required this.userData, this.embedded = false});

  @override
  State<GarageCompletedJobsPage> createState() => _GarageCompletedJobsPageState();
}

class _GarageCompletedJobsPageState extends State<GarageCompletedJobsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _jobs = [];
  String _filter = 'all'; // all | unpaid | paid

  @override
  void initState() {
    super.initState();
    _fetchJobs();
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
      _jobs = all.where((r) => r['status']?.toString() == 'completed').toList()
        ..sort((a, b) => (b['completed_at']?.toString() ?? '').compareTo(a['completed_at']?.toString() ?? ''));
    });
  }

  double get _totalConfirmed => _jobs
      .where((j) => j['payment_status']?.toString() == 'confirmed')
      .fold<double>(0, (sum, j) => sum + (double.tryParse(j['payment_amount']?.toString() ?? '0') ?? 0));

  List<Map<String, dynamic>> get _filteredJobs {
    if (_filter == 'all') return _jobs;
    return _jobs.where((job) {
      final paid = job['payment_status']?.toString() == 'confirmed';
      return _filter == 'paid' ? paid : !paid;
    }).toList();
  }

  String _repairCode(dynamic id) => '#REQ${(id ?? 0).toString().padLeft(6, '0')}';

  String _paymentStatusLabel(String? status) {
    switch (status) {
      case 'confirmed':
        return 'ชำระเงินแล้ว';
      case 'pending_confirmation':
        return 'รอตรวจสอบสลิป';
      case 'rejected':
        return 'ปฏิเสธสลิปแล้ว';
      default:
        return 'ยังไม่ชำระเงิน';
    }
  }

  Color _paymentStatusColor(String? status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xff4CAF50);
      case 'pending_confirmation':
        return const Color(0xffFF9800);
      case 'rejected':
        return const Color(0xffE53935);
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? isoString) {
    final dt = DateTime.tryParse(isoString ?? '');
    if (dt == null) return '-';
    final buddhistYear2Digit = (dt.year + 543) % 100;
    return '${dt.day}/${dt.month}/${buddhistYear2Digit.toString().padLeft(2, '0')}';
  }

  String _formatCompact(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final jobs = _filteredJobs;

    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: const Color(0xff2196F3),
              title: const Text('ประวัติงานซ่อม', style: TextStyle(color: Colors.white)),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              elevation: 0,
            ),
      body: SafeArea(
        top: widget.embedded,
        child: Column(
          children: [
            // ---------- การ์ดสถิติ 2 ใบ ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(child: _statCard(Icons.build_outlined, const Color(0xff2196F3), 'งานทั้งหมด', '${_jobs.length}')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(Icons.attach_money, const Color(0xff4CAF50), 'รายได้', '฿${_formatCompact(_totalConfirmed)}'),
                  ),
                ],
              ),
            ),

            // ---------- ตัวกรอง ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _filterChip('ทั้งหมด', 'all'),
                  const SizedBox(width: 8),
                  _filterChip('เสร็จสิ้น', 'unpaid'),
                  const SizedBox(width: 8),
                  _filterChip('ชำระแล้ว', 'paid'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ---------- ลิสต์งาน ----------
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : jobs.isEmpty
                      ? Center(
                          child: Text(
                            _jobs.isEmpty ? 'ยังไม่มีงานที่ซ่อมเสร็จ' : 'ไม่มีงานที่ตรงกับตัวกรองนี้',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: jobs.length,
                          itemBuilder: (context, index) => _jobCard(jobs[index]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, Color color, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return InkWell(
      onTap: () => setState(() => _filter = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xff2196F3) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.transparent : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _jobCard(Map<String, dynamic> job) {
    final name = '${job['first_name'] ?? ''} ${job['last_name'] ?? ''}'.trim();
    final paymentStatus = job['payment_status']?.toString();
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
              Text(_repairCode(job['id']),
                  style: const TextStyle(color: Color(0xff2196F3), fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _paymentStatusColor(paymentStatus).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_paymentStatusLabel(paymentStatus),
                    style: TextStyle(color: _paymentStatusColor(paymentStatus), fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('ลูกค้า: ${name.isEmpty ? 'ไม่ระบุชื่อ' : name}', style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          Text('ปัญหา: ${job['problem_category'] ?? '-'}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 4),
          Text('ซ่อมเสร็จ: ${_formatDate(job['completed_at']?.toString())}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (amount > 0) ...[
            const SizedBox(height: 8),
            Text('฿${amount.toStringAsFixed(0)}',
                style: const TextStyle(color: Color(0xff4CAF50), fontWeight: FontWeight.bold, fontSize: 16)),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GarageJobDetailPage(job: job)),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xff2196F3),
                side: const BorderSide(color: Color(0xff2196F3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('ดูรายละเอียด'),
            ),
          ),
        ],
      ),
    );
  }
}