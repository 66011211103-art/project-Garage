import 'package:flutter/material.dart';
import 'api_service.dart';

/// ตัวเลือก "ประเภทรถ" ผูกกับรถแต่ละคัน (แทนที่การถามซ้ำทุกครั้งตอนส่งคำขอซ่อม)
/// public ไว้เพราะ request_repair_page.dart เอาไปใช้ตอนเปิดฟอร์มเพิ่มรถแบบ inline ด้วย
class VehicleTypeOption {
  final String value;
  final String label;
  final IconData icon;
  const VehicleTypeOption(this.value, this.label, this.icon);
}

const List<VehicleTypeOption> kVehicleTypes = [
  VehicleTypeOption('sedan', 'รถเก๋ง', Icons.directions_car),
  VehicleTypeOption('suv', 'SUV', Icons.airport_shuttle),
  VehicleTypeOption('pickup', 'กระบะ', Icons.local_shipping),
  VehicleTypeOption('van', 'รถตู้', Icons.airport_shuttle),
  VehicleTypeOption('motorcycle', 'มอเตอร์ไซค์', Icons.two_wheeler),
  VehicleTypeOption('other', 'อื่นๆ', Icons.directions_car_filled),
];

String vehicleTypeLabel(String? value) {
  if (value == null || value.isEmpty) return 'ไม่ระบุประเภท';
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
        SnackBar(content: Text(result.message.isNotEmpty ? result.message : 'โหลดข้อมูลรถไม่สำเร็จ')),
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
        title: const Text('ลบรถคันนี้?'),
        content: const Text('คุณต้องการลบข้อมูลรถคันนี้ใช่หรือไม่'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
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
          SnackBar(content: Text(result.message.isNotEmpty ? result.message : 'ลบรถไม่สำเร็จ')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        title: const Text('รถของฉัน'),
        backgroundColor: const Color(0xff2196F3),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xff2196F3),
        onPressed: () => _openCarForm(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cars.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _loadCars,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _cars.length,
                    itemBuilder: (context, index) => _carCard(_cars[index]),
                  ),
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
          const Text('ยังไม่มีรถที่บันทึกไว้', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _openCarForm(),
            icon: const Icon(Icons.add),
            label: const Text('เพิ่มรถของฉัน'),
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
                  car['car_model'] ?? 'ไม่ระบุรุ่น',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  car['car_plate'] ?? 'ไม่ระบุทะเบียน',
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
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('แก้ไข')),
              PopupMenuItem(value: 'delete', child: Text('ลบ')),
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
    _modelCtrl.dispose();
    _plateCtrl.dispose();
    _brandCtrl.dispose();
    _colorCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
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
        SnackBar(content: Text(result.message.isNotEmpty ? result.message : 'บันทึกข้อมูลไม่สำเร็จ')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'แก้ไขข้อมูลรถ' : 'เพิ่มรถของฉัน',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('ประเภทรถ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kVehicleTypes.map((v) {
                final selected = _carType == v.value;
                return ChoiceChip(
                  label: Text(v.label),
                  avatar: Icon(v.icon, size: 16, color: selected ? const Color(0xff2196F3) : Colors.grey.shade600),
                  selected: selected,
                  onSelected: (_) => setState(() => _carType = v.value),
                  selectedColor: const Color(0xffE3F2FD),
                  backgroundColor: const Color(0xffF5F5F5),
                  labelStyle: TextStyle(
                    color: selected ? const Color(0xff2196F3) : Colors.black87,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(color: selected ? const Color(0xff2196F3) : Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _modelCtrl,
              decoration: const InputDecoration(labelText: 'รุ่นรถ', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกรุ่นรถ' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _plateCtrl,
              decoration: const InputDecoration(labelText: 'ทะเบียนรถ', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกทะเบียนรถ' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _brandCtrl,
              decoration: const InputDecoration(labelText: 'ยี่ห้อ (ถ้ามี)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _colorCtrl,
                    decoration: const InputDecoration(labelText: 'สี', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _yearCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'ปี', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'บันทึกการแก้ไข' : 'เพิ่มรถ'),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}