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

/// หน่วยนับสำหรับรายการอะไหล่/งาน
const List<String> kPartUnits = ['ชิ้น', 'ลิตร', 'ขวด', 'เมตร', 'ชุด', 'ครั้ง', 'อัน'];

/// หน่วยเวลาสำหรับรายการค่าแรง
const List<String> kLaborTimeUnits = ['ชั่วโมง', 'นาที', 'วัน', 'ครั้ง'];

class _QuoteItem {
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;
  String unit;

  _QuoteItem({this.unit = 'ชิ้น'})
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

class _LaborItem {
  final TextEditingController nameCtrl;
  final TextEditingController timeCtrl;
  final TextEditingController priceCtrl;
  String timeUnit;

  _LaborItem({this.timeUnit = 'ชั่วโมง'})
      : nameCtrl = TextEditingController(),
        timeCtrl = TextEditingController(text: '1'),
        priceCtrl = TextEditingController();

  void dispose() {
    nameCtrl.dispose();
    timeCtrl.dispose();
    priceCtrl.dispose();
  }

  double get subtotal => double.tryParse(priceCtrl.text) ?? 0;
}

class _CreateQuotationPageState extends State<CreateQuotationPage> {
  final List<_QuoteItem> _items = [_QuoteItem()];
  final List<_LaborItem> _laborItems = [_LaborItem()];
  final _notesController = TextEditingController();

  static const double _vatRate = 0.07;

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    for (final item in _laborItems) {
      item.dispose();
    }
    _notesController.dispose();
    super.dispose();
  }

  double get _partsCost => _items.fold(0, (sum, item) => sum + item.subtotal);
  double get _laborCost => _laborItems.fold(0, (sum, item) => sum + item.subtotal);
  double get _subTotal => _partsCost + _laborCost;
  double get _vatAmount => _subTotal * _vatRate;
  double get _totalPrice => _subTotal + _vatAmount;

  void _addItem() => setState(() => _items.add(_QuoteItem()));

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  void _addLaborItem() => setState(() => _laborItems.add(_LaborItem()));

  void _removeLaborItem(int index) {
    setState(() {
      _laborItems[index].dispose();
      _laborItems.removeAt(index);
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
              'unit': i.unit,
              'price': double.tryParse(i.priceCtrl.text) ?? 0,
            })
        .toList();

    // รวมรายการค่าแรงทั้งหมดเป็นยอดเดียว เพื่อให้เข้ากับ ApiService.createQuotation เดิม
    // (แต่ละรายการค่าแรงจะถูกรวมชื่อ+เวลาไว้ในหมายเหตุด้านล่างให้อู่/ลูกค้าเห็นรายละเอียด)
    final validLaborItems = _laborItems
        .where((i) => i.nameCtrl.text.trim().isNotEmpty || i.subtotal > 0)
        .toList();

    if (validItems.isEmpty && _laborCost == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกรายการอะไหล่หรือค่าแรงอย่างน้อย 1 รายการ'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final laborBreakdown = validLaborItems
        .where((i) => i.nameCtrl.text.trim().isNotEmpty)
        .map((i) => '${i.nameCtrl.text.trim()} (${i.timeCtrl.text} ${i.timeUnit})')
        .join(', ');
    final notesText = _notesController.text.trim();
    final combinedNotes = [
      if (laborBreakdown.isNotEmpty) 'รายการค่าแรง: $laborBreakdown',
      if (notesText.isNotEmpty) notesText,
    ].join('\n');

    final result = await ApiService.createQuotation(
      repairRequestId: widget.repairRequestId,
      items: validItems,
      laborCost: _laborCost,
      estimatedStartDate: _isoDate(_startDate),
      estimatedEndDate: _isoDate(_endDate),
      notes: combinedNotes,
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
      backgroundColor: const Color(0xffF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: const Text('สร้างใบเสนอราคา',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ข้อมูลลูกค้า
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xffE3F2FD),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.person, color: Color(0xff2196F3), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ข้อมูลลูกค้า',
                                  style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(widget.customerName,
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // รายการอะไหล่
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('รายการอะไหล่',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        _addButton('เพิ่มอะไหล่', _addItem),
                      ],
                    ),
                    const SizedBox(height: 10),

                    ...List.generate(_items.length, (index) {
                      final item = _items[index];
                      return _sectionCard(
                        onDelete: _items.length > 1 ? () => _removeItem(index) : null,
                        children: [
                          TextField(
                            controller: item.nameCtrl,
                            decoration: _fieldDecoration('ชื่อรายการ'),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _labeledField(
                                  label: 'จำนวน',
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: item.qtyCtrl,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(decimal: true),
                                          onChanged: (_) => setState(() {}),
                                          decoration: _fieldDecoration(null, dense: true),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      _unitDropdown(
                                        value: item.unit,
                                        options: kPartUnits,
                                        onChanged: (v) => setState(() => item.unit = v!),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: _labeledField(
                                  label: 'ราคา/หน่วย',
                                  child: TextField(
                                    controller: item.priceCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(decimal: true),
                                    onChanged: (_) => setState(() {}),
                                    decoration: _fieldDecoration('฿0', dense: true),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _subtotalRow(item.subtotal),
                        ],
                      );
                    }),

                    _totalPill('รวมค่าอะไหล่', _partsCost),

                    const SizedBox(height: 20),

                    // ค่าแรง
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ค่าแรง',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        _addButton('เพิ่มค่าแรง', _addLaborItem),
                      ],
                    ),
                    const SizedBox(height: 10),

                    ...List.generate(_laborItems.length, (index) {
                      final labor = _laborItems[index];
                      return _sectionCard(
                        onDelete: _laborItems.length > 1 ? () => _removeLaborItem(index) : null,
                        children: [
                          TextField(
                            controller: labor.nameCtrl,
                            decoration: _fieldDecoration('ชื่องาน'),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _labeledField(
                                  label: 'เวลา',
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: labor.timeCtrl,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(decimal: true),
                                          decoration: _fieldDecoration(null, dense: true),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      _unitDropdown(
                                        value: labor.timeUnit,
                                        options: kLaborTimeUnits,
                                        onChanged: (v) => setState(() => labor.timeUnit = v!),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: _labeledField(
                                  label: 'ค่าแรง',
                                  child: TextField(
                                    controller: labor.priceCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(decimal: true),
                                    onChanged: (_) => setState(() {}),
                                    decoration: _fieldDecoration('฿0', dense: true),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _subtotalRow(labor.subtotal),
                        ],
                      );
                    }),

                    _totalPill('รวมค่าแรง', _laborCost),

                    const SizedBox(height: 20),
                    const Text('ระยะเวลาซ่อมโดยประมาณ',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _dateButton(
                            label: _fmtDate(_startDate),
                            onTap: () => _pickDate(isStart: true),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('ถึง', style: TextStyle(color: Colors.grey)),
                        ),
                        Expanded(
                          child: _dateButton(
                            label: _fmtDate(_endDate),
                            onTap: () => _pickDate(isStart: false),
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // สรุปยอดรวม
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xff2196F3), Color(0xff1976D2)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('สรุปยอดรวม',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          const SizedBox(height: 10),
                          _summaryRow('ค่าอะไหล่', _partsCost),
                          _summaryRow('ค่าแรง', _laborCost),
                          _summaryRow('ภาษีมูลค่าเพิ่ม 7%', _vatAmount),
                          const Divider(color: Colors.white38, height: 20),
                          _summaryRow('ยอดรวมสุทธิ', _totalPrice, big: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
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

  // ---------- reusable pieces ----------

  Widget _addButton(String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: const Color(0xffE3F2FD),
        foregroundColor: const Color(0xff2196F3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      icon: const Icon(Icons.add_circle, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  Widget _sectionCard({required List<Widget> children, VoidCallback? onDelete}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onDelete != null)
            Align(
              alignment: Alignment.topRight,
              child: InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                ),
              ),
            ),
          ...children,
        ],
      ),
    );
  }

  Widget _labeledField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  InputDecoration _fieldDecoration(String? hint, {bool dense = false}) {
    return InputDecoration(
      hintText: hint,
      isDense: dense,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: const Color(0xffF5F5F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _unitDropdown({
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xffF5F5F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          items: options
              .map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13))))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _subtotalRow(double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('รวม', style: TextStyle(fontSize: 12, color: Colors.grey)),
        Text('฿${value.toStringAsFixed(0)}',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xff2196F3))),
      ],
    );
  }

  Widget _totalPill(String label, double value) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xffF0F4F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text('฿${value.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xff2196F3))),
        ],
      ),
    );
  }

  Widget _dateButton({required String label, required VoidCallback onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black87,
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xffE0E0E0)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.calendar_today, size: 15, color: Colors.grey),
      label: Text(label, style: const TextStyle(fontSize: 13)),
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
                  fontSize: big ? 15 : 13,
                  fontWeight: big ? FontWeight.bold : FontWeight.normal)),
          Text(
            '฿${value.toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.white,
              fontWeight: big ? FontWeight.bold : FontWeight.normal,
              fontSize: big ? 20 : 13,
            ),
          ),
        ],
      ),
    );
  }
}