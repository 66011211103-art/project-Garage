// ============================================================
// 📄 ไฟล์: payment_card.dart
// 📌 หน้า/ฟีเจอร์: การ์ดสรุป "ชำระเงิน" — ฝังอยู่ในหน้า "ประวัติคำขอซ่อม"
//     (my_repair_requests_page.dart) ของฝั่งลูกค้า เมื่องานซ่อมสถานะเป็น "completed"
//     แต่ยังไม่ได้ชำระเงิน หรือชำระแล้วแต่อู่ยังไม่ยืนยัน/ปฏิเสธมา
// 📝 คำอธิบาย: ต้องชำระเงินให้อู่ยืนยันก่อน ถึงจะรีวิวได้ (ตามลำดับ ซ่อมเสร็จ →
//     จ่ายเงิน → รีวิว) เมื่อยืนยันแล้ว การ์ดนี้จะหายไปแล้วสลับไปโชว์ ReviewCard แทน
// ============================================================

import 'package:flutter/material.dart';
import 'customer_payment_page.dart';

class PaymentCard extends StatelessWidget {
  final int repairRequestId;
  final int customerId;
  final int garageId;
  final String shopName;
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankAccountName;
  final String? promptpayId; // ✅ เบอร์/เลขบัตรพร้อมเพย์ของอู่ — ใช้สร้าง QR ให้ลูกค้าสแกนจ่าย

  /// สถานะการชำระเงินปัจจุบัน: null (ยังไม่จ่าย), pending_confirmation, rejected
  final String? paymentStatus;
  final String? rejectionReason;

  final VoidCallback? onChanged;

  const PaymentCard({
    super.key,
    required this.repairRequestId,
    required this.customerId,
    required this.garageId,
    required this.shopName,
    this.bankName,
    this.bankAccountNumber,
    this.bankAccountName,
    this.promptpayId,
    this.paymentStatus,
    this.rejectionReason,
    this.onChanged,
  });

  Future<void> _openPaymentPage(BuildContext context) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerPaymentPage(
          repairRequestId: repairRequestId,
          customerId: customerId,
          garageId: garageId,
          shopName: shopName,
          bankName: bankName,
          bankAccountNumber: bankAccountNumber,
          bankAccountName: bankAccountName,
          promptpayId: promptpayId,
        ),
      ),
    );
    if (changed == true) onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    late Widget content;

    if (paymentStatus == 'pending_confirmation') {
      content = Row(
        children: [
          const Icon(Icons.hourglass_top, size: 18, color: Color(0xffFF9800)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('แจ้งชำระเงินแล้ว รออู่ตรวจสอบและยืนยัน',
                style: TextStyle(fontSize: 13, color: Color(0xffFF9800), fontWeight: FontWeight.w600)),
          ),
        ],
      );
    } else if (paymentStatus == 'rejected') {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, size: 18, color: Color(0xffE53935)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('อู่ปฏิเสธสลิปที่แนบมา', style: TextStyle(color: Color(0xffE53935), fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          if ((rejectionReason ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(rejectionReason!, style: const TextStyle(color: Color(0xffE53935), fontSize: 12)),
          ],
        ],
      );
    } else {
      content = const Text('ซ่อมเสร็จแล้ว — ชำระเงินให้อู่เพื่อดำเนินการต่อ',
          style: TextStyle(fontSize: 13, color: Colors.grey));
    }

    final buttonLabel = paymentStatus == 'rejected'
        ? 'แนบสลิปใหม่'
        : paymentStatus == 'pending_confirmation'
            ? 'ดูสถานะการชำระเงิน'
            : 'ชำระเงิน';

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: const Color(0xffE8F5E9), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.payments_outlined, size: 16, color: Color(0xff4CAF50)),
              ),
              const SizedBox(width: 8),
              const Text('การชำระเงิน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          content,
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _openPaymentPage(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: paymentStatus == 'rejected' ? const Color(0xffE53935) : const Color(0xff4CAF50),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(buttonLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}