import 'package:flutter/material.dart';
import 'api_service.dart';
import ' myCarPage.dart' show vehicleTypeLabel;
import 'app_locale.dart';

/// หน้าสร้างใบเสนอราคา ให้อู่กรอกหลังจากกด "รับงาน" คำขอซ่อมแล้ว
/// ✅ ใช้หน้าเดียวกันนี้ทำโหมด "แก้ไข" ได้ด้วย — ส่ง existingQuotation มา
/// (ข้อมูลใบเสนอราคาเดิมจาก ApiService.getQuotation) เพื่อพรีฟิลข้อมูลและ
/// เปลี่ยนไปเรียก ApiService.updateQuotation ตอนกดบันทึกแทนการสร้างใหม่
/// ✅ carInfo / garageServices (ไม่บังคับ) — "เชื่อมต่อ" ใบเสนอราคาเข้ากับ
/// ข้อมูลรถของลูกค้า (แสดงการ์ดข้อมูลรถ) และรายการบริการของอู่เอง
/// (เลือกจากบริการที่อู่ตั้งไว้แทนการพิมพ์ชื่อ/ราคาใหม่ทุกครั้ง)
class CreateQuotationPage extends StatefulWidget {
  final int repairRequestId;
  final String customerName;
  final Map<String, dynamic>? existingQuotation;
  final Map<String, dynamic>? carInfo;
  final List<dynamic>? garageServices;

  const CreateQuotationPage({
    super.key,
    required this.repairRequestId,
    required this.customerName,
    this.existingQuotation,
    this.carInfo,
    this.garageServices,
  });

  @override
  State<CreateQuotationPage> createState() => _CreateQuotationPageState();
}

/// หน่วยนับสำหรับรายการอะไหล่/งาน
const List<String> kPartUnits = ['ชิ้น', 'ลิตร', 'ขวด', 'เมตร', 'ชุด', 'ครั้ง', 'อัน'];

/// หน่วยเวลาสำหรับรายการค่าแรง
const List<String> kLaborTimeUnits = ['ชั่วโมง', 'นาที', 'วัน', 'ครั้ง'];

// ✅ ค่าใน kPartUnits/kLaborTimeUnits ยังคงเป็นภาษาไทยเสมอ (เก็บเป็น unit/timeUnit
// ที่ส่งไป backend และรวมอยู่ในหมายเหตุค่าแรงที่บันทึกจริง) — ใช้ตัวนี้แค่ตอนแสดงผล
// ใน dropdown เท่านั้น
String _unitDisplayLabel(String unit) {
  const map = {
    'ชิ้น': 'cqp_unit_piece',
    'ลิตร': 'cqp_unit_liter',
    'ขวด': 'cqp_unit_bottle',
    'เมตร': 'cqp_unit_meter',
    'ชุด': 'cqp_unit_set',
    'ครั้ง': 'cqp_unit_time',
    'อัน': 'cqp_unit_item',
    'ชั่วโมง': 'cqp_unit_hour',
    'นาที': 'cqp_unit_minute',
    'วัน': 'cqp_unit_day',
  };
  final key = map[unit];
  return key != null ? AppLocale.instance.t(key) : unit;
}

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

  bool get _isEditMode => widget.existingQuotation != null;

  @override
  void initState() {
    super.initState();
    AppLocale.instance.addListener(_onLocaleChanged);
    final q = widget.existingQuotation;
    if (q == null) return;

    // ✅ พรีฟิลรายการอะไหล่จากใบเสนอราคาเดิม
    final existingItems = (q['items'] is List) ? List<dynamic>.from(q['items']) : [];
    if (existingItems.isNotEmpty) {
      _items.clear();
      for (final it in existingItems) {
        final item = _QuoteItem(unit: it['unit']?.toString() ?? 'ชิ้น');
        item.nameCtrl.text = it['name']?.toString() ?? '';
        item.qtyCtrl.text = (it['quantity']?.toString() ?? '1');
        item.priceCtrl.text = (it['price']?.toString() ?? '0');
        _items.add(item);
      }
    }

    // ⚠️ ข้อมูลเดิมเก็บ "ค่าแรงรวม" เป็นยอดเดียว (ไม่ได้แยกเป็นรายการย่อยแบบตอนกรอก
    // ครั้งแรก) เลยพรีฟิลกลับมาเป็นรายการค่าแรงเดียวชื่อ "ค่าแรงรวม" — ถ้าอู่อยาก
    // แยกเป็นหลายรายการใหม่ก็แก้ชื่อ/เพิ่มรายการเองได้ตามปกติ
    final laborCost = double.tryParse(q['labor_cost']?.toString() ?? '0') ?? 0;
    if (laborCost > 0) {
      _laborItems.clear();
      final labor = _LaborItem();
      labor.nameCtrl.text = AppLocale.instance.t('qc_labor_total_label');
      labor.priceCtrl.text = laborCost.toStringAsFixed(0);
      _laborItems.add(labor);
    }

    // ✅ .toLocal() กัน backend ตอบเป็น UTC ISO ("...T00:00:00.000Z") แล้วพอ
    // แปลงกลับมาเป็นเวลาไทย (+7) วันที่เลื่อนข้ามมาอีกวันจากที่อู่เลือกไว้จริง
    _startDate = DateTime.tryParse(q['estimated_start_date']?.toString() ?? '')?.toLocal();
    _endDate = DateTime.tryParse(q['estimated_end_date']?.toString() ?? '')?.toLocal();
    _notesController.text = q['notes']?.toString() ?? '';
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    for (final item in _laborItems) {
      item.dispose();
    }
    _notesController.dispose();
    AppLocale.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
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

  String _fmtDate(DateTime? d) => d == null ? AppLocale.instance.t('cqp_select_date') : '${d.day}/${d.month}/${d.year}';
  String? _isoDate(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ✅ "เชื่อมกับบริการของอู่" — ให้อู่เลือกรายการจากบริการที่ตั้งไว้ในโปรไฟล์
  // (editprofile_shop_page.dart) แทนการพิมพ์ชื่อ/ราคาใหม่ทุกครั้ง รองรับทั้ง
  // รูปแบบเก่า {name, price} และรูปแบบใหม่ {category, name, priceMin, priceMax,
  // details, active} — แสดงเฉพาะรายการที่เปิดใช้งานอยู่ (active ไม่ระบุ = ถือว่าเปิด)
  Future<void> _pickGarageService(_QuoteItem item) async {
    final services = (widget.garageServices ?? [])
        .whereType<Map>()
        .where((s) {
          final name = s['name']?.toString().trim() ?? '';
          final active = s['active'] is bool ? s['active'] as bool : true;
          return name.isNotEmpty && active;
        })
        .toList();
    if (services.isEmpty) return;

    final picked = await showModalBottomSheet<Map>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // ✅ แก้บัค: ห่อด้วย Material(color: Colors.white) กัน ListTile ขึ้น
        // warning เรื่อง ink splash อาจมองไม่เห็น ตอนกดใน showModalBottomSheet
        return Material(
          color: Colors.white,
          child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocale.instance.t('cqp_pick_service_title'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: services.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final s = services[i];
                      final name = s['name']?.toString() ?? '';
                      final min = s['priceMin'];
                      final max = s['priceMax'];
                      final legacyPrice = s['price'];
                      String priceLabel = '';
                      final minStr = min?.toString() ?? '';
                      final maxStr = max?.toString() ?? '';
                      if (minStr.isNotEmpty && maxStr.isNotEmpty) {
                        priceLabel = '฿$minStr - ฿$maxStr';
                      } else if (minStr.isNotEmpty) {
                        priceLabel = AppLocale.instance.t('cqp_price_from_prefix').replaceAll('%s', minStr);
                      } else if (maxStr.isNotEmpty) {
                        priceLabel = AppLocale.instance.t('cqp_price_upto_prefix').replaceAll('%s', maxStr);
                      } else if (legacyPrice != null && legacyPrice.toString().isNotEmpty) {
                        priceLabel = '฿$legacyPrice';
                      }
                      return ListTile(
                        title: Text(name),
                        subtitle: priceLabel.isNotEmpty ? Text(priceLabel) : null,
                        onTap: () => Navigator.pop(context, s),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      item.nameCtrl.text = picked['name']?.toString() ?? '';
      final min = picked['priceMin']?.toString() ?? '';
      final max = picked['priceMax']?.toString() ?? '';
      final legacyPrice = picked['price']?.toString() ?? '';
      final priceValue = min.isNotEmpty ? min : (max.isNotEmpty ? max : legacyPrice);
      if (priceValue.isNotEmpty) item.priceCtrl.text = priceValue;
    });
  }

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
        SnackBar(content: Text(AppLocale.instance.t('cqp_validation_msg')),
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
      if (laborBreakdown.isNotEmpty) "${AppLocale.instance.t('cqp_labor_breakdown_prefix')}$laborBreakdown",
      if (notesText.isNotEmpty) notesText,
    ].join('\n');

    final result = _isEditMode
        ? await ApiService.updateQuotation(
            quotationId: widget.existingQuotation!['id'],
            items: validItems,
            laborCost: _laborCost,
            totalPrice: _totalPrice,
            estimatedStartDate: _isoDate(_startDate),
            estimatedEndDate: _isoDate(_endDate),
            notes: combinedNotes,
          )
        : await ApiService.createQuotation(
            repairRequestId: widget.repairRequestId,
            items: validItems,
            laborCost: _laborCost,
            totalPrice: _totalPrice,
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
    final loc = AppLocale.instance;
    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: Text(_isEditMode ? loc.t('grd_edit_quotation_button') : loc.t('grd_create_quotation_button'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
                              Text(loc.t('cqp_customer_info_label'),
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(widget.customerName,
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ✅ ข้อมูลรถ — แสดงเมื่อคำขอนี้ผูกกับรถจาก "รถของฉัน" ของลูกค้า
                    if (widget.carInfo != null) ...[
                      const SizedBox(height: 12),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xffE8F5E9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.directions_car, color: Color(0xff4CAF50), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(loc.t('cqp_car_info_label'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  Builder(builder: (context) {
                                    final brandModel =
                                        '${widget.carInfo!['car_brand'] ?? ''} ${widget.carInfo!['car_model'] ?? ''}'
                                            .trim();
                                    return Text(
                                      brandModel.isEmpty ? loc.t('garage_address_fallback') : brandModel,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    );
                                  }),
                                  const SizedBox(height: 2),
                                  Builder(builder: (context) {
                                    final plate = widget.carInfo!['car_plate']?.toString() ?? '';
                                    final color = widget.carInfo!['car_color']?.toString() ?? '';
                                    final parts = [
                                      vehicleTypeLabel(widget.carInfo!['car_type']?.toString()),
                                      if (plate.isNotEmpty) loc.t('cqp_plate_prefix').replaceAll('%s', plate),
                                      if (color.isNotEmpty) color,
                                    ];
                                    return Text(parts.join(' • '),
                                        style: const TextStyle(fontSize: 12, color: Colors.grey));
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // รายการอะไหล่
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.build_outlined, size: 18, color: Color(0xff2196F3)),
                            const SizedBox(width: 6),
                            Text(loc.t('qc_parts_list_title'),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        _addButton(loc.t('cqp_add_part_button'), _addItem),
                      ],
                    ),
                    const SizedBox(height: 10),

                    ...List.generate(_items.length, (index) {
                      final item = _items[index];
                      return _sectionCard(
                        onDelete: _items.length > 1 ? () => _removeItem(index) : null,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: item.nameCtrl,
                                  decoration: _fieldDecoration(loc.t('cqp_item_name_hint')),
                                ),
                              ),
                              if ((widget.garageServices ?? []).isNotEmpty) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _pickGarageService(item),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xffE3F2FD),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.playlist_add_check,
                                        color: Color(0xff2196F3), size: 20),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _labeledField(
                                  label: loc.t('ujs_part_qty_label'),
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
                                  label: loc.t('cqp_price_per_unit_label'),
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

                    _totalPill(loc.t('qc_parts_subtotal_label'), _partsCost),

                    const SizedBox(height: 20),

                    // ค่าแรง
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.engineering_outlined, size: 18, color: Color(0xff2196F3)),
                            const SizedBox(width: 6),
                            Text(loc.t('gjd_labor_cost'),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        _addButton(loc.t('cqp_add_labor_button'), _addLaborItem),
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
                            decoration: _fieldDecoration(loc.t('cqp_labor_name_hint')),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _labeledField(
                                  label: loc.t('cqp_time_label'),
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
                                  label: loc.t('gjd_labor_cost'),
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

                    _totalPill(loc.t('cqp_labor_subtotal_label'), _laborCost),

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.date_range_outlined, size: 18, color: Color(0xff2196F3)),
                        const SizedBox(width: 6),
                        Text(loc.t('cqp_estimated_duration_title'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _dateButton(
                            label: _fmtDate(_startDate),
                            onTap: () => _pickDate(isStart: true),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(loc.t('cqp_to_label'), style: const TextStyle(color: Colors.grey)),
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
                    Row(
                      children: [
                        const Icon(Icons.notes_outlined, size: 18, color: Color(0xff2196F3)),
                        const SizedBox(width: 6),
                        Text(loc.t('cqp_notes_optional_title'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: loc.t('cqp_notes_hint'),
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
                          Row(
                            children: [
                              const Icon(Icons.receipt_long_outlined, size: 17, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(loc.t('cqp_summary_title'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _summaryRow(loc.t('cqp_parts_cost_label'), _partsCost),
                          _summaryRow(loc.t('gjd_labor_cost'), _laborCost),
                          _summaryRow(loc.t('common_vat_7'), _vatAmount),
                          const Divider(color: Colors.white38, height: 20),
                          _summaryRow(loc.t('cqp_net_total_label'), _totalPrice, big: true),
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
                    : Icon(_isEditMode ? Icons.save : Icons.send, color: Colors.white),
                label: Text(
                  _isSubmitting
                      ? (_isEditMode ? loc.t('cqp_saving') : loc.t('cqp_sending'))
                      : (_isEditMode ? loc.t('cqp_save_edit_button') : loc.t('cqp_send_quotation_button')),
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
              .map((u) => DropdownMenuItem(value: u, child: Text(_unitDisplayLabel(u), style: const TextStyle(fontSize: 13))))
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
        Text(AppLocale.instance.t('cqp_subtotal_label'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
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