import 'package:flutter/material.dart';
import 'api_service.dart';
import 'reject_reason_dialog.dart'; // ✅ popup เลือกเหตุผลปฏิเสธ
import 'create_quotation_page.dart'; // ✅ หน้าสร้างใบเสนอราคา

const List<String> _thaiMonthsAbbr = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];

/// หน้ารายการคำขอซ่อมทั้งหมด (ฝั่งอู่) พร้อมแท็บกรองสถานะ
class AllRepairRequestsPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const AllRepairRequestsPage({super.key, required this.userData});

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

  // "รายการคำขอซ่อม" นับเฉพาะงานที่ยัง active อยู่ (รอดำเนินการ + รับแล้ว/เสนอราคา/ยืนยันแล้ว)
  // ไม่รวมที่ปฏิเสธ/เสร็จงานไปแล้ว เพราะถือว่าไม่ใช่งานที่ต้อง follow-up ต่อ
  List<Map<String, dynamic>> get _activeRequests => _requests
      .where((r) => ['pending', 'accepted', 'quoted', 'confirmed'].contains(r['status']))
      .toList();

  List<Map<String, dynamic>> get _pendingOnly =>
      _requests.where((r) => r['status'] == 'pending').toList();

  // "รับแล้ว" ครอบคลุมทุกขั้นหลังรับงาน (รับแล้ว/ส่งใบเสนอราคาแล้ว/ลูกค้ายืนยันแล้ว)
  List<Map<String, dynamic>> get _acceptedOnly => _requests
      .where((r) => ['accepted', 'quoted', 'confirmed'].contains(r['status']))
      .toList();

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
      appBar: AppBar(
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
      body: RefreshIndicator(
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

    // ป้ายสถานะ: ใหม่ / รอดำเนินการ / รับแล้ว / รอลูกค้ายืนยันใบเสนอราคา / ลูกค้ายืนยันแล้ว
    late String badgeText;
    late Color badgeColor;
    if (isConfirmed) {
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(badgeText,
                    style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.w600)),
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
                    onPressed: () => _showRequestDetail(r),
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
                    onPressed: () => _showRequestDetail(r),
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
                    label: const Text('สร้างใบเสนอราคา', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            )
          else if (isQuoted)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showRequestDetail(r),
                icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                label: const Text('ดูรายละเอียด / รอลูกค้ายืนยันใบเสนอราคา'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRequestDetail(r),
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
                    onPressed: () => _respondToRequest(id, 'done'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff2196F3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.task_alt, color: Colors.white, size: 16),
                    label: const Text('งานเสร็จแล้ว', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
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

  void _showRequestDetail(Map<String, dynamic> r) {
    final name = '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim();
    final photos = (r['photos'] is List) ? List<dynamic>.from(r['photos']) : [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('#REQ${r['id'].toString().padLeft(6, '0')}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 4),
              Text(name.isEmpty ? 'ไม่ระบุชื่อ' : name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('ประเภทรถ: ${_vehicleLabel(r['vehicle_type']?.toString())}',
                  style: const TextStyle(color: Colors.grey)),
              Text('ประเภทปัญหา: ${r['problem_category'] ?? '-'}', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              Text(r['description']?.toString().isNotEmpty == true
                  ? r['description'].toString()
                  : 'ไม่มีรายละเอียดเพิ่มเติม'),
              const SizedBox(height: 12),
              Text('ที่อยู่: ${r['address'] ?? 'ไม่ระบุ'}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              if ((r['rejection_reason']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xffFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('เหตุผลที่ปฏิเสธ: ${r['rejection_reason']}',
                      style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              ],
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
                          child: Image.network(url.toString(), width: 90, height: 90, fit: BoxFit.cover),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}