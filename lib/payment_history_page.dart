// ============================================================
// 📄 ไฟล์: payment_history_page.dart
// 📌 หน้า/ฟีเจอร์: หน้า "ประวัติการชำระเงิน" — ใช้ได้ทั้งฝั่งลูกค้า (ประวัติที่จ่ายไป)
//     และฝั่งอู่ (ประวัติรายได้ที่ได้รับ) สลับด้วย isGarageView
// 📝 คำอธิบาย: โชว์ยอดรวมที่ยืนยันแล้วด้านบน ตามด้วยลิสต์รายการชำระเงินทั้งหมด
//     พร้อมสถานะ (รอตรวจสอบ/ยืนยันแล้ว/ถูกปฏิเสธ) กดแต่ละรายการดูสลิปแบบเต็มจอได้
// ============================================================

import 'package:flutter/material.dart';
import 'api_service.dart';
import 'payment_confirm_dialog.dart'; // ✅ ให้อู่ยืนยัน/ปฏิเสธได้ตรงจากหน้าประวัติเลย

class PaymentHistoryPage extends StatefulWidget {
  final int? customerId;
  final int? garageId;
  final bool isGarageView;
  final bool embedded;

  const PaymentHistoryPage({
    super.key,
    this.customerId,
    this.garageId,
    required this.isGarageView,
    this.embedded = false,
  });

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _payments = [];
  double _totalConfirmed = 0;

  @override
  void initState() {
    super.initState();
    _fetchPayments();
  }

  Future<void> _fetchPayments() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getPayments(
      customerId: widget.isGarageView ? null : widget.customerId,
      garageId: widget.isGarageView ? widget.garageId : null,
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.success && result.data != null) {
        _payments = List<Map<String, dynamic>>.from(result.data!['payments'] ?? []);
        _totalConfirmed = (result.data!['totalConfirmed'] as num?)?.toDouble() ?? 0;
      }
    });
  }

  String _methodLabel(String? method) {
    switch (method) {
      case 'bank_transfer':
        return 'โอนเงินผ่านธนาคาร';
      case 'qr':
        return 'QR Payment';
      case 'credit_card':
        return 'บัตรเครดิต/เดบิต';
      default:
        return method ?? '-';
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'confirmed':
        return 'ยืนยันแล้ว';
      case 'pending_confirmation':
        return 'รอตรวจสอบ';
      case 'rejected':
        return 'ถูกปฏิเสธ';
      default:
        return status ?? '-';
    }
  }

  Color _statusColor(String? status) {
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

  void _viewSlip(String? url) {
    if (url == null) return;
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

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
      onRefresh: _fetchPayments,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xff4CAF50), Color(0xff388E3C)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(widget.isGarageView ? 'รายได้ที่ยืนยันแล้วทั้งหมด' : 'ยอดที่ชำระแล้วทั้งหมด',
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text('฿${_totalConfirmed.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${_payments.length} รายการ', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('ประวัติการชำระเงินทั้งหมด', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 12),
                if (_payments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('ยังไม่มีประวัติการชำระเงิน', style: TextStyle(color: Colors.grey))),
                  )
                else
                  ..._payments.map((p) {
                    final name = widget.isGarageView
                        ? '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim()
                        : p['shop_name']?.toString() ?? '-';
                    final status = p['status']?.toString();
                    final amount = double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
                    final canConfirm = widget.isGarageView && status == 'pending_confirmation';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                      ),
                      child: InkWell(
                        onTap: () async {
                          if (canConfirm) {
                            final changed = await showPaymentConfirmDialog(
                              context,
                              paymentId: p['id'],
                              garageId: widget.garageId!,
                              amount: amount,
                              slipUrl: p['slip_photo']?.toString(),
                            );
                            if (changed == true) _fetchPayments();
                          } else {
                            _viewSlip(p['slip_photo']?.toString());
                          }
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name.isEmpty ? '-' : name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text(_methodLabel(p['method']?.toString()),
                                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Text(_formatDate(p['submitted_at']?.toString()),
                                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                  if (canConfirm) ...[
                                    const SizedBox(height: 4),
                                    const Text('แตะเพื่อตรวจสอบและยืนยัน',
                                        style: TextStyle(color: Color(0xffFF9800), fontSize: 11, fontWeight: FontWeight.w600)),
                                  ],
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('฿${amount.toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _statusColor(status).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(_statusLabel(status),
                                      style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                            if (canConfirm) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );

    if (widget.embedded) {
      return Scaffold(backgroundColor: const Color(0xffF5F5F5), body: body);
    }

    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: const Text('ประวัติการชำระเงิน', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: body,
    );
  }
}