import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';
import 'app_locale.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfilePage({super.key, required this.userData});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _shopNameController; // ใช้เมื่อเป็นอู่ (repair)
  late TextEditingController _firstNameController; // ใช้เมื่อเป็นลูกค้า
  late TextEditingController _lastNameController; // ใช้เมื่อเป็นลูกค้า
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  bool _isLoading = false;
  Uint8List? _selectedImageBytes; // ✅ ใช้ bytes แทน File เพื่อรองรับทั้ง Web และมือถือ
  String? _selectedImageName;

  @override
  void initState() {
    super.initState();
    AppLocale.instance.addListener(_onLocaleChanged);
    final u = widget.userData;
    _shopNameController = TextEditingController(text: u['shop_name'] ?? '');
    _firstNameController = TextEditingController(text: u['first_name'] ?? '');
    _lastNameController = TextEditingController(text: u['last_name'] ?? '');
    _phoneController = TextEditingController(text: u['phone'] ?? '');
    _emailController = TextEditingController(text: u['email'] ?? '');
  }

  @override
  void dispose() {
    AppLocale.instance.removeListener(_onLocaleChanged);
    _shopNameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  String get _displayInitial {
    final isRepair = widget.userData['userType'] == 'repair';
    final name = isRepair ? _shopNameController.text : _firstNameController.text;
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // ✅ แก้บัค: ห่อด้วย Material(color: Colors.white) กัน ListTile ขึ้น
      // warning เรื่อง ink splash อาจมองไม่เห็น ตอนกดใน showModalBottomSheet
      builder: (context) => Material(
        color: Colors.white,
        child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocale.instance.t('pap_sheet_title'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: Text(AppLocale.instance.t('pap_pick_gallery')),
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final picked = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 80,
                );
                if (picked != null) {
                  final bytes = await picked.readAsBytes(); // ✅ ใช้ได้ทั้ง Web และมือถือ
                  setState(() {
                    _selectedImageBytes = bytes;
                    _selectedImageName = picked.name;
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: Text(AppLocale.instance.t('pap_take_photo')),
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final picked = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                );
                if (picked != null) {
                  final bytes = await picked.readAsBytes(); // ✅ ใช้ได้ทั้ง Web และมือถือ
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
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    if (_selectedImageBytes != null) {
      final avatarResult = await ApiService.uploadAvatar(
        userId: widget.userData['id'],
        userType: widget.userData['userType'] ?? 'customer',
        fileBytes: _selectedImageBytes!,
        fileName: _selectedImageName ?? 'avatar.jpg',
      );

      if (!avatarResult.success) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocale.instance.t('ep_avatar_upload_failed').replaceAll('%s', avatarResult.message)),
            backgroundColor: Colors.red,
          ),
        );
        return; // หยุดตรงนี้ ไม่ต้องไปต่อ updateProfile ถ้ารูปพัง
      }
    }

    final isRepair = widget.userData['userType'] == 'repair';
    final nameToSend = isRepair
        ? _shopNameController.text.trim()
        : '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'.trim();

    final result = await ApiService.updateProfile(
      userId: widget.userData['id'],
      name: nameToSend,
      phone: _phoneController.text.trim(),
      address: '',
      carModel: '',
      carPlate: '',
      userType: widget.userData['userType'] ?? 'customer',
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

  // ✅ กำหนด backgroundImage ให้ถูกต้อง (รองรับทั้ง Web และมือถือ)
  ImageProvider? get _avatarImage {
    if (_selectedImageBytes != null) return MemoryImage(_selectedImageBytes!);
    final avatarUrl = widget.userData['avatar'];
    if (avatarUrl != null && avatarUrl.toString().isNotEmpty) {
      return NetworkImage(avatarUrl);
    }
    return null;
  }

  bool get _hasImage => _avatarImage != null;

  @override
  Widget build(BuildContext context) {
    final isRepair = widget.userData['userType'] == 'repair';
    final loc = AppLocale.instance;

    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: Text(loc.t('ep_page_title'), style: const TextStyle(color: Colors.white)),
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

                // ===== รูปโปรไฟล์ =====
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
                              backgroundImage: _avatarImage, // ✅ แสดงรูปเดิมหรือรูปที่เลือกใหม่
                              child: !_hasImage
                                  ? Text(
                                      _displayInitial,
                                      style: const TextStyle(
                                        fontSize: 40,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xff1976D2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loc.t('pap_change_photo'),
                        style: const TextStyle(color: Color(0xff2196F3), fontSize: 14),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                if (isRepair) ...[
                  Text(loc.t('reg_shop_name_label')),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _shopNameController,
                    onChanged: (_) => setState(() {}),
                    decoration: _inputDeco(hint: loc.t('ep_shop_name_hint'), icon: Icons.store_outlined),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? loc.t('reg_shop_name_required') : null,
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc.t('reg_first_name_label')),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _firstNameController,
                              onChanged: (_) => setState(() {}),
                              decoration: _inputDeco(hint: loc.t('reg_first_name_label'), icon: Icons.person_outline),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? loc.t('reg_first_name_required') : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc.t('reg_last_name_label')),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _lastNameController,
                              decoration: _inputDeco(hint: loc.t('reg_last_name_label'), icon: Icons.person_outline),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? loc.t('reg_last_name_required') : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                Text(loc.t('reg_phone_label')),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration:
                      _inputDeco(hint: '089-123-4567', icon: Icons.phone_outlined),
                ),

                const SizedBox(height: 16),

                Text(loc.t('auth_email_label')),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  readOnly: true,
                  decoration: _inputDeco(
                    hint: 'example@email.com',
                    icon: Icons.email_outlined,
                  ).copyWith(
                    fillColor: const Color(0xFFEEEEEE),
                    suffixIcon: const Icon(Icons.lock_outline, color: Colors.grey, size: 18),
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
                        child: Text(loc.t('cancel'),
                            style: const TextStyle(color: Colors.grey, fontSize: 16)),
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
                            : Text(
                                loc.t('ep_save_changes_button'),
                                style: const TextStyle(
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