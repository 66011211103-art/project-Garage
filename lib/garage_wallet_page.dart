// ============================================================
// 📄 ไฟล์: garage_wallet_page.dart
// 📌 หน้า/ฟีเจอร์: Wallet ของอู่ — ดูยอดคงเหลือ + อัตราค่าคอมมิชชั่น,
//     เลือกชำระค่าคอมมิชชั่นที่ค้างจ่ายทีละงาน (โอนเข้าบัญชีแพลตฟอร์ม + แนบสลิป),
//     ดูประวัติการชำระค่าคอมมิชชั่นย้อนหลัง
// 📝 คำอธิบาย: เดิมหน้านี้เป็น "แจ้งเติมเงินเข้า Wallet" แบบให้อู่พิมพ์ยอดเงินเอง
//     ซึ่งเสี่ยงพิมพ์ผิด/ไม่ตรงกับยอดค้างจริง — เปลี่ยนมาให้อู่เห็นรายการค่าคอมมิชชั่น
//     ที่ยังไม่ได้จ่ายเป็นรายงาน (unpaid) ทีละงาน เลือกได้ทีละรายการหรือหลายรายการ
//     พร้อมกัน แล้วยอดที่ต้องโอนจะคำนวณจากรายการที่เลือกให้อัตโนมัติ
// ============================================================

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ Clipboard.setData ให้อู่กดคัดลอกเลขบัญชีได้
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';
import 'app_locale.dart';
import 'request_repair_page.dart' show problemCategoryDisplayLabel;

class GarageWalletPage extends StatefulWidget {
  final int garageId;
  final bool embedded;

  const GarageWalletPage({super.key, required this.garageId, this.embedded = false});

  @override
  State<GarageWalletPage> createState() => _GarageWalletPageState();
}

class _GarageWalletPageState extends State<GarageWalletPage> {
  bool _isLoading = true;
  double _walletBalance = 0;
  double _commissionRate = 0;
  List<Map<String, dynamic>> _topups = [];

  // ✅ รายการค่าคอมมิชชั่นที่ยัง "ค้างจ่าย" ทีละงาน (payment_status = 'unpaid')
  // แทนที่การให้อู่พิมพ์ยอดเติมเงินเอง — อู่เลือกได้ว่าจะจ่ายงานไหนบ้าง
  List<Map<String, dynamic>> _unpaidCommissions = [];
  final Set<int> _selectedCommissionIds = {};
  // ✅ กันเคสโหลดรายการค้างจ่ายไม่สำเร็จ (เช่น backend ยังไม่ได้รัน migration เพิ่มคอลัมน์
  // payment_status/wallet_topup_id) แล้วโค้ดเดิมจะเงียบแล้วโชว์ "ไม่มีค่าคอมค้างจ่าย" ซึ่ง
  // หลอกอู่ว่าไม่มีหนี้ทั้งที่จริงคือดึงข้อมูลพัง — ต้องแยกสถานะ error ออกจากสถานะว่างจริงๆ
  String? _unpaidLoadError;

  // ✅ บัญชีรับเงินของแพลตฟอร์ม — จุดที่ขาดหายไปเดิม (หน้านี้เคยบอกให้ "โอนเข้าบัญชี
  // แพลตฟอร์ม" แต่ไม่เคยโชว์เลขบัญชีจริงเลยสักที่ ต้อง Admin ตั้งค่าไว้ก่อนถึงจะมีข้อมูล)
  Map<String, dynamic>? _platformBankAccount;

  Uint8List? _slipBytes;
  String? _slipFileName;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchAll();
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

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    final walletResult = await ApiService.getWallet(garageId: widget.garageId);
    final unpaidResult = await ApiService.getUnpaidCommissions(garageId: widget.garageId);
    final topupsResult = await ApiService.getWalletTopups(garageId: widget.garageId);
    final bankResult = await ApiService.getPlatformBankAccount();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (walletResult.success && walletResult.data != null) {
        _walletBalance = double.tryParse(walletResult.data!['wallet_balance']?.toString() ?? '0') ?? 0;
        _commissionRate = double.tryParse(walletResult.data!['commission_rate']?.toString() ?? '0') ?? 0;
      }
      if (unpaidResult.success && unpaidResult.data != null) {
        final allUnpaid = List<Map<String, dynamic>>.from(unpaidResult.data as List);
        // ✅ ซ่อนงานที่ตั้งค่าคอมมิชชั่นเป็น 0 ออกจากรายการค้างจ่าย — เฉพาะกรณีค่าคอมเป็น
        // 0 เป๊ะเท่านั้น (งานที่มีค่าคอมแม้เพียงเล็กน้อยยังต้องแสดงและให้จ่ายตามปกติ)
        // เพราะ 0 บาทไม่มีอะไรให้อู่ต้องโอนจ่ายจริงๆ อยู่แล้ว
        _unpaidCommissions = allUnpaid.where((c) {
          final amount = double.tryParse(c['commission_amount']?.toString() ?? '0') ?? 0;
          return amount != 0;
        }).toList();
        _unpaidLoadError = null;
        // ✅ กันเลือกค้างรายการที่ไม่อยู่ในลิสต์แล้ว (เช่น จ่ายไปแล้วจากอีกเครื่อง หรือถูกกรอง
        // ออกเพราะค่าคอมเป็น 0)
        final validIds = _unpaidCommissions.map((c) => c['id'] as int).toSet();
        _selectedCommissionIds.removeWhere((id) => !validIds.contains(id));
      } else if (!unpaidResult.success) {
        // ✅ ดึงรายการค้างจ่ายไม่สำเร็จจริงๆ (ไม่ใช่แค่ไม่มีรายการ) — เก็บ error ไว้เตือน
        // แทนที่จะปล่อยให้ขึ้น "ไม่มีค่าคอมค้างจ่าย" หลอกๆ เหมือนก่อนหน้านี้
        _unpaidLoadError = unpaidResult.message.isNotEmpty
            ? unpaidResult.message
            : AppLocale.instance.t('gw_load_unpaid_failed');
      }
      if (topupsResult.success && topupsResult.data != null) {
        _topups = List<Map<String, dynamic>>.from(topupsResult.data as List);
      }
      if (bankResult.success) {
        _platformBankAccount = bankResult.data;
      }
    });
  }

  double get _selectedTotal {
    return _unpaidCommissions
        .where((c) => _selectedCommissionIds.contains(c['id'] as int))
        .fold(0.0, (sum, c) => sum + (double.tryParse(c['commission_amount']?.toString() ?? '0') ?? 0));
  }

  // ✅ ยอดค้างจ่าย "ทั้งหมด" (ไม่ใช่แค่ที่ติ๊กเลือกไว้) — เดิมหน้านี้โชว์ยอดรวมให้เห็นก็
  // ต่อเมื่อติ๊กเลือกงานแล้วเท่านั้น อู่เลยไม่มีทางเทียบเลขนี้กับ "ยอดเครดิตคงเหลือใน
  // Wallet" ด้านบนได้ง่ายๆ ว่าตรงกันไหม (สองยอดนี้ควรจะใกล้เคียงกันเสมอ เพราะทั้งคู่มา
  // จากค่าคอมที่ยังไม่ได้จ่ายเหมือนกัน) — โชว์ไว้ตลอดให้เทียบกันได้ทันทีที่เข้าหน้า
  double get _unpaidTotal {
    return _unpaidCommissions
        .fold(0.0, (sum, c) => sum + (double.tryParse(c['commission_amount']?.toString() ?? '0') ?? 0));
  }

  void _toggleCommission(int id) {
    setState(() {
      if (_selectedCommissionIds.contains(id)) {
        _selectedCommissionIds.remove(id);
      } else {
        _selectedCommissionIds.add(id);
      }
    });
  }

  void _copyToClipboard(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocale.instance.t('gw_copied_msg').replaceAll('%s', label)), duration: const Duration(seconds: 1)),
    );
  }

  Future<void> _pickSlip() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    // ✅ เดิมไม่เช็ค mounted ก่อน setState — ถ้าผู้ใช้ปิดหน้านี้ระหว่างรอเลือกรูป
    // (ImagePicker เปิดค้างนาน) จะ crash ด้วย "setState() called after dispose()"
    if (!mounted) return;
    setState(() {
      _slipBytes = bytes;
      _slipFileName = picked.name;
    });
  }

  Future<void> _submitTopup() async {
    if (_selectedCommissionIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocale.instance.t('gw_select_commission_required')), backgroundColor: Colors.red),
      );
      return;
    }
    if (_slipBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocale.instance.t('gw_slip_required')), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await ApiService.submitWalletTopup(
      garageId: widget.garageId,
      commissionTransactionIds: _selectedCommissionIds.toList(),
      slipBytes: _slipBytes,
      slipFileName: _slipFileName,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message), backgroundColor: result.success ? Colors.green : Colors.red),
    );

    if (result.success) {
      setState(() {
        _slipBytes = null;
        _slipFileName = null;
        _selectedCommissionIds.clear();
      });
      _fetchAll();
    }
  }

  String _topupStatusLabel(String? status) {
    switch (status) {
      case 'confirmed':
        return AppLocale.instance.t('qc_status_confirmed');
      case 'rejected':
        return AppLocale.instance.t('track_status_rejected');
      default:
        return AppLocale.instance.t('php_status_pending');
    }
  }

  Color _topupStatusColor(String? status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xff4CAF50);
      case 'rejected':
        return const Color(0xffE53935);
      default:
        return const Color(0xffFF9800);
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (e) {
      return '-';
    }
  }

  Widget _bankRow(String label, String value, {bool copyable = false}) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        if (copyable)
          IconButton(
            icon: const Icon(Icons.copy, size: 16, color: Color(0xff2196F3)),
            onPressed: () => _copyToClipboard(value, label),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }

  // ✅ รายการค่าคอมมิชชั่นค้างจ่ายทีละงาน — กดที่แถวหรือ checkbox เพื่อเลือก/ยกเลิกเลือก
  Widget _commissionItem(Map<String, dynamic> c) {
    final id = c['id'] as int;
    final selected = _selectedCommissionIds.contains(id);
    final grossAmount = double.tryParse(c['gross_amount']?.toString() ?? '0') ?? 0;
    final commissionAmount = double.tryParse(c['commission_amount']?.toString() ?? '0') ?? 0;
    final rate = c['commission_rate']?.toString() ?? '-';
    final loc = AppLocale.instance;
    final category = (c['problem_category']?.toString() ?? '').isNotEmpty
        ? problemCategoryDisplayLabel(c['problem_category'].toString())
        : loc.t('gw_repair_job_fallback');

    return InkWell(
      onTap: () => _toggleCommission(id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xffE3F2FD) : const Color(0xffF7F7F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? const Color(0xff2196F3) : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: (_) => _toggleCommission(id),
              activeColor: const Color(0xff2196F3),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.t('gw_job_number_prefix').replaceAll('%id', '${c['repair_request_id']}').replaceAll('%category', category),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  const SizedBox(height: 3),
                  Text(loc.t('gw_gross_amount_line').replaceAll('%amount', grossAmount.toStringAsFixed(2)).replaceAll('%rate', rate).replaceAll('%date', _formatDate(c['created_at']?.toString())),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5)),
                ],
              ),
            ),
            Text('฿${commissionAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xffE53935))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocale.instance;
    final isNegative = _walletBalance < 0;

    final body = RefreshIndicator(
      onRefresh: _fetchAll,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isNegative
                          ? [const Color(0xffE53935), const Color(0xffC62828)]
                          : [const Color(0xff2196F3), const Color(0xff1976D2)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(loc.t('gw_wallet_balance_label'),
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text('฿${_walletBalance.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(loc.t('gw_commission_rate_label').replaceAll('%s', _commissionRate.toStringAsFixed(1)),
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      if (isNegative) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(loc.t('gw_negative_credit_warning'),
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ✅ การ์ดโชว์เลขบัญชีแพลตฟอร์มจริง — ต้องเห็นก่อนโอน ไม่ใช่แค่บอกลอยๆ
                if (_platformBankAccount == null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xffFFF3E0), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xffE65100), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            loc.t('gw_no_platform_account'),
                            style: const TextStyle(color: Color(0xffE65100), fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.t('gw_transfer_to_account_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 12),
                        _bankRow(loc.t('bsp_bank_label'), _platformBankAccount!['bank_name']?.toString() ?? '-'),
                        const SizedBox(height: 8),
                        _bankRow(loc.t('bsp_account_number_label'), _platformBankAccount!['bank_account_number']?.toString() ?? '-', copyable: true),
                        const SizedBox(height: 8),
                        _bankRow(loc.t('bsp_account_name_label'), _platformBankAccount!['bank_account_name']?.toString() ?? '-'),
                        if ((_platformBankAccount!['promptpay_id']?.toString() ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _bankRow(loc.t('gw_promptpay_label'), _platformBankAccount!['promptpay_id'].toString(), copyable: true),
                        ],
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // ✅ รายการค่าคอมมิชชั่นค้างจ่ายทีละงาน + เลือกจ่าย + แนบสลิป
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.t('gw_unpaid_commissions_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(loc.t('gw_unpaid_instructions'),
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),

                      // ✅ โชว์ยอดรวมค้างจ่ายทั้งหมดไว้ตลอด (ไม่ต้องรอติ๊กเลือกก่อน) — ให้เทียบ
                      // กับ "ยอดเครดิตคงเหลือใน Wallet" ด้านบนได้ทันที เห็นความผิดปกติได้ไว
                      if (_unpaidLoadError == null && _unpaidCommissions.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: const Color(0xffFFF3E0), borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            loc.t('gw_unpaid_total_prefix').replaceAll('%s', _unpaidTotal.toStringAsFixed(2)),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xffE65100)),
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      if (_unpaidLoadError != null)
                        // ✅ แยกเคส "ดึงข้อมูลไม่สำเร็จ" ออกจาก "ไม่มีค่าคอมค้างจริงๆ" ให้ชัดเจน
                        // กันอู่เข้าใจผิดว่าไม่มีหนี้ทั้งที่ backend แค่ตอบกลับ error
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: const Color(0xffFFEBEE), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Color(0xffC62828), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(loc.t('gw_load_unpaid_failed_banner').replaceAll('%s', '$_unpaidLoadError'),
                                    style: const TextStyle(color: Color(0xffC62828), fontSize: 12.5)),
                              ),
                            ],
                          ),
                        )
                      else if (_unpaidCommissions.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(color: const Color(0xffE8F5E9), borderRadius: BorderRadius.circular(12)),
                          child: Center(
                            child: Text(loc.t('gw_no_unpaid_commissions'),
                                style: const TextStyle(color: Color(0xff2E7D32), fontWeight: FontWeight.w600)),
                          ),
                        )
                      else ...[
                        ..._unpaidCommissions.map(_commissionItem),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(color: const Color(0xffF5F5F5), borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(loc.t('gw_selected_count').replaceAll('%s', '${_selectedCommissionIds.length}'),
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                              Text(loc.t('gw_selected_total_prefix').replaceAll('%s', _selectedTotal.toStringAsFixed(2)),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xff1976D2))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: _pickSlip,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xffF5F5F5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: _slipBytes == null
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.upload_file, color: Colors.grey.shade600, size: 18),
                                      const SizedBox(width: 8),
                                      Text(loc.t('gw_attach_slip_label'), style: TextStyle(color: Colors.grey.shade600)),
                                    ],
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.memory(_slipBytes!, height: 160, fit: BoxFit.contain),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitTopup,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff2196F3),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(loc.t('gw_submit_payment_button'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                Text(loc.t('gw_history_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),

                if (_topups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Center(child: Text(loc.t('gw_history_empty'), style: const TextStyle(color: Colors.grey))),
                  )
                else
                  ..._topups.map((t) {
                    final amount = double.tryParse(t['amount']?.toString() ?? '0') ?? 0;
                    final status = t['status']?.toString();
                    final jobCount = t['job_count'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('฿${amount.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                if (jobCount != null) ...[
                                  const SizedBox(height: 2),
                                  Text(loc.t('gw_history_job_count_date').replaceAll('%count', '$jobCount').replaceAll('%date', _formatDate(t['submitted_at']?.toString())),
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                ],
                                if (status == 'rejected' && (t['rejection_reason'] ?? '').toString().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(loc.t('myreq_rejection_reason_prefix').replaceAll('%s', '${t['rejection_reason']}'),
                                      style: const TextStyle(color: Color(0xffE53935), fontSize: 12)),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _topupStatusColor(status).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(_topupStatusLabel(status),
                                style: TextStyle(color: _topupStatusColor(status), fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ],
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
        title: Text(loc.t('gw_page_title'), style: const TextStyle(color: Colors.white)),
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