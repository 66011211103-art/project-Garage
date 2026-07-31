// ============================================================
// 📄 ไฟล์: technician_job_detail_page.dart
// 📌 หน้า/ฟีเจอร์: หน้า "รายละเอียดงาน" (Mechanic Job Screen) ฝั่งช่าง
// 📝 คำอธิบาย: แสดงข้อมูลลูกค้า, รายละเอียดรถ, คำอธิบายปัญหา (ไฮไลต์กรอบเหลือง),
//     ตำแหน่งงาน + ปุ่มนำทาง, เช็กลิสต์อะไหล่ที่ต้องใช้ (ดึงจากใบเสนอราคาที่
//     ยืนยันแล้วของงานนี้ — ถ้ามี), รูปถ่ายก่อน/หลังซ่อมจากบันทึกความคืบหน้า,
//     ไทม์ไลน์ความคืบหน้า และปุ่มไปหน้าอัปเดตสถานะงาน (update_job_status_page.dart)
// ⚠️ หมายเหตุ: ปุ่ม "นำทาง" ใช้แพ็กเกจ url_launcher เปิด Google Maps —
//     ต้องมี `url_launcher` ใน pubspec.yaml (ตัวเดียวกับที่ใช้ในหน้า dashboard)
// ⚠️ เช็กลิสต์ "อุปกรณ์/อะไหล่ที่ต้องใช้" ดึงจากรายการในใบเสนอราคาจริงของงานนี้
//     (ไม่ได้เดา/สร้างข้อมูลเอง) — ถ้างานนี้ยังไม่มีใบเสนอราคา จะไม่แสดงส่วนนี้
// ============================================================

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'update_job_status_page.dart';

const List<String> _thaiMonthsAbbr = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];

class TechnicianJobDetailPage extends StatefulWidget {
  final Map<String, dynamic> job;
  final Map<String, dynamic> userData;

  const TechnicianJobDetailPage({super.key, required this.job, required this.userData});

  @override
  State<TechnicianJobDetailPage> createState() => _TechnicianJobDetailPageState();
}

class _TechnicianJobDetailPageState extends State<TechnicianJobDetailPage> {
  late Map<String, dynamic> _job;
  bool _isLoadingLogs = true;
  List<Map<String, dynamic>> _logs = [];

  bool _isLoadingQuotation = true;
  List<dynamic> _quotationItems = [];

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    _fetchLogs();
    _fetchQuotationItems();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoadingLogs = true);
    final result = await ApiService.getRepairLogs(repairRequestId: _job['id']);
    if (!mounted) return;
    setState(() {
      _isLoadingLogs = false;
      _logs = result.success && result.data != null
          ? List<Map<String, dynamic>>.from(result.data!['logs'] ?? [])
          : [];
    });
  }

  // ✅ ดึงรายการอะไหล่จากใบเสนอราคาของงานนี้ (ถ้ามี) มาแสดงเป็นเช็กลิสต์
  Future<void> _fetchQuotationItems() async {
    setState(() => _isLoadingQuotation = true);
    final result = await ApiService.getQuotation(repairRequestId: _job['id']);
    if (!mounted) return;
    final quotation = result.success ? (result.data?['quotation'] as Map<String, dynamic>?) : null;
    setState(() {
      _isLoadingQuotation = false;
      _quotationItems = (quotation?['items'] is List) ? List<dynamic>.from(quotation!['items']) : [];
    });
  }

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

  String _formatThaiDateTime(String? isoString) {
    if (isoString == null) return '-';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return '-';
    final buddhistYear2Digit = (dt.year + 543) % 100;
    final month = _thaiMonthsAbbr[dt.month - 1];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} $month ${buddhistYear2Digit.toString().padLeft(2, '0')}, $hh:$mm';
  }

  Future<void> _openNavigation() async {
    final lat = _job['latitude'];
    final lng = _job['longitude'];
    final Uri uri;
    if (lat != null && lng != null) {
      uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    } else {
      final address = Uri.encodeComponent(_job['address']?.toString() ?? '');
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$address');
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถเปิดแผนที่ได้')),
      );
    }
  }

  Future<void> _openUpdateStatus() async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UpdateJobStatusPage(job: _job, userData: widget.userData),
      ),
    );
    if (updated is Map<String, dynamic>) {
      setState(() => _job = {..._job, ...updated});
      _fetchLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _job['status']?.toString() ?? 'assigned';
    final customerName = '${_job['first_name'] ?? ''} ${_job['last_name'] ?? ''}'.trim();
    final photos = (_job['photos'] is List) ? List<dynamic>.from(_job['photos']) : [];

    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: const Text('รายละเอียดงาน', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ---------- รหัสงาน + สถานะ ----------
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xff2196F3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('รหัสงาน #${_job['id']}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_statusLabel(status),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                _infoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _cardHeader(Icons.person_outline, 'ข้อมูลลูกค้า'),
                      const SizedBox(height: 10),
                      Text(customerName.isEmpty ? 'ไม่ระบุชื่อ' : customerName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(_job['customer_phone']?.toString() ?? 'ไม่ระบุเบอร์',
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                _infoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _cardHeader(Icons.directions_car_outlined, 'รายละเอียดรถ'),
                      const SizedBox(height: 10),
                      Text('ประเภทรถ: ${_vehicleLabel(_job['vehicle_type']?.toString())}'),
                      const SizedBox(height: 4),
                      Text('ประเภทปัญหา: ${_job['problem_category'] ?? '-'}'),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                _infoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _cardHeader(Icons.warning_amber_outlined, 'คำอธิบายปัญหา'),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xffFFF8E1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _job['description']?.toString().isNotEmpty == true
                              ? _job['description'].toString()
                              : 'ไม่มีรายละเอียดเพิ่มเติม',
                          style: const TextStyle(fontSize: 13, height: 1.5),
                        ),
                      ),
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
                                  child: Image.network(url.toString(),
                                      width: 90, height: 90, fit: BoxFit.cover),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                _infoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _cardHeader(Icons.location_on_outlined, 'ตำแหน่งงาน'),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xffE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_job['address']?.toString() ?? 'ไม่ระบุที่อยู่',
                            style: const TextStyle(fontSize: 13, height: 1.4)),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openNavigation,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xff2196F3),
                            side: const BorderSide(color: Color(0xff2196F3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.navigation_outlined, size: 16),
                          label: const Text('นำทาง'),
                        ),
                      ),
                    ],
                  ),
                ),

                // ---------- เช็กลิสต์อะไหล่ (จากใบเสนอราคาจริง ถ้ามี) ----------
                if (!_isLoadingQuotation && _quotationItems.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _infoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardHeader(Icons.checklist_outlined, 'อุปกรณ์/อะไหล่ที่ต้องใช้'),
                        const SizedBox(height: 6),
                        ..._quotationItems.map((it) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_box_outlined, size: 18, color: Color(0xff4CAF50)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                        '${it['name']} (${it['quantity']}${(it['unit'] ?? '').toString().isNotEmpty ? ' ${it['unit']}' : ''})',
                                        style: const TextStyle(fontSize: 13)),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                _infoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _cardHeader(Icons.history, 'ไทม์ไลน์ความคืบหน้า'),
                      const SizedBox(height: 8),
                      if (_isLoadingLogs)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_logs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('ยังไม่มีบันทึกความคืบหน้า', style: TextStyle(color: Colors.grey)),
                        )
                      else
                        ..._logs.map(_logItem),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ===== ปุ่มอัปเดตสถานะ / บันทึกความคืบหน้า ติดด้านล่างเสมอ =====
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))],
            ),
            child: status == 'completed'
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(14)),
                    child: const Center(
                      child: Text('งานนี้เสร็จเรียบร้อยแล้ว ✅',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                  )
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openUpdateStatus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff2196F3),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.update, color: Colors.white),
                      label: const Text('อัปเดตสถานะงาน',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'assigned':
        return 'รอเริ่มงาน';
      case 'checking':
        return 'ช่างกำลังเดินทาง';
      case 'in_progress':
        return 'กำลังซ่อม';
      case 'waiting_parts':
        return 'รอรับอะไหล่';
      case 'completed':
        return 'ซ่อมเสร็จแล้ว';
      default:
        return status;
    }
  }

  Widget _logItem(Map<String, dynamic> log) {
    final photos = (log['photos'] is List) ? List<dynamic>.from(log['photos']) : [];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xffF5F5F5), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(log['technician_name']?.toString() ?? 'ช่าง',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(_formatThaiDateTime(log['created_at']?.toString()),
                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
          if ((log['note']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(log['note'].toString(), style: const TextStyle(fontSize: 13)),
          ],
          if ((log['parts_used']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('อะไหล่: ${log['parts_used']}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: photos.map((url) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(url.toString(), width: 70, height: 70, fit: BoxFit.cover),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: child,
    );
  }

  Widget _cardHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xff2196F3)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }
}