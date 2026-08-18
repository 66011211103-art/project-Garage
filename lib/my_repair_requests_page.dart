import 'package:flutter/material.dart';
import 'api_service.dart';
import 'quotation_card.dart'; // ✅ การ์ดใบเสนอราคา (ยืนยัน/ปฏิเสธ)
import 'repair_tracking_page.dart'; // ✅ หน้าติดตามสถานะระหว่างซ่อม (เฉพาะงานที่ยังไม่เสร็จ)
import 'review_card.dart'; // ✅ การ์ดให้คะแนนอู่ — ฝังในลิสต์ตอนซ่อมเสร็จแล้ว ไม่ต้องเปิดหน้าใหม่
import 'payment_card.dart'; // ✅ การ์ดชำระเงิน — ต้องจ่ายก่อนถึงจะรีวิวได้
import 'chat_screen.dart'; // ✅ แชทกับอู่
import 'customer_request_detail_page.dart'; // ✅ หน้ารายละเอียดเต็มจอ (แทน bottom sheet เดิม)
import ' myCarPage.dart' show vehicleTypeLabel; // ✅ ใช้ label กลางที่รองรับรถตู้/มอเตอร์ไซค์/อื่นๆ ด้วย

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
  /// ถ้าหน้านี้ถูกใช้เป็นแท็บในหน้าแรก (ไม่ได้ถูก push มา) ให้ส่ง callback นี้มา
  /// เพื่อสลับกลับไปแท็บ "หน้าหลัก" แทนการ Navigator.pop() ซึ่งจะไม่มีอะไรให้ pop กลับ
  final VoidCallback? onBack;

  const MyRepairRequestsPage({super.key, required this.userData, this.highlightRequestId, this.onBack});

  @override
  State<MyRepairRequestsPage> createState() => _MyRepairRequestsPageState();
}

class _MyRepairRequestsPageState extends State<MyRepairRequestsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];

  // สถานะระหว่างซ่อมจริง (หลังมอบหมายช่างแล้ว แต่ยังไม่เสร็จ)
  static const List<String> _inRepairStatuses = ['assigned', 'checking', 'in_progress', 'waiting_parts'];


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
        WidgetsBinding.instance.addPostFrameCallback((_) => _openDetail(match.first));
      }
    }
  }

  // ✅ เปิดแชทกับอู่ของคำขอซ่อมนี้ (หาบทสนทนาเดิม หรือสร้างใหม่ถ้ายังไม่เคยคุยกัน)
  Future<void> _openChat(Map<String, dynamic> r) async {
    final result = await ApiService.getOrCreateConversation(
      customerId: widget.userData['id'],
      garageId: r['garage_id'],
    );
    if (!mounted) return;
    if (!result.success || result.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message.isNotEmpty ? result.message : 'เปิดแชทไม่สำเร็จ'), backgroundColor: Colors.red),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: result.data!['conversationId'],
          myId: widget.userData['id'],
          myType: 'customer',
          otherPartyName: r['shop_name']?.toString() ?? 'อู่ซ่อมรถ',
          otherPartyAvatar: r['garage_avatar']?.toString(),
        ),
      ),
    );
  }

  // ✅ เดิมรองรับแค่ sedan/suv/pickup แล้ว fallback เป็น "ไม่ระบุ" — พอมีตัวเลือก
  // รถตู้/มอเตอร์ไซค์/อื่นๆ เพิ่มเข้ามา (จาก car_type ที่ผูกกับ "รถของฉัน") คำขอที่
  // ใช้รถประเภทเหล่านี้เลยโชว์ "ไม่ระบุ" ทั้งที่จริงมีข้อมูลอยู่ — ใช้ vehicleTypeLabel
  // กลางแทน ซึ่งรองรับครบทุกประเภท
  String _vehicleLabel(String? value) => vehicleTypeLabel(value);

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'รอดำเนินการ';
      case 'accepted':
        return 'อู่รับงานแล้ว';
      case 'quoted':
        return 'มีใบเสนอราคาใหม่';
      case 'confirmed':
        return 'ยืนยันแล้ว รอมอบหมายช่าง';
      case 'assigned':
        return 'มอบหมายช่างแล้ว';
      case 'checking':
        return 'ช่างกำลังเดินทาง';
      case 'in_progress':
        return 'กำลังซ่อม';
      case 'waiting_parts':
        return 'รอรับอะไหล่';
      case 'completed':
        return 'ซ่อมเสร็จแล้ว';
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
      case 'assigned':
        return const Color(0xff2196F3);
      case 'checking':
        return const Color(0xff9C27B0);
      case 'in_progress':
        return const Color(0xffFF9800);
      case 'waiting_parts':
        return const Color(0xff795548);
      case 'completed':
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
      case 'assigned':
        return Icons.engineering_outlined;
      case 'checking':
        return Icons.search;
      case 'in_progress':
        return Icons.build_circle_outlined;
      case 'waiting_parts':
        return Icons.inventory_2_outlined;
      case 'completed':
        return Icons.task_alt;
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
          onPressed: widget.onBack ?? () => Navigator.pop(context),
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
        onTap: () => _openDetail(r),
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
                  InkWell(
                    onTap: () => _openChat(r),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(color: const Color(0xffE3F2FD), borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.chat_bubble_outline, size: 16, color: Color(0xff2196F3)),
                    ),
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
                QuotationCard(
                  repairRequestId: r['id'],
                  customerId: widget.userData['id'],
                  onResponded: _fetchRequests,
                ),

              // ✅ กำลังซ่อมอยู่ (มอบหมายช่างแล้วแต่ยังไม่เสร็จ) — ไปหน้าติดตามสถานะแบบเต็ม
              if (_inRepairStatuses.contains(status)) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => RepairTrackingPage(job: r, isCustomerView: true)),
                    ),
                    icon: const Icon(Icons.timeline, size: 16),
                    label: const Text('ติดตามสถานะการซ่อม'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xff2196F3),
                      side: const BorderSide(color: Color(0xff2196F3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],

              // ✅ ซ่อมเสร็จแล้ว — ต้องจ่ายเงินก่อน แล้วอู่ยืนยันแล้วถึงจะรีวิวได้
              if (status == 'completed')
                r['payment_status'] == 'confirmed'
                    ? ReviewCard(
                        repairRequestId: r['id'],
                        customerId: r['customer_id'],
                        shopName: shopName,
                        garageAvatar: r['garage_avatar']?.toString(),
                        garageAddress: r['garage_address']?.toString(),
                        initialRating: (r['review_rating'] as num?)?.toInt(),
                        initialComment: r['review_comment']?.toString(),
                        initialReply: r['review_reply']?.toString(),
                        onSubmitted: _fetchRequests,
                      )
                    : PaymentCard(
                        repairRequestId: r['id'],
                        customerId: r['customer_id'],
                        garageId: r['garage_id'],
                        shopName: shopName,
                        bankName: r['bank_name']?.toString(),
                        bankAccountNumber: r['bank_account_number']?.toString(),
                        bankAccountName: r['bank_account_name']?.toString(),
                        promptpayId: r['promptpay_id']?.toString(),
                        paymentStatus: r['payment_status']?.toString(),
                        rejectionReason: r['payment_rejection_reason']?.toString(),
                        onChanged: _fetchRequests,
                      ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ เปิดหน้ารายละเอียดเต็มจอ (แทน bottom sheet เดิม) — มีข้อมูลครบ + ยืนยัน/
  // ปฏิเสธใบเสนอราคา/จ่ายเงิน/รีวิว ได้ในตัว รีเฟรชลิสต์ทันทีถ้ามีการเปลี่ยนแปลง
  Future<void> _openDetail(Map<String, dynamic> r) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerRequestDetailPage(request: r, userData: widget.userData),
      ),
    );
    if (changed == true) _fetchRequests();
  }
}