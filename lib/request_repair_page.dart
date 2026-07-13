import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';
import 'address_picker_sheet.dart'; // ✅ ใช้ chatbox ค้นหาที่อยู่แบบเดียวกับหน้าอื่น

class _VehicleTypeOption {
  final String value;
  final String label;
  final IconData icon;
  const _VehicleTypeOption(this.value, this.label, this.icon);
}

const List<_VehicleTypeOption> kVehicleTypes = [
  _VehicleTypeOption('sedan', 'รถเก๋ง', Icons.directions_car),
  _VehicleTypeOption('suv', 'SUV', Icons.airport_shuttle),
  _VehicleTypeOption('pickup', 'กระบะ', Icons.local_shipping),
];

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
  String _vehicleType = kVehicleTypes.first.value;
  String _problemCategory = kProblemCategories.first;
  final _descriptionController = TextEditingController();

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
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
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
    if (picked != null) {
      setState(() {
        _address = picked.address;
        _latitude = picked.latitude;
        _longitude = picked.longitude;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกรายละเอียดปัญหา'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final garageUserId = widget.garage['user_id'] ?? widget.garage['id'];

    final result = await ApiService.submitRepairRequest(
      customerId: widget.userData['id'],
      garageId: garageUserId,
      vehicleType: _vehicleType,
      problemCategory: _problemCategory,
      description: _descriptionController.text.trim(),
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
                    const Text('ประเภทรถ',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      children: kVehicleTypes.map((v) {
                        final selected = _vehicleType == v.value;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                                right: v == kVehicleTypes.last ? 0 : 10),
                            child: InkWell(
                              onTap: () => setState(() => _vehicleType = v.value),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: selected ? const Color(0xffE3F2FD) : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected
                                        ? const Color(0xff2196F3)
                                        : Colors.grey.shade300,
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(v.icon,
                                        color: selected
                                            ? const Color(0xff2196F3)
                                            : Colors.grey.shade600),
                                    const SizedBox(height: 6),
                                    Text(
                                      v.label,
                                      style: TextStyle(
                                        color: selected
                                            ? const Color(0xff2196F3)
                                            : Colors.black87,
                                        fontWeight:
                                            selected ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

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
                      decoration: InputDecoration(
                        hintText: 'อธิบายปัญหาที่พบ เช่น รถติดยาก เครื่องดับบ่อย มีเสียงผิดปกติ...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
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
}