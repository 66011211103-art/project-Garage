import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'profile_avatar_picker.dart'; // ใช้ pickProfileAvatar (bottom sheet เลือก/ถ่ายรูป) ร่วมกัน

/// รายการบริการที่อู่สามารถเลือกให้บริการได้
const List<String> kGarageServiceOptions = [
  'เครื่องยนต์',
  'ยาง',
  'แบตเตอรี่',
  'ซ่อมสี',
  'เบรก',
  'ช่วงล่าง',
  'ตัวถัง',
  'ระบบไฟ',
];

/// หน้าแก้ไข "ข้อมูลอู่" (รูปภาพ, ที่อยู่, เวลาทำการ, บริการ)
/// แยกจากหน้า "แก้ไขข้อมูลส่วนตัว" — ใช้สำหรับข้อมูลธุรกิจ/หน้าร้านที่แสดงในโปรไฟล์อู่
class GarageInfoEditPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const GarageInfoEditPage({super.key, required this.userData});

  @override
  State<GarageInfoEditPage> createState() => _GarageInfoEditPageState();
}

class _GarageInfoEditPageState extends State<GarageInfoEditPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _garageNameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;

  bool _isLoading = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  // เวลาทำการ เก็บเป็นข้อความ "HH:mm-HH:mm"
  String _weekdayHours = '08:00-18:00';
  String _weekendHours = '09:00-17:00';

  // บริการที่เลือก
  late Set<String> _selectedServices;

  @override
  void initState() {
    super.initState();
    final u = widget.userData;
    _garageNameController =
        TextEditingController(text: u['shop_name'] ?? u['garage_name'] ?? '');
    _addressController = TextEditingController(text: u['address'] ?? '');
    _phoneController = TextEditingController(text: u['phone'] ?? '');

    _weekdayHours = u['hours_weekday'] ?? _weekdayHours;
    _weekendHours = u['hours_weekend'] ?? _weekendHours;

    final existingServices = u['services'];
    _selectedServices = existingServices is List
        ? existingServices.map((e) => e.toString()).toSet()
        : <String>{};
  }

  @override
  void dispose() {
    _garageNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  ImageProvider? get _coverImage {
    if (_selectedImageBytes != null) return MemoryImage(_selectedImageBytes!);
    final photoUrl = widget.userData['garage_photo'];
    if (photoUrl != null && photoUrl.toString().isNotEmpty) {
      return NetworkImage(photoUrl);
    }
    return null;
  }

  Future<void> _handlePickCoverImage() async {
    final picked = await pickProfileAvatar(context);
    if (picked != null) {
      setState(() {
        _selectedImageBytes = picked.bytes;
        _selectedImageName = picked.name;
      });
    }
  }

  Future<void> _editHours({required bool isWeekday}) async {
    final current = isWeekday ? _weekdayHours : _weekendHours;
    final parts = current.split('-');
    TimeOfDay start = _parseTime(parts.isNotEmpty ? parts[0] : '08:00');
    TimeOfDay end = _parseTime(parts.length > 1 ? parts[1] : '18:00');

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        TimeOfDay tempStart = start;
        TimeOfDay tempEnd = end;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isWeekday ? 'เวลาทำการ จันทร์-ศุกร์' : 'เวลาทำการ เสาร์-อาทิตย์'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('เวลาเปิด'),
                    trailing: TextButton(
                      child: Text(tempStart.format(context)),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: tempStart,
                        );
                        if (picked != null) {
                          setDialogState(() => tempStart = picked);
                        }
                      },
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('เวลาปิด'),
                    trailing: TextButton(
                      child: Text(tempEnd.format(context)),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: tempEnd,
                        );
                        if (picked != null) {
                          setDialogState(() => tempEnd = picked);
                        }
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final formatted =
                        '${_fmt(tempStart)}-${_fmt(tempEnd)}';
                    Navigator.pop(context, formatted);
                  },
                  child: const Text('ตกลง'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        if (isWeekday) {
          _weekdayHours = result;
        } else {
          _weekendHours = result;
        }
      });
    }
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  TimeOfDay _parseTime(String hhmm) {
    final segments = hhmm.split(':');
    final h = int.tryParse(segments.isNotEmpty ? segments[0] : '') ?? 8;
    final m = int.tryParse(segments.length > 1 ? segments[1] : '') ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    if (_selectedImageBytes != null) {
      final photoResult = await ApiService.uploadAvatar(
        userId: widget.userData['id'],
        userType: 'repair',
        fileBytes: _selectedImageBytes!,
        fileName: _selectedImageName ?? 'garage.jpg',
        // หมายเหตุ: ตอนนี้ใช้ endpoint เดียวกับ uploadAvatar
        // ถ้า backend แยก endpoint รูปอู่ออกจากรูปโปรไฟล์ ให้เปลี่ยนมาเรียก endpoint นั้นแทน
      );

      if (!photoResult.success) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('อัปโหลดรูปไม่สำเร็จ: ${photoResult.message}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // หมายเหตุสำคัญ: ApiService.updateProfile ปัจจุบันรองรับแค่
    // name / phone / address / carModel / carPlate / userType
    // ส่วนเวลาทำการ (hours_weekday, hours_weekend) และบริการ (services)
    // ยังไม่มีพารามิเตอร์รองรับ — ต้องเพิ่มเมธอดใหม่ เช่น ApiService.updateGarageInfo(...)
    // ที่ backend เพื่อให้บันทึกค่าพวกนี้ได้จริง ตอนนี้ผมส่งเฉพาะฟิลด์ที่มีอยู่แล้วไปก่อน
    final result = await ApiService.updateProfile(
      userId: widget.userData['id'],
      name: _garageNameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      carModel: '',
      carPlate: '',
      userType: 'repair',
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );

    if (result.success) {
      Navigator.pop(context, {
        'success': true,
        'hours_weekday': _weekdayHours,
        'hours_weekend': _weekendHours,
        'services': _selectedServices.toList(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: const Text('แก้ไขข้อมูลอู่', style: TextStyle(color: Colors.white)),
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('รูปภาพอู่',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      _buildCoverImage(),

                      const SizedBox(height: 20),
                      const Text('ชื่ออู่',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _garageNameController,
                        decoration: profileInputDeco(
                            hint: 'ชื่ออู่ซ่อมรถ', icon: Icons.store_outlined),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'กรุณากรอกชื่ออู่' : null,
                      ),

                      const SizedBox(height: 16),
                      const Text('ที่อยู่',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: profileInputDeco(
                            hint: 'ที่อยู่อู่ซ่อมรถ',
                            icon: Icons.location_on_outlined),
                      ),

                      const SizedBox(height: 16),
                      const Text('เบอร์โทรศัพท์',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: profileInputDeco(
                            hint: '02-123-4567', icon: Icons.phone_outlined),
                      ),

                      const SizedBox(height: 16),
                      const Text('เวลาทำการ',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _HoursCard(
                              label: 'จ-ศ:',
                              value: _weekdayHours,
                              onTap: () => _editHours(isWeekday: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _HoursCard(
                              label: 'ส-อา:',
                              value: _weekendHours,
                              onTap: () => _editHours(isWeekday: false),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      const Text('บริการที่ให้บริการ',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: kGarageServiceOptions.map((service) {
                            final selected = _selectedServices.contains(service);
                            return FilterChip(
                              label: Text(service),
                              selected: selected,
                              showCheckmark: false,
                              avatar: selected
                                  ? const Icon(Icons.check, size: 16, color: Color(0xff2196F3))
                                  : null,
                              labelStyle: TextStyle(
                                color: selected ? const Color(0xff2196F3) : Colors.black87,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                              ),
                              backgroundColor: const Color(0xffF5F5F5),
                              selectedColor: const Color(0xffE3F2FD),
                              side: BorderSide(
                                color: selected ? const Color(0xff2196F3) : Colors.grey.shade300,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              onSelected: (value) {
                                setState(() {
                                  if (value) {
                                    _selectedServices.add(service);
                                  } else {
                                    _selectedServices.remove(service);
                                  }
                                });
                              },
                            );
                          }).toList(),
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
                                'ข้อมูลที่แก้ไขจะแสดงในโปรไฟล์อู่ของคุณทันที',
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
            ),

            // ปุ่มบันทึก ติดด้านล่างเสมอ
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))],
              ),
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff2196F3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, color: Colors.white),
                label: Text(
                  _isLoading ? 'กำลังบันทึก...' : 'บันทึกข้อมูล',
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

  Widget _buildCoverImage() {
    return GestureDetector(
      onTap: _handlePickCoverImage,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          height: 190,
          color: Colors.grey.shade300,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_coverImage != null)
                Image(image: _coverImage!, fit: BoxFit.cover)
              else
                Icon(Icons.image_outlined, size: 48, color: Colors.grey.shade500),
              Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xff2196F3).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('เปลี่ยนรูปภาพ',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ],
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
}

class _HoursCard extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _HoursCard({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  Text(value,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
