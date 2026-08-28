// ============================================================
// 📄 ไฟล์: quotation_card.dart
// 📌 หน้า/ฟีเจอร์: การ์ด "ใบเสนอราคา" — แสดงในหน้า "ประวัติคำขอซ่อม" (my_repair_requests_page.dart)
//     ของฝั่งลูกค้า ใช้ดูรายละเอียดใบเสนอราคาจากอู่ พร้อมปุ่มยืนยัน/ปฏิเสธ
// 📝 คำอธิบาย: ดึงข้อมูลใบเสนอราคาตาม repairRequestId, แสดงรายการอะไหล่ + ค่าแรง
//     + ยอดรวม และให้ลูกค้ากดยืนยันหรือปฏิเสธ (พร้อมเลือก/กรอกเหตุผล) ได้
// ============================================================

import 'package:flutter/material.dart';
import 'api_service.dart';
import 'app_locale.dart';

const List<String> kQuoteRejectionReasons = [
  'ราคาสูงเกินไป',
  'ระยะเวลาซ่อมนานเกินไป',
  'อยากเปรียบเทียบราคากับอู่อื่นก่อน',
  'เปลี่ยนใจ ไม่ต้องการซ่อมแล้ว',
  'ไม่แน่ใจในรายการอะไหล่ที่เสนอมา',
];

// ✅ ค่า kQuoteRejectionReasons ยังคงเป็นภาษาไทยเสมอ (ส่งตรงไปเป็น reason ให้ API) —
// ใช้ตัวนี้แค่ตอนแสดงผลใน Text widget เท่านั้น
String _quoteRejectionReasonDisplayLabel(String reason) {
  const map = {
    'ราคาสูงเกินไป': 'qc_reason_price_high',
    'ระยะเวลาซ่อมนานเกินไป': 'qc_reason_duration_long',
    'อยากเปรียบเทียบราคากับอู่อื่นก่อน': 'qc_reason_compare_price',
    'เปลี่ยนใจ ไม่ต้องการซ่อมแล้ว': 'qc_reason_changed_mind',
    'ไม่แน่ใจในรายการอะไหล่ที่เสนอมา': 'qc_reason_unsure_parts',
  };
  final key = map[reason];
  return key != null ? AppLocale.instance.t(key) : reason;
}

/// การ์ดแสดงใบเสนอราคา พร้อมปุ่มยืนยัน/ปฏิเสธ (ใช้ในหน้าประวัติคำขอซ่อมของลูกค้า)
class QuotationCard extends StatefulWidget {
  final int repairRequestId;
  final int customerId; // ✅ ให้ backend เช็คว่าลูกค้าที่ตอบเป็นเจ้าของคำขอซ่อมนี้จริง
  final VoidCallback? onResponded;

  const QuotationCard({
    super.key,
    required this.repairRequestId,
    required this.customerId,
    this.onResponded,
  });

  @override
  State<QuotationCard> createState() => _QuotationCardState();
}

class _QuotationCardState extends State<QuotationCard> {
  bool _isLoading = true;
  Map<String, dynamic>? _quotation;
  bool _isResponding = false;

  @override
  void initState() {
    super.initState();
    _fetchQuotation();
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

  Future<void> _fetchQuotation() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getQuotation(repairRequestId: widget.repairRequestId);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _quotation = result.success ? (result.data?['quotation'] as Map<String, dynamic>?) : null;
    });
  }

  Future<void> _respond(String status, {String? reason}) async {
    if (_quotation == null) return;
    setState(() => _isResponding = true);

    final result = await ApiService.respondToQuotation(
      quotationId: _quotation!['id'],
      customerId: widget.customerId,
      status: status,
      reason: reason,
    );

    if (!mounted) return;
    setState(() => _isResponding = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message), backgroundColor: result.success ? Colors.green : Colors.red),
    );

    if (result.success) {
      _fetchQuotation();
      widget.onResponded?.call();
    }
  }

  Future<void> _handleReject() async {
    String? selectedReason;
    final customController = TextEditingController();

    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocale.instance.t('qc_reject_sheet_title'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...kQuoteRejectionReasons.map((r) {
                final selected = selectedReason == r;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => setSheetState(() {
                      selectedReason = selected ? null : r;
                      customController.clear();
                    }),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xffFFEBEE) : const Color(0xffF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? Colors.red : Colors.transparent),
                      ),
                      child: Row(
                        children: [
                          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                              size: 18, color: selected ? Colors.red : Colors.grey),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_quoteRejectionReasonDisplayLabel(r), style: const TextStyle(fontSize: 13))),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 4),
              TextField(
                controller: customController,
                onChanged: (_) => setSheetState(() => selectedReason = null),
                decoration: InputDecoration(
                  hintText: AppLocale.instance.t('qc_custom_reason_hint'),
                  filled: true,
                  fillColor: const Color(0xffF5F5F5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final finalReason = customController.text.trim().isNotEmpty
                        ? customController.text.trim()
                        : selectedReason;
                    if (finalReason == null) return;
                    Navigator.pop(context, finalReason);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(AppLocale.instance.t('qc_confirm_reject_button'), style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // ✅ เดิม customController ไม่ถูก dispose เลย (leak) — แต่ dispose ทันทีตรงนี้จะ
    // ชนบั๊กเดียวกับที่เคยแก้ใน editprofile_shop_page.dart (TextField ในชีทยังไม่ถูก
    // unmount จริงจนกว่า animation ปิดชีทจะเล่นจบ ทำให้ "used after being disposed"
    // ได้) — หน่วงเวลาสั้นๆ ให้ animation จบก่อนค่อย dispose ปลอดภัยกว่า
    Future.delayed(const Duration(milliseconds: 300), customController.dispose);

    if (reason != null) _respond('rejected', reason: reason);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_quotation == null) return const SizedBox.shrink();

    final loc = AppLocale.instance;
    final items = (_quotation!['items'] is List) ? List<dynamic>.from(_quotation!['items']) : [];
    final status = _quotation!['status']?.toString() ?? 'pending';
    final laborCost = double.tryParse(_quotation!['labor_cost']?.toString() ?? '0') ?? 0;
    final startDate = _quotation!['estimated_start_date']?.toString();
    final endDate = _quotation!['estimated_end_date']?.toString();
    final notes = _quotation!['notes']?.toString() ?? '';

    // ✅ ราคาต่อรายการต้องคูณจำนวน (quantity) เสมอ — ของเดิมบวกแค่ 'price' เฉยๆ
    // ทำให้รายการที่ quantity > 1 คิดเงินขาดไป ไม่ตรงกับยอดที่ customer_payment_page.dart
    // ใช้เรียกเก็บเงินจริงจากลูกค้า (แก้ไปพร้อมกันทั้งสองที่ให้คิดแบบเดียวกัน)
    double itemSubtotal(dynamic it) =>
        (double.tryParse(it['price']?.toString() ?? '0') ?? 0) *
        (double.tryParse(it['quantity']?.toString() ?? '1') ?? 1);

    // ยอดรวมค่าอะไหล่ (รวมจากราคา x จำนวนต่อรายการที่ backend ส่งมา)
    final partsCost = items.fold<double>(0, (sum, it) => sum + itemSubtotal(it));

    // ✅ คำนวณภาษีมูลค่าเพิ่ม 7% "บวกเพิ่มจริง" บนยอดค่าอะไหล่+ค่าแรง แล้วคำนวณ
    // ยอดรวมสุทธิเองจากตรงนี้เสมอ (ไม่ใช้ total_price ที่ backend เก็บไว้โดยตรง)
    // เพราะของเดิม backend เก็บ total_price = ค่าอะไหล่+ค่าแรง โดยไม่ได้บวก VAT
    // เพิ่มเลย โค้ดเก่าเลยแค่ "ผ่า" ยอดเดิมออกเป็นก่อนภาษี/ภาษีโดยที่ยอดสุทธิไม่ขยับ
    // (เช่น 1100 ผ่าเป็น 1028.04 + 71.96 = 1100 เท่าเดิม) ทำให้ลูกค้าเข้าใจผิดว่ามี
    // VAT ทั้งที่จ่ายเท่าเดิม — ตอนนี้คิดจาก partsCost+laborCost ตรงๆ ให้ตรงกับที่
    // customer_payment_page.dart ใช้เรียกเก็บเงินจริง
    const vatRate = 0.07;
    final subTotal = partsCost + laborCost;
    final vatAmount = subTotal * vatRate;
    final totalPrice = subTotal + vatAmount;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- หัวการ์ด ----------
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xffE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_long, size: 16, color: Color(0xff2196F3)),
              ),
              const SizedBox(width: 8),
              Text(loc.t('rrd_quotation_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              if (status != 'pending') _statusBadge(status),
            ],
          ),

          const SizedBox(height: 12),

          // ---------- รายการอะไหล่ ----------
          if (items.isNotEmpty) ...[
            Text(loc.t('qc_parts_list_title'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 6),
            ...items.map((it) => _lineItemCard(
                  title: '${it['name']}',
                  subtitle: loc.t('qc_qty_prefix').replaceAll('%s', '${it['quantity']}${(it['unit'] ?? '').toString().isNotEmpty ? ' ${it['unit']}' : ''}'),
                  price: itemSubtotal(it),
                )),
            _subtotalRow(loc.t('qc_parts_subtotal_label'), partsCost),
            const SizedBox(height: 10),
          ],

          // ---------- ค่าแรง ----------
          if (laborCost > 0) ...[
            Text(loc.t('gjd_labor_cost'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 6),
            _lineItemCard(title: loc.t('qc_labor_total_label'), subtitle: null, price: laborCost),
            const SizedBox(height: 10),
          ],

          // ---------- ยอดรวมสุทธิ ----------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xff2196F3), Color(0xff1976D2)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (vatAmount > 0) ...[
                  _summaryRow(loc.t('qc_price_before_vat'), totalPrice - vatAmount),
                  _summaryRow(loc.t('common_vat_7'), vatAmount),
                  const Divider(color: Colors.white38, height: 16),
                ],
                _summaryRow(loc.t('common_grand_total'), totalPrice, big: true),
              ],
            ),
          ),

          // ---------- ระยะเวลาซ่อม ----------
          if (startDate != null || endDate != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(loc.t('qc_repair_duration_prefix').replaceAll('%start', '$startDate').replaceAll('%end', '$endDate'),
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ],
            ),
          ],

          // ---------- หมายเหตุจากอู่ ----------
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xffFFF8E1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xffF9A825)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(loc.t('qc_notes_prefix').replaceAll('%s', notes),
                        style: const TextStyle(fontSize: 12, color: Color(0xff8D6E00))),
                  ),
                ],
              ),
            ),
          ],

          // ---------- เหตุผลที่ลูกค้าปฏิเสธ (ถ้ามี) ----------
          if (status == 'rejected' && (_quotation!['customer_rejection_reason']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xffFFEBEE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.cancel_outlined, size: 16, color: Color(0xffE53935)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(loc.t('grd_rejection_reason_prefix').replaceAll('%s', '${_quotation!['customer_rejection_reason']}'),
                        style: const TextStyle(fontSize: 12, color: Color(0xffE53935))),
                  ),
                ],
              ),
            ),
          ],

          // ---------- ปุ่มยืนยัน/ปฏิเสธ ----------
          if (status == 'pending') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isResponding ? null : _handleReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.close, size: 16),
                    label: Text(loc.t('garage_reject')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isResponding ? null : () => _respond('confirmed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff43A047),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isResponding
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check, size: 16, color: Colors.white),
                    label: Text(_isResponding ? '' : loc.t('qc_accept_quotation_button'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------- ชิ้นส่วน UI ย่อยที่ใช้ซ้ำ ----------

  Widget _statusBadge(String status) {
    final confirmed = status == 'confirmed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: confirmed ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        confirmed ? AppLocale.instance.t('qc_status_confirmed') : AppLocale.instance.t('qc_status_rejected'),
        style: TextStyle(
          fontSize: 11,
          color: confirmed ? Colors.green.shade800 : Colors.red.shade800,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _lineItemCard({required String title, String? subtitle, required double price}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xffF7F8FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ],
            ),
          ),
          Text('฿${price.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xff2196F3))),
        ],
      ),
    );
  }

  Widget _subtotalRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
          Text('฿${value.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool big = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: big ? 15 : 12,
                  fontWeight: big ? FontWeight.bold : FontWeight.normal)),
          Text(
            '฿${value.toStringAsFixed(big ? 0 : 2)}',
            style: TextStyle(
              color: Colors.white,
              fontWeight: big ? FontWeight.bold : FontWeight.normal,
              fontSize: big ? 19 : 12,
            ),
          ),
        ],
      ),
    );
  }
}