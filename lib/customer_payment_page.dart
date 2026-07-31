// ============================================================
// 📄 ไฟล์: customer_payment_page.dart
// 📌 หน้า/ฟีเจอร์: หน้า "ชำระเงิน" ฝั่งลูกค้า (ตาม Figma ที่ส่งมา)
// 📝 คำอธิบาย: เปิดได้เมื่องานซ่อมสถานะ "completed" แล้วเท่านั้น — ดึงยอดจริงจาก
//     ใบเสนอราคาที่ยืนยันแล้ว (quotations.total_price) ให้เลือกวิธีชำระเงิน
//     (โอนผ่านธนาคาร ใช้งานได้จริง / QR /บัตรเครดิต เป็น "เร็วๆ นี้") แนบสลิป
//     แล้วส่งให้อู่ตรวจสอบ มี 3 สถานะการแสดงผล:
//       - ยังไม่จ่าย → ฟอร์มให้กรอก
//       - จ่ายแล้วรออู่ยืนยัน (pending_confirmation) → หน้าจอรอผล
//       - อู่ปฏิเสธสลิป (rejected) → โชว์เหตุผล + ให้แนบใหม่ได้
//       - อู่ยืนยันแล้ว (confirmed) → หน้าจอสำเร็จ (ไปรีวิวต่อได้จากหน้าประวัติ)
// ============================================================

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';

class CustomerPaymentPage extends StatefulWidget {
  final int repairRequestId;
  final int customerId;
  final int garageId;
  final String shopName;
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankAccountName;

  const CustomerPaymentPage({
    super.key,
    required this.repairRequestId,
    required this.customerId,
    required this.garageId,
    required this.shopName,
    this.bankName,
    this.bankAccountNumber,
    this.bankAccountName,
  });

  @override
  State<CustomerPaymentPage> createState() => _CustomerPaymentPageState();
}

class _CustomerPaymentPageState extends State<CustomerPaymentPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _quotation;
  Map<String, dynamic>? _payment; // สถานะการชำระเงินล่าสุด (ถ้ามี)

  bool _showCostDetails = false;
  String _selectedMethod = 'bank_transfer';
  Uint8List? _slipBytes;
  String? _slipName;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      ApiService.getQuotation(repairRequestId: widget.repairRequestId),
      ApiService.getPayments(repairRequestId: widget.repairRequestId),
    ]);
    if (!mounted) return;

    final quotationResult = results[0];
    final paymentResult = results[1];

    Map<String, dynamic>? quotation;
    if (quotationResult.success && quotationResult.data != null) {
      quotation = quotationResult.data!['quotation'] as Map<String, dynamic>?;
    }

    Map<String, dynamic>? payment;
    if (paymentResult.success && paymentResult.data != null) {
      payment = paymentResult.data!['payment'] as Map<String, dynamic>?;
    }

    setState(() {
      _isLoading = false;
      _quotation = quotation;
      _payment = payment;
    });
  }

  double get _totalAmount => double.tryParse(_quotation?['total_price']?.toString() ?? '0') ?? 0;

  Future<void> _pickSlip() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _slipBytes = bytes;
      _slipName = picked.name;
    });
  }

  Future<void> _submit() async {
    if (_selectedMethod != 'bank_transfer') return; // กันไว้ (ปุ่มถูกปิดอยู่แล้วสำหรับวิธีอื่น)
    if (_slipBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาแนบสลิปการโอนเงิน'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await ApiService.submitPayment(
      repairRequestId: widget.repairRequestId,
      customerId: widget.customerId,
      garageId: widget.garageId,
      amount: _totalAmount,
      method: _selectedMethod,
      slipBytes: _slipBytes!,
      slipName: _slipName ?? 'slip.jpg',
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message), backgroundColor: result.success ? Colors.green : Colors.red),
    );

    if (result.success) _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: const Text('ชำระเงิน', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildBody(),
    );
  }

  Widget _buildBody() {
    final paymentStatus = _payment?['status']?.toString();

    if (paymentStatus == 'confirmed') return _confirmedView();
    if (paymentStatus == 'pending_confirmation') return _pendingView();

    // ไม่มีรายการชำระเงิน หรือถูกปฏิเสธ (rejected) → โชว์ฟอร์มให้กรอก/แนบใหม่
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (paymentStatus == 'rejected') ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xffFFEBEE), borderRadius: BorderRadius.circular(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: Color(0xffE53935), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('อู่ปฏิเสธสลิปที่แนบมา',
                          style: TextStyle(color: Color(0xffE53935), fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(_payment?['rejection_reason']?.toString() ?? '-',
                          style: const TextStyle(color: Color(0xffE53935), fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        _amountCard(),
        const SizedBox(height: 20),
        const Text('เลือกวิธีการชำระเงิน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
        _methodOption(
          value: 'bank_transfer',
          icon: Icons.account_balance,
          title: 'โอนเงินผ่านธนาคาร',
          subtitle: 'โอนผ่านแอปธนาคาร',
        ),
        const SizedBox(height: 10),
        _methodOption(
          value: 'qr',
          icon: Icons.qr_code,
          title: 'QR Payment',
          subtitle: 'สแกน QR Code เพื่อชำระเงิน',
        ),
        const SizedBox(height: 10),
        _methodOption(
          value: 'credit_card',
          icon: Icons.credit_card,
          title: 'บัตรเครดิต / เดบิต',
          subtitle: 'ชำระด้วยบัตรเครดิต',
        ),

        if (_selectedMethod == 'bank_transfer') ...[
          const SizedBox(height: 20),
          const Text('รายละเอียดการโอนเงิน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          _bankDetailsCard(),
          const SizedBox(height: 20),
          const Text('อัปโหลดสลิปการโอนเงิน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          _slipUploadBox(),
        ] else ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: const Row(
              children: [
                Icon(Icons.hourglass_top, color: Colors.grey, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text('ฟีเจอร์นี้จะเปิดให้บริการเร็วๆ นี้ ขณะนี้รองรับเฉพาะ "โอนเงินผ่านธนาคาร"',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xffE3F2FD), borderRadius: BorderRadius.circular(12)),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Color(0xff2196F3)),
              SizedBox(width: 8),
              Expanded(
                child: Text('กรุณาชำระเงินภายใน 24 ชั่วโมง หลังจากงานซ่อมเสร็จเรียบร้อย',
                    style: TextStyle(color: Color(0xff2196F3), fontSize: 12)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_selectedMethod == 'bank_transfer' && !_isSubmitting) ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff4CAF50),
              disabledBackgroundColor: Colors.grey.shade300,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            label: Text(_isSubmitting ? 'กำลังส่ง...' : 'ยืนยันการชำระเงิน',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _amountCard() {
    final items = (_quotation?['items'] is List) ? List<dynamic>.from(_quotation!['items']) : [];
    final laborCost = double.tryParse(_quotation?['labor_cost']?.toString() ?? '0') ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xff2196F3), Color(0xff1976D2)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Text('ยอดชำระทั้งหมด', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Text('฿${_totalAmount.toStringAsFixed(0)}',
              style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _showCostDetails = !_showCostDetails),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('ดูรายละเอียดค่าใช้จ่าย', style: TextStyle(color: Colors.white, fontSize: 12)),
                  Icon(_showCostDetails ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
          if (_showCostDetails) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...items.map((it) => _costRow(
                      '${it['name']} x${it['quantity'] ?? 1}',
                      double.tryParse(it['price']?.toString() ?? '0') ?? 0)),
                  if (laborCost > 0) _costRow('ค่าแรง', laborCost),
                  const Divider(height: 16),
                  _costRow('รวมทั้งหมด', _totalAmount, bold: true),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _costRow(String label, double amount, {bool bold = false}) {
    final style = TextStyle(
      fontSize: 13,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: bold ? Colors.black : Colors.black87,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text('฿${amount.toStringAsFixed(0)}', style: style),
        ],
      ),
    );
  }

  Widget _methodOption({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _selectedMethod == value;
    return InkWell(
      onTap: () => setState(() => _selectedMethod = value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xffE3F2FD) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? const Color(0xff2196F3) : Colors.grey.shade200, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: const Color(0xff2196F3), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? const Color(0xff2196F3) : Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _bankDetailsCard() {
    final hasBankDetails = (widget.bankAccountNumber ?? '').isNotEmpty;

    if (!hasBankDetails) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xffFFF3E0), borderRadius: BorderRadius.circular(14)),
        child: const Text('อู่ยังไม่ได้ตั้งค่าบัญชีธนาคารสำหรับรับชำระเงิน กรุณาติดต่ออู่โดยตรง',
            style: TextStyle(color: Color(0xffE65100), fontSize: 13)),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          _bankRow('ธนาคาร', widget.bankName ?? '-'),
          const Divider(height: 20),
          _bankRow('เลขที่บัญชี', widget.bankAccountNumber ?? '-', copyable: true),
          const Divider(height: 20),
          _bankRow('ชื่อบัญชี', widget.bankAccountName ?? widget.shopName),
        ],
      ),
    );
  }

  Widget _bankRow(String label, String value, {bool copyable = false}) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14, color: copyable ? const Color(0xff2196F3) : Colors.black)),
        if (copyable) ...[
          const SizedBox(width: 6),
          InkWell(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('คัดลอกเลขบัญชีแล้ว'), duration: Duration(seconds: 1)),
              );
            },
            child: const Icon(Icons.copy, size: 16, color: Color(0xff2196F3)),
          ),
        ],
      ],
    );
  }

  Widget _slipUploadBox() {
    return InkWell(
      onTap: _pickSlip,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: _slipBytes == null
            ? Column(
                children: [
                  Icon(Icons.image_outlined, size: 36, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  const Text('แตะเพื่ออัปโหลดสลิป', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('รองรับไฟล์ JPG, PNG', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                ],
              )
            : Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(_slipBytes!, height: 160, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _pickSlip,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('เปลี่ยนรูป'),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _pendingView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _amountCard(),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              const Icon(Icons.hourglass_top, size: 48, color: Color(0xffFF9800)),
              const SizedBox(height: 12),
              const Text('รอการตรวจสอบจากอู่', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text('อู่ ${widget.shopName} กำลังตรวจสอบสลิปการโอนเงินของคุณ',
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              if (_payment?['slip_photo'] != null) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(_payment!['slip_photo'].toString(), height: 160, fit: BoxFit.contain),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _confirmedView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _amountCard(),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              const Icon(Icons.check_circle, size: 48, color: Color(0xff4CAF50)),
              const SizedBox(height: 12),
              const Text('ชำระเงินเรียบร้อยแล้ว', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              const Text('ตอนนี้คุณให้คะแนนอู่ได้แล้วที่หน้าประวัติคำขอซ่อม',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}