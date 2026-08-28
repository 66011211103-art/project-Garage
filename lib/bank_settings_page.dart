// ============================================================
// 📄 ไฟล์: bank_settings_page.dart
// 📌 หน้า/ฟีเจอร์: ให้อู่ตั้งค่าบัญชีธนาคารสำหรับรับชำระเงินจากลูกค้า
//     (ใช้แสดงในหน้า customer_payment_page.dart ของฝั่งลูกค้า)
// ============================================================

import 'package:flutter/material.dart';
import 'api_service.dart';
import 'garage_wallet_page.dart'; // ✅ ลิงก์ไปหน้า Wallet — เตือนเรื่องค่าคอมมิชชั่นตรงนี้เลย
import 'app_locale.dart';

// ✅ ชื่อธนาคารใน _thaiBanks ยังคงเป็นภาษาไทยเสมอ (เก็บ/เทียบเป็น bank_name ที่ส่งไป
// backend) — ใช้ตัวนี้แค่ตอนแสดงผลใน dropdown เท่านั้น
String _bankDisplayLabel(String bank) {
  const map = {
    'ธนาคารกสิกรไทย': 'bsp_bank_kasikorn',
    'ธนาคารไทยพาณิชย์': 'bsp_bank_scb',
    'ธนาคารกรุงเทพ': 'bsp_bank_bangkok',
    'ธนาคารกรุงไทย': 'bsp_bank_krungthai',
    'ธนาคารกรุงศรีอยุธยา': 'bsp_bank_krungsri',
    'ธนาคารทหารไทยธนชาต': 'bsp_bank_ttb',
    'ธนาคารออมสิน': 'bsp_bank_gsb',
    'ธนาคารเพื่อการเกษตรและสหกรณ์การเกษตร': 'bsp_bank_baac',
    'ธนาคารซีไอเอ็มบีไทย': 'bsp_bank_cimb',
    'ธนาคารยูโอบี': 'bsp_bank_uob',
  };
  final key = map[bank];
  return key != null ? AppLocale.instance.t(key) : bank;
}

class BankSettingsPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const BankSettingsPage({super.key, required this.userData});

  @override
  State<BankSettingsPage> createState() => _BankSettingsPageState();
}

class _BankSettingsPageState extends State<BankSettingsPage> {
  late final TextEditingController _bankNameController;
  late final TextEditingController _accountNumberController;
  late final TextEditingController _accountNameController;
  late final TextEditingController _promptPayController; // ✅ เบอร์โทร/เลขบัตรประชาชน สำหรับ QR พร้อมเพย์
  bool _isSaving = false;

  static const List<String> _thaiBanks = [
    'ธนาคารกสิกรไทย',
    'ธนาคารไทยพาณิชย์',
    'ธนาคารกรุงเทพ',
    'ธนาคารกรุงไทย',
    'ธนาคารกรุงศรีอยุธยา',
    'ธนาคารทหารไทยธนชาต',
    'ธนาคารออมสิน',
    'ธนาคารเพื่อการเกษตรและสหกรณ์การเกษตร',
    'ธนาคารซีไอเอ็มบีไทย',
    'ธนาคารยูโอบี',
  ];

  @override
  void initState() {
    super.initState();
    _bankNameController = TextEditingController(text: widget.userData['bank_name']?.toString() ?? '');
    _accountNumberController =
        TextEditingController(text: widget.userData['bank_account_number']?.toString() ?? '');
    _accountNameController =
        TextEditingController(text: widget.userData['bank_account_name']?.toString() ?? widget.userData['shop_name']?.toString() ?? '');
    _promptPayController =
        TextEditingController(text: widget.userData['promptpay_id']?.toString() ?? '');
    AppLocale.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    _promptPayController.dispose();
    AppLocale.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (_bankNameController.text.trim().isEmpty || _accountNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocale.instance.t('bsp_validation_msg')), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);
    final result = await ApiService.updateBankDetails(
      garageId: widget.userData['id'],
      bankName: _bankNameController.text.trim(),
      bankAccountNumber: _accountNumberController.text.trim(),
      bankAccountName: _accountNameController.text.trim(),
      promptpayId: _promptPayController.text.trim().isEmpty ? null : _promptPayController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message), backgroundColor: result.success ? Colors.green : Colors.red),
    );

    if (result.success) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocale.instance;
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: Text(loc.t('bsp_page_title'), style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xffE3F2FD), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Color(0xff2196F3)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loc.t('bsp_info_banner'),
                    style: const TextStyle(color: Color(0xff2196F3), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ✅ ลิงก์ไปหน้า Wallet — หน้านี้กับ Wallet เป็นเรื่อง "การเงินของอู่" คู่กัน
          // (บัญชีนี้ = รับเงินจากลูกค้า / Wallet = จ่ายค่าคอมมิชชั่นให้แพลตฟอร์ม)
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => GarageWalletPage(garageId: widget.userData['id'])),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xffF3E5F5), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xff9C27B0), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.t('bsp_wallet_card_title'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                        Text(loc.t('bsp_wallet_card_subtitle'), style: const TextStyle(color: Colors.grey, fontSize: 11.5)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          Text(loc.t('bsp_bank_label'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: DropdownButtonFormField<String>(
              value: _thaiBanks.contains(_bankNameController.text) ? _bankNameController.text : null,
              hint: Text(loc.t('bsp_bank_hint')),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              items: _thaiBanks.map((b) => DropdownMenuItem(value: b, child: Text(_bankDisplayLabel(b)))).toList(),
              onChanged: (value) => setState(() => _bankNameController.text = value ?? ''),
            ),
          ),

          const SizedBox(height: 16),
          Text(loc.t('bsp_account_number_label'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _accountNumberController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'xxx-x-xxxxx-x',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),

          const SizedBox(height: 16),
          Text(loc.t('bsp_account_name_label'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _accountNameController,
            decoration: InputDecoration(
              hintText: loc.t('bsp_account_name_hint'),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),

          const SizedBox(height: 24),
          Row(
            children: [
              Text(loc.t('bsp_promptpay_label'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(width: 6),
              Text(loc.t('ujs_optional_label'), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _promptPayController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: loc.t('bsp_promptpay_hint'),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 6),
          Text(loc.t('bsp_promptpay_helper'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff2196F3),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(loc.t('bsp_save_button'), style: const TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}