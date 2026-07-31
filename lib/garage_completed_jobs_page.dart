// ============================================================
// 📄 ไฟล์: garage_completed_jobs_page.dart
// 📌 หน้า/ฟีเจอร์: แท็บ "ประวัติ" ฝั่งอู่ — ลิสต์งานซ่อมที่ "เสร็จแล้ว" ของลูกค้า
//     ทุกคน (ไม่ใช่แค่รายการที่มีการชำระเงินเข้ามาแล้วเหมือนเดิม) พร้อมป้ายสถานะ
//     การชำระเงินของแต่ละงานให้ดูคร่าวๆ (ดูอย่างเดียว ไม่มีปุ่มยืนยัน/ปฏิเสธในนี้)
// 📝 คำอธิบาย: เดิมแท็บนี้ใช้ payment_history_page.dart ซึ่งดึงจากตาราง payments
//     ทำให้งานที่ซ่อมเสร็จแล้วแต่ลูกค้ายังไม่จ่ายเงินจะไม่โผล่ในลิสต์เลย ไฟล์นี้
//     ดึงจาก repair_requests โดยตรง (สถานะ completed) แล้วรวมสถานะชำระเงินที่
//     backend join มาให้อยู่แล้วในตัว (payment_status/payment_amount ฯลฯ) มาแสดง
//     เป็นข้อมูลอ้างอิงเฉยๆ — ส่วนการยืนยัน/ปฏิเสธสลิปจริงๆ แยกไปอยู่ที่ปุ่ม
//     "การชำระเงิน" ในเมนูด่วนหน้า Dashboard ต่างหาก (payment_history_page.dart)
// 🎨 อัปเดต UI: ปรับหน้าตาให้ตรงกับดีไซน์ตัวอย่าง (Figma "History Screen") —
//     เพิ่ม header ไล่สีฟ้าพร้อมช่องค้นหา, การ์ดสถิติ 2 ใบ (งานทั้งหมด/รายได้),
//     แถบตัวกรอง (ทั้งหมด/เสร็จสิ้น/ชำระแล้ว) และการ์ดรายการที่โชว์เลข Repair ID
//     พร้อมปุ่ม "ดูรายละเอียด" เต็มความกว้างด้านล่างการ์ด
// ============================================================

import 'package:flutter/material.dart';
import 'api_service.dart';

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

  final _searchController = TextEditingController();
  String _query = '';
  // ✅ ตัวกรอง: all = ทั้งหมด, unpaid = เสร็จสิ้น(ยังไม่ชำระ), paid = ชำระแล้ว
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _fetchJobs();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  // ✅ รายการหลังผ่านตัวกรอง + คำค้นหา (Repair ID หรือชื่อลูกค้า)
  List<Map<String, dynamic>> get _filteredJobs {
    return _jobs.where((job) {
      final paymentStatus = job['payment_status']?.toString();
      if (_filter == 'paid' && paymentStatus != 'confirmed') return false;
      if (_filter == 'unpaid' && paymentStatus == 'confirmed') return false;

      if (_query.isEmpty) return true;
      final name = '${job['first_name'] ?? ''} ${job['last_name'] ?? ''}'.toLowerCase();
      final code = _repairCode(job['id']).toLowerCase();
      return name.contains(_query) || code.contains(_query);
    }).toList();
  }

  String _repairCode(dynamic id) => '#REQ${(id ?? 0).toString().padLeft(6, '0')}';

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

  // ✅ ย่อจำนวนเงินให้อ่านง่ายแบบในดีไซน์ตัวอย่าง (เช่น 485,000 -> 485K)
  String _formatCompact(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }

  void _showJobDetail(Map<String, dynamic> job) {
    final name = '${job['first_name'] ?? ''} ${job['last_name'] ?? ''}'.trim();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_repairCode(job['id']), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(name.isEmpty ? 'ไม่ระบุชื่อ' : name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('ประเภทรถ: ${_vehicleLabel(job['vehicle_type']?.toString())}', style: const TextStyle(color: Colors.grey)),
            Text('ประเภทปัญหา: ${job['problem_category'] ?? '-'}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            Text('ซ่อมเสร็จเมื่อ: ${_formatDate(job['completed_at']?.toString())}',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _paymentStatusColor(job['payment_status']?.toString()).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_paymentStatusLabel(job['payment_status']?.toString()),
                  style: TextStyle(
                      color: _paymentStatusColor(job['payment_status']?.toString()),
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Header ไล่สีฟ้า + ช่องค้นหา =====
  Widget _header() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, widget.embedded ? 16 : 8, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xff2196F3), Color(0xff1976D2)]),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (!widget.embedded)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              Expanded(
                child: Text(
                  'ประวัติงานซ่อม',
                  textAlign: widget.embedded ? TextAlign.center : TextAlign.start,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              if (!widget.embedded) const SizedBox(width: 48), // สมดุลกับปุ่ม back
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหา Repair ID, ชื่อลูกค้า...',
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: Icon(Icons.tune, color: Colors.blue.shade300),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== การ์ดสถิติ 2 ใบ =====
  Widget _statCard({required IconData icon, required Color color, required String label, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== แถบตัวกรอง (chip) =====
  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _filter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
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
      ),
    );
  }

  // ===== การ์ดแต่ละรายการงานซ่อม =====
  Widget _jobCard(Map<String, dynamic> job) {
    final name = '${job['first_name'] ?? ''} ${job['last_name'] ?? ''}'.trim();
    final paymentStatus = job['payment_status']?.toString();
    final amount = double.tryParse(job['payment_amount']?.toString() ?? '0') ?? 0;
    final carModel = (job['car_model'] ?? job['car_plate'])?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_repairCode(job['id']),
                        style: const TextStyle(color: Color(0xff2196F3), fontWeight: FontWeight.bold, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _paymentStatusColor(paymentStatus).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_paymentStatusLabel(paymentStatus),
                          style: TextStyle(
                              color: _paymentStatusColor(paymentStatus), fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _iconLine(Icons.person_outline, 'ลูกค้า: ${name.isEmpty ? 'ไม่ระบุชื่อ' : name}'),
                const SizedBox(height: 6),
                _iconLine(
                  Icons.directions_car_outlined,
                  'รถ: ${_vehicleLabel(job['vehicle_type']?.toString())}${carModel != null && carModel.isNotEmpty ? ' - $carModel' : ''}',
                ),
                const SizedBox(height: 6),
                _iconLine(Icons.build_outlined, 'ปัญหา: ${job['problem_category'] ?? '-'}'),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _iconLine(Icons.calendar_today_outlined, 'ซ่อมเสร็จ ${_formatDate(job['completed_at']?.toString())}'),
                    if (amount > 0)
                      Text('฿${amount.toStringAsFixed(0)}',
                          style: const TextStyle(color: Color(0xff4CAF50), fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _showJobDetail(job),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xffE3F2FD),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('ดูรายละเอียด', style: TextStyle(color: Color(0xff2196F3), fontWeight: FontWeight.w600)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, color: Color(0xff2196F3), size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconLine(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: const TextStyle(fontSize: 12.5, color: Colors.black87))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobs = _filteredJobs;

    final content = Column(
      children: [
        _header(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchJobs,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          _statCard(
                            icon: Icons.build_outlined,
                            color: const Color(0xff2196F3),
                            label: 'งานทั้งหมด',
                            value: '${_jobs.length}',
                          ),
                          const SizedBox(width: 12),
                          _statCard(
                            icon: Icons.attach_money,
                            color: const Color(0xff4CAF50),
                            label: 'รายได้',
                            value: '฿${_formatCompact(_totalConfirmed)}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _filterChip('ทั้งหมด', 'all'),
                          _filterChip('เสร็จสิ้น', 'unpaid'),
                          _filterChip('ชำระแล้ว', 'paid'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (jobs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text(
                              _jobs.isEmpty ? 'ยังไม่มีงานที่ซ่อมเสร็จ' : 'ไม่พบรายการที่ตรงกับการค้นหา',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ...jobs.map(_jobCard),
                    ],
                  ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      body: SafeArea(bottom: false, child: content),
    );
  }
}