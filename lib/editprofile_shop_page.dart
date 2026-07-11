import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'profile_avatar_picker.dart'; // ใช้ pickProfileAvatar (bottom sheet เลือก/ถ่ายรูป) และ profileInputDeco ร่วมกัน
import 'address_picker_sheet.dart'; // ✅ ค้นหาที่อยู่แบบแชท + geocoding ฟรีผ่าน OpenStreetMap
import 'address_map_page.dart'; // ✅ หน้าแผนที่กลาง ใช้ได้ทั้งลูกค้าและอู่
import 'change_email_sheet.dart'; // ✅ เปลี่ยนอีเมลผ่าน OTP

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

/// หน้าแก้ไขข้อมูล "อู่ซ่อมรถ" แบบรวมเดียว
/// รวมทั้งข้อมูลส่วนตัว (ชื่อร้าน, เจ้าของร้าน, เบอร์, ที่อยู่, อีเมล, รูป)
/// และข้อมูลธุรกิจของอู่ (เวลาทำการ, บริการที่ให้บริการ) ไว้ในหน้าเดียว
/// เพื่อไม่ให้ผู้ใช้ต้องกรอกชื่อร้าน/ที่อยู่/เบอร์โทร/รูปซ้ำสองรอบ
class EditProfileShopPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileShopPage({super.key, required this.userData});

  @override
  State<EditProfileShopPage> createState() => _EditProfileShopPageState();
}

class _EditProfileShopPageState extends State<EditProfileShopPage> {
  final _formKey = GlobalKey<FormState>();

  // ===== ข้อมูลส่วนตัว / ร้าน (ใช้ร่วมกัน ไม่ซ้ำ) =====
  late TextEditingController _shopNameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;

  bool _isLoading = false;
  bool _emailChangedSuccessfully = false; // ✅ อีเมลถูกเปลี่ยนไปแล้วจริงใน DB แม้ยังไม่กด "บันทึกข้อมูล"
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  // ===== ข้อมูลธุรกิจของอู่ (ไม่มีฝั่งลูกค้า) =====
  String _weekdayHours = '08:00-18:00';
  String _weekendHours = '09:00-17:00';
  late Set<String> _selectedServices;

  // ===== พิกัดที่อยู่ (ได้จากการค้นหาที่อยู่แบบแชท) =====
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    final u = widget.userData;
    _shopNameController = TextEditingController(text: u['shop_name'] ?? '');
    _ownerNameController = TextEditingController(text: u['owner_name'] ?? '');
    _phoneController = TextEditingController(text: u['phone'] ?? '');
    _emailController = TextEditingController(text: u['email'] ?? '');
    _addressController = TextEditingController(text: u['address'] ?? '');

    _weekdayHours = u['hours_weekday'] ?? _weekdayHours;
    _weekendHours = u['hours_weekend'] ?? _weekendHours;

    final existingServices = u['services'];
    _selectedServices = existingServices is List
        ? existingServices.map((e) => e.toString()).toSet()
        : <String>{};

    _latitude = double.tryParse(u['latitude']?.toString() ?? '');
    _longitude = double.tryParse(u['longitude']?.toString() ?? '');
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // ✅ รูปเดียว ใช้ทั้งเป็นรูปโปรไฟล์และรูปอู่ (เดิมมี 2 ฟิลด์ซ้ำกัน: avatar กับ garage_photo)
  ImageProvider? get _shopImage {
    if (_selectedImageBytes != null) return MemoryImage(_selectedImageBytes!);
    final photoUrl = widget.userData['avatar'];
    if (photoUrl != null && photoUrl.toString().isNotEmpty) {
      return NetworkImage(photoUrl);
    }
    return null;
  }

  Future<void> _handlePickImage() async {
    final picked = await pickProfileAvatar(context);
    if (picked != null) {
      setState(() {
        _selectedImageBytes = picked.bytes;
        _selectedImageName = picked.name;
      });
    }
  }

  // ✅ เปิด chatbox ให้พิมพ์ที่อยู่ ค้นหาพิกัดให้อัตโนมัติ (ฟรี ไม่ใช้ Google API)
  Future<void> _handlePickAddress() async {
    final picked = await pickAddressViaChat(
      context,
      initialQuery: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
    );
    if (picked != null) {
      setState(() {
        _addressController.text = picked.address;
        _latitude = picked.latitude;
        _longitude = picked.longitude;
      });
    }
  }

  void _openAddressOnMap() {
    if (_latitude == null || _longitude == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddressMapPage(
          title: _shopNameController.text.trim().isEmpty
              ? 'อู่ซ่อมรถ'
              : _shopNameController.text.trim(),
          subtitle: _addressController.text.trim(),
          latitude: _latitude!,
          longitude: _longitude!,
        ),
      ),
    );
  }

  // ✅ เปิดขั้นตอนเปลี่ยนอีเมล (กรอกอีเมลใหม่ -> ยืนยัน OTP) แล้วอัปเดตช่องอีเมลทันทีเมื่อสำเร็จ
  // หมายเหตุ: อีเมลใหม่ถูกบันทึกลง DB ทันทีที่ยืนยัน OTP สำเร็จ (ไม่ต้องรอกด "บันทึกข้อมูล")
  Future<void> _handleChangeEmail() async {
    final newEmail = await showChangeEmailSheet(context, userId: widget.userData['id']);
    if (newEmail != null && mounted) {
      setState(() {
        _emailController.text = newEmail;
        _emailChangedSuccessfully = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เปลี่ยนอีเมลสำเร็จ'), backgroundColor: Colors.green),
      );
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
                    final formatted = '${_fmt(tempStart)}-${_fmt(tempEnd)}';
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
        fileName: _selectedImageName ?? 'shop.jpg',
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

    // ส่งข้อมูลไป backend ครบทุกฟิลด์แล้ว (name/phone/address ฟังก์ชันเดิม
    // + ownerName/hoursWeekday/hoursWeekend/services ที่เพิ่มใหม่ใน ApiService)
    // หมายเหตุ: ฝั่ง Express route + MySQL ต้องรองรับคีย์เหล่านี้ด้วย
    // ไม่งั้น backend จะรับค่ามาแต่ไม่บันทึกลงฐานข้อมูลจริง
    final result = await ApiService.updateProfile(
      userId: widget.userData['id'],
      name: _shopNameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      carModel: '',
      carPlate: '',
      userType: 'repair',
      ownerName: _ownerNameController.text.trim(),
      hoursWeekday: _weekdayHours,
      hoursWeekend: _weekendHours,
      services: _selectedServices.toList(),
      latitude: _latitude,
      longitude: _longitude,
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
        'owner_name': _ownerNameController.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
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
          onPressed: () => Navigator.pop(
            context,
            _emailChangedSuccessfully ? {'success': true} : null,
          ),
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
                      // ===== รูปภาพ (ใช้ทั้งเป็นรูปโปรไฟล์และรูปอู่ — เหลือรูปเดียว) =====
                      const Text('รูปภาพอู่',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      _buildCoverImage(),

                      const SizedBox(height: 20),
                      const Text('ชื่ออู่',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _shopNameController,
                        decoration:
                            profileInputDeco(hint: 'ชื่ออู่ซ่อมรถ', icon: Icons.store_outlined),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'กรุณากรอกชื่ออู่' : null,
                      ),

                      const SizedBox(height: 16),
                      const Text('ชื่อเจ้าของร้าน',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _ownerNameController,
                        decoration: profileInputDeco(
                            hint: 'ชื่อ-นามสกุลเจ้าของร้าน', icon: Icons.person_outline),
                      ),

                      const SizedBox(height: 16),
                      const Text('เบอร์โทรศัพท์',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration:
                            profileInputDeco(hint: '02-123-4567', icon: Icons.phone_outlined),
                      ),

                      const SizedBox(height: 16),
                      const Text('ที่อยู่',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: profileInputDeco(
                            hint: 'ที่อยู่อู่ซ่อมรถ', icon: Icons.location_on_outlined),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _handlePickAddress,
                              icon: const Icon(Icons.chat_bubble_outline, size: 18),
                              label: const Text('ค้นหาที่อยู่/พิกัด'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xff2196F3),
                                side: const BorderSide(color: Color(0xff2196F3)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _latitude != null && _longitude != null
                                  ? _openAddressOnMap
                                  : null,
                              icon: const Icon(Icons.map_outlined, size: 18),
                              label: const Text('ดูบนแผนที่'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey.shade700,
                                side: BorderSide(color: Colors.grey.shade400),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      const Text('อีเมล',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        readOnly: true,
                        onTap: _handleChangeEmail,
                        decoration: profileInputDeco(
                          hint: 'example@email.com',
                          icon: Icons.email_outlined,
                        ).copyWith(
                          suffixIcon: TextButton(
                            onPressed: _handleChangeEmail,
                            child: const Text('เปลี่ยน'),
                          ),
                        ),
                      ),

                      // ===== ข้อมูลธุรกิจของอู่ (ไม่มีในฝั่งลูกค้า) =====
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
      onTap: _handlePickImage,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          height: 190,
          color: Colors.grey.shade300,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_shopImage != null)
                Image(image: _shopImage!, fit: BoxFit.cover)
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