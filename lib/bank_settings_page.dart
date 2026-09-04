// ============================================================
// 📄 ไฟล์: bank_settings_page.dart
// 📌 หน้า/ฟีเจอร์: ให้อู่ตั้งค่าบัญชีธนาคารสำหรับรับชำระเงินจากลูกค้า
//     (ใช้แสดงในหน้า customer_payment_page.dart ของฝั่งลูกค้า)
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
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

  // ✅ ใหม่ — เก็บ "ฉบับร่าง" ของสิ่งที่พิมพ์ไว้ในเครื่องนี้ (SharedPreferences) แยกเป็นราย
  // อู่ (ผูกกับ userId) ให้ข้อความที่พิมพ์ไม่หายแม้ยังไม่ได้กดบันทึก/ออกจากหน้านี้ไปก่อน/
  // ปิดแอปไปกลางคัน — พอกดบันทึกสำเร็จแล้วจะล้างฉบับร่างทิ้ง (ให้ข้อมูลจริงจาก backend
  // เป็นเจ้าของค่าต่อจากนั้น) ทุกช่องยังพิมพ์แก้ไขได้ตามปกติเสมอ ไม่มีการล็อกใดๆ
  String get _draftKey => 'bank_settings_draft_${widget.userData['id']}';

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

    // ✅ ทุกครั้งที่ข้อความในช่องไหนเปลี่ยน (พิมพ์เอง หรือเลือกธนาคารจาก dropdown) ให้บันทึก
    // ฉบับร่างลงเครื่องทันที กันข้อความหายถ้าออกจากหน้านี้/ปิดแอปไปก่อนจะกดบันทึกจริง
    _bankNameController.addListener(_saveDraft);
    _accountNumberController.addListener(_saveDraft);
    _accountNameController.addListener(_saveDraft);
    _promptPayController.addListener(_saveDraft);

    // ✅ โหลดฉบับร่างที่เคยพิมพ์ค้างไว้ในเครื่องนี้ก่อน (ถ้ามี — ถือเป็นสิ่งล่าสุดที่ผู้ใช้
    // ตั้งใจจะกรอก) แล้วค่อยดึงข้อมูลจาก backend มาเติมเฉพาะช่องที่ยังว่างอยู่อีกที
    _loadDraft().then((_) => _refreshFromServer());
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null || raw.isEmpty) return;
      final draft = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (!mounted) return;
      setState(() {
        final bankName = draft['bank_name']?.toString() ?? '';
        if (bankName.isNotEmpty) _bankNameController.text = bankName;
        final accNum = draft['bank_account_number']?.toString() ?? '';
        if (accNum.isNotEmpty) _accountNumberController.text = accNum;
        final accName = draft['bank_account_name']?.toString() ?? '';
        if (accName.isNotEmpty) _accountNameController.text = accName;
        final promptpay = draft['promptpay_id']?.toString() ?? '';
        if (promptpay.isNotEmpty) _promptPayController.text = promptpay;
      });
    } catch (e) {
      // ✅ อ่านฉบับร่างไม่สำเร็จก็แค่ข้าม ไม่ต้องกวนผู้ใช้ (ยังใช้ค่าจาก userData/backend ตามปกติ)
    }
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _draftKey,
        jsonEncode({
          'bank_name': _bankNameController.text,
          'bank_account_number': _accountNumberController.text,
          'bank_account_name': _accountNameController.text,
          'promptpay_id': _promptPayController.text,
        }),
      );
    } catch (e) {
      // เงียบๆ พอ — บันทึกฉบับร่างไม่ได้ไม่ใช่เรื่องคอขวด แค่เสียความสะดวกเล็กน้อย
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (e) {
      // เงียบๆ พอ
    }
  }

  Future<void> _refreshFromServer() async {
    final result = await ApiService.getProfile(
      userId: widget.userData['id'],
      userType: 'repair',
    );
    if (!mounted || !result.success || result.data == null) return;

    final fresh = Map<String, dynamic>.from(result.data!['user'] ?? {});

    void fillIfEmpty(TextEditingController controller, String key) {
      if (controller.text.trim().isNotEmpty) return; // ผู้ใช้เห็น/พิมพ์อะไรอยู่แล้ว ไม่ทับ
      final value = fresh[key]?.toString();
      if (value != null && value.isNotEmpty) {
        controller.text = value;
      }
    }

    setState(() {
      fillIfEmpty(_bankNameController, 'bank_name');
      fillIfEmpty(_accountNumberController, 'bank_account_number');
      fillIfEmpty(_accountNameController, 'bank_account_name');
      fillIfEmpty(_promptPayController, 'promptpay_id');
    });
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

    if (result.success) {
      // ✅ บันทึกขึ้น backend สำเร็จแล้ว ไม่ต้องเก็บฉบับร่างในเครื่องต่อ (backend คือเจ้าของ
      // ค่าตัวจริงแล้ว กันฉบับร่างเก่าค้างมาทับข้อมูลใหม่ที่อาจแก้จากที่อื่นในอนาคต)
      await _clearDraft();
      if (!mounted) return;
      Navigator.pop(context, true);
    }
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

          const SizedBox(height: 20),

          Text(loc.t('bsp_bank_label'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: DropdownButtonFormField<String>(
              // ✅ แก้บั๊ก: เดิมไม่ใส่ isExpanded ทำให้ Row ภายใน dropdown (ข้อความ +
              // ไอคอนลูกศร) กว้างเกินพื้นที่ที่มีไปเล็กน้อย เกิด "RIGHT OVERFLOWED BY
              // X PIXELS" ที่ขอบขวา — ใส่ isExpanded: true ให้ dropdown ยืดเต็มความกว้าง
              // ที่มี ข้อความยาวเกินจะตัดด้วย ... แทนการล้นจอ
              isExpanded: true,
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