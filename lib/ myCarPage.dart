import 'package:flutter/material.dart';
import 'api_service.dart';
import 'app_locale.dart';

/// ตัวเลือก "ประเภทรถ" ผูกกับรถแต่ละคัน (แทนที่การถามซ้ำทุกครั้งตอนส่งคำขอซ่อม)
/// public ไว้เพราะ request_repair_page.dart เอาไปใช้ตอนเปิดฟอร์มเพิ่มรถแบบ inline ด้วย
class VehicleTypeOption {
  final String value;
  final String labelKey;
  final IconData icon;
  const VehicleTypeOption(this.value, this.labelKey, this.icon);
  String get label => AppLocale.instance.t(labelKey);
}

const List<VehicleTypeOption> kVehicleTypes = [
  VehicleTypeOption('sedan', 'tech_vehicle_sedan', Icons.directions_car),
  VehicleTypeOption('suv', 'car_type_suv', Icons.airport_shuttle),
  VehicleTypeOption('pickup', 'tech_vehicle_pickup', Icons.local_shipping),
  VehicleTypeOption('van', 'car_type_van', Icons.airport_shuttle),
  VehicleTypeOption('motorcycle', 'car_type_motorcycle', Icons.two_wheeler),
  VehicleTypeOption('other', 'car_type_other', Icons.directions_car_filled),
];

String vehicleTypeLabel(String? value) {
  if (value == null || value.isEmpty) return AppLocale.instance.t('car_type_unspecified');
  return kVehicleTypes
      .firstWhere((v) => v.value == value, orElse: () => kVehicleTypes.last)
      .label;
}

class MyCarPage extends StatefulWidget {
  final int userId; // ✅ ใช้ userId (userData['id']) เหมือนหน้าอื่นๆ ในแอป

  const MyCarPage({super.key, required this.userId});

  @override
  State<MyCarPage> createState() => _MyCarPageState();
}

class _MyCarPageState extends State<MyCarPage> {
  List<Map<String, dynamic>> _cars = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCars();
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

  // ✅ โหลดรายการรถทั้งหมดของผู้ใช้คนนี้
  Future<void> _loadCars() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getCars(userId: widget.userId);
    if (!mounted) return;

    if (result.success && result.data != null) {
      setState(() {
        _cars = List<Map<String, dynamic>>.from(result.data!['cars'] ?? []);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message.isNotEmpty ? result.message : AppLocale.instance.t('car_load_failed'))),
      );
    }
  }

  // ✅ เปิดฟอร์มเพิ่ม/แก้ไขรถ
  // ⚠️ CarFormSheet ตอนนี้ pop กลับเป็น Map ข้อมูลรถ (ไม่ใช่ true/false เฉยๆ) เพราะ
  // request_repair_page.dart เอาไปเลือกรถที่เพิ่งเพิ่ม/แก้ไขให้อัตโนมัติด้วย — หน้านี้
  // สนใจแค่ว่ามีการบันทึกสำเร็จไหม (result != null) แล้วโหลดลิสต์ใหม่เหมือนเดิม
  Future<void> _openCarForm({Map<String, dynamic>? car}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CarFormSheet(
        userId: widget.userId,
        existingCar: car,
      ),
    );
    if (result != null) {
      _loadCars();
    }
  }

  Future<void> _deleteCar(int carId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocale.instance.t('car_delete_confirm_title')),
        content: Text(AppLocale.instance.t('car_delete_confirm_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocale.instance.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocale.instance.t('common_delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await ApiService.deleteCar(carId: carId);
      if (!mounted) return;
      if (result.success) {
        _loadCars();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message.isNotEmpty ? result.message : AppLocale.instance.t('car_delete_failed'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocale.instance;
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        title: Text(loc.t('profile_my_cars')),
        backgroundColor: const Color(0xff2196F3),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cars.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _loadCars,
                  child: ListView.builder(
                    // ✅ เผื่อ padding ล่างกัน FloatingActionButton บังการ์ดรถคันสุดท้าย
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
                    itemCount: _cars.length,
                    itemBuilder: (context, index) => _carCard(_cars[index]),
                  ),
                ),
      // ✅ แก้บั๊ก: เดิมปุ่มเพิ่มรถอยู่แค่ตอนลิสต์ว่าง (_emptyState()) พอมีรถคันแรก
      // แล้วไม่มีทางเพิ่มคันที่ 2 ได้เลยในหน้านี้ (backend รองรับหลายคันต่อ user
      // อยู่แล้ว แค่ UI ไม่มีปุ่มให้กด) เพิ่ม FAB ให้กดเพิ่มได้เรื่อยๆ เมื่อมีรถแล้ว
      // อย่างน้อย 1 คัน (ตอนลิสต์ว่างใช้ปุ่มกลางจอใน _emptyState() แทน ไม่ต้องมีซ้ำ)
      floatingActionButton: _cars.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openCarForm(),
              icon: const Icon(Icons.add),
              label: Text(loc.t('car_add_another')),
              backgroundColor: const Color(0xff2196F3),
              foregroundColor: Colors.white,
            ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          Text(AppLocale.instance.t('car_empty_state'), style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _openCarForm(),
            icon: const Icon(Icons.add),
            label: Text(AppLocale.instance.t('car_add_button')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff2196F3),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _carCard(Map<String, dynamic> car) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.directions_car, color: Color(0xff2196F3)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  car['car_model'] ?? AppLocale.instance.t('car_model_unspecified'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  car['car_plate'] ?? AppLocale.instance.t('car_plate_unspecified'),
                  style: const TextStyle(color: Colors.grey),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xffE3F2FD),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      vehicleTypeLabel(car['car_type']?.toString()),
                      style: const TextStyle(fontSize: 11, color: Color(0xff2196F3)),
                    ),
                  ),
                ),
                if ((car['car_brand'] ?? '').toString().isNotEmpty ||
                    (car['car_color'] ?? '').toString().isNotEmpty ||
                    car['car_year'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      [
                        car['car_brand'],
                        car['car_color'],
                        car['car_year']?.toString(),
                      ].where((e) => e != null && e.toString().isNotEmpty).join(' · '),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _openCarForm(car: car);
              } else if (value == 'delete') {
                _deleteCar(car['id']);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'edit', child: Text(AppLocale.instance.t('common_edit'))),
              PopupMenuItem(value: 'delete', child: Text(AppLocale.instance.t('common_delete'))),
            ],
          ),
        ],
      ),
    );
  }
}

// ✅ ฟอร์มเพิ่ม/แก้ไขรถ (bottom sheet) — public เพราะ request_repair_page.dart
// เรียกใช้ฟอร์มเดียวกันนี้ตอนลูกค้ากด "+ เพิ่มรถใหม่" ระหว่างส่งคำขอซ่อม
// (กันไม่ให้ต้องเขียนฟอร์มเพิ่มรถซ้ำสองที่)
class CarFormSheet extends StatefulWidget {
  final int userId;
  final Map<String, dynamic>? existingCar;

  const CarFormSheet({super.key, required this.userId, this.existingCar});

  @override
  State<CarFormSheet> createState() => _CarFormSheetState();
}

class _CarFormSheetState extends State<CarFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _modelCtrl;
  late final TextEditingController _plateCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _colorCtrl;
  late final TextEditingController _yearCtrl;
  late String _carType;
  bool _isSaving = false;

  bool get _isEditing => widget.existingCar != null;

  @override
  void initState() {
    super.initState();
    AppLocale.instance.addListener(_onLocaleChanged);
    final car = widget.existingCar;
    _modelCtrl = TextEditingController(text: car?['car_model'] ?? '');
    _plateCtrl = TextEditingController(text: car?['car_plate'] ?? '');
    _brandCtrl = TextEditingController(text: car?['car_brand'] ?? '');
    _colorCtrl = TextEditingController(text: car?['car_color'] ?? '');
    _yearCtrl = TextEditingController(text: car?['car_year']?.toString() ?? '');
    final existingType = car?['car_type']?.toString();
    // ✅ ถ้าเป็นการ "แก้ไข" รถเก่าที่บันทึกไว้ก่อนมีฟีเจอร์ประเภทรถ (car_type เป็น
    // null/ไม่ตรงตัวเลือกไหนเลย) ห้ามเดาเป็น 'sedan' เงียบๆ เพราะกดบันทึกแล้วจะ
    // เขียนทับเป็นรถเก๋งถาวรทั้งที่อาจเป็นรถประเภทอื่น — ใช้ 'other' (อื่นๆ) แทนซึ่ง
    // สื่อว่า "ยังไม่ทราบ/ยังไม่ระบุ" ตรงกว่า ส่วนรถที่เพิ่งเพิ่มใหม่ (car == null)
    // ค่าเริ่มต้นเป็นตัวเลือกแรกได้ตามปกติ เพราะผู้ใช้จะเลือกเองอยู่แล้ว
    _carType = kVehicleTypes.any((v) => v.value == existingType)
        ? existingType!
        : (car != null ? kVehicleTypes.last.value : kVehicleTypes.first.value);
  }

  @override
  void dispose() {
    AppLocale.instance.removeListener(_onLocaleChanged);
    _modelCtrl.dispose();
    _plateCtrl.dispose();
    _brandCtrl.dispose();
    _colorCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final result = _isEditing
        ? await ApiService.updateCar(
            carId: widget.existingCar!['id'],
            carModel: _modelCtrl.text.trim(),
            carPlate: _plateCtrl.text.trim(),
            carBrand: _brandCtrl.text.trim(),
            carColor: _colorCtrl.text.trim(),
            carYear: int.tryParse(_yearCtrl.text.trim()),
            carType: _carType,
          )
        : await ApiService.addCar(
            userId: widget.userId,
            carModel: _modelCtrl.text.trim(),
            carPlate: _plateCtrl.text.trim(),
            carBrand: _brandCtrl.text.trim(),
            carColor: _colorCtrl.text.trim(),
            carYear: int.tryParse(_yearCtrl.text.trim()),
            carType: _carType,
          );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.success) {
      // ✅ pop กลับเป็น Map ข้อมูลรถที่เพิ่ง save แทนแค่ true เฉยๆ — เพื่อให้หน้าที่เรียกฟอร์มนี้
      // (เช่น request_repair_page.dart) เลือกรถคันนี้ให้อัตโนมัติได้ทันที ไม่ต้องโหลดลิสต์ใหม่ทั้งหมด
      final carId = _isEditing ? widget.existingCar!['id'] : result.data?['id'];
      Navigator.pop(context, {
        'id': carId,
        'car_model': _modelCtrl.text.trim(),
        'car_plate': _plateCtrl.text.trim(),
        'car_brand': _brandCtrl.text.trim(),
        'car_color': _colorCtrl.text.trim(),
        'car_year': int.tryParse(_yearCtrl.text.trim()),
        'car_type': _carType,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message.isNotEmpty ? result.message : AppLocale.instance.t('common_save_failed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocale.instance;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? loc.t('car_edit_title') : loc.t('car_add_button'),
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          loc.t('car_form_subtitle'),
                          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                      child: Icon(Icons.close, size: 18, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(loc.t('car_type_label'),
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              _vehicleTypeGrid(),
              const SizedBox(height: 20),
              _fieldLabel(loc.t('car_model_label'), required: true),
              const SizedBox(height: 8),
              _carTextField(
                controller: _modelCtrl,
                hint: loc.t('car_model_hint'),
                validator: (v) => (v == null || v.trim().isEmpty) ? loc.t('car_model_required') : null,
              ),
              const SizedBox(height: 16),
              _fieldLabel(loc.t('car_plate_label'), required: true),
              const SizedBox(height: 8),
              _carTextField(
                controller: _plateCtrl,
                hint: loc.t('car_plate_hint'),
                validator: (v) => (v == null || v.trim().isEmpty) ? loc.t('car_plate_required') : null,
              ),
              const SizedBox(height: 16),
              _fieldLabel(loc.t('car_brand_label')),
              const SizedBox(height: 8),
              _carTextField(controller: _brandCtrl, hint: loc.t('car_brand_hint')),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel(loc.t('car_color_label')),
                        const SizedBox(height: 8),
                        _carTextField(controller: _colorCtrl, hint: loc.t('car_color_hint')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel(loc.t('car_year_label')),
                        const SizedBox(height: 8),
                        _carTextField(
                          controller: _yearCtrl,
                          hint: loc.t('car_year_hint'),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xff42A5F5), Color(0xff1976D2)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff2196F3).withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _isSaving ? null : _save,
                      child: Center(
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isEditing ? loc.t('car_save_edit_button') : loc.t('car_add_short_button'),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text, {bool required = false}) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Colors.black87),
        children: [
          TextSpan(text: text),
          if (required)
            const TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _carTextField({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        filled: true,
        fillColor: const Color(0xFFF5F6FA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xff2196F3), width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.6),
        ),
      ),
    );
  }

  Widget _vehicleTypeGrid() {
    final rows = <Widget>[];
    for (int i = 0; i < kVehicleTypes.length; i += 3) {
      final rowItems = kVehicleTypes.skip(i).take(3).toList();
      rows.add(Row(
        children: [
          for (int j = 0; j < rowItems.length; j++) ...[
            Expanded(child: _vehicleTypeCard(rowItems[j])),
            if (j != rowItems.length - 1) const SizedBox(width: 10),
          ],
        ],
      ));
      if (i + 3 < kVehicleTypes.length) rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }

  Widget _vehicleTypeCard(VehicleTypeOption v) {
    final selected = _carType == v.value;
    return GestureDetector(
      onTap: () => setState(() => _carType = v.value),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: selected ? const Color(0xffE3F2FD) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? const Color(0xff2196F3) : Colors.grey.shade200,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(v.icon, color: selected ? const Color(0xff2196F3) : Colors.grey.shade600, size: 24),
                const SizedBox(height: 6),
                Text(
                  v.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? const Color(0xff2196F3) : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(color: Color(0xff2196F3), shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 12),
              ),
            ),
        ],
      ),
    );
  }
}