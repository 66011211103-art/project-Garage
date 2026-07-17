import 'package:flutter/material.dart';
import 'api_service.dart';

/// หน้าสร้างใบเสนอราคา ให้อู่กรอกหลังจากกด "รับงาน" คำขอซ่อมแล้ว
class CreateQuotationPage extends StatefulWidget {
  final int repairRequestId;
  final String customerName;

  const CreateQuotationPage({
    super.key,
    required this.repairRequestId,
    required this.customerName,
  });

  @override
  State<CreateQuotationPage> createState() => _CreateQuotationPageState();
}

class _QuoteItem {
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  _QuoteItem()
      : nameCtrl = TextEditingController(),
        qtyCtrl = TextEditingController(text: '1'),
        priceCtrl = TextEditingController();

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }

  double get subtotal =>
      (double.tryParse(priceCtrl.text) ?? 0) * (double.tryParse(qtyCtrl.text) ?? 1);
}

class _CreateQuotationPageState extends State<CreateQuotationPage> {
  final List<_QuoteItem> _items = [_QuoteItem()];
  final _laborCostController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    _laborCostController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _partsCost => _items.fold(0, (sum, item) => sum + item.subtotal);
  double get _laborCost => double.tryParse(_laborCostController.text) ?? 0;
  double get _totalPrice => _partsCost + _laborCost;

  void _addItem() => setState(() => _items.add(_QuoteItem()));

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
      } else {
        _endDate = picked;
      }
    });
  }

  String _fmtDate(DateTime? d) => d == null ? 'เลือกวันที่' : '${d.day}/${d.month}/${d.year}';
  String? _isoDate(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _handleSubmit() async {
    final validItems = _items
        .where((i) => i.nameCtrl.text.trim().isNotEmpty)
        .map((i) => {
              'name': i.nameCtrl.text.trim(),
              'quantity': double.tryParse(i.qtyCtrl.text) ?? 1,
              'price': double.tryParse(i.priceCtrl.text) ?? 0,
            })
        .toList();

    if (validItems.isEmpty && _laborCost == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกรายการอะไหล่หรือค่าแรงอย่างน้อย 1 รายการ'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await ApiService.createQuotation(
      repairRequestId: widget.repairRequestId,
      items: validItems,
      laborCost: _laborCost,
      estimatedStartDate: _isoDate(_startDate),
      estimatedEndDate: _isoDate(_endDate),
      notes: _notesController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );

    if (result.success) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: const Text('สร้างใบเสนอราคา', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ลูกค้า: ${widget.customerName}',
                        style: const TextStyle(fontSize: 15, color: Colors.grey)),

                    const SizedBox(height: 20),
                    const Text('รายการอะไหล่ / งานซ่อม',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

                    ...List.generate(_items.length, (index) {
                      final item = _items[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: item.nameCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'ชื่อรายการ',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                if (_items.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _removeItem(index),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: item.qtyCtrl,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(
                                      labelText: 'จำนวน',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: item.priceCtrl,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(
                                      labelText: 'ราคาต่อหน่วย (บาท)',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),

                    TextButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add),
                      label: const Text('เพิ่มรายการ'),
                    ),

                    const SizedBox(height: 10),
                    const Text('ค่าแรง', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _laborCostController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: '0',
                        suffixText: 'บาท',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Text('ระยะเวลาซ่อมโดยประมาณ',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(isStart: true),
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(_fmtDate(_startDate)),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('ถึง'),
                        ),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(isStart: false),
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(_fmtDate(_endDate)),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const Text('หมายเหตุ (ถ้ามี)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'เช่น ต้องสั่งอะไหล่จากศูนย์ อาจใช้เวลาเพิ่ม',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xffE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _summaryRow('ค่าอะไหล่รวม', _partsCost),
                          _summaryRow('ค่าแรง', _laborCost),
                          const Divider(),
                          _summaryRow('รวมทั้งหมด', _totalPrice, bold: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))],
              ),
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff2196F3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                label: Text(
                  _isSubmitting ? 'กำลังส่ง...' : 'ส่งใบเสนอราคา',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
          Text(
            '${value.toStringAsFixed(0)} บาท',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 18 : 14,
              color: bold ? const Color(0xff2196F3) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
