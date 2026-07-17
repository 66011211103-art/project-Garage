import 'package:flutter/material.dart';
import 'api_service.dart';

const List<String> kQuoteRejectionReasons = [
  'ราคาสูงเกินไป',
  'ระยะเวลาซ่อมนานเกินไป',
  'อยากเปรียบเทียบราคากับอู่อื่นก่อน',
  'เปลี่ยนใจ ไม่ต้องการซ่อมแล้ว',
  'ไม่แน่ใจในรายการอะไหล่ที่เสนอมา',
];

/// การ์ดแสดงใบเสนอราคา พร้อมปุ่มยืนยัน/ปฏิเสธ (ใช้ในหน้าประวัติคำขอซ่อมของลูกค้า)
class QuotationCard extends StatefulWidget {
  final int repairRequestId;
  final VoidCallback? onResponded;

  const QuotationCard({super.key, required this.repairRequestId, this.onResponded});

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
              const Text('ปฏิเสธใบเสนอราคา',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                          Expanded(child: Text(r, style: const TextStyle(fontSize: 13))),
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
                  hintText: 'หรือพิมพ์เหตุผลเอง',
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
                  child: const Text('ยืนยันการปฏิเสธ', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

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

    final items = (_quotation!['items'] is List) ? List<dynamic>.from(_quotation!['items']) : [];
    final status = _quotation!['status']?.toString() ?? 'pending';
    final totalPrice = double.tryParse(_quotation!['total_price']?.toString() ?? '0') ?? 0;
    final startDate = _quotation!['estimated_start_date']?.toString();
    final endDate = _quotation!['estimated_end_date']?.toString();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xffE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xff2196F3).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, size: 18, color: Color(0xff2196F3)),
              const SizedBox(width: 6),
              const Text('ใบเสนอราคา', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (status != 'pending')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: status == 'confirmed' ? Colors.green.shade100 : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status == 'confirmed' ? 'ยืนยันแล้ว' : 'ปฏิเสธแล้ว',
                    style: TextStyle(
                      fontSize: 11,
                      color: status == 'confirmed' ? Colors.green.shade800 : Colors.red.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((it) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('${it['name']} x${it['quantity']}', style: const TextStyle(fontSize: 13)),
                    ),
                    Text('${it['price']} บาท', style: const TextStyle(fontSize: 13)),
                  ],
                ),
              )),
          if ((double.tryParse(_quotation!['labor_cost']?.toString() ?? '0') ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ค่าแรง', style: TextStyle(fontSize: 13)),
                  Text('${_quotation!['labor_cost']} บาท', style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('รวมทั้งหมด', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${totalPrice.toStringAsFixed(0)} บาท',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xff2196F3))),
            ],
          ),
          if (startDate != null || endDate != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text('ระยะเวลาซ่อม: $startDate ถึง $endDate',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
          if ((_quotation!['notes']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('หมายเหตุ: ${_quotation!['notes']}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
          if (status == 'rejected' && (_quotation!['customer_rejection_reason']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('เหตุผลที่ปฏิเสธ: ${_quotation!['customer_rejection_reason']}',
                style: const TextStyle(fontSize: 12, color: Colors.red)),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isResponding ? null : _handleReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('ปฏิเสธ'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isResponding ? null : () => _respond('confirmed'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: _isResponding
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}