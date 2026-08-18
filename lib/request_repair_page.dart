import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';
import 'address_picker_sheet.dart'; // ✅ ใช้ chatbox ค้นหาที่อยู่แบบเดียวกับหน้าอื่น
import ' myCarPage.dart'; // ✅ ใช้ kVehicleTypes/vehicleTypeLabel/CarFormSheet ร่วมกัน — "ประเภทรถ"
// ผูกกับรถแต่ละคันใน "รถของฉัน" แล้ว ไม่ต้องถามซ้ำเป็นปุ่มลอยๆ ในหน้านี้อีกต่อไป

const List<String> kProblemCategories = [
  'เครื่องยนต์',
  'ยาง',
  'แบตเตอรี่',
  'เบรก',
  'ซ่อมสี',
  'อื่นๆ',
];

const int kMaxRepairPhotos = 5;

/// หน้าส่งคำขอซ่อมรถ ไปยังอู่ที่เลือกไว้จากหน้ารายละเอียดอู่
class RequestRepairPage extends StatefulWidget {
  final Map<String, dynamic> garage;
  final Map<String, dynamic> userData;

  const RequestRepairPage({super.key, required this.garage, required this.userData});

  @override
  State<RequestRepairPage> createState() => _RequestRepairPageState();
}

class _RequestRepairPageState extends State<RequestRepairPage> {
  // ✅ เลิกถาม "ประเภทรถ" แบบลอยๆ แล้ว — ให้ลูกค้าเลือกจาก "รถของฉัน" แทน (ประเภทรถผูก
  // ไว้กับแต่ละคันตอนเพิ่มรถแล้ว) _cars = รายการรถทั้งหมดของลูกค้า, _selectedCar = คันที่เลือกส่งซ่อม
  List<Map<String, dynamic>> _cars = [];
  Map<String, dynamic>? _selectedCar;
  bool _isLoadingCars = true;

  String _problemCategory = kProblemCategories.first;
  final _descriptionController = TextEditingController();
  // ✅ ลูกค้าบางคนรถเสียกลางทาง ไม่รู้อาการ/ไม่รู้จะอธิบายยังไง แต่หน้านี้เดิมบังคับ
  // กรอกรายละเอียดเสมอ (เช็คที่ _handleSubmit) ทำให้ส่งคำขอไม่ได้เลย — เพิ่มสวิตช์นี้
  // ให้ข้ามการบังคับกรอก แล้วแทรกข้อความมาตรฐานแจ้งอู่แทน (ไม่ต้องเพิ่มคอลัมน์ DB ใหม่)
  bool _symptomUnknown = false;

  final List<Uint8List> _photos = [];
  final List<String> _photoNames = [];

  late String _address;
  double? _latitude;
  double? _longitude;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _address = widget.userData['address']?.toString() ?? '';
    _latitude = double.tryParse(widget.userData['latitude']?.toString() ?? '');
    _longitude = double.tryParse(widget.userData['longitude']?.toString() ?? '');
    _loadCars();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  // ✅ โหลดรถของลูกค้าคนนี้ แล้วเลือกคันแรกให้อัตโนมัติถ้ายังไม่เคยเลือกไว้
  Future<void> _loadCars() async {
    setState(() => _isLoadingCars = true);
    final result = await ApiService.getCars(userId: widget.userData['id']);
    if (!mounted) return;
    if (result.success && result.data != null) {
      setState(() {
        _cars = List<Map<String, dynamic>>.from(result.data!['cars'] ?? []);
        _isLoadingCars = false;
        if (_selectedCar == null && _cars.isNotEmpty) {
          _selectedCar = _cars.first;
        } else if (_selectedCar != null) {
          // ✅ ถ้ารถที่เลือกไว้ถูกแก้ไขข้อมูล (เช่น เพิ่งเปลี่ยนประเภทรถ) ให้ syncข้อมูลล่าสุดมาด้วย
          final match = _cars.where((c) => c['id'] == _selectedCar!['id']);
          if (match.isNotEmpty) _selectedCar = match.first;
        }
      });
    } else {
      setState(() => _isLoadingCars = false);
    }
  }

  // ✅ เปิดชีทเลือกรถจากลิสต์ที่มี หรือกด "+ เพิ่มรถใหม่" เพื่อเปิดฟอร์มเพิ่มรถ (ใช้ฟอร์ม
  // เดียวกับหน้า "รถของฉัน" — CarFormSheet จาก myCarPage.dart) แล้วเลือกคันที่เพิ่งเพิ่มให้ทันที
  Future<void> _openCarPicker() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('เลือกรถที่ต้องการซ่อม',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (_cars.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text('ยังไม่มีรถที่บันทึกไว้ กด "เพิ่มรถใหม่" ด้านล่างเพื่อเริ่มต้น',
                      style: TextStyle(color: Colors.grey.shade600)),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.4),
                  child: ListView(
                    shrinkWrap: true,
                    children: _cars.map((car) {
                      final selected = _selectedCar != null && _selectedCar!['id'] == car['id'];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.directions_car,
                            color: selected ? const Color(0xff2196F3) : Colors.grey.shade500),
                        title: Text(car['car_model'] ?? 'ไม่ระบุรุ่น',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${car['car_plate'] ?? 'ไม่ระบุทะเบียน'} · ${vehicleTypeLabel(car['car_type']?.toString())}'),
                        trailing: selected
                            ? const Icon(Icons.check_circle, color: Color(0xff2196F3))
                            : null,
                        onTap: () => Navigator.pop(sheetContext, car),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final added = await showModalBottomSheet<Map<String, dynamic>>(
                    context: sheetContext,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (_) => CarFormSheet(userId: widget.userData['id']),
                  );
                  if (added != null && sheetContext.mounted) {
                    Navigator.pop(sheetContext, added);
                  }
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('เพิ่มรถใหม่'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xff2196F3),
                  side: const BorderSide(color: Color(0xff2196F3)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(double.infinity, 0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );
      },
    );

    // ✅ ต้องเช็ค mounted ก่อน setState เสมอ เผื่อหน้านี้ถูกปิดไปแล้วระหว่างที่
    // bottom sheet เลือกรถยังเปิดค้างอยู่ (เช่น กด back ถี่ๆ)
    if (picked != null && mounted) {
      setState(() => _selectedCar = picked);
      _loadCars(); // ✅ sync รายการรถทั้งหมดใหม่เผื่อเพิ่งเพิ่ม/แก้ไขรถไป (ทำงานเงียบๆ เบื้องหลัง)
    }
  }

  Future<void> _pickPhotos() async {
    final remaining = kMaxRepairPhotos - _photos.length;
    if (remaining <= 0) return;

    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;

    final toAdd = picked.take(remaining).toList();
    final bytesList = await Future.wait(toAdd.map((f) => f.readAsBytes()));

    if (!mounted) return;
    setState(() {
      for (var i = 0; i < toAdd.length; i++) {
        _photos.add(bytesList[i]);
        _photoNames.add(toAdd[i].name);
      }
    });

    if (picked.length > remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เลือกได้สูงสุด $kMaxRepairPhotos รูป เพิ่มให้แล้ว $remaining รูป')),
      );
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
      _photoNames.removeAt(index);
    });
  }

  Future<void> _pickAddress() async {
    final picked = await pickAddressViaChat(context, initialQuery: _address);
    if (picked != null && mounted) {
      setState(() {
        _address = picked.address;
        _latitude = picked.latitude;
        _longitude = picked.longitude;
      });
    }
  }

  // ✅ ประกอบข้อความ description ที่จะส่งจริง — ถ้าลูกค้าติ๊ก "ไม่ทราบอาการ" ให้แทรก
  // ป้ายกำกับไว้ข้างหน้าเสมอ (ไม่ว่าจะพิมพ์อะไรเพิ่มมาหรือไม่) เพื่อให้อู่เห็นชัดว่าต้อง
  // ตรวจสอบอาการเบื้องต้นเองหน้างาน ไม่ใช่คาดหวังคำอธิบายที่ชัดเจนจากลูกค้า
  String _buildDescriptionToSend() {
    final text = _descriptionController.text.trim();
    if (!_symptomUnknown) return text;
    const flag = '[ลูกค้าไม่ทราบอาการที่ชัดเจน กรุณาตรวจสอบเบื้องต้นหน้างาน]';
    return text.isEmpty ? flag : '$flag $text';
  }

  Future<void> _handleSubmit() async {
    if (_selectedCar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกรถที่ต้องการซ่อม'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_descriptionController.text.trim().isEmpty && !_symptomUnknown) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกรายละเอียดปัญหา หรือติ๊กว่า "ไม่ทราบอาการ"'), backgroundColor: Colors.red),
      );
      return;
    }
    // ✅ เดิมไม่เช็คว่าเลือกที่อยู่แล้วหรือยัง — ถ้าลูกค้าไม่เคยตั้งที่อยู่ไว้ในโปรไฟล์
    // และไม่กดเลือกตำแหน่งเอง คำขอจะส่งไปแบบไม่มีที่อยู่/พิกัดเลย อู่หาตัวลูกค้าไม่เจอ
    if (_address.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกตำแหน่งที่ต้องการให้ไปซ่อม'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final garageUserId = widget.garage['user_id'] ?? widget.garage['id'];

    final result = await ApiService.submitRepairRequest(
      customerId: widget.userData['id'],
      garageId: garageUserId,
      carId: _selectedCar!['id'] is int
          ? _selectedCar!['id'] as int
          : int.tryParse(_selectedCar!['id'].toString()),
      vehicleType: _selectedCar!['car_type']?.toString(),
      problemCategory: _problemCategory,
      description: _buildDescriptionToSend(),
      address: _address,
      latitude: _latitude,
      longitude: _longitude,
      photos: _photos,
      photoNames: _photoNames,
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
        title: const Text('ส่งคำขอซ่อมรถ', style: TextStyle(color: Colors.white)),
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
                    const Text('รถที่ต้องการซ่อม',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    _buildCarSelector(),

                    const SizedBox(height: 20),
                    const Text('ประเภทปัญหา',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kProblemCategories.map((c) {
                        final selected = _problemCategory == c;
                        return ChoiceChip(
                          label: Text(c),
                          selected: selected,
                          onSelected: (_) => setState(() => _problemCategory = c),
                          selectedColor: const Color(0xffE3F2FD),
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: selected ? const Color(0xff2196F3) : Colors.black87,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: selected ? const Color(0xff2196F3) : Colors.grey.shade300,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),
                    const Text('รายละเอียดปัญหา',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 4,
                      enabled: !_symptomUnknown,
                      decoration: InputDecoration(
                        hintText: _symptomUnknown
                            ? 'ไม่บังคับ — พิมพ์สิ่งที่สังเกตเห็นได้ก็ได้ เช่น มีเสียงดัง มีไฟโชว์ที่หน้าปัด...'
                            : 'อธิบายปัญหาที่พบ เช่น รถติดยาก เครื่องดับบ่อย มีเสียงผิดปกติ...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // ✅ กรณีรถเสียกลางทางแล้วไม่รู้อาการ — ให้ลูกค้าติ๊กแทนการบังคับพิมพ์
                    // อธิบาย ระบบจะแจ้งอู่ให้ช่วยตรวจสอบเบื้องต้นหน้างานแทน (ดูรายละเอียดถ่ายรูป
                    // แนบเพิ่มก็ยังช่วยอู่ประเมินได้แม้ไม่มีคำอธิบาย)
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _symptomUnknown = !_symptomUnknown),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _symptomUnknown,
                              onChanged: (v) => setState(() => _symptomUnknown = v ?? false),
                              activeColor: const Color(0xff2196F3),
                            ),
                            const Expanded(
                              child: Text('ไม่ทราบอาการ / ไม่รู้ว่ารถเสียตรงไหน',
                                  style: TextStyle(fontSize: 14)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_symptomUnknown)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, top: 2),
                        child: Text(
                          'ไม่เป็นไร — ส่งคำขอได้เลย แนะนำให้ถ่ายรูป/แนบรูปเพิ่มเติมด้านล่าง อู่จะช่วยตรวจสอบอาการเบื้องต้นให้',
                          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                        ),
                      ),

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Text('อัปโหลดรูปภาพรถ',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 6),
                        Text('(${_photos.length}/$kMaxRepairPhotos)',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 92,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ..._photos.asMap().entries.map((entry) {
                            final index = entry.key;
                            final bytes = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.memory(
                                      bytes,
                                      width: 92,
                                      height: 92,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => _removePhoto(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close,
                                            size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (_photos.length < kMaxRepairPhotos)
                            InkWell(
                              onTap: _pickPhotos,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 92,
                                height: 92,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt_outlined, color: Colors.grey.shade400),
                                    const SizedBox(height: 6),
                                    Text('เพิ่มรูปภาพ',
                                        style:
                                            TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Text('ตำแหน่งปัจจุบัน',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _pickAddress,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: Color(0xff2196F3)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('ตำแหน่งของคุณ',
                                      style: TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    _address.isEmpty ? 'แตะเพื่อเลือกตำแหน่ง' : _address,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xffE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xff2196F3), size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'อู่ซ่อมรถจะติดต่อกลับภายใน 15 นาที',
                              style: TextStyle(color: Color(0xff1976D2), fontSize: 13),
                            ),
                          ),
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
                  elevation: 2,
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                label: Text(
                  _isSubmitting ? 'กำลังส่ง...' : 'ส่งคำขอซ่อม',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ การ์ดเลือกรถที่ต้องการซ่อม — แทนที่ปุ่มเลือก "ประเภทรถ" แบบเดิม ด้วยการเลือกรถจริง
  // จาก "รถของฉัน" (ประเภทรถผูกไว้กับแต่ละคันแล้วตอนเพิ่มรถ ไม่ต้องถามซ้ำตรงนี้)
  Widget _buildCarSelector() {
    if (_isLoadingCars) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final car = _selectedCar;
    if (car == null) {
      return InkWell(
        onTap: _openCarPicker,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xff2196F3), style: BorderStyle.solid),
          ),
          child: Column(
            children: [
              const Icon(Icons.add_circle_outline, color: Color(0xff2196F3), size: 28),
              const SizedBox(height: 8),
              const Text('เพิ่มรถของฉัน',
                  style: TextStyle(color: Color(0xff2196F3), fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('เลือกหรือเพิ่มรถที่ต้องการส่งซ่อม',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    final subtitleParts = [
      car['car_brand'],
      car['car_color'],
      car['car_year']?.toString(),
    ].where((e) => e != null && e.toString().isNotEmpty).join(' · ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xffE3F2FD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.directions_car, color: Color(0xff2196F3)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(car['car_model'] ?? 'ไม่ระบุรุ่น',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(car['car_plate'] ?? 'ไม่ระบุทะเบียน',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                if (subtitleParts.isNotEmpty)
                  Text(subtitleParts,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: _openCarPicker,
            child: const Text('เปลี่ยนรถ'),
          ),
        ],
      ),
    );
  }
}