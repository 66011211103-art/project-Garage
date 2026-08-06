import 'package:flutter/material.dart';
import 'api_service.dart';
import 'reject_reason_dialog.dart'; // ✅ popup เลือกเหตุผลปฏิเสธ
import 'create_quotation_page.dart'; // ✅ หน้าสร้างใบเสนอราคา
import 'assign_technician_page.dart'; // ✅ หน้ามอบหมายงานให้ช่าง
import 'repair_tracking_page.dart'; // ✅ หน้าติดตามสถานะการซ่อม
import 'payment_confirm_dialog.dart'; // ✅ popup ตรวจสอบ/ยืนยัน/ปฏิเสธการชำระเงิน
import 'chat_screen.dart'; // ✅ แชทกับลูกค้า
import 'garage_request_detail_page.dart'; // ✅ หน้ารายละเอียดเต็มจอ (แทน bottom sheet เดิม)

const List<String> _thaiMonthsAbbr = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];

/// หน้ารายการคำขอซ่อมทั้งหมด (ฝั่งอู่) พร้อมแท็บกรองสถานะ
class AllRepairRequestsPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  /// ถ้าใช้เป็นแท็บ "งาน" ในหน้าแรก (ไม่ได้ถูก push มา) ส่ง true เพื่อซ่อน AppBar/ปุ่มย้อนกลับ
  final bool embedded;

  const AllRepairRequestsPage({super.key, required this.userData, this.embedded = false});

  @override
  State<AllRepairRequestsPage> createState() => _AllRepairRequestsPageState();
}

enum _RequestTab { all, pending, accepted }

class _AllRepairRequestsPageState extends State<AllRepairRequestsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];
  _RequestTab _selectedTab = _RequestTab.all;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getRepairRequests(garageId: widget.userData['id']);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _requests = result.success && result.data != null
          ? List<Map<String, dynamic>>.from(result.data!['requests'] ?? [])
          : [];
    });
  }

  // ✅ เปิดแชทกับลูกค้าของคำขอซ่อมนี้ (หาบทสนทนาเดิม หรือสร้างใหม่ถ้ายังไม่เคยคุยกัน)
  Future<void> _openChat(Map<String, dynamic> r) async {
    final result = await ApiService.getOrCreateConversation(
      customerId: r['customer_id'],
      garageId: widget.userData['id'],
    );
    if (!mounted) return;
    if (!result.success || result.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message.isNotEmpty ? result.message : 'เปิดแชทไม่สำเร็จ'), backgroundColor: Colors.red),
      );
      return;
    }

    final name = '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: result.data!['conversationId'],
          myId: widget.userData['id'],
          myType: 'repair',
          otherPartyName: name.isEmpty ? 'ลูกค้า' : name,
          otherPartyAvatar: r['customer_avatar']?.toString(),
        ),
      ),
    );
  }

  Future<void> _respondToRequest(int requestId, String status, {String? reason}) async {
    final result = await ApiService.updateRepairRequestStatus(
      requestId: requestId,
      status: status,
      reason: reason,
    );
    if (!mounted) return;
    if (result.success) {
      _fetchRequests();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleReject(int requestId) async {
    final reason = await showRejectReasonDialog(context);
    if (reason == null) return;
    await _respondToRequest(requestId, 'rejected', reason: reason);
  }

  // สถานะระหว่างซ่อมจริง (หลังมอบหมายช่างแล้ว) — ช่างเป็นคนอัปเดตจากฝั่งของช่างเอง
  static const List<String> _inRepairStatuses = ['assigned', 'checking', 'in_progress', 'waiting_parts'];

  // "รายการคำขอซ่อม" นับเฉพาะงานที่ยัง active อยู่ (รอดำเนินการ + รับแล้ว/เสนอราคา/ยืนยันแล้ว/กำลังซ่อม
  // + ซ่อมเสร็จแล้วแต่ลูกค้ายังไม่จ่ายเงิน หรือจ่ายแล้วรอ/ถูกปฏิเสธการยืนยัน)
  // ไม่รวมที่ปฏิเสธ/จ่ายเงินยืนยันเสร็จสมบูรณ์แล้ว เพราะถือว่าไม่ใช่งานที่ต้อง follow-up ต่อ
  bool _isActiveRequest(Map<String, dynamic> r) {
    final status = r['status'];
    if (['pending', 'accepted', 'quoted', 'confirmed', ..._inRepairStatuses].contains(status)) return true;
    if (status == 'completed' && r['payment_status'] != 'confirmed') return true;
    return false;
  }

  List<Map<String, dynamic>> get _activeRequests => _requests.where(_isActiveRequest).toList();

  List<Map<String, dynamic>> get _pendingOnly =>
      _requests.where((r) => r['status'] == 'pending').toList();

  // "รับแล้ว" ครอบคลุมทุกขั้นหลังรับงาน (รับแล้ว/ส่งใบเสนอราคาแล้ว/ลูกค้ายืนยันแล้ว/กำลังซ่อม/รอเก็บเงิน)
  List<Map<String, dynamic>> get _acceptedOnly =>
      _requests.where((r) => r['status'] != 'pending' && _isActiveRequest(r)).toList();

  List<Map<String, dynamic>> get _visibleRequests {
    switch (_selectedTab) {
      case _RequestTab.pending:
        return _pendingOnly;
      case _RequestTab.accepted:
        return _acceptedOnly;
      case _RequestTab.all:
        return _activeRequests;
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

  IconData _problemIcon(String? category) {
    switch (category) {
      case 'เครื่องยนต์':
        return Icons.build_outlined;
      case 'ยาง':
        return Icons.circle_outlined;
      case 'แบตเตอรี่':
        return Icons.battery_charging_full_outlined;
      case 'เบรก':
        return Icons.album_outlined;
      case 'ซ่อมสี':
        return Icons.format_paint_outlined;
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

  bool _isRecentlyCreated(String? isoString) {
    final dt = DateTime.tryParse(isoString ?? '');
    if (dt == null) return false;
    return DateTime.now().difference(dt).inHours < 3;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: const Color(0xff2196F3),
              title: const Text('รายการคำขอซ่อม', style: TextStyle(color: Colors.white)),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  onPressed: () {},
                ),
              ],
              elevation: 0,
            ),
      body: SafeArea(
        top: widget.embedded,
        child: RefreshIndicator(
        onRefresh: _fetchRequests,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        _filterPill(
                          label: 'ทั้งหมด',
                          count: _activeRequests.length,
                          selected: _selectedTab == _RequestTab.all,
                          onTap: () => setState(() => _selectedTab = _RequestTab.all),
                        ),
                        const SizedBox(width: 8),
                        _filterPill(
                          label: 'รอดำเนินการ',
                          count: _pendingOnly.length,
                          selected: _selectedTab == _RequestTab.pending,
                          onTap: () => setState(() => _selectedTab = _RequestTab.pending),
                        ),
                        const SizedBox(width: 8),
                        _filterPill(
                          label: 'รับแล้ว',
                          count: _acceptedOnly.length,
                          selected: _selectedTab == _RequestTab.accepted,
                          onTap: () => setState(() => _selectedTab = _RequestTab.accepted),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _visibleRequests.isEmpty
                        ? ListView(
                            children: const [
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 60),
                                child: Center(
                                  child: Text('ไม่มีคำขอในหมวดนี้', style: TextStyle(color: Colors.grey)),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 20),
                            itemCount: _visibleRequests.length,
                            itemBuilder: (context, index) => _requestCard(_visibleRequests[index]),
                          ),
                  ),
                ],
              ),
      ),
      ),
    );
  }

  Widget _filterPill({
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xffE3F2FD) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? const Color(0xff2196F3) : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xff2196F3) : Colors.black87,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 6),
            CircleAvatar(
              radius: 10,
              backgroundColor: selected ? const Color(0xff2196F3) : Colors.grey.shade300,
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? Colors.white : Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> r) {
    final id = r['id'];
    final name = '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim();
    final status = r['status']?.toString() ?? 'pending';
    final isPending = status == 'pending';
    final isAccepted = status == 'accepted';
    final isQuoted = status == 'quoted';
    final isConfirmed = status == 'confirmed';
    final isInRepair = _inRepairStatuses.contains(status);
    final isCompleted = status == 'completed';
    final paymentStatus = r['payment_status']?.toString();

    // ป้ายสถานะ: ใหม่ / รอดำเนินการ / รับแล้ว / รอลูกค้ายืนยันใบเสนอราคา / ลูกค้ายืนยันแล้ว / กำลังซ่อม / รอเก็บเงิน
    late String badgeText;
    late Color badgeColor;
    if (isCompleted) {
      if (paymentStatus == 'pending_confirmation') {
        badgeText = 'รอตรวจสอบการชำระเงิน';
        badgeColor = const Color(0xffFF9800);
      } else if (paymentStatus == 'rejected') {
        badgeText = 'ปฏิเสธสลิป รอลูกค้าส่งใหม่';
        badgeColor = const Color(0xffE53935);
      } else {
        badgeText = 'ซ่อมเสร็จ รอลูกค้าชำระเงิน';
        badgeColor = const Color(0xff4CAF50);
      }
    } else if (isInRepair) {
      const labels = {
        'assigned': 'มอบหมายช่างแล้ว',
        'checking': 'ช่างกำลังเดินทาง',
        'in_progress': 'กำลังซ่อม',
        'waiting_parts': 'รอรับอะไหล่',
      };
      const colors = {
        'assigned': Color(0xff2196F3),
        'checking': Color(0xff9C27B0),
        'in_progress': Color(0xffFF9800),
        'waiting_parts': Color(0xff795548),
      };
      badgeText = labels[status] ?? status;
      badgeColor = colors[status] ?? Colors.grey;
    } else if (isConfirmed) {
      badgeText = 'ลูกค้ายืนยันแล้ว';
      badgeColor = const Color(0xff4CAF50);
    } else if (isQuoted) {
      badgeText = 'รอลูกค้ายืนยันใบเสนอราคา';
      badgeColor = const Color(0xff9C27B0);
    } else if (isAccepted) {
      badgeText = 'รับแล้ว';
      badgeColor = const Color(0xff2196F3);
    } else if (_isRecentlyCreated(r['created_at']?.toString())) {
      badgeText = 'ใหม่';
      badgeColor = const Color(0xff4CAF50);
    } else {
      badgeText = 'รอดำเนินการ';
      badgeColor = const Color(0xffFF9800);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.description_outlined, size: 18, color: Color(0xff2196F3)),
                  const SizedBox(width: 6),
                  Text('#REQ${id.toString().padLeft(6, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
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
                    // ✅ Flexible กันบั๊ก overflow ตอน badgeText ยาว เช่น "รอลูกค้ายืนยันใบเสนอราคา"
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badgeText,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _detailRow(Icons.person_outline, name.isEmpty ? 'ไม่ระบุชื่อ' : name),
          const SizedBox(height: 6),
          _detailRow(Icons.directions_car_outlined, _vehicleLabel(r['vehicle_type']?.toString())),
          const SizedBox(height: 6),
          _detailRow(_problemIcon(r['problem_category']?.toString()), r['problem_category']?.toString() ?? '-'),
          const SizedBox(height: 6),
          _detailRow(Icons.access_time, _formatThaiDateTime(r['created_at']?.toString())),
          const SizedBox(height: 12),
          if (isPending)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openDetail(r),
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                    label: const Text('ดูรายละเอียด'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleReject(id),
                    icon: const Icon(Icons.close, size: 16, color: Colors.red),
                    label: const Text('ปฏิเสธ', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _respondToRequest(id, 'accepted'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check, color: Colors.white, size: 16),
                    label: const Text('รับงาน', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            )
          else if (isAccepted)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openDetail(r),
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                    label: const Text('ดูรายละเอียด'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateQuotationPage(
                            repairRequestId: id,
                            customerName: name.isEmpty ? 'ไม่ระบุชื่อ' : name,
                          ),
                        ),
                      );
                      if (result == true) _fetchRequests();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff9C27B0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.receipt_long, color: Colors.white, size: 16),
                    label: const Text('ใบเสนอราคา', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                ),
              ],
            )
          else if (isQuoted)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openDetail(r),
                icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                label: const Text('ดูรายละเอียด / รอลูกค้ายืนยันใบเสนอราคา'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            )
          // ✅ ลูกค้ายืนยันใบเสนอราคาแล้ว — จุดที่อู่มอบหมายงานให้ช่างได้
          else if (isConfirmed)
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openDetail(r),
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                    label: const Text('ดูรายละเอียด'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: r['assigned_technician_id'] != null
                      ? InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RepairTrackingPage(job: r, isCustomerView: false),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text('มอบหมายงานให้ช่างแล้ว — แตะเพื่อดูสถานะ ✅',
                                  style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AssignTechnicianPage(
                                  job: r,
                                  garageId: widget.userData['id'],
                                ),
                              ),
                            );
                            if (result == true) _fetchRequests();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff2196F3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.engineering_outlined, color: Colors.white, size: 16),
                          label: const Text('มอบหมายงานให้ช่าง', style: TextStyle(color: Colors.white)),
                        ),
                ),
              ],
            )
          // ✅ ซ่อมเสร็จแล้ว รอเก็บเงิน — ถ้ามีลูกค้าแจ้งชำระเงินเข้ามาแล้ว ให้อู่ตรวจสลิป/ยืนยัน/ปฏิเสธได้
          else if (isCompleted)
            SizedBox(
              width: double.infinity,
              child: paymentStatus == 'pending_confirmation'
                  ? ElevatedButton.icon(
                      onPressed: () async {
                        final changed = await showPaymentConfirmDialog(
                          context,
                          paymentId: r['payment_id'],
                          garageId: widget.userData['id'],
                          amount: double.tryParse(r['payment_amount']?.toString() ?? '0') ?? 0,
                          slipUrl: r['payment_slip']?.toString(),
                        );
                        if (changed == true) _fetchRequests();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffFF9800),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.receipt_long, color: Colors.white, size: 16),
                      label: const Text('ตรวจสอบการชำระเงิน', style: TextStyle(color: Colors.white)),
                    )
                  : OutlinedButton.icon(
                      onPressed: () => _openDetail(r),
                      icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                      label: Text(paymentStatus == 'rejected'
                          ? 'ดูรายละเอียด (รอลูกค้าแนบสลิปใหม่)'
                          : 'ดูรายละเอียด (รอลูกค้าชำระเงิน)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
            )
          // ✅ มอบหมายช่างแล้ว กำลังซ่อมอยู่ — อู่ดูความคืบหน้าได้ (ช่างเป็นคนอัปเดตสถานะจากฝั่งช่าง)
          else if (isInRepair)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RepairTrackingPage(job: r, isCustomerView: false),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff2196F3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.timeline, color: Colors.white, size: 16),
                label: const Text('ดูสถานะการซ่อม', style: TextStyle(color: Colors.white)),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openDetail(r),
                icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                label: const Text('ดูรายละเอียด'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }

  // ✅ เปิดหน้ารายละเอียดเต็มจอ (แทน bottom sheet เดิม) — มีข้อมูลครบ + ดู/แก้ไข
  // ใบเสนอราคาได้ในตัว ถ้ามีการเปลี่ยนแปลงกลับมา (รับงาน/ปฏิเสธ/สร้างหรือแก้ไข
  // ใบเสนอราคา/มอบหมายช่าง/ยืนยันการชำระเงิน) ให้รีเฟรชลิสต์ทันที
  Future<void> _openDetail(Map<String, dynamic> r) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GarageRequestDetailPage(request: r, userData: widget.userData),
      ),
    );
    if (changed == true) _fetchRequests();
  }
}