import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// ผลลัพธ์จากการเลือกรูป (bytes รองรับทั้ง Web และมือถือ)
class PickedAvatar {
  final Uint8List bytes;
  final String name;
  const PickedAvatar({required this.bytes, required this.name});
}

/// เปิด bottom sheet ให้เลือกรูปจากคลัง หรือถ่ายรูปใหม่
/// คืนค่า null ถ้าผู้ใช้ไม่ได้เลือกรูป
Future<PickedAvatar?> pickProfileAvatar(BuildContext context) async {
  return showModalBottomSheet<PickedAvatar>(
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
              final picker = ImagePicker();
              final picked = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 80,
              );
              if (picked != null) {
                final bytes = await picked.readAsBytes();
                if (context.mounted) {
                  Navigator.pop(
                    context,
                    PickedAvatar(bytes: bytes, name: picked.name),
                  );
                }
              } else if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.blue),
            title: const Text('ถ่ายรูป'),
            onTap: () async {
              final picker = ImagePicker();
              final picked = await picker.pickImage(
                source: ImageSource.camera,
                imageQuality: 80,
              );
              if (picked != null) {
                final bytes = await picked.readAsBytes();
                if (context.mounted) {
                  Navigator.pop(
                    context,
                    PickedAvatar(bytes: bytes, name: picked.name),
                  );
                }
              } else if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    ),
  );
}

/// วิดเจ็ตแสดงรูปโปรไฟล์วงกลม พร้อมปุ่มกล้องมุมขวาล่าง แตะเพื่อเปลี่ยนรูป
/// ใช้ร่วมกันทั้งหน้าลูกค้าและหน้าอู่ซ่อม
class ProfileAvatarPicker extends StatelessWidget {
  final ImageProvider? imageProvider;
  final String displayInitial;
  final VoidCallback onTap;

  const ProfileAvatarPicker({
    super.key,
    required this.imageProvider,
    required this.displayInitial,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageProvider != null;

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xff2196F3),
                  backgroundImage: imageProvider,
                  child: !hasImage
                      ? Text(
                          displayInitial,
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
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'เปลี่ยนรูปโปรไฟล์',
            style: TextStyle(color: Color(0xff2196F3), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// กล่อง input style กลาง ใช้ร่วมกันทั้งสองฟอร์ม
InputDecoration profileInputDeco({required String hint, required IconData icon}) {
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
