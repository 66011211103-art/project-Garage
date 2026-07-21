// ============================================================
// 📄 ไฟล์: my_repair_requests_page.dart
// 📌 หน้า/ฟีเจอร์: หน้า "ประวัติคำขอซ่อม" ฝั่งลูกค้า
// 📝 คำอธิบาย: แสดงรายการคำขอซ่อมทั้งหมดของลูกค้า พร้อมสถานะ (รอดำเนินการ/
//     อู่รับงานแล้ว/มีใบเสนอราคาใหม่/ยืนยันแล้ว/ปฏิเสธ/เสร็จสิ้น) กดเข้าไปดู
//     รายละเอียดคำขอแต่ละรายการได้ และฝัง QuotationCard (quotation_card.dart)
//     ไว้ในการ์ดเพื่อให้ลูกค้ายืนยัน/ปฏิเสธใบเสนอราคาได้ทันที
//     ใช้เป็นปลายทางเมื่อลูกค้ากดแจ้งเตือน (push notification) เรื่องสถานะคำขอซ่อมด้วย
// ============================================================

import 'package:flutter/material.dart';
import 'api_service.dart';
import 'quotation_card.dart'; // ✅ การ์ดใบเสนอราคา (ยืนยัน/ปฏิเสธ)
import 'repair_request_detail_page.dart'; // ✅ หน้ารายละเอียดคำขอซ่อมแบบเต็มหน้าจอ

const List<String> _thaiMonthsAbbr = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];

/// หน้าประวัติคำขอซ่อมของ "ลูกค้า" เอง — ดูสถานะและเหตุผลปฏิเสธ (ถ้ามี)
/// ใช้เป็นปลายทางเมื่อลูกค้ากดแจ้งเตือน push notification เรื่องสถานะคำขอซ่อม
class MyRepairRequestsPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  /// ถ้ามาจากการกดแจ้งเตือน จะส่ง id ของคำขอนั้นมาด้วย เพื่อเปิดรายละเอียดให้อัตโนมัติ
  final int? highlightRequestId;

  const MyRepairRequestsPage({super.key, required this.userData, this.highlightRequestId});

  @override
  State<MyRepairRequestsPage> createState() => _MyRepairRequestsPageState();
}

class _MyRepairRequestsPageState extends State<MyRepairRequestsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getRepairRequests(customerId: widget.userData['id']);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _requests = result.success && result.data != null
          ? List<Map<String, dynamic>>.from(result.data!['requests'] ?? [])
          : [];
    });

    // ถ้ามาจากการกดแจ้งเตือน ให้เปิด detail ของคำขอนั้นให้อัตโนมัติ
    if (widget.highlightRequestId != null) {
      final match = _requests.where((r) => r['id'] == widget.highlightRequestId).toList();
      if (match.isNotEmpty && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showRequestDetail(match.first));
      }
    }
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

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'รอดำเนินการ';
      case 'accepted':
        return 'อู่รับงานแล้ว';
      case 'quoted':
        return 'มีใบเสนอราคาใหม่';
      case 'confirmed':
        return 'ยืนยันแล้ว กำลังซ่อม';
      case 'rejected':
        return 'อู่ปฏิเสธ';
      case 'done':
        return 'เสร็จสิ้น';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xffFF9800);
      case 'accepted':
        return const Color(0xff2196F3);
      case 'quoted':
        return const Color(0xff9C27B0);
      case 'confirmed':
        return const Color(0xff4CAF50);
      case 'rejected':
        return const Color(0xffE53935);
      case 'done':
        return const Color(0xff4CAF50);
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'accepted':
        return Icons.check_circle_outline;
      case 'quoted':
        return Icons.receipt_long;
      case 'confirmed':
        return Icons.build_circle_outlined;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'done':
        return Icons.task_alt;
      default:
        return Icons.help_outline;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: const Text('ประวัติคำขอซ่อม', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchRequests,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _requests.isEmpty
                ? ListView(
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 80),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.inbox_outlined, size: 56, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('ยังไม่มีคำขอซ่อม', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _requests.length,
                    itemBuilder: (context, index) => _requestCard(_requests[index]),
                  ),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> r) {
    final status = r['status']?.toString() ?? 'pending';
    final shopName = r['shop_name']?.toString() ?? 'ไม่ระบุชื่ออู่';
    final isHighlighted = widget.highlightRequestId != null && r['id'] == widget.highlightRequestId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isHighlighted ? Border.all(color: const Color(0xff2196F3), width: 2) : null,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: InkWell(
        onTap: () => _showRequestDetail(r),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(shopName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon(status), size: 14, color: _statusColor(status)),
                        const SizedBox(width: 4),
                        Text(_statusLabel(status),
                            style: TextStyle(
                                color: _statusColor(status), fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.directions_car_outlined, size: 15, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(_vehicleLabel(r['vehicle_type']?.toString()),
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(width: 12),
                  Icon(Icons.build_outlined, size: 15, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(r['problem_category']?.toString() ?? '-',
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 15, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(_formatThaiDateTime(r['created_at']?.toString()),
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),

              // ✅ จุดสำคัญตามที่ขอ — โชว์เหตุผลปฏิเสธตรงๆ ในการ์ดเลย ไม่ต้องกดเข้าไปดูอีกที
              if (status == 'rejected' && (r['rejection_reason']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xffFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Color(0xffE53935)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'เหตุผล: ${r['rejection_reason']}',
                          style: const TextStyle(color: Color(0xffE53935), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ✅ โชว์ใบเสนอราคาให้ยืนยัน/ปฏิเสธตรงในการ์ดเลย
              if (status == 'quoted' || status == 'confirmed')
                QuotationCard(repairRequestId: r['id'], onResponded: _fetchRequests),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ เปิดหน้ารายละเอียดคำขอซ่อมแบบเต็มหน้าจอ (แทนที่ bottom sheet ตัวหนังสือล้วนแบบเดิม)
  void _showRequestDetail(Map<String, dynamic> r) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RepairRequestDetailPage(
          request: r,
          onQuotationResponded: _fetchRequests,
        ),
      ),
    );
  }
}