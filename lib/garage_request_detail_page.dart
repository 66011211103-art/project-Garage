// ============================================================
// 📄 ไฟล์: garage_request_detail_page.dart
// 📌 หน้า/ฟีเจอร์: หน้ารายละเอียดคำขอซ่อมแบบเต็มจอ ฝั่งอู่ — เปิดจากปุ่ม
//     "ดูรายละเอียด" ในหน้า "งาน" (all_repair_requests_page.dart)
// 📝 คำอธิบาย: แทนที่ bottom sheet เดิม (_showRequestDetail) ที่มีข้อมูลน้อยและ
//     ไม่มีใบเสนอราคาให้ดู ด้วยหน้าเต็มที่รวมข้อมูลลูกค้า/รถ/ปัญหา/รูปภาพ/ที่อยู่
//     ไว้ครบ พร้อมการ์ดใบเสนอราคา (ถ้ามี) ที่กด "แก้ไขใบเสนอราคา" ได้ทันที
//     — ปุ่มการทำงานด้านล่างจะเปลี่ยนไปตามสถานะของคำขอ (รอดำเนินการ/รับแล้ว/
//     รอลูกค้ายืนยัน/ยืนยันแล้ว/กำลังซ่อม/เสร็จแล้ว) เหมือนพฤติกรรมเดิมในลิสต์
// ============================================================

import 'package:flutter/material.dart';
import 'api_service.dart';
import 'reject_reason_dialog.dart';
import 'create_quotation_page.dart';
import 'assign_technician_page.dart';
import 'repair_tracking_page.dart';
import 'payment_confirm_dialog.dart';
import 'chat_screen.dart';
import ' myCarPage.dart' show vehicleTypeLabel;

class GarageRequestDetailPage extends StatefulWidget {
  final Map<String, dynamic> request;
  final Map<String, dynamic> userData;

  const GarageRequestDetailPage({super.key, required this.request, required this.userData});

  @override
  State<GarageRequestDetailPage> createState() => _GarageRequestDetailPageState();
}

class _GarageRequestDetailPageState extends State<GarageRequestDetailPage> {
  static const List<String> _inRepairStatuses = ['assigned', 'checking', 'in_progress', 'waiting_parts'];

  late Map<String, dynamic> _request;
  Map<String, dynamic>? _quotation;
  bool _isLoadingQuotation = true;
  bool _changed = false; // ✅ แจ้งหน้าลิสต์ว่าต้องรีเฟรชตอนกลับไปไหม
  // ✅ กันกดปุ่ม "รับงาน"/"ปฏิเสธ" รัวๆ ยิง request ซ้ำซ้อน (เดิมไม่มี guard เลย)
  bool _isResponding = false;

  @override
  void initState() {
    super.initState();
    _request = widget.request;
    _fetchQuotation();
  }

  Future<void> _fetchQuotation() async {
    setState(() => _isLoadingQuotation = true);
    final result = await ApiService.getQuotation(repairRequestId: _request['id']);
    if (!mounted) return;
    setState(() {
      _isLoadingQuotation = false;
      _quotation = (result.success && result.data != null)
          ? result.data!['quotation'] as Map<String, dynamic>?
          : null;
    });
  }

  String get _status => _request['status']?.toString() ?? 'pending';
  bool get _isPending => _status == 'pending';
  bool get _isAccepted => _status == 'accepted';
  bool get _isQuoted => _status == 'quoted';
  bool get _isConfirmed => _status == 'confirmed';
  bool get _isInRepair => _inRepairStatuses.contains(_status);
  bool get _isCompleted => _status == 'completed';
  bool get _isRejected => _status == 'rejected';

  // ใบเสนอราคาแก้ไขได้เฉพาะช่วงที่ยังไม่เริ่มลงมือซ่อมจริง (ก่อน/หลังลูกค้ายืนยันก็ยังแก้ได้
  // แต่พอมอบหมายช่างหรือซ่อมไปแล้วห้ามแก้ เพราะราคาที่ตกลงกันไปแล้วไม่ควรเปลี่ยนกลางทาง)
  bool get _canEditQuotation => _quotation != null && (_isQuoted || _isConfirmed);

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

  // ✅ คำขอซ่อมใหม่จะผูกกับรถจริงจาก "รถของฉัน" (มี car_id / cars.car_type) —
  // ใช้ vehicleTypeLabel ที่รองรับประเภทรถครบกว่า ส่วนคำขอเก่าก่อนอัปเดตแอป
  // ที่ไม่มีรถผูกไว้ ให้ fallback ไปใช้ vehicle_type แบบเดิม
  bool get _hasCarInfo => (_request['car_model']?.toString().trim().isNotEmpty ?? false);

  String get _vehicleTypeDisplay {
    final carType = _request['car_type']?.toString();
    if (carType != null && carType.isNotEmpty) return vehicleTypeLabel(carType);
    return _vehicleLabel(_request['vehicle_type']?.toString());
  }

  Map<String, dynamic>? get _carInfo {
    if (!_hasCarInfo) return null;
    return {
      'car_brand': _request['car_brand'],
      'car_model': _request['car_model'],
      'car_type': _request['car_type'],
      'car_plate': _request['car_plate'],
      'car_color': _request['car_color'],
      'car_year': _request['car_year'],
    };
  }

  String _formatDateTime(String? isoString) {
    // ✅ backend ตอบวันที่กลับมาเป็น UTC ISO string (เช่น "...T10:00:00.000Z")
    // ถ้าไม่ .toLocal() ก่อน ตัวเลข .hour/.day ที่อ่านออกมาจะเป็นเวลา UTC ตรงๆ
    // ซึ่งช้ากว่าเวลาไทยจริง 7 ชั่วโมง (เวลาที่โชว์ในแอปเลยดู "ไม่ตรงกับปัจจุบัน")
    final dt = DateTime.tryParse(isoString ?? '')?.toLocal();
    if (dt == null) return '-';
    final buddhistYear2Digit = (dt.year + 543) % 100;
    return '${dt.day}/${dt.month}/${buddhistYear2Digit.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} น.';
  }

  ({String label, Color color}) get _statusInfo {
    final paymentStatus = _request['payment_status']?.toString();
    if (_isCompleted) {
      if (paymentStatus == 'pending_confirmation') {
        return (label: 'รอตรวจสอบการชำระเงิน', color: const Color(0xffFF9800));
      } else if (paymentStatus == 'rejected') {
        return (label: 'ปฏิเสธสลิป รอลูกค้าส่งใหม่', color: const Color(0xffE53935));
      }
      return (label: 'ซ่อมเสร็จ รอลูกค้าชำระเงิน', color: const Color(0xff4CAF50));
    }
    if (_isInRepair) {
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
      return (label: labels[_status] ?? _status, color: colors[_status] ?? Colors.grey);
    }
    if (_isConfirmed) return (label: 'ลูกค้ายืนยันแล้ว', color: const Color(0xff4CAF50));
    if (_isQuoted) return (label: 'รอลูกค้ายืนยันใบเสนอราคา', color: const Color(0xff9C27B0));
    if (_isAccepted) return (label: 'รับแล้ว', color: const Color(0xff2196F3));
    if (_isRejected) return (label: 'ปฏิเสธคำขอแล้ว', color: const Color(0xffE53935));
    return (label: 'รอดำเนินการ', color: const Color(0xffFF9800));
  }

  Future<void> _openChat() async {
    final result = await ApiService.getOrCreateConversation(
      customerId: _request['customer_id'],
      garageId: widget.userData['id'],
    );
    if (!mounted) return;
    if (!result.success || result.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message.isNotEmpty ? result.message : 'เปิดแชทไม่สำเร็จ'), backgroundColor: Colors.red),
      );
      return;
    }
    final name = '${_request['first_name'] ?? ''} ${_request['last_name'] ?? ''}'.trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: result.data!['conversationId'],
          myId: widget.userData['id'],
          myType: 'repair',
          otherPartyName: name.isEmpty ? 'ลูกค้า' : name,
          otherPartyAvatar: _request['customer_avatar']?.toString(),
        ),
      ),
    );
  }

  Future<void> _respond(String status, {String? reason}) async {
    if (_isResponding) return; // ✅ กันกดซ้ำระหว่าง request ก่อนหน้ายังไม่เสร็จ
    setState(() => _isResponding = true);
    final result = await ApiService.updateRepairRequestStatus(
      requestId: _request['id'],
      garageId: widget.userData['id'],
      status: status,
      reason: reason,
    );
    if (!mounted) return;
    setState(() => _isResponding = false);
    if (result.success) {
      setState(() {
        _request = {..._request, 'status': status};
        _changed = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleReject() async {
    final reason = await showRejectReasonDialog(context);
    if (reason == null) return;
    await _respond('rejected', reason: reason);
  }

  Future<void> _openCreateOrEditQuotation() async {
    final name = '${_request['first_name'] ?? ''} ${_request['last_name'] ?? ''}'.trim();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateQuotationPage(
          repairRequestId: _request['id'],
          customerName: name.isEmpty ? 'ไม่ระบุชื่อ' : name,
          existingQuotation: _quotation, // ✅ null = สร้างใหม่, มีค่า = แก้ไข
          carInfo: _carInfo, // ✅ ข้อมูลรถของลูกค้า (ถ้าคำขอนี้ผูกกับรถใน "รถของฉัน")
          garageServices: (widget.userData['services'] is List)
              ? List<dynamic>.from(widget.userData['services'])
              : null, // ✅ รายการบริการของอู่ ให้เลือกใส่ในใบเสนอราคาได้แทนการพิมพ์เอง
        ),
      ),
    );
    if (result == true) {
      _changed = true;
      _fetchQuotation();
    }
  }

  Future<void> _openAssignTechnician() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignTechnicianPage(job: _request, garageId: widget.userData['id']),
      ),
    );
    if (result == true) {
      setState(() => _changed = true);
    }
  }

  void _openTracking() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RepairTrackingPage(job: _request, isCustomerView: false)),
    );
  }

  Future<void> _openPaymentConfirm() async {
    final changed = await showPaymentConfirmDialog(
      context,
      paymentId: _request['payment_id'],
      garageId: widget.userData['id'],
      amount: double.tryParse(_request['payment_amount']?.toString() ?? '0') ?? 0,
      slipUrl: _request['payment_slip']?.toString(),
    );
    if (changed == true) setState(() => _changed = true);
  }

  @override
  Widget build(BuildContext context) {
    final name = '${_request['first_name'] ?? ''} ${_request['last_name'] ?? ''}'.trim();
    final photos = (_request['photos'] is List) ? List<dynamic>.from(_request['photos']) : [];
    final statusInfo = _statusInfo;
    final paymentStatus = _request['payment_status']?.toString();
    final amount = double.tryParse(_request['payment_amount']?.toString() ?? '0') ?? 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: const Color(0xffF5F6FA),
        appBar: AppBar(
          backgroundColor: const Color(0xff2196F3),
          title: Text(_repairCode(_request['id']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context, _changed),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
              onPressed: _openChat,
              tooltip: 'แชทกับลูกค้า',
            ),
          ],
          elevation: 0,
        ),
        body: RefreshIndicator(
          onRefresh: _fetchQuotation,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ---------- สถานะ ----------
              _card(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: statusInfo.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.info_outline, color: statusInfo.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(statusInfo.label,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: statusInfo.color)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ---------- ข้อมูลลูกค้า/รถ/ปัญหา ----------
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow(Icons.person_outline, 'ลูกค้า', name.isEmpty ? 'ไม่ระบุชื่อ' : name),
                    const Divider(height: 20),
                    _infoRow(Icons.directions_car_outlined, 'ประเภทรถ', _vehicleTypeDisplay),
                    if (_hasCarInfo) ...[
                      const Divider(height: 20),
                      _infoRow(Icons.badge_outlined, 'ยี่ห้อ/รุ่น',
                          '${_request['car_brand'] ?? ''} ${_request['car_model'] ?? ''}'.trim().isEmpty
                              ? 'ไม่ระบุ'
                              : '${_request['car_brand'] ?? ''} ${_request['car_model'] ?? ''}'.trim()),
                      if ((_request['car_plate']?.toString() ?? '').isNotEmpty) ...[
                        const Divider(height: 20),
                        _infoRow(Icons.pin_outlined, 'ทะเบียนรถ', _request['car_plate'].toString()),
                      ],
                    ],
                    const Divider(height: 20),
                    _infoRow(Icons.build_outlined, 'ประเภทปัญหา', _request['problem_category']?.toString() ?? '-'),
                    const Divider(height: 20),
                    _infoRow(Icons.event_outlined, 'วันที่แจ้งซ่อม', _formatDateTime(_request['created_at']?.toString())),
                    if (_request['technician_name'] != null) ...[
                      const Divider(height: 20),
                      _infoRow(Icons.engineering_outlined, 'ช่างที่รับผิดชอบ', _request['technician_name'].toString()),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ---------- รายละเอียดที่แจ้ง ----------
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('รายละเอียดที่ลูกค้าแจ้ง',
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

              // ---------- เหตุผลที่อู่ปฏิเสธคำขอ (ถ้ามี) ----------
              if (_isRejected && (_request['rejection_reason']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                _card(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.cancel_outlined, size: 18, color: Color(0xffE53935)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('เหตุผลที่ปฏิเสธ: ${_request['rejection_reason']}',
                            style: const TextStyle(color: Color(0xffE53935), fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],

              // ---------- ใบเสนอราคา ----------
              const SizedBox(height: 12),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('ใบเสนอราคา', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                        ),
                        if (_canEditQuotation)
                          TextButton.icon(
                            onPressed: _openCreateOrEditQuotation,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              foregroundColor: const Color(0xff2196F3),
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 15),
                            label: const Text('แก้ไขใบเสนอราคา', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_isLoadingQuotation)
                      const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                    else if (_quotation == null) ...[
                      const Text('ยังไม่มีใบเสนอราคา', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      if (_isAccepted) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _openCreateOrEditQuotation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff9C27B0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.receipt_long, color: Colors.white, size: 16),
                            label: const Text('สร้างใบเสนอราคา', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ] else ...[
                      ...((_quotation!['items'] is List) ? List<dynamic>.from(_quotation!['items']) : []).map(
                        (it) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text('${it['name']} x${it['quantity'] ?? 1}',
                                      style: const TextStyle(fontSize: 13))),
                              Text('฿${double.tryParse(it['price']?.toString() ?? '0')?.toStringAsFixed(0) ?? '0'}',
                                  style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                      if ((double.tryParse(_quotation!['labor_cost']?.toString() ?? '0') ?? 0) > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              const Expanded(child: Text('ค่าแรง', style: TextStyle(fontSize: 13))),
                              Text('฿${double.tryParse(_quotation!['labor_cost']?.toString() ?? '0')?.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      if ((_quotation!['notes']?.toString() ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(_quotation!['notes'].toString(),
                            style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4)),
                      ],
                      // ✅ VAT 7% บวกเพิ่มจริงจากค่าอะไหล่+ค่าแรง ให้ตรงกับยอดที่
                      // ลูกค้าเห็น (quotation_card.dart) และยอดที่เรียกเก็บเงินจริง
                      // (customer_payment_page.dart) — ไม่ใช้ total_price จาก
                      // backend ตรงๆ เพราะยังไม่ได้บวก VAT เข้าไป
                      Builder(builder: (context) {
                        final partsCost =
                            ((_quotation!['items'] is List) ? List<dynamic>.from(_quotation!['items']) : [])
                                .fold<double>(0, (sum, it) => sum + (double.tryParse(it['price']?.toString() ?? '0') ?? 0));
                        final laborCost = double.tryParse(_quotation!['labor_cost']?.toString() ?? '0') ?? 0;
                        final subTotal = partsCost + laborCost;
                        final vatAmount = subTotal * 0.07;
                        final totalPrice = subTotal + vatAmount;
                        return Column(
                          children: [
                            const Divider(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  const Expanded(child: Text('ภาษีมูลค่าเพิ่ม 7%', style: TextStyle(fontSize: 13))),
                                  Text('฿${vatAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                            const Divider(height: 16),
                            Row(
                              children: [
                                const Expanded(child: Text('รวมทั้งหมด', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                                Text('฿${totalPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xff4CAF50))),
                              ],
                            ),
                          ],
                        );
                      }),
                    ],
                  ],
                ),
              ),

              // ---------- สลิปการชำระเงิน ----------
              if (_request['payment_slip'] != null) ...[
                const SizedBox(height: 12),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('สลิปการชำระเงิน', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: GestureDetector(
                          onTap: () => _viewPhoto(_request['payment_slip'].toString()),
                          child: Image.network(_request['payment_slip'].toString(), fit: BoxFit.contain),
                        ),
                      ),
                      if (amount > 0) ...[
                        const SizedBox(height: 8),
                        Text('ยอดที่แจ้งโอน: ฿${amount.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 90), // เผื่อพื้นที่ให้ปุ่มด้านล่างไม่บังเนื้อหา
            ],
          ),
        ),
        bottomNavigationBar: _bottomActionBar(),
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

  /// แถบปุ่มการทำงานด้านล่าง — เปลี่ยนไปตามสถานะ เหมือนพฤติกรรมเดิมในลิสต์
  Widget? _bottomActionBar() {
    final id = _request['id'];
    final paymentStatus = _request['payment_status']?.toString();

    Widget bar(List<Widget> children) => Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))],
          ),
          child: SafeArea(top: false, child: Row(children: children)),
        );

    if (_isPending) {
      return bar([
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isResponding ? null : _handleReject,
            icon: const Icon(Icons.close, size: 16, color: Colors.red),
            label: const Text('ปฏิเสธ', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isResponding ? null : () => _respond('accepted'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.check, color: Colors.white, size: 16),
            label: const Text('รับงาน', style: TextStyle(color: Colors.white)),
          ),
        ),
      ]);
    }

    if (_isAccepted && _quotation == null) {
      // สร้างใบเสนอราคาปุ่มหลักอยู่ในการ์ดใบเสนอราคาแล้ว ไม่ต้องซ้ำตรงนี้
      return null;
    }

    if (_isConfirmed) {
      if (_request['assigned_technician_id'] != null) {
        return bar([
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _openTracking,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff4CAF50),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.task_alt, color: Colors.white, size: 16),
              label: const Text('มอบหมายงานให้ช่างแล้ว — ดูสถานะ', style: TextStyle(color: Colors.white)),
            ),
          ),
        ]);
      }
      return bar([
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _openAssignTechnician,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff2196F3),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.engineering_outlined, color: Colors.white, size: 16),
            label: const Text('มอบหมายงานให้ช่าง', style: TextStyle(color: Colors.white)),
          ),
        ),
      ]);
    }

    if (_isInRepair) {
      return bar([
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _openTracking,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff2196F3),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.timeline, color: Colors.white, size: 16),
            label: const Text('ดูสถานะการซ่อม', style: TextStyle(color: Colors.white)),
          ),
        ),
      ]);
    }

    if (_isCompleted && paymentStatus == 'pending_confirmation') {
      return bar([
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _openPaymentConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffFF9800),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.receipt_long, color: Colors.white, size: 16),
            label: const Text('ตรวจสอบการชำระเงิน', style: TextStyle(color: Colors.white)),
          ),
        ),
      ]);
    }

    return null;
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