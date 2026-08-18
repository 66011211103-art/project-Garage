import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'profile_avatar_picker.dart'; // ใช้ pickProfileAvatar (bottom sheet เลือก/ถ่ายรูป) และ profileInputDeco ร่วมกัน
import 'address_picker_sheet.dart'; // ✅ ค้นหาที่อยู่แบบแชท + geocoding ฟรีผ่าน OpenStreetMap
import 'address_map_page.dart'; // ✅ หน้าแผนที่กลาง ใช้ได้ทั้งลูกค้าและอู่
import 'change_email_sheet.dart'; // ✅ เปลี่ยนอีเมลผ่าน OTP

/// หมวดบริการมาตรฐาน — ใช้เป็นตัวเลือก "หมวด" ในฟอร์มเพิ่ม/แก้ไขบริการ และเป็นปุ่มเพิ่มด่วนด้านบน
/// ส่วนชื่อเฉพาะของแต่ละบริการ (เช่น "เปลี่ยนน้ำมันเครื่อง") อู่ยังพิมพ์เองได้อิสระเสมอ
/// 'อื่นๆ' ไว้รองรับบริการที่ไม่เข้าหมวดไหนเลย และรองรับข้อมูลเก่าก่อนแยกหมวด/ชื่อบริการออกจากกัน
const List<String> kGarageCategories = [
  'เครื่องยนต์',
  'เบรก',
  'ช่วงล่าง',
  'ยางและล้อ',
  'แบตเตอรี่',
  'ระบบไฟฟ้า',
  'แอร์รถยนต์',
  'ตัวถังและสี',
  'บริการฉุกเฉิน',
  'อื่นๆ',
];
const String kGarageOtherCategory = 'อื่นๆ';

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
  // ✅ อู่เพิ่ม/ลบ/แก้ไข/จัดลำดับ "บริการ" ของตัวเองได้อิสระ ผ่านฟอร์มเพิ่ม/แก้ไขแบบ bottom sheet
  // แต่ละรายการมีหมวดบริการ (เลือกจากรายการมาตรฐาน) + ชื่อบริการเฉพาะ (พิมพ์อิสระ) +
  // ช่วงราคาโดยประมาณ + รายละเอียดเพิ่มเติม + สวิตช์เปิด/ปิดการแสดงผล เก็บเป็น List<Map> ส่งไป backend
  late List<_ServiceEntry> _services;

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
    _services = [];
    if (existingServices is List) {
      for (final item in existingServices) {
        if (item is Map) {
          final name = item['name']?.toString().trim() ?? '';
          if (name.isEmpty) continue;

          // ✅ รองรับข้อมูลเก่าก่อนแยก "หมวด" ออกจาก "ชื่อบริการ" — ถ้าไม่มีหมวด/หมวดไม่ตรงรายการ
          // มาตรฐาน ให้ลองจับคู่ชื่อเดิมกับหมวดที่ตรงกันพอดี ไม่งั้น fallback เป็น 'อื่นๆ'
          var category = item['category']?.toString() ?? '';
          if (!kGarageCategories.contains(category)) {
            category = kGarageCategories.firstWhere(
              (c) => c.toLowerCase() == name.toLowerCase(),
              orElse: () => kGarageOtherCategory,
            );
          }

          // ✅ รองรับข้อมูลเก่าที่เก็บราคาเป็นข้อความอิสระช่องเดียว (price) แทนช่วงต่ำสุด-สูงสุด
          var priceMin = item['priceMin']?.toString().trim() ?? '';
          var priceMax = item['priceMax']?.toString().trim() ?? '';
          if (priceMin.isEmpty && priceMax.isEmpty) {
            final legacyPrice = item['price']?.toString().trim() ?? '';
            if (legacyPrice.isNotEmpty) {
              final parts = legacyPrice.split('-');
              final lo = parts.isNotEmpty ? double.tryParse(parts[0].trim()) : null;
              final hi = parts.length > 1 ? double.tryParse(parts[1].trim()) : null;
              if (lo != null && hi != null) {
                priceMin = parts[0].trim();
                priceMax = parts[1].trim();
              } else {
                // พิมพ์ไว้แบบข้อความอิสระ (เช่น "เริ่มต้น 500 บาท") เก็บไว้ในช่องราคาต่ำสุดไปก่อน
                priceMin = legacyPrice;
              }
            }
          }

          // ✅ ข้อมูลเก่าไม่มีฟิลด์นี้ -> ถือว่าเปิดใช้งานอยู่เสมอ กันบริการเดิมหายไปจากโปรไฟล์ทันที
          final active = item['active'] is bool ? item['active'] as bool : true;

          _services.add(_ServiceEntry(
            category: category,
            name: name,
            priceMin: priceMin,
            priceMax: priceMax,
            details: item['details']?.toString() ?? '',
            active: active,
          ));
        } else {
          final name = item.toString().trim();
          if (name.isEmpty) continue;
          final category = kGarageCategories.firstWhere(
            (c) => c.toLowerCase() == name.toLowerCase(),
            orElse: () => kGarageOtherCategory,
          );
          _services.add(_ServiceEntry(category: category, name: name));
        }
      }
    }

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

  void _removeService(int index) {
    setState(() => _services.removeAt(index));
  }

  // ✅ ข้อความช่วงราคาที่จะโชว์ในการ์ดรายการ — รองรับกรณีมีแค่ค่าเดียว หรือไม่มีเลย
  String _priceLabel(_ServiceEntry s) {
    final min = s.priceMin.trim();
    final max = s.priceMax.trim();
    if (min.isEmpty && max.isEmpty) return '';
    if (min.isNotEmpty && max.isNotEmpty && min != max) return '$min - $max บาท';
    return '${min.isNotEmpty ? min : max} บาท';
  }

  // ✅ เปิดฟอร์มเพิ่ม/แก้ไขบริการแบบ bottom sheet
  // editIndex != null = แก้ไขรายการเดิม (แก้ทับ object เดิมเพื่อให้ key ตอน reorder ยังนิ่งอยู่)
  // presetCategory = พรีฟิลหมวดไว้ล่วงหน้า เผื่อเปิดจากปุ่มเพิ่มด่วนของหมวดนั้น
  Future<void> _openServiceForm({int? editIndex, String? presetCategory}) async {
    final existing = editIndex != null ? _services[editIndex] : null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final minCtrl = TextEditingController(text: existing?.priceMin ?? '');
    final maxCtrl = TextEditingController(text: existing?.priceMax ?? '');
    final detailsCtrl = TextEditingController(text: existing?.details ?? '');
    String category = existing?.category ?? presetCategory ?? kGarageCategories.first;
    bool active = existing?.active ?? true;
    final formKey = GlobalKey<FormState>();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            existing != null ? 'แก้ไขบริการ' : 'เพิ่มบริการใหม่',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(sheetContext, false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('เลือกหมวดบริการ',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: category,
                        items: kGarageCategories
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF5F6FA),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (v) => setSheetState(() => category = v ?? category),
                      ),
                      const SizedBox(height: 14),
                      const Text('ชื่อบริการ',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: profileInputDeco(
                            hint: 'เช่น เปลี่ยนน้ำมันเครื่อง', icon: Icons.build_outlined),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'กรุณากรอกชื่อบริการ' : null,
                      ),
                      const SizedBox(height: 14),
                      const Text('ราคาโดยประมาณ (บาท)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: minCtrl,
                              keyboardType: TextInputType.number,
                              decoration: profileInputDeco(
                                  hint: 'ราคาต่ำสุด', icon: Icons.sell_outlined),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('-'),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: maxCtrl,
                              keyboardType: TextInputType.number,
                              decoration: profileInputDeco(
                                  hint: 'ราคาสูงสุด', icon: Icons.sell_outlined),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ใส่เฉพาะตัวเลข เช่น 800 กับ 1,500 (เว้นว่างได้ถ้ายังไม่ระบุราคา)',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 14),
                      const Text('รายละเอียดเพิ่มเติม (ไม่บังคับ)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: detailsCtrl,
                        maxLines: 2,
                        decoration: profileInputDeco(
                            hint: 'เช่น รองรับรถเก๋งและรถกระบะ', icon: Icons.notes_outlined),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('เปิดให้บริการ',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          Switch(
                            value: active,
                            activeColor: const Color(0xff2196F3),
                            onChanged: (v) => setSheetState(() => active = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (!(formKey.currentState?.validate() ?? false)) return;
                            Navigator.pop(sheetContext, true);
                          },
                          icon: const Icon(Icons.save_outlined, color: Colors.white),
                          label: const Text('บันทึกบริการ',
                              style:
                                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff2196F3),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (saved == true) {
      setState(() {
        if (existing != null) {
          existing
            ..category = category
            ..name = nameCtrl.text.trim()
            ..priceMin = minCtrl.text.trim()
            ..priceMax = maxCtrl.text.trim()
            ..details = detailsCtrl.text.trim()
            ..active = active;
        } else {
          _services.add(_ServiceEntry(
            category: category,
            name: nameCtrl.text.trim(),
            priceMin: minCtrl.text.trim(),
            priceMax: maxCtrl.text.trim(),
            details: detailsCtrl.text.trim(),
            active: active,
          ));
        }
      });
    }

    // ⚠️ ห้าม dispose() ตรงนี้ทันที — showModalBottomSheet คืนค่ากลับมาตอนที่ route ถูก pop
    // แล้ว แต่ตัว sheet ยังอยู่ระหว่างเล่นแอนิเมชันปิด (เลื่อนลง) จึงยังมี TextFormField
    // อ้างอิง controller พวกนี้อยู่ ถ้า dispose ทันทีจะเจอ "used after being disposed"
    // กลางแอนิเมชัน (บั๊กที่เจอ) ปล่อยให้ garbage collector เก็บทีหลังแทน ปลอดภัยกว่า
    // เพราะ controller ระยะสั้นพวกนี้ไม่ได้ผูก listener ค้างไว้ที่ไหน
  }

  // ✅ แปลงเป็น List<Map> พร้อมส่งไป backend (เก็บครบทุกฟิลด์ใหม่ backend เก็บเป็น JSON blob อยู่แล้ว)
  List<Map<String, dynamic>> get _servicesWithPrices =>
      _services.map((s) => s.toJson()).toList();

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
      services: _servicesWithPrices,
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
        'services': _servicesWithPrices,
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
                      const SizedBox(height: 4),
                      Text(
                        'เพิ่มบริการของอู่เอง พร้อมราคาโดยประมาณ — ลูกค้าจะเห็นเฉพาะบริการที่เปิดให้บริการเท่านั้น',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 10),

                      // ✅ ปุ่มหมวดบริการ — แตะเพื่อเปิดฟอร์มเพิ่มบริการโดยพรีฟิลหมวดนั้นไว้ล่วงหน้า
                      // (ไม่มีไอคอน/รูปประกอบ ใช้ข้อความล้วนตามที่ขอ)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: kGarageCategories.map((category) {
                          return OutlinedButton(
                            onPressed: () => _openServiceForm(presetCategory: category),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xff2196F3),
                              backgroundColor: const Color(0xffE3F2FD),
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(category,
                                style:
                                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 16),

                      if (_services.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.build_outlined, color: Colors.grey.shade400, size: 28),
                              const SizedBox(height: 8),
                              Text(
                                'ยังไม่มีบริการ — กด "เพิ่มบริการใหม่" ด้านล่าง หรือแตะหมวดบริการด้านบน',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        Text('บริการที่เพิ่มแล้ว (${_services.length})',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          itemCount: _services.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final item = _services.removeAt(oldIndex);
                              _services.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (context, index) {
                            final s = _services[index];
                            final priceLabel = _priceLabel(s);
                            return Container(
                              key: ObjectKey(s),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 10),
                                      child: Icon(Icons.drag_handle, color: Colors.grey.shade400),
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                s.name,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w600, fontSize: 15),
                                              ),
                                            ),
                                            if (!s.active)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade200,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text('ปิดใช้งาน',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey.shade600)),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(s.category,
                                            style: TextStyle(
                                                fontSize: 12.5, color: Colors.grey.shade600)),
                                        if (priceLabel.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(priceLabel,
                                              style: const TextStyle(
                                                  color: Color(0xff2196F3),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13)),
                                        ],
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 20, color: Color(0xff2196F3)),
                                    tooltip: 'แก้ไขบริการนี้',
                                    onPressed: () => _openServiceForm(editIndex: index),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        size: 20, color: Colors.red.shade400),
                                    tooltip: 'ลบบริการนี้',
                                    onPressed: () => _removeService(index),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                      ],

                      OutlinedButton.icon(
                        onPressed: () => _openServiceForm(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('เพิ่มบริการใหม่'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xff2196F3),
                          side: const BorderSide(color: Color(0xff2196F3)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

/// บริการหนึ่งรายการที่อู่กำหนดเอง — แก้ไขผ่านฟอร์ม bottom sheet เท่านั้น (ไม่มี controller
/// ค้างอยู่ในลิสต์หลัก) ฟิลด์ไม่ final เพราะแก้ไขทับ object เดิมตอนกด "แก้ไข" เพื่อให้
/// ObjectKey ที่ใช้กับ ReorderableListView ยังนิ่งอยู่ ไม่กระพริบ/สลับตำแหน่งตอนแก้ไข
class _ServiceEntry {
  String category;
  String name;
  String priceMin;
  String priceMax;
  String details;
  bool active;

  _ServiceEntry({
    required this.category,
    required this.name,
    this.priceMin = '',
    this.priceMax = '',
    this.details = '',
    this.active = true,
  });

  Map<String, dynamic> toJson() => {
        'category': category,
        'name': name,
        'priceMin': priceMin,
        'priceMax': priceMax,
        'details': details,
        'active': active,
      };
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