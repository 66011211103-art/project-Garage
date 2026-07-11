import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'profile_avatar_picker.dart';

/// หน้าแก้ไขข้อมูลส่วนตัวสำหรับ "อู่ซ่อมรถ"
class EditProfileShopPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileShopPage({super.key, required this.userData});

  @override
  State<EditProfileShopPage> createState() => _EditProfileShopPageState();
}

class _EditProfileShopPageState extends State<EditProfileShopPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _shopNameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;

  bool _isLoading = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  @override
  void initState() {
    super.initState();
    final u = widget.userData;
    _shopNameController = TextEditingController(text: u['shop_name'] ?? '');
    _ownerNameController = TextEditingController(text: u['owner_name'] ?? '');
    _phoneController = TextEditingController(text: u['phone'] ?? '');
    _emailController = TextEditingController(text: u['email'] ?? '');
    _addressController = TextEditingController(text: u['address'] ?? '');
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

  String get _displayInitial {
    final name = _shopNameController.text;
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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    if (_selectedImageBytes != null) {
      final avatarResult = await ApiService.uploadAvatar(
        userId: widget.userData['id'],
        userType: 'repair',
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

    final result = await ApiService.updateProfile(
      userId: widget.userData['id'],
      name: _shopNameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      carModel: '',
      carPlate: '',
      userType: 'repair',
      // หมายเหตุ: ถ้า ApiService.updateProfile ยังไม่รองรับพารามิเตอร์ owner_name
      // ให้เพิ่มพารามิเตอร์นั้นใน ApiService ก่อน แล้วส่ง _ownerNameController.text.trim() ต่อ
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
        title: const Text('แก้ไขโปรไฟล์ร้าน', style: TextStyle(color: Colors.white)),
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

                const Text('ชื่อร้านอู่ซ่อมรถ'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _shopNameController,
                  onChanged: (_) => setState(() {}),
                  decoration:
                      profileInputDeco(hint: 'ชื่อร้าน', icon: Icons.store_outlined),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'กรุณากรอกชื่อร้าน' : null,
                ),

                const SizedBox(height: 16),

                const Text('ชื่อเจ้าของร้าน'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _ownerNameController,
                  decoration: profileInputDeco(
                      hint: 'ชื่อ-นามสกุลเจ้าของร้าน',
                      icon: Icons.person_outline),
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

                const Text('ที่อยู่ร้าน'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: profileInputDeco(
                      hint: 'ที่อยู่ร้านอู่ซ่อม',
                      icon: Icons.location_on_outlined),
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
