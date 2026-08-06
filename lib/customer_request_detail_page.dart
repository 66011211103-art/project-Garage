// ============================================================
// 📄 ไฟล์: customer_request_detail_page.dart
// 📌 หน้า/ฟีเจอร์: หน้ารายละเอียดคำขอซ่อมแบบเต็มจอ ฝั่งลูกค้า — เปิดจากการแตะ
//     การ์ดในหน้า "ประวัติคำขอซ่อม" (my_repair_requests_page.dart)
// 📝 คำอธิบาย: แทนที่ bottom sheet เดิม (_showRequestDetail) ที่มีข้อมูลน้อยและ
//     ไม่มีปุ่มให้ทำอะไรต่อ ด้วยหน้าเต็มที่รวมข้อมูลอู่/รถ/ปัญหา/รูปภาพ/ที่อยู่
//     ไว้ครบ พร้อมฝัง QuotationCard/PaymentCard/ReviewCard ตัวเดิม (ใช้ logic
//     เดิมทุกอย่าง ไม่เขียนใหม่) เพื่อให้ลูกค้ายืนยัน/ปฏิเสธใบเสนอราคา จ่ายเงิน
//     หรือรีวิว ได้จากหน้านี้เลยเหมือนในลิสต์ — ดีไซน์คู่กับ
//     garage_request_detail_page.dart ฝั่งอู่
// ============================================================

import 'package:flutter/material.dart';
import 'api_service.dart';
import 'quotation_card.dart';
import 'payment_card.dart';
import 'review_card.dart';
import 'repair_tracking_page.dart';
import 'chat_screen.dart';

class CustomerRequestDetailPage extends StatefulWidget {
  final Map<String, dynamic> request;
  final Map<String, dynamic> userData;

  const CustomerRequestDetailPage({super.key, required this.request, required this.userData});

  @override
  State<CustomerRequestDetailPage> createState() => _CustomerRequestDetailPageState();
}

class _CustomerRequestDetailPageState extends State<CustomerRequestDetailPage> {
  static const List<String> _inRepairStatuses = ['assigned', 'checking', 'in_progress', 'waiting_parts'];

  late Map<String, dynamic> _request;
  bool _isRefreshing = false;
  bool _changed = false; // ✅ แจ้งหน้าลิสต์ว่าต้องรีเฟรชตอนกลับไปไหม

  @override
  void initState() {
    super.initState();
    _request = widget.request;
  }

  // ✅ ดึงคำขอซ่อมนี้ตัวล่าสุดใหม่ทั้งก้อน (สถานะอาจเปลี่ยนหลังลูกค้ายืนยัน
  // ใบเสนอราคา/จ่ายเงิน/รีวิว ผ่านการ์ดที่ฝังอยู่ด้านล่าง)
  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    final result = await ApiService.getRepairRequests(customerId: widget.userData['id']);
    if (!mounted) return;
    if (result.success && result.data != null) {
      final all = List<Map<String, dynamic>>.from(result.data!['requests'] ?? []);
      final match = all.where((x) => x['id'] == _request['id']).toList();
      if (match.isNotEmpty) {
        setState(() {
          _request = match.first;
          _changed = true;
        });
      }
    }
    if (mounted) setState(() => _isRefreshing = false);
  }

  String get _status => _request['status']?.toString() ?? 'pending';
  String get _shopName => _request['shop_name']?.toString() ?? 'ไม่ระบุชื่ออู่';

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

  String _formatDateTime(String? isoString) {
    final dt = DateTime.tryParse(isoString ?? '');
    if (dt == null) return '-';
    const months = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    final buddhistYear2Digit = (dt.year + 543) % 100;
    return '${dt.day} ${months[dt.month - 1]} ${buddhistYear2Digit.toString().padLeft(2, '0')}, '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} น.';
  }

  Future<void> _openChat() async {
    final result = await ApiService.getOrCreateConversation(
      customerId: widget.userData['id'],
      garageId: _request['garage_id'],
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
          otherPartyName: _shopName,
          otherPartyAvatar: _request['garage_avatar']?.toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = (_request['photos'] is List) ? List<dynamic>.from(_request['photos']) : [];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: const Color(0xffF5F6FA),
        appBar: AppBar(
          backgroundColor: const Color(0xff2196F3),
          title: Text(_shopName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context, _changed),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
              onPressed: _openChat,
              tooltip: 'แชทกับอู่',
            ),
          ],
          elevation: 0,
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ---------- สถานะ ----------
              _card(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration:
                          BoxDecoration(color: _statusColor(_status).withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                      child: Icon(_statusIcon(_status), color: _statusColor(_status), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_statusLabel(_status),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _statusColor(_status))),
                    ),
                    if (_isRefreshing)
                      const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ---------- ข้อมูลอู่/รถ/ปัญหา ----------
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow(Icons.store_outlined, 'อู่ซ่อม', _shopName),
                    const Divider(height: 20),
                    _infoRow(Icons.phone_outlined, 'เบอร์อู่', _request['garage_phone']?.toString() ?? '-'),
                    const Divider(height: 20),
                    _infoRow(Icons.directions_car_outlined, 'ประเภทรถ', _vehicleLabel(_request['vehicle_type']?.toString())),
                    const Divider(height: 20),
                    _infoRow(Icons.build_outlined, 'ประเภทปัญหา', _request['problem_category']?.toString() ?? '-'),
                    const Divider(height: 20),
                    _infoRow(Icons.event_outlined, 'วันที่แจ้งซ่อม', _formatDateTime(_request['created_at']?.toString())),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ---------- รายละเอียดที่แจ้ง ----------
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('รายละเอียดที่แจ้งไป',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(
                      _request['description']?.toString().isNotEmpty == true
                          ? _request['description'].toString()
                          : 'ไม่มีรายละเอียดเพิ่มเติม',
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ---------- ที่อยู่ ----------
              _card(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _request['address']?.toString().isNotEmpty == true ? _request['address'].toString() : 'ไม่ระบุที่อยู่',
                        style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              // ---------- รูปภาพ ----------
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
                            child: GestureDetector(
                              onTap: () => _viewPhoto(photos[i].toString()),
                              child: Image.network(photos[i].toString(), width: 96, height: 96, fit: BoxFit.cover),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ---------- เหตุผลที่อู่ปฏิเสธ (ถ้ามี) ----------
              if (_status == 'rejected' && (_request['rejection_reason']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                _card(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.cancel_outlined, size: 18, color: Color(0xffE53935)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('เหตุผลที่อู่ปฏิเสธ: ${_request['rejection_reason']}',
                            style: const TextStyle(color: Color(0xffE53935), fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],

              // ---------- ใบเสนอราคา (ยืนยัน/ปฏิเสธได้ในนี้เลย) ----------
              if (_status == 'quoted' || _status == 'confirmed')
                QuotationCard(
                  repairRequestId: _request['id'],
                  onResponded: _refresh,
                ),

              // ---------- กำลังซ่อมอยู่ ----------
              if (_inRepairStatuses.contains(_status)) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => RepairTrackingPage(job: _request, isCustomerView: true)),
                    ),
                    icon: const Icon(Icons.timeline, size: 16),
                    label: const Text('ติดตามสถานะการซ่อม'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xff2196F3),
                      side: const BorderSide(color: Color(0xff2196F3)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],

              // ---------- ซ่อมเสร็จแล้ว — จ่ายเงิน แล้วค่อยรีวิว ----------
              if (_status == 'completed')
                _request['payment_status'] == 'confirmed'
                    ? ReviewCard(
                        repairRequestId: _request['id'],
                        customerId: _request['customer_id'],
                        shopName: _shopName,
                        garageAvatar: _request['garage_avatar']?.toString(),
                        garageAddress: _request['garage_address']?.toString(),
                        initialRating: (_request['review_rating'] as num?)?.toInt(),
                        initialComment: _request['review_comment']?.toString(),
                        initialReply: _request['review_reply']?.toString(),
                        onSubmitted: _refresh,
                      )
                    : PaymentCard(
                        repairRequestId: _request['id'],
                        customerId: _request['customer_id'],
                        garageId: _request['garage_id'],
                        shopName: _shopName,
                        bankName: _request['bank_name']?.toString(),
                        bankAccountNumber: _request['bank_account_number']?.toString(),
                        bankAccountName: _request['bank_account_name']?.toString(),
                        promptpayId: _request['promptpay_id']?.toString(),
                        paymentStatus: _request['payment_status']?.toString(),
                        rejectionReason: _request['payment_rejection_reason']?.toString(),
                        onChanged: _refresh,
                      ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _viewPhoto(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(child: Image.network(url)),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
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
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}