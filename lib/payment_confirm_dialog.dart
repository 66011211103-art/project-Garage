// ============================================================
// 📄 ไฟล์: payment_confirm_dialog.dart
// 📌 หน้า/ฟีเจอร์: bottom sheet ให้อู่ตรวจสลิปการโอนเงินของลูกค้า แล้วกด
//     ยืนยัน/ปฏิเสธ — เรียกใช้จาก all_repair_requests_page.dart ตอนงานสถานะ
//     "completed" และมีการแจ้งชำระเงินเข้ามารอตรวจสอบ (payment_status = pending_confirmation)
// 📝 คำอธิบาย: คืนค่า true ถ้ามีการยืนยัน/ปฏิเสธสำเร็จ (ให้หน้าที่เรียกไปรีเฟรชลิสต์ต่อ)
// ============================================================

import 'package:flutter/material.dart';
import 'api_service.dart';

Future<bool?> showPaymentConfirmDialog(
  BuildContext context, {
  required int paymentId,
  required int garageId,
  required double amount,
  required String? slipUrl,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => _PaymentConfirmSheet(
      paymentId: paymentId,
      garageId: garageId,
      amount: amount,
      slipUrl: slipUrl,
    ),
  );
}

class _PaymentConfirmSheet extends StatefulWidget {
  final int paymentId;
  final int garageId;
  final double amount;
  final String? slipUrl;

  const _PaymentConfirmSheet({
    required this.paymentId,
    required this.garageId,
    required this.amount,
    required this.slipUrl,
  });

  @override
  State<_PaymentConfirmSheet> createState() => _PaymentConfirmSheetState();
}

class _PaymentConfirmSheetState extends State<_PaymentConfirmSheet> {
  bool _isSubmitting = false;
  bool _showRejectForm = false;
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() => _isSubmitting = true);
    final result = await ApiService.confirmPayment(paymentId: widget.paymentId, garageId: widget.garageId);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message), backgroundColor: result.success ? Colors.green : Colors.red),
    );
    if (result.success) Navigator.pop(context, true);
  }

  Future<void> _reject() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาระบุเหตุผลที่ปฏิเสธ'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await ApiService.rejectPayment(
      paymentId: widget.paymentId,
      garageId: widget.garageId,
      reason: _reasonController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message), backgroundColor: result.success ? Colors.green : Colors.red),
    );
    if (result.success) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.payments_outlined, color: Color(0xff4CAF50)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('ตรวจสอบการชำระเงิน', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 4),
              Text('ยอดที่แจ้งโอน: ฿${widget.amount.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xff2196F3))),
              const SizedBox(height: 14),
              if (widget.slipUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(widget.slipUrl!, fit: BoxFit.contain),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: const Color(0xffF5F5F5), borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('ไม่พบรูปสลิป', style: TextStyle(color: Colors.grey))),
                ),
              const SizedBox(height: 16),

              if (_showRejectForm) ...[
                TextField(
                  controller: _reasonController,
                  maxLines: 3,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'เหตุผลที่ปฏิเสธ เช่น ยอดไม่ตรง, สลิปไม่ชัด...',
                    filled: true,
                    fillColor: const Color(0xffF5F5F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _reject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffE53935),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('ยืนยันการปฏิเสธ', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => setState(() => _showRejectForm = true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xffE53935),
                          side: const BorderSide(color: Color(0xffE53935)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('ปฏิเสธ'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _confirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff4CAF50),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('ยืนยันรับเงินแล้ว', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
