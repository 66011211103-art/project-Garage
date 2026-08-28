// ============================================================
// 📄 ไฟล์: customer_payment_page.dart
// 📌 หน้า/ฟีเจอร์: หน้า "ชำระเงิน" ฝั่งลูกค้า (ตาม Figma ที่ส่งมา)
// 📝 คำอธิบาย: เปิดได้เมื่องานซ่อมสถานะ "completed" แล้วเท่านั้น — ดึงยอดจริงจาก
//     ใบเสนอราคาที่ยืนยันแล้ว (คำนวณเองรวม VAT 7%) ให้เลือกวิธีชำระเงิน
//     (โอนผ่านธนาคาร / QR พร้อมเพย์ ใช้งานได้จริงทั้งคู่ / บัตรเครดิต เป็น "เร็วๆ นี้")
//     แนบสลิปแล้วส่งให้อู่ตรวจสอบ มี 3 สถานะการแสดงผล:
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
import 'promptpay_qr.dart'; // ✅ ตัวสร้าง QR พร้อมเพย์จริง (EMV QR Code)
import 'network_image_helper.dart';
import 'app_locale.dart';

class CustomerPaymentPage extends StatefulWidget {
  final int repairRequestId;
  final int customerId;
  final int garageId;
  final String shopName;
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankAccountName;
  final String? promptpayId; // ✅ เบอร์/เลขบัตรพร้อมเพย์ของอู่ — ใช้สร้าง QR ให้สแกนจ่าย

  const CustomerPaymentPage({
    super.key,
    required this.repairRequestId,
    required this.customerId,
    required this.garageId,
    required this.shopName,
    this.bankName,
    this.bankAccountNumber,
    this.bankAccountName,
    this.promptpayId,
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
    AppLocale.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    AppLocale.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
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

  // ✅ คำนวณยอดที่ต้องจ่ายจริงเอง (รวม VAT 7%) แทนการอ่าน total_price ตรงๆ จาก
  // backend เพราะ backend เก็บ total_price = ค่าอะไหล่+ค่าแรง โดยไม่ได้บวก VAT
  // เข้าไปเลย ต้องคำนวณให้ตรงกับยอดที่ quotation_card.dart แสดงให้ลูกค้าดูก่อนหน้านี้
  // ✅ ราคาต่อรายการต้องคูณจำนวน (quantity) เสมอ — ของเดิมบวกแค่ 'price' เฉยๆ
  // ทำให้รายการที่ quantity > 1 (เช่น ผ้าเบรก 4 ชิ้น ชิ้นละ 500) คิดเงินขาดไป
  // และยอดที่ลูกค้าโอนจริงน้อยกว่ายอดในใบเสนอราคาที่อู่ตกลงไว้
  double _itemSubtotal(dynamic it) =>
      (double.tryParse(it['price']?.toString() ?? '0') ?? 0) *
      (double.tryParse(it['quantity']?.toString() ?? '1') ?? 1);

  double get _totalAmount {
    final items = (_quotation?['items'] is List) ? List<dynamic>.from(_quotation!['items']) : [];
    final partsCost = items.fold<double>(0, (sum, it) => sum + _itemSubtotal(it));
    final laborCost = double.tryParse(_quotation?['labor_cost']?.toString() ?? '0') ?? 0;
    final subTotal = partsCost + laborCost;
    return subTotal + (subTotal * 0.07);
  }

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
    if (_selectedMethod != 'bank_transfer' && _selectedMethod != 'qr') return; // กันไว้ (บัตรเครดิตยังปิดอยู่)
    if (_slipBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocale.instance.t('gw_slip_required')), backgroundColor: Colors.red),
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
    final loc = AppLocale.instance;
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: Text(loc.t('pc_pay_button'), style: const TextStyle(color: Colors.white)),
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
    final loc = AppLocale.instance;
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
                      Text(loc.t('pc_rejected_msg'),
                          style: const TextStyle(color: Color(0xffE53935), fontWeight: FontWeight.bold, fontSize: 13)),
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
        Text(loc.t('cpp_select_method_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
        _methodOption(
          value: 'bank_transfer',
          icon: Icons.account_balance,
          title: loc.t('php_method_bank_transfer'),
          subtitle: loc.t('cpp_bank_transfer_subtitle'),
        ),
        const SizedBox(height: 10),
        _methodOption(
          value: 'qr',
          icon: Icons.qr_code,
          title: loc.t('php_method_qr'),
          subtitle: loc.t('cpp_qr_subtitle'),
        ),
        const SizedBox(height: 10),
        _methodOption(
          value: 'credit_card',
          icon: Icons.credit_card,
          title: loc.t('cpp_credit_card_label'),
          subtitle: loc.t('cpp_credit_card_subtitle'),
        ),

        if (_selectedMethod == 'bank_transfer') ...[
          const SizedBox(height: 20),
          Text(loc.t('cpp_transfer_details_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          _bankDetailsCard(),
          const SizedBox(height: 20),
          Text(loc.t('cpp_upload_slip_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          _slipUploadBox(),
        ] else if (_selectedMethod == 'qr') ...[
          const SizedBox(height: 20),
          Text(loc.t('cpp_scan_qr_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          _qrPaymentCard(),
          const SizedBox(height: 20),
          Text(loc.t('cpp_upload_slip_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          _slipUploadBox(),
        ] else ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const Icon(Icons.hourglass_top, color: Colors.grey, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(loc.t('cpp_coming_soon_msg'),
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
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
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: Color(0xff2196F3)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(loc.t('cpp_payment_deadline_note'),
                    style: const TextStyle(color: Color(0xff2196F3), fontSize: 12)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: ((_selectedMethod == 'bank_transfer' || _selectedMethod == 'qr') && !_isSubmitting) ? _submit : null,
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
            label: Text(_isSubmitting ? loc.t('cqp_sending') : loc.t('cpp_confirm_payment_button'),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _amountCard() {
    final loc = AppLocale.instance;
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
          Text(loc.t('cpp_total_amount_label'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
                  Text(loc.t('cpp_view_cost_details'), style: const TextStyle(color: Colors.white, fontSize: 12)),
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
                      _itemSubtotal(it))),
                  if (laborCost > 0) _costRow(loc.t('gjd_labor_cost'), laborCost),
                  _costRow(loc.t('common_vat_7'),
                      (items.fold<double>(0, (sum, it) => sum + _itemSubtotal(it)) + laborCost) * 0.07),
                  const Divider(height: 16),
                  _costRow(loc.t('common_grand_total'), _totalAmount, bold: true),
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

  // ✅ สีประจำธนาคารแต่ละเจ้า (อิงจากสีแบรนด์จริง) ให้การ์ดดูมืออาชีพขึ้น
  Color _bankColor(String? bankName) {
    switch (bankName) {
      case 'ธนาคารกสิกรไทย':
        return const Color(0xff138F2D);
      case 'ธนาคารไทยพาณิชย์':
        return const Color(0xff4E2A84);
      case 'ธนาคารกรุงเทพ':
        return const Color(0xff1E4598);
      case 'ธนาคารกรุงไทย':
        return const Color(0xff1BA5E1);
      case 'ธนาคารกรุงศรีอยุธยา':
        return const Color(0xffFEC200);
      case 'ธนาคารทหารไทยธนชาต':
        return const Color(0xff1279BE);
      case 'ธนาคารออมสิน':
        return const Color(0xffEB198D);
      case 'ธนาคารเพื่อการเกษตรและสหกรณ์การเกษตร':
        return const Color(0xff4B9B1D);
      case 'ธนาคารซีไอเอ็มบีไทย':
        return const Color(0xff7E2F36);
      case 'ธนาคารยูโอบี':
        return const Color(0xff0B3979);
      default:
        return const Color(0xff2196F3);
    }
  }

  Widget _bankDetailsCard() {
    final loc = AppLocale.instance;
    final hasBankDetails = (widget.bankAccountNumber ?? '').isNotEmpty;

    if (!hasBankDetails) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xffFFF3E0), borderRadius: BorderRadius.circular(14)),
        child: Text(loc.t('cpp_no_bank_details'),
            style: const TextStyle(color: Color(0xffE65100), fontSize: 13)),
      );
    }

    final color = _bankColor(widget.bankName);

    // ✅ การ์ดสไตล์ "บัตรธนาคาร" — พื้นไล่สีตามแบรนด์ธนาคาร โชว์เลขบัญชีตัวใหญ่
    // อ่านง่าย พร้อมปุ่มคัดลอกเด่นชัด (ต่างจากเดิมที่เป็นแค่รายการข้อความล้วน)
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.75)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.account_balance, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.bankName ?? '-',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(loc.t('bsp_account_number_label'), style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.bankAccountNumber ?? '-',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
              ),
              InkWell(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: widget.bankAccountNumber ?? ''));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(loc.t('cpp_copied_account_number')), duration: const Duration(seconds: 1)),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.copy, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(loc.t('bsp_account_name_label'), style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
          const SizedBox(height: 2),
          Text(widget.bankAccountName ?? widget.shopName,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ✅ การ์ด QR พร้อมเพย์จริง — ใช้ตัวสร้าง QR จาก promptpay_qr.dart (มาตรฐาน EMV QR)
  // เข้ารหัสยอดที่ต้องจ่ายพอดีลงใน QR เลย ลูกค้าสแกนแล้วยอดขึ้นให้อัตโนมัติ
  Widget _qrPaymentCard() {
    final promptpayId = widget.promptpayId;
    if ((promptpayId ?? '').isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xffFFF3E0), borderRadius: BorderRadius.circular(14)),
        child: Text(AppLocale.instance.t('cpp_no_promptpay'),
            style: const TextStyle(color: Color(0xffE65100), fontSize: 13)),
      );
    }

    return PromptPayQrCode(
      promptPayId: promptpayId!,
      amount: _totalAmount,
      accountName: widget.bankAccountName ?? widget.shopName,
    );
  }


  Widget _slipUploadBox() {
    final loc = AppLocale.instance;
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
                  Text(loc.t('cpp_tap_to_upload_slip'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(loc.t('cpp_supported_files'), style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
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
                    label: Text(loc.t('cpp_change_image_button')),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _pendingView() {
    final loc = AppLocale.instance;
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
              Text(loc.t('cpp_pending_review_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text(loc.t('cpp_pending_review_body').replaceAll('%s', widget.shopName),
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              if (_payment?['slip_photo'] != null) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: NetImage(_payment!['slip_photo'].toString(), height: 160, fit: BoxFit.contain),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _confirmedView() {
    final loc = AppLocale.instance;
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
              Text(loc.t('cpp_payment_success_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text(loc.t('cpp_payment_success_body'),
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}