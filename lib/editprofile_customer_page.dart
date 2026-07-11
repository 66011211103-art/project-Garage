import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'profile_avatar_picker.dart';
import 'address_picker_sheet.dart'; // ✅ ค้นหาที่อยู่แบบแชท + geocoding ฟรีผ่าน OpenStreetMap
import 'address_map_page.dart'; // ✅ หน้าแผนที่กลาง ใช้ได้ทั้งลูกค้าและอู่

/// หน้าแก้ไขข้อมูลส่วนตัวสำหรับ "ลูกค้า"
class EditProfileCustomerPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileCustomerPage({super.key, required this.userData});

  @override
  State<EditProfileCustomerPage> createState() =>
      _EditProfileCustomerPageState();
}

class _EditProfileCustomerPageState extends State<EditProfileCustomerPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;

  bool _isLoading = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  // ===== พิกัดที่อยู่ (ได้จากการค้นหาที่อยู่แบบแชท) =====
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    final u = widget.userData;
    _firstNameController = TextEditingController(text: u['first_name'] ?? '');
    _lastNameController = TextEditingController(text: u['last_name'] ?? '');
    _phoneController = TextEditingController(text: u['phone'] ?? '');
    _emailController = TextEditingController(text: u['email'] ?? '');
    _addressController = TextEditingController(text: u['address'] ?? '');

    _latitude = double.tryParse(u['latitude']?.toString() ?? '');
    _longitude = double.tryParse(u['longitude']?.toString() ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String get _displayInitial {
    final name = _firstNameController.text;
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  ImageProvider? get _avatarImage {
    if (_selectedImageBytes != null) return MemoryImage(_selectedImageBytes!);
    final avatarUrl = widget.userData['avatar'];
    if (avatarUrl != null && avatarUrl.toString().isNotEmpty) {
      return NetworkImage(avatarUrl);
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
    final name =
        '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
            .trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddressMapPage(
          title: name.isEmpty ? 'ที่อยู่ของฉัน' : name,
          subtitle: _addressController.text.trim(),
          latitude: _latitude!,
          longitude: _longitude!,
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    if (_selectedImageBytes != null) {
      final avatarResult = await ApiService.uploadAvatar(
        userId: widget.userData['id'],
        userType: 'customer',
        fileBytes: _selectedImageBytes!,
        fileName: _selectedImageName ?? 'avatar.jpg',
      );

      if (!avatarResult.success) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('อัปโหลดรูปไม่สำเร็จ: ${avatarResult.message}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final nameToSend =
        '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
            .trim();

    final result = await ApiService.updateProfile(
      userId: widget.userData['id'],
      name: nameToSend,
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      carModel: '',
      carPlate: '',
      userType: 'customer',
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

    if (result.success) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: const Text('แก้ไขโปรไฟล์', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfileAvatarPicker(
                  imageProvider: _avatarImage,
                  displayInitial: _displayInitial,
                  onTap: _handlePickImage,
                ),

                const SizedBox(height: 24),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ชื่อ'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _firstNameController,
                            onChanged: (_) => setState(() {}),
                            decoration: profileInputDeco(
                                hint: 'ชื่อ', icon: Icons.person_outline),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'กรุณากรอกชื่อ'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('นามสกุล'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _lastNameController,
                            decoration: profileInputDeco(
                                hint: 'นามสกุล', icon: Icons.person_outline),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'กรุณากรอกนามสกุล'
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                const Text('เบอร์โทรศัพท์'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: profileInputDeco(
                      hint: '089-123-4567', icon: Icons.phone_outlined),
                ),

                const SizedBox(height: 16),

                const Text('ที่อยู่'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: profileInputDeco(
                      hint: 'ที่อยู่สำหรับติดต่อ',
                      icon: Icons.location_on_outlined),
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

                const Text('อีเมล'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  readOnly: true,
                  decoration: profileInputDeco(
                    hint: 'example@email.com',
                    icon: Icons.email_outlined,
                  ).copyWith(
                    fillColor: const Color(0xFFEEEEEE),
                    suffixIcon:
                        const Icon(Icons.lock_outline, color: Colors.grey, size: 18),
                  ),
                ),

                const SizedBox(height: 32),

                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Colors.grey),
                          ),
                        ),
                        child: const Text('ยกเลิก',
                            style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff2196F3),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'บันทึกการเปลี่ยนแปลง',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}