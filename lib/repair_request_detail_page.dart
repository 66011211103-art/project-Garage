// ============================================================
// 📄 ไฟล์: repair_request_detail_page.dart
// 📌 หน้า/ฟีเจอร์: หน้า "รายละเอียดคำขอซ่อม" ฝั่งลูกค้า (เปิดจากการกดการ์ดใน
//     my_repair_requests_page.dart)
// 📝 คำอธิบาย: แสดงรายละเอียดคำขอซ่อม 1 รายการแบบเต็มหน้าจอ (แทนที่ bottom
//     sheet แบบเดิมที่เป็นตัวหนังสือล้วน) จัดเป็นการ์ดสวยงาม — ข้อมูลอู่,
//     ประเภทรถ/ปัญหา, รายละเอียดที่ลูกค้าแจ้ง, รูปภาพ, ที่อยู่, เหตุผลที่อู่
//     ปฏิเสธ (ถ้ามี) และฝัง QuotationCard (quotation_card.dart) ไว้ท้ายหน้า
//     เพื่อให้ลูกค้าดูใบเสนอราคาและกดยืนยัน/ปฏิเสธได้ในหน้าเดียว
// ============================================================

import 'package:flutter/material.dart';
import 'quotation_card.dart'; // ✅ การ์ดใบเสนอราคา (ยืนยัน/ปฏิเสธ)

const List<String> _detailThaiMonthsAbbr = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];

class RepairRequestDetailPage extends StatelessWidget {
  final Map<String, dynamic> request;
  /// เรียกกลับเมื่อลูกค้ายืนยัน/ปฏิเสธใบเสนอราคาสำเร็จ เพื่อให้หน้ารายการรีเฟรช
  final VoidCallback? onQuotationResponded;

  const RepairRequestDetailPage({super.key, required this.request, this.onQuotationResponded});

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
    final month = _detailThaiMonthsAbbr[dt.month - 1];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} $month ${buddhistYear2Digit.toString().padLeft(2, '0')}, $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final status = request['status']?.toString() ?? 'pending';
    final shopName = request['shop_name']?.toString() ?? 'ไม่ระบุชื่ออู่';
    final photos = (request['photos'] is List) ? List<dynamic>.from(request['photos']) : [];
    final hasQuotation = status == 'quoted' || status == 'confirmed' || status == 'rejected';

    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: const Text('รายละเอียดคำขอซ่อม',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---------- การ์ดข้อมูลอู่ + สถานะ ----------
          _card(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xffE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.store, color: Color(0xff2196F3), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shopName,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(_formatThaiDateTime(request['created_at']?.toString()),
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(status), size: 13, color: _statusColor(status)),
                      const SizedBox(width: 4),
                      Text(_statusLabel(status),
                          style: TextStyle(
                              color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ---------- การ์ดข้อมูลคำขอซ่อม ----------
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Icons.directions_car_outlined, 'ประเภทรถ',
                    _vehicleLabel(request['vehicle_type']?.toString())),
                const Divider(height: 20),
                _infoRow(Icons.build_outlined, 'ประเภทปัญหา',
                    request['problem_category']?.toString() ?? '-'),
                const Divider(height: 20),
                _infoRow(Icons.call_outlined, 'เบอร์อู่', request['garage_phone']?.toString() ?? '-'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ---------- รายละเอียดปัญหาที่แจ้ง ----------
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('รายละเอียดที่แจ้ง',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(height: 8),
                Text(
                  request['description']?.toString().isNotEmpty == true
                      ? request['description'].toString()
                      : 'ไม่มีรายละเอียดเพิ่มเติม',
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ---------- ที่อยู่ที่แจ้ง ----------
          _card(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request['address']?.toString().isNotEmpty == true
                        ? request['address'].toString()
                        : 'ไม่ระบุที่อยู่',
                    style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          // ---------- รูปภาพประกอบ ----------
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('รูปภาพประกอบ',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(photos[i].toString(),
                            width: 96, height: 96, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ---------- เหตุผลที่อู่ปฏิเสธคำขอ (ปฏิเสธก่อนเสนอราคา) ----------
          if (status == 'rejected' && (request['rejection_reason']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            _card(
              color: const Color(0xffFFEBEE),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Color(0xffE53935)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('เหตุผลที่อู่ปฏิเสธ',
                            style: TextStyle(color: Color(0xffE53935), fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(request['rejection_reason'].toString(),
                            style: const TextStyle(color: Color(0xffE53935), fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ---------- ใบเสนอราคา (ถ้ามี) ----------
          if (hasQuotation) ...[
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text('ใบเสนอราคา', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            QuotationCard(
              repairRequestId: request['id'],
              onResponded: onQuotationResponded,
            ),
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _card({required Widget child, Color color = Colors.white}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: color == Colors.white
            ? const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))]
            : null,
      ),
      child: child,
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 17, color: const Color(0xff2196F3)),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
