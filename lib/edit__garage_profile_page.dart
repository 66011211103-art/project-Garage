import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';

class EditGarageProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditGarageProfilePage({super.key, required this.userData});

  @override
  State<EditGarageProfilePage> createState() => _EditGarageProfilePageState();
}

class _EditGarageProfilePageState extends State<EditGarageProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _shopNameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _openTimeController;
  late TextEditingController _closeTimeController;

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
    _openTimeController = TextEditingController(text: u['open_time'] ?? '08:00');
    _closeTimeController = TextEditingController(text: u['close_time'] ?? '18:00');
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _openTimeController.dispose();
    _closeTimeController.dispose();
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

  bool get _hasImage => _avatarImage != null;

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('เลือกรูปโปรไฟล์',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('เลือกจากคลังรูป'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await ImagePicker().pickImage(
                  source: ImageSource.gallery, imageQuality: 80);
                if (picked != null) {
                  final bytes = await picked.readAsBytes();
                  setState(() {
                    _selectedImageBytes = bytes;
                    _selectedImageName = picked.name;
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('ถ่ายรูป'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await ImagePicker().pickImage(
                  source: ImageSource.camera, imageQuality: 80);
                if (picked != null) {
                  final bytes = await picked.readAsBytes();
                  setState(() {
                    _selectedImageBytes = bytes;
                    _selectedImageName = picked.name;
                  });
                }
              },
            ),
          ],
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
        userType: 'repair',
        fileBytes: _selectedImageBytes!,
        fileName: _selectedImageName ?? 'avatar.jpg',
      );
      if (!avatarResult.success) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อัปโหลดรูปไม่สำเร็จ: ${avatarResult.message}'),
              backgroundColor: Colors.red),
        );
        return;
      }
    }

    final result = await ApiService.updateGarageProfile(
      userId: widget.userData['id'],
      shopName: _shopNameController.text.trim(),
      ownerName: _ownerNameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      openTime: _openTimeController.text.trim(),
      closeTime: _closeTimeController.text.trim(),
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

  InputDecoration _inputDeco({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFFF5F6FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: const Text('แก้ไขข้อมูลอู่ซ่อม', style: TextStyle(color: Colors.white)),
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

                // รูปโปรไฟล์
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: const Color(0xff2196F3),
                              backgroundImage: _avatarImage,
                              child: !_hasImage
                                  ? Text(_displayInitial,
                                      style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold))
                                  : null,
                            ),
                            Positioned(
                              bottom: 0, right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(color: Color(0xff1976D2), shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('เปลี่ยนรูปโปรไฟล์', style: TextStyle(color: Color(0xff2196F3), fontSize: 14)),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                const Text('ชื่อร้านอู่ซ่อมรถ'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _shopNameController,
                  onChanged: (_) => setState(() {}),
                  decoration: _inputDeco(hint: 'ชื่อร้าน', icon: Icons.store_outlined),
                  validator: (v) => v == null || v.trim().isEmpty ? 'กรุณากรอกชื่อร้าน' : null,
                ),

                const SizedBox(height: 16),
                const Text('ชื่อเจ้าของอู่'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _ownerNameController,
                  decoration: _inputDeco(hint: 'ชื่อ-นามสกุล', icon: Icons.person_outline),
                  validator: (v) => v == null || v.trim().isEmpty ? 'กรุณากรอกชื่อเจ้าของ' : null,
                ),

                const SizedBox(height: 16),
                const Text('เบอร์โทรศัพท์'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDeco(hint: '089-123-4567', icon: Icons.phone_outlined),
                ),

                const SizedBox(height: 16),
                const Text('อีเมล'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  readOnly: true,
                  decoration: _inputDeco(hint: 'example@email.com', icon: Icons.email_outlined)
                      .copyWith(fillColor: const Color(0xFFEEEEEE),
                          suffixIcon: const Icon(Icons.lock_outline, color: Colors.grey, size: 18)),
                ),

                const SizedBox(height: 16),
                const Text('ที่อยู่อู่ซ่อม'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: _inputDeco(hint: '123 ถนน...', icon: Icons.location_on_outlined),
                ),

                const SizedBox(height: 16),
                const Text('เวลาทำการ'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('เปิด', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _openTimeController,
                            decoration: _inputDeco(hint: '08:00', icon: Icons.access_time),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ปิด', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _closeTimeController,
                            decoration: _inputDeco(hint: '18:00', icon: Icons.access_time_filled),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                        child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey, fontSize: 16)),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('บันทึกการเปลี่ยนแปลง',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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